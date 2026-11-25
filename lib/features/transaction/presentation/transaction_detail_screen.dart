import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kasirku/core/database/app_database.dart';
import 'package:kasirku/core/theme/app_colors.dart';
import 'package:kasirku/core/utils/format.dart';
import 'package:kasirku/features/auth/data/profile_repository.dart';
import 'package:kasirku/features/transaction/application/transaction_providers.dart';

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.id, this.isNew = false});

  final String id;

  /// true = baru saja dibayar (tampilkan tanda sukses + tombol Transaksi baru).
  final bool isNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(transactionDetailProvider(id));
    final storeName = ref.watch(myProfileProvider).asData?.value?.storeName ?? 'KasirKu';

    void soon() => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cetak & bagikan struk dibuat di fitur printer.')),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Transaksi berhasil' : 'Detail transaksi'),
        automaticallyImplyLeading: !isNew,
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (d) {
          if (d == null) return const Center(child: Text('Transaksi tidak ditemukan'));
          final (trx, items) = d;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (isNew) ...[
                const SizedBox(height: 8),
                const Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.successBg,
                    child: Icon(Icons.check, size: 44, color: AppColors.success),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Transaksi berhasil',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Center(
                child: Text(
                  '${trx.invoiceNo} · ${formatDateTime(trx.createdAt)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 8),
              Center(child: TrxSyncBadge(status: trx.syncStatus, withHint: true)),
              const SizedBox(height: 16),
              ReceiptView(trx: trx, items: items, storeName: storeName),
            ],
          );
        },
      ),
      bottomNavigationBar: isNew
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: OutlinedButton(onPressed: soon, child: const Text('Cetak struk'))),
                        const SizedBox(width: 12),
                        Expanded(child: OutlinedButton(onPressed: soon, child: const Text('Bagikan'))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.go('/kasir'),
                      child: const Text('Transaksi baru'),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

/// Badge status sinkron satu transaksi.
class TrxSyncBadge extends StatelessWidget {
  const TrxSyncBadge({super.key, required this.status, this.withHint = false});

  final String status;
  final bool withHint;

  @override
  Widget build(BuildContext context) {
    final synced = status == 'synced';
    final fg = synced ? AppColors.success : AppColors.warning;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: synced ? AppColors.successBg : AppColors.warningBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            synced ? 'Tersinkron' : 'Menunggu',
            style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        if (withHint && !synced) ...[
          const SizedBox(width: 8),
          const Text(
            'Dikirim otomatis saat online',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// Tampilan struk. Nanti dipakai juga untuk cetak ke printer.
class ReceiptView extends StatelessWidget {
  const ReceiptView({super.key, required this.trx, required this.items, required this.storeName});

  final TransactionData trx;
  final List<TransactionItem> items;
  final String storeName;

  Widget _line(String l, String r, {bool bold = false, Color? color}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Flexible(child: Text(l, style: style)), Text(r, style: style)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(storeName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 2),
            Text(
              '${trx.invoiceNo} · ${formatDateTime(trx.createdAt)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const Divider(height: 24),
            for (final i in items) _line('${i.productName} ${i.qty}x', rupiah(i.price * i.qty)),
            const Divider(height: 24),
            if (trx.discount > 0) ...[
              _line('Subtotal', rupiah(trx.subtotal), color: AppColors.textSecondary),
              _line('Diskon', '-${rupiah(trx.discount)}', color: AppColors.textSecondary),
            ],
            _line('Total', rupiah(trx.total), bold: true),
            _line(paymentLabel(trx.paymentMethod), rupiah(trx.paid), color: AppColors.textSecondary),
            if (trx.paymentMethod == 'cash')
              _line('Kembalian', rupiah(trx.change), color: AppColors.textSecondary),
            const Divider(height: 24),
            const Text(
              'Terima kasih, sampai jumpa lagi!',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}