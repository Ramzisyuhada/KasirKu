import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kasirku/core/database/app_database.dart';
import 'package:kasirku/core/database/database_provider.dart';

enum RiwayatRange { today, yesterday, week }

/// Rentang waktu [dari, sampai) untuk tiap pilihan.
(DateTime, DateTime) rangeOf(RiwayatRange range) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return switch (range) {
    RiwayatRange.today => (today, today.add(const Duration(days: 1))),
    RiwayatRange.yesterday => (today.subtract(const Duration(days: 1)), today),
    RiwayatRange.week => (today.subtract(const Duration(days: 6)), today.add(const Duration(days: 1))),
  };
}

final transactionsProvider =
    StreamProvider.autoDispose.family<List<TransactionData>, RiwayatRange>((ref, range) {
  final (from, to) = rangeOf(range);
  return ref.watch(appDatabaseProvider).watchTransactionsBetween(from, to);
});

/// Transaksi + item-itemnya, untuk layar detail / struk.
final transactionDetailProvider =
    FutureProvider.autoDispose.family<(TransactionData, List<TransactionItem>)?, String>((ref, id) async {
  final db = ref.watch(appDatabaseProvider);
  final trx = await db.getTransaction(id);
  if (trx == null) return null;
  final items = await db.getTransactionItems(id);
  return (trx, items);
});