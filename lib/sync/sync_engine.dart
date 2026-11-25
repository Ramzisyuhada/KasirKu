import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kasirku/core/database/app_database.dart';
import 'package:kasirku/core/database/database_provider.dart';
import 'sync_mappers.dart';

class SyncReport {
  const SyncReport({this.pushed = 0, this.pulled = 0});
  final int pushed;
  final int pulled;
}

class SyncEngine {
  SyncEngine(this._db, this._client);

  final AppDatabase _db;
  final SupabaseClient _client;

  /// Urutan penting karena foreign key: produk harus ada sebelum stok, transaksi sebelum item.
  static const _order = ['categories', 'products', 'transactions', 'transaction_items', 'stock_movements'];

  /// Tabel yang boleh diubah setelah dibuat (pakai upsert biasa).
  /// Sisanya append-only (insert saja, abaikan kalau sudah ada).
  static const _mutable = {'categories', 'products'};

  static const maxAttempts = 10;
  static const _batchSize = 50;
  static const _timeout = Duration(seconds: 20);

  Future<SyncReport> run() async {
    if (_client.auth.currentUser == null) return const SyncReport();
    final pushed = await _push();
    final pulled = await _pull();
    return SyncReport(pushed: pushed, pulled: pulled);
  }

  // ======================= PUSH =======================

  Future<int> _push() async {
    var count = 0;
    for (final entity in _order) {
      while (true) {
        final entries = await (_db.select(_db.syncQueue)
              ..where((q) => q.entity.equals(entity) & q.attempts.isSmallerThanValue(maxAttempts))
              ..orderBy([(q) => OrderingTerm.asc(q.id)])
              ..limit(_batchSize))
            .get();
        if (entries.isEmpty) break;

        final ids = entries.map((e) => e.entityId).toSet().toList();
        try {
          // Ambil versi TERBARU dari tabel lokal (bukan isi payload lama).
          final rows = await _localRows(entity, ids);
          if (rows.isNotEmpty) {
            final table = _client.from(entity);
            if (_mutable.contains(entity)) {
              await table.upsert(rows, onConflict: 'id').timeout(_timeout);
            } else {
              // Kalau terkirim dua kali (mis. koneksi putus di tengah), server cukup abaikan.
              await table.upsert(rows, onConflict: 'id', ignoreDuplicates: true).timeout(_timeout);
            }
          }

          await _db.transaction(() async {
            await (_db.delete(_db.syncQueue)..where((q) => q.id.isIn(entries.map((e) => e.id)))).go();
            await _markSynced(entity, ids);
          });
          count += entries.length;
        } catch (e) {
          await _recordFailure(entity, entries, e);
          rethrow; // berhenti supaya urutan tetap terjaga; controller akan coba lagi nanti
        }
      }
    }
    return count;
  }

  Future<List<Map<String, dynamic>>> _localRows(String entity, List<String> ids) async {
    switch (entity) {
      case 'categories':
        final r = await (_db.select(_db.categories)..where((t) => t.id.isIn(ids))).get();
        return r.map(categoryToServer).toList();
      case 'products':
        final r = await (_db.select(_db.products)..where((t) => t.id.isIn(ids))).get();
        return r.map(productToServer).toList();
      case 'transactions':
        final r = await (_db.select(_db.transactions)..where((t) => t.id.isIn(ids))).get();
        return r.map(transactionToServer).toList();
      case 'transaction_items':
        final r = await (_db.select(_db.transactionItems)..where((t) => t.id.isIn(ids))).get();
        return r.map(itemToServer).toList();
      case 'stock_movements':
        final userId = _client.auth.currentUser!.id;
        final r = await (_db.select(_db.stockMovements)..where((t) => t.id.isIn(ids))).get();
        return [for (final m in r) movementToServer(m, userId)];
    }
    return [];
  }

