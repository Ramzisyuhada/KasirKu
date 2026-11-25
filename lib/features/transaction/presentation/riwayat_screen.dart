import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kasirku/core/database/database_provider.dart';
import 'package:kasirku/core/theme/app_colors.dart';
import 'package:kasirku/core/utils/format.dart';
import 'package:kasirku/features/transaction/application/transaction_providers.dart';
import 'package:kasirku/features/transaction/presentation/transaction_detail_screen.dart';

class RiwayatScreen extends ConsumerStatefulWidget {
  const RiwayatScreen({super.key});

  @override
  ConsumerState<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends ConsumerState<RiwayatScreen> {
  RiwayatRange _range = RiwayatRange.today;

  @override
  Widget build(BuildContext context) {
    final trxAsync = ref.watch(transactionsProvider(_range));
    final pending = ref.watch(pendingSyncCountProvider).asData?.value ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          if (pending > 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.sync, color: AppColors.warning, size: 20),
                  const SizedBox(width: 10),
                  Text('$pending data menunggu sinkron',
                      style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SegmentedButton<RiwayatRange>(
            segments: const [
              ButtonSegment(value: RiwayatRange.today, label: Text('Hari ini')),
              ButtonSegment(value: RiwayatRange.yesterday, label: Text('Kemarin')),
              ButtonSegment(value: RiwayatRange.week, label: Text('7 hari')),
            ],
            selected: {_range},
            onSelectionChanged: (s) => setState(() => _range = s.first),
          ),
          const SizedBox(height: 12),
          trxAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (list) {
              final paidList = list.where((t) => t.status == 'paid');
              final omzet = paidList.fold<int>(0, (s, t) => s + t.total);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${paidList.length} transaksi', style: const TextStyle(color: AppColors.textSecondary)),
                      Text(rupiah(omzet), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Text('Belum ada transaksi.',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                    )
                  else
                    Card(
                      child: Column(
                        children: [
                          for (var i = 0; i < list.length; i++) ...[
                            if (i > 0) const Divider(),
                            ListTile(
                              onTap: () => context.push('/transaksi/${list[i].id}'),
                              title: Text(list[i].invoiceNo, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                '${_range == RiwayatRange.today ? formatTime(list[i].createdAt) : formatDateTime(list[i].createdAt)}'
                                ' · ${paymentLabel(list[i].paymentMethod)}',
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(rupiah(list[i].total), style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  TrxSyncBadge(status: list[i].syncStatus),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}