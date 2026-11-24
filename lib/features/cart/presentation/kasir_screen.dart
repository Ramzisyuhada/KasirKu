import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kasirku/core/database/database_provider.dart';
import 'package:kasirku/core/theme/app_colors.dart';
import 'package:kasirku/features/auth/data/auth_repository.dart';
import 'package:kasirku/features/auth/data/profile_repository.dart';
import 'package:kasirku/features/auth/data/store_repository.dart';

class KasirScreen extends ConsumerWidget {
  const KasirScreen({super.key});

  Future<void> _addSampleProduct(WidgetRef ref, String storeId) async {
    final samples = [
      ('Indomie Goreng', 3500, 2800, 48),
      ('Aqua 600 ml', 4000, 3000, 36),
      ('Kopi Kapal Api', 1500, 1100, 120),
      ('Telur Ayam 1 kg', 28000, 25000, 3),
    ];
    final count = ref.read(productsProvider).asData?.value.length ?? 0;
    final s = samples[count % samples.length];

    await ref.read(appDatabaseProvider).addProductWithStock(
          storeId: storeId,
          name: s.$1,
          sellPrice: s.$2,
          costPrice: s.$3,
          initialStock: s.$4,
        );
  }

  Future<void> _createInvite(BuildContext context, WidgetRef ref) async {
    try {
      final code = await ref.read(storeRepositoryProvider).createInvite();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Kode undangan kasir'),
          content: SelectableText(
            code,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: 4),
          ),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
              child: const Text('Salin'),
            ),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyStoreError(e))));
    }
  }

  String _rupiah(int v) {
    final s = v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return 'Rp$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).asData?.value;
    final products = ref.watch(productsProvider);
    final stock = ref.watch(stockByProductProvider).asData?.value ?? {};
    final pending = ref.watch(pendingSyncCountProvider).asData?.value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Halo, ${profile?.name ?? ''}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            profile?.isOwner == true ? 'Peran: Pemilik' : 'Peran: Kasir',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pending > 0 ? AppColors.warningBg : AppColors.successBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              pending > 0 ? '$pending data menunggu sinkron' : 'Semua data tersinkron',
              style: TextStyle(
                color: pending > 0 ? AppColors.warning : AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (profile?.storeId != null)
            FilledButton(
              onPressed: () => _addSampleProduct(ref, profile!.storeId!),
              child: const Text('Tambah produk contoh (lokal)'),
            ),
          if (profile?.isOwner == true) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _createInvite(context, ref),
              child: const Text('Buat kode undangan kasir'),
            ),
          ],
          const SizedBox(height: 24),
          Text('Produk di HP', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          products.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (list) => list.isEmpty
                ? const Text('Belum ada produk.')
                : Card(
                    child: Column(
                      children: [
                        for (final p in list)
                          ListTile(
                            title: Text(p.name),
                            subtitle: Text('${_rupiah(p.sellPrice)} · ${p.syncStatus}'),
                            trailing: Text(
                              'Stok ${stock[p.id] ?? 0}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: (stock[p.id] ?? 0) <= 5 ? AppColors.danger : AppColors.textPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}