  /// Tandai 'synced' hanya kalau tidak ada antrean lain untuk baris itu
  /// (mis. produk diedit lagi saat sinkron sedang berjalan).
  Future<void> _markSynced(String entity, List<String> ids) async {
    final stillQueued = await (_db.select(_db.syncQueue)..where((q) => q.entityId.isIn(ids))).get();
    final pendingIds = stillQueued.map((q) => q.entityId).toSet();
    final done = ids.where((id) => !pendingIds.contains(id)).toList();
    if (done.isNotEmpty) await _setStatus(entity, done, 'synced');
  }

  Future<void> _recordFailure(String entity, List<SyncQueueEntry> entries, Object error) async {
    final message = error is PostgrestException ? error.message : error.toString();
    final failedIds = <String>[];
    await _db.transaction(() async {
      for (final e in entries) {
        final attempts = e.attempts + 1;
        await (_db.update(_db.syncQueue)..where((q) => q.id.equals(e.id))).write(
          SyncQueueCompanion(attempts: Value(attempts), lastError: Value(message)),
        );
        if (attempts >= maxAttempts) failedIds.add(e.entityId);
      }
      if (failedIds.isNotEmpty) await _setStatus(entity, failedIds, 'failed');
    });
  }

  Future<void> _setStatus(String entity, List<String> ids, String status) async {
    switch (entity) {
      case 'categories':
        await (_db.update(_db.categories)..where((t) => t.id.isIn(ids)))
            .write(CategoriesCompanion(syncStatus: Value(status)));
      case 'products':
        await (_db.update(_db.products)..where((t) => t.id.isIn(ids)))
            .write(ProductsCompanion(syncStatus: Value(status)));
      case 'transactions':
        await (_db.update(_db.transactions)..where((t) => t.id.isIn(ids)))
            .write(TransactionsCompanion(syncStatus: Value(status)));
      case 'transaction_items':
        await (_db.update(_db.transactionItems)..where((t) => t.id.isIn(ids)))
            .write(TransactionItemsCompanion(syncStatus: Value(status)));
      case 'stock_movements':
        await (_db.update(_db.stockMovements)..where((t) => t.id.isIn(ids)))
            .write(StockMovementsCompanion(syncStatus: Value(status)));
    }
  }

  // ======================= PULL =======================

  Future<int> _pull() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _client.auth.currentUser!.id;
    var count = 0;

    for (final entity in _order) {
      final key = 'last_pulled_${userId}_$entity';
      var cursor = prefs.getString(key) ?? '1970-01-01T00:00:00Z';

      while (true) {
        // RLS di Supabase otomatis hanya mengembalikan data toko milik user ini.
        final List<dynamic> rows = await _client
            .from(entity)
            .select()
            .gt('server_updated_at', cursor)
            .order('server_updated_at', ascending: true)
            .limit(1000)
            .timeout(_timeout);
        if (rows.isEmpty) break;

        await _db.transaction(() async {
          for (final r in rows) {
            await _applyServerRow(entity, r as Map<String, dynamic>);
          }
        });

        cursor = (rows.last as Map<String, dynamic>)['server_updated_at'] as String;
        await prefs.setString(key, cursor);
        count += rows.length;
        if (rows.length < 1000) break;
      }
    }
    return count;
  }

  Future<void> _applyServerRow(String entity, Map<String, dynamic> r) async {
    // Baris lokal yang belum terkirim tidak boleh ditimpa (perubahan lokal lebih baru).
    final pending = await (_db.select(_db.syncQueue)
          ..where((q) => q.entityId.equals(r['id'] as String))
          ..limit(1))
        .getSingleOrNull();
    if (pending != null) return;

    switch (entity) {
      case 'categories':
        await _db.into(_db.categories).insertOnConflictUpdate(categoryFromServer(r));
      case 'products':
        await _db.into(_db.products).insertOnConflictUpdate(productFromServer(r));
      case 'transactions':
        await _db.into(_db.transactions).insertOnConflictUpdate(transactionFromServer(r));
      case 'transaction_items':
        await _db.into(_db.transactionItems).insertOnConflictUpdate(itemFromServer(r));
      case 'stock_movements':
        await _db.into(_db.stockMovements).insertOnConflictUpdate(movementFromServer(r));
    }
  }
}

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(ref.watch(appDatabaseProvider), Supabase.instance.client);
});