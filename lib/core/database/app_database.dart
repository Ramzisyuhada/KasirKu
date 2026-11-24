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

  /// File database: kasirku.sqlite di penyimpanan internal HP.
  static QueryExecutor _openConnection() => driftDatabase(name: 'kasirku');

  // ---------------- Produk ----------------

  /// Daftar produk (yang belum dihapus), otomatis update kalau data berubah.
  Stream<List<Product>> watchProducts() {
    return (select(products)
          ..where((p) => p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .watch();
  }

  /// Stok per produk = jumlah semua stock_movements.
  Stream<Map<String, int>> watchStockByProduct() {
    final total = stockMovements.qtyDelta.sum();
    final query = selectOnly(stockMovements)
      ..addColumns([stockMovements.productId, total])
      ..groupBy([stockMovements.productId]);

    return query.watch().map((rows) => {
          for (final row in rows)
            row.read(stockMovements.productId)!: row.read(total) ?? 0,
        });
  }

  /// Tambah produk + stok awal + masukkan ke antrean sinkron,
  /// semua dalam SATU transaksi database (berhasil semua atau batal semua).
  Future<Product> addProductWithStock({
    required String storeId,
    required String name,
    required int sellPrice,
    int costPrice = 0,
    String? barcode,
    String unit = 'pcs',
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
          unit: Value(unit),
        ),
      );
      await _enqueue('products', product.id, 'upsert', product.toJson());

      if (initialStock > 0) {
        final movement = await into(stockMovements).insertReturning(
          StockMovementsCompanion.insert(
            storeId: storeId,
            productId: product.id,
            type: 'restock',
            qtyDelta: initialStock,
          ),
        );
        await _enqueue('stock_movements', movement.id, 'insert', movement.toJson());
      }
      return product;
    });
  }

  // ---------------- Antrean sinkron ----------------

  /// Jumlah data yang belum terkirim ke server.
  Stream<int> watchPendingSyncCount() {
    final count = syncQueue.id.count();
    final query = selectOnly(syncQueue)..addColumns([count]);
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  Future<void> _enqueue(
    String entity,
    String entityId,
    String operation,
    Map<String, dynamic> payload,
  ) {
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