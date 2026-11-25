import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kasirku/core/theme/app_colors.dart';
import 'package:kasirku/core/utils/format.dart';
import 'package:kasirku/features/auth/data/profile_repository.dart';
import 'package:kasirku/features/report/application/report_providers.dart';
import 'package:kasirku/features/report/presentation/widgets/hourly_chart.dart';

class LaporanScreen extends ConsumerStatefulWidget {
  const LaporanScreen({super.key});

  @override
  ConsumerState<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends ConsumerState<LaporanScreen> {
  ReportPeriod _period = ReportPeriod.today;

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(myProfileProvider).asData?.value?.isOwner ?? false;

    if (!isOwner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Laporan')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: AppColors.textSecondary),
                SizedBox(height: 12),
                Text(
                  'Laporan hanya bisa dilihat oleh pemilik toko.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final range = rangeFor(_period);
    final reportAsync = ref.watch(salesReportProvider(_period));

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SegmentedButton<ReportPeriod>(
            segments: const [
              ButtonSegment(value: ReportPeriod.today, label: Text('Hari ini')),
              ButtonSegment(value: ReportPeriod.week, label: Text('Minggu ini')),
              ButtonSegment(value: ReportPeriod.month, label: Text('Bulan ini')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 16),
          reportAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 64),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (r) => _ReportBody(report: r, range: range),
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report, required this.range});

  final SalesReport report;
  final PeriodRange range;

  @override
  Widget build(BuildContext context) {
    final growth = report.growthPercent;
    final peak = report.peakHour;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---------- Omzet ----------
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(range.title, style: const TextStyle(color: AppColors.primarySoft)),
              const SizedBox(height: 4),
              Text(
                rupiah(report.omzet),
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    growth == null
                        ? Icons.remove
                        : (growth >= 0 ? Icons.trending_up : Icons.trending_down),
                    size: 16,
                    color: AppColors.primarySoft,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    growth == null
                        ? 'Belum ada data pembanding'
                        : '${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(0)}% ${range.compareLabel}',
                    style: const TextStyle(color: AppColors.primarySoft, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ---------- KPI kecil ----------
        Row(
          children: [
            Expanded(child: _KpiCard(label: 'Laba kotor', value: rupiah(report.grossProfit))),
            const SizedBox(width: 12),
            Expanded(child: _KpiCard(label: 'Transaksi', value: '${report.trxCount}')),
          ],
        ),
        const SizedBox(height: 12),
        _KpiCard(label: 'Rata-rata per transaksi', value: rupiah(report.averagePerTrx)),
        const SizedBox(height: 12),

        if (report.trxCount == 0)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Text(
              'Belum ada transaksi di periode ini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else ...[
          // ---------- Grafik per jam ----------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Penjualan per jam', style: TextStyle(fontWeight: FontWeight.w700)),
                      if (peak != null)
                        Text(
                          'Ramai ${peak.toString().padLeft(2, '0')}.00',
                          style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  HourlyChart(hourly: report.hourly, peakHour: peak),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ---------- Produk terlaris ----------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Produk terlaris', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (var i = 0; i < report.topProducts.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: i == 0 ? AppColors.warningBg : AppColors.background,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: i == 0 ? AppColors.accent : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(report.topProducts[i].name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(
                                  '${report.topProducts[i].qty} terjual',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Text(rupiah(report.topProducts[i].revenue), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}