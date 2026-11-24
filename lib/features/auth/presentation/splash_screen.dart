import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kasirku/features/auth/data/auth_repository.dart';
import 'package:kasirku/features/auth/data/profile_repository.dart';

/// Ditampilkan sebentar saat profil sedang diambil dari server.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      body: Center(
        child: profile.hasError
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Gagal memuat data akun.\nCek koneksi internet.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(myProfileProvider),
                      child: const Text('Coba lagi'),
                    ),
                    TextButton(
                      onPressed: () => ref.read(authRepositoryProvider).signOut(),
                      child: const Text('Keluar'),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}