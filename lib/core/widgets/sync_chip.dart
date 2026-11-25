import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kasirku/core/database/database_provider.dart';
import 'package:kasirku/core/theme/app_colors.dart';
import 'package:kasirku/sync/sync_controller.dart';

/// Chip di app bar. Ketuk untuk sinkron sekarang.
class SyncChip extends ConsumerWidget {
  const SyncChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingSyncCountProvider).asData?.value ?? 0;
    final sync = ref.watch(syncControllerProvider);

    final (String label, IconData icon, Color fg, Color bg) = switch (sync.phase) {
      SyncPhase.syncing => ('Menyinkron…', Icons.sync, AppColors.primary, AppColors.primaryLight),
      SyncPhase.offline => (
          pending > 0 ? 'Offline · $pending' : 'Offline',
          Icons.cloud_off,
          AppColors.textSecondary,
          AppColors.background,
        ),
      SyncPhase.error => ('Gagal · $pending', Icons.error_outline, AppColors.danger, AppColors.dangerBg),
      SyncPhase.idle when pending > 0 => ('$pending menunggu', Icons.sync, AppColors.warning, AppColors.warningBg),
      SyncPhase.idle => ('Tersinkron', Icons.cloud_done_outlined, AppColors.success, AppColors.successBg),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        ref.read(syncControllerProvider.notifier).syncNow();
        final last = sync.lastSyncedAt;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(
              sync.phase == SyncPhase.error
                  ? 'Sinkron gagal, mencoba lagi… (${sync.lastError ?? ''})'
                  : last == null
                      ? 'Menyinkron data…'
                      : 'Terakhir sinkron ${last.hour.toString().padLeft(2, '0')}.${last.minute.toString().padLeft(2, '0')}',
            ),
          ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}