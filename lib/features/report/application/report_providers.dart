import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kasirku/core/database/app_database.dart';
import 'package:kasirku/core/database/database_provider.dart';

enum ReportPeriod { today, week, month }

class PeriodRange {
  const PeriodRange({
    required this.from,
    required this.to,
    required this.prevFrom,
    required this.prevTo,
    required this.title,
    required this.compareLabel,
  });

  final DateTime from, to, prevFrom, prevTo;
  final String title;
  final String compareLabel;
}

PeriodRange rangeFor(ReportPeriod period) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  const day = Duration(days: 1);

  switch (period) {
    case ReportPeriod.today:
      return PeriodRange(
        from: today,
        to: today.add(day),
        prevFrom: today.subtract(day),
        prevTo: today,
        title: 'Omzet hari ini',
        compareLabel: 'dari kemarin',
      );
    case ReportPeriod.week:
      final start = today.subtract(Duration(days: today.weekday - 1)); // Senin
      return PeriodRange(
        from: start,
        to: start.add(const Duration(days: 7)),
        prevFrom: start.subtract(const Duration(days: 7)),
        prevTo: start,
        title: 'Omzet minggu ini',
        compareLabel: 'dari minggu lalu',
      );
    case ReportPeriod.month:
      final start = DateTime(now.year, now.month, 1);
      return PeriodRange(
        from: start,
        to: DateTime(now.year, now.month + 1, 1),
        prevFrom: DateTime(now.year, now.month - 1, 1),
        prevTo: start,
        title: 'Omzet bulan ini',
        compareLabel: 'dari bulan lalu',
      );
  }
}

class TopProduct {
  const TopProduct({required this.name, required this.qty, required this.revenue});
  final String name;
  final int qty;
  final int revenue;
}

class SalesReport {
  const SalesReport({
    required this.omzet,
    required this.prevOmzet,
    required this.grossProfit,
    required this.trxCount,
    required this.hourly,
    required this.topProducts,
  });

  final int omzet;
  final int prevOmzet;
  final int grossProfit;
  final int trxCount;
  final List<int> hourly; // 24 angka: omzet per jam (0..23)
  final List<TopProduct> topProducts;

  int get averagePerTrx => trxCount == 0 ? 0 : omzet ~/ trxCount;

  /// null kalau periode sebelumnya belum ada penjualan.
  double? get growthPercent => prevOmzet == 0 ? null : (omzet - prevOmzet) / prevOmzet * 100;

  /// Jam dengan omzet terbesar, null kalau belum ada penjualan.
  int? get peakHour {
    var best = -1;
    var bestValue = 0;
    for (var h = 0; h < 24; h++) {
      if (hourly[h] > bestValue) {
        bestValue = hourly[h];
        best = h;
      }
    }
    return best < 0 ? null : best;
  }
}

/// Laporan dihitung dari database lokal → tetap bisa dibuka saat offline,
/// dan otomatis diperbarui setiap ada transaksi baru.
final salesReportProvider =
    StreamProvider.autoDispose.family<SalesReport, ReportPeriod>((ref, period) {
  final db = ref.watch(appDatabaseProvider);
  final range = rangeFor(period);

  return db.watchTransactionsBetween(range.prevFrom, range.to).asyncMap((all) async {
    final paid = all.where((t) => t.status == 'paid');
    final current = paid.where((t) => !t.createdAt.isBefore(range.from)).toList();
    final previous = paid.where((t) => t.createdAt.isBefore(range.from));

    // Ambil item transaksi periode ini (dipecah per 500 id, batas SQLite).
    final ids = current.map((t) => t.id).toList();
    final items = <TransactionItem>[];
    for (var i = 0; i < ids.length; i += 500) {
      final chunk = ids.sublist(i, i + 500 > ids.length ? ids.length : i + 500);
      items.addAll(await (db.select(db.transactionItems)..where((x) => x.transactionId.isIn(chunk))).get());
    }

    final omzet = current.fold<int>(0, (s, t) => s + t.total);
    final cost = items.fold<int>(0, (s, i) => s + i.costPrice * i.qty);

    final hourly = List<int>.filled(24, 0);
    for (final t in current) {
      hourly[t.createdAt.hour] += t.total;
    }

    final byProduct = <String, (int qty, int revenue)>{};
    for (final i in items) {
      final prev = byProduct[i.productName] ?? (0, 0);
      byProduct[i.productName] = (prev.$1 + i.qty, prev.$2 + i.price * i.qty);
    }
    final top = byProduct.entries
        .map((e) => TopProduct(name: e.key, qty: e.value.$1, revenue: e.value.$2))
        .toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));

    return SalesReport(
      omzet: omzet,
      prevOmzet: previous.fold<int>(0, (s, t) => s + t.total),
      grossProfit: omzet - cost,
      trxCount: current.length,
      hourly: hourly,
      topProducts: top.take(5).toList(),
    );
  });
});