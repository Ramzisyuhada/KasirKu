import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kasirku/core/theme/app_colors.dart';
import 'package:kasirku/features/auth/data/auth_repository.dart';
import 'package:kasirku/features/auth/data/profile_repository.dart';
import 'package:kasirku/features/auth/data/store_repository.dart';

class KasirScreen extends ConsumerWidget {
  const KasirScreen({super.key});

  Future<void> _createInvite(BuildContext context, WidgetRef ref) async {
    try {
      final code = await ref.read(storeRepositoryProvider).createInvite();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Kode undangan kasir'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                code,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: 4),
              ),
              const SizedBox(height: 8),
              const Text('Berlaku 7 hari, hanya untuk 1 kasir.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
              child: const Text('Salin'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyStoreError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).asData?.value;

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
          const SizedBox(height: 4),
          Text(
            profile?.isOwner == true ? 'Peran: Pemilik' : 'Peran: Kasir',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          if (profile?.isOwner == true)
            OutlinedButton(
              onPressed: () => _createInvite(context, ref),
              child: const Text('Buat kode undangan kasir'),
            ),
          const SizedBox(height: 24),
          const Text('Layar kasir lengkap dibuat di fitur berikutnya.'),
        ],
      ),
    );
  }
}