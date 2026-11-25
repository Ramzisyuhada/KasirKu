import 'package:flutter/material.dart';

import 'package:kasirku/core/theme/app_colors.dart';

/// Chip kecil di app bar: "Tersinkron" atau "N menunggu".
class SyncChip extends StatelessWidget {
  const SyncChip({super.key, required this.pending});

  final int pending;

  @override
  Widget build(BuildContext context) {
    final waiting = pending > 0;
    final fg = waiting ? AppColors.warning : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: waiting ? AppColors.warningBg : AppColors.successBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(waiting ? Icons.sync : Icons.cloud_done_outlined, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            waiting ? '$pending menunggu' : 'Tersinkron',
            style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}