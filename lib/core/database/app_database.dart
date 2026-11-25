import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// Satu baris barang yang akan dijual (dari keranjang).
class SaleLine {
  const SaleLine({
    required this.productId,
    required this.productName,
    required this.price,
    required this.costPrice,
    required this.qty,
  });

  final String productId;
  final String productName;
  final int price;
  final int costPrice;
  final int qty;
}

@DriftDatabase(tables: [
  Categories,
  Products,
  Transactions,
  TransactionItems,
  StockMovements,
  SyncQueue,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() => driftDatabase(name: 'kasirku');

  // ================= Kategori =================

  Stream<List<ProductCategory>> watchCategories() {
    return (select(categories)
          ..where((c) => c.deletedAt.isNull())
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .watch();
  }

  Future<ProductCategory> addCategory({required String storeId, required String name}) {
    return transaction(() async {
      final category = await into(categories).insertReturning(
        CategoriesCompanion.insert(storeId: storeId, name: name),
      );
      await _enqueue('categories', category.id, 'upsert', category.toJson());
      return category;
    });
  }

  // ================= Produk =================

  Stream<List<Product>> watchProducts() {
    return (select(products)
          ..where((p) => p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .watch();
  }

  Future<Product?> getProduct(String id) {
    return (select(products)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Future<Product?> findByBarcode(String barcode) {
    return (select(products)..where((p) => p.barcode.equals(barcode) & p.deletedAt.isNull()))
        .getSingleOrNull();
  }

  // ================= Stok =================

  Stream<Map<String, int>> watchStockByProduct() {
    final total = stockMovements.qtyDelta.sum();
    final query = selectOnly(stockMovements)
      ..addColumns([stockMovements.productId, total])
      ..groupBy([stockMovements.productId]);

    return query.watch().map((rows) => {
          for (final row in rows) row.read(stockMovements.productId)!: row.read(total) ?? 0,
        });
  }

  Future<int> getStock(String productId) async {
    final total = stockMovements.qtyDelta.sum();
    final query = selectOnly(stockMovements)
      ..addColumns([total])
      ..where(stockMovements.productId.equals(productId));
    final row = await query.getSingle();
    return row.read(total) ?? 0;
  }

  // ================= Tambah / ubah / hapus produk =================

  Future<Product> addProductWithStock({
    required String storeId,
    required String name,
    required int sellPrice,
    int costPrice = 0,
    String? barcode,
    String? categoryId,
    String unit = 'pcs',
    int minStock = 0,
    int initialStock = 0,
  }) {
    return transaction(() async {
      final product = await into(products).insertReturning(
        ProductsCompanion.insert(
          storeId: storeId,
          name: name,
          sellPrice: Value(sellPrice),
          costPrice: Value(costPrice),
          barcode: Value(barcode),
          categoryId: Value(categoryId),
          unit: Value(unit),
          minStock: Value(minStock),
        ),
      );
      await _enqueue('products', product.id, 'upsert', product.toJson());

      if (initialStock != 0) {
        await _addMovement(storeId, product.id, 'restock', initialStock);
      }
      return product;
    });
  }

  Future<void> updateProduct({
    required Product product,
    required String name,
    required int sellPrice,
    required int costPrice,
    required String unit,
    required int minStock,
    String? barcode,
    String? categoryId,
    int? newStock,
  }) {
    return transaction(() async {
      final updated = product.copyWith(
        name: name,
        sellPrice: sellPrice,
        costPrice: costPrice,
        unit: unit,
        minStock: minStock,
        barcode: Value(barcode),
        categoryId: Value(categoryId),
        updatedAt: DateTime.now(),
        syncStatus: 'pending',
      );
      await update(products).replace(updated);
      await _enqueue('products', updated.id, 'upsert', updated.toJson());

      if (newStock != null) {
        final delta = newStock - await getStock(product.id);
        if (delta != 0) {
          await _addMovement(product.storeId, product.id, 'adjust', delta);
        }
      }
    });
  }

  Future<void> softDeleteProduct(Product product) {
    return transaction(() async {
      final deleted = product.copyWith(
        deletedAt: Value(DateTime.now()),
        updatedAt: DateTime.now(),
        syncStatus: 'pending',
      );
      await update(products).replace(deleted);
      await _enqueue('products', deleted.id, 'upsert', deleted.toJson());
    });
  }

  // ================= Transaksi penjualan =================

  /// Simpan penjualan dalam SATU database transaction:
  /// transaksi + item + pengurangan stok + antrean sinkron.
  Future<TransactionData> createSale({
    required String storeId,
    required String cashierId,
    required String deviceId,
    required String deviceCode,
    required List<SaleLine> lines,
    required int discount,
    required int paid,
    required String paymentMethod,
  }) {
    return transaction(() async {
      final seq = await _countTransactionsOfDevice(deviceId) + 1;
      final invoiceNo = '$deviceCode-${seq.toString().padLeft(6, '0')}';

      final subtotal = lines.fold<int>(0, (sum, l) => sum + l.price * l.qty);
      final total = (subtotal - discount).clamp(0, subtotal);
      final change = paymentMethod == 'cash' ? (paid - total).clamp(0, paid) : 0;

      final trx = await into(transactions).insertReturning(
        TransactionsCompanion.insert(
          storeId: storeId,
          cashierId: cashierId,
          deviceId: deviceId,
          invoiceNo: invoiceNo,
          subtotal: subtotal,
          discount: Value(discount),
          total: total,
          paid: paid,
          change: Value(change),
          paymentMethod: Value(paymentMethod),
        ),
      );
      await _enqueue('transactions', trx.id, 'insert', trx.toJson());

      for (final line in lines) {
        final item = await into(transactionItems).insertReturning(
          TransactionItemsCompanion.insert(
            storeId: storeId,
            transactionId: trx.id,
            productId: Value(line.productId),
            productName: line.productName,
            price: line.price,
            costPrice: Value(line.costPrice),
            qty: line.qty,
          ),
        );
        await _enqueue('transaction_items', item.id, 'insert', item.toJson());
        await _addMovement(storeId, line.productId, 'sale', -line.qty, refId: trx.id);
      }
      return trx;
    });
  }

  Stream<List<TransactionData>> watchTransactionsBetween(DateTime from, DateTime to) {
    return (select(transactions)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(from) & t.createdAt.isSmallerThanValue(to))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<TransactionData?> getTransaction(String id) {
    return (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<TransactionItem>> getTransactionItems(String transactionId) {
    return (select(transactionItems)..where((i) => i.transactionId.equals(transactionId))).get();
  }

  Future<int> _countTransactionsOfDevice(String deviceId) async {
    final count = transactions.id.count();
    final query = selectOnly(transactions)
      ..addColumns([count])
      ..where(transactions.deviceId.equals(deviceId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  // ================= Pergerakan stok =================

  Future<void> _addMovement(
    String storeId,
    String productId,
    String type,
    int qtyDelta, {
    String? refId,
  }) async {
    final movement = await into(stockMovements).insertReturning(
      StockMovementsCompanion.insert(
        storeId: storeId,
        productId: productId,
        type: type,
        qtyDelta: qtyDelta,
        refId: Value(refId),
      ),
    );
    await _enqueue('stock_movements', movement.id, 'insert', movement.toJson());
  }

  // ================= Antrean sinkron =================

  Stream<int> watchPendingSyncCount() {
    final count = syncQueue.id.count();
    final query = selectOnly(syncQueue)..addColumns([count]);
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  Future<void> _enqueue(String entity, String entityId, String operation, Map<String, dynamic> payload) {
    return into(syncQueue).insert(
      SyncQueueCompanion.insert(
        entity: entity,
        entityId: entityId,
        operation: operation,
        payload: jsonEncode(payload),
      ),
    );
  }
}