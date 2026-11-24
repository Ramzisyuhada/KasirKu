import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

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

  /// Dipakai nanti di layar Kasir saat scan barcode.
  Future<Product?> findByBarcode(String barcode) {
    return (select(products)
          ..where((p) => p.barcode.equals(barcode) & p.deletedAt.isNull()))
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

  /// Ubah produk. Kalau [newStock] diisi dan berbeda dari stok sekarang,
  /// dibuat pergerakan stok 'adjust' sebesar selisihnya.
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

  /// Hapus "lunak": data tetap ada, hanya ditandai deleted_at.
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

  Future<void> _addMovement(String storeId, String productId, String type, int qtyDelta) async {
    final movement = await into(stockMovements).insertReturning(
      StockMovementsCompanion.insert(
        storeId: storeId,
        productId: productId,
        type: type,
        qtyDelta: qtyDelta,
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