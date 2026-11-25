import 'dart:math';

import 'package:flutter/material.dart';

import 'package:kasirku/core/theme/app_colors.dart';
import 'package:kasirku/core/utils/format.dart';

/// Grafik batang sederhana tanpa library: omzet per jam, jam ramai disorot.
class HourlyChart extends StatelessWidget {
  const HourlyChart({super.key, required this.hourly, this.peakHour});

  final List<int> hourly;
  final int? peakHour;

  @override
  Widget build(BuildContext context) {
    // Tampilkan jam 06–22, diperluas kalau ada penjualan di luar jam itu.
    var start = 6, end = 22;
    for (var h = 0; h < 24; h++) {
      if (hourly[h] > 0) {
        start = min(start, h);
        end = max(end, h);
      }
    }
    final hours = [for (var h = start; h <= end; h++) h];
    final maxValue = hours.map((h) => hourly[h]).fold<int>(0, max);

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final h in hours)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: '${h.toString().padLeft(2, '0')}.00 · ${rupiah(hourly[h])}',
                      child: Container(
                        height: maxValue == 0 ? 2 : max(2, 110 * hourly[h] / maxValue).toDouble(),
                        decoration: BoxDecoration(
                          color: h == peakHour ? AppColors.accent : AppColors.primarySoft,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 14,
                      child: Text(
                        h.isEven ? '$h' : '',
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
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