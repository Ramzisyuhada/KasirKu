import 'package:flutter/material.dart';

import 'bootstrap.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key, required this.env});

  final Env env;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KasirKu',
      debugShowCheckedModeBanner: env == Env.dev,
      theme: AppTheme.light, // ← tema dari app_theme.dart
      home: const ThemePreview(),
    );
  }
}

/// Layar sementara untuk mengecek tema. Nanti diganti router.
class ThemePreview extends StatelessWidget {
  const ThemePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Cek Tema')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Masuk ke KasirKu', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Kasir warung yang tetap jalan walau internet putus.',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          const TextField(decoration: InputDecoration(labelText: 'Email', hintText: 'nama@email.com')),
          const SizedBox(height: 16),
          FilledButton(onPressed: () {}, child: const Text('Masuk')),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () {}, child: const Text('Gabung pakai kode toko')),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '2 transaksi menunggu sinkron',
              style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}