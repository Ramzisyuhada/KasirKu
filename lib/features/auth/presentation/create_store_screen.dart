import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kasirku/core/theme/app_colors.dart';
import 'package:kasirku/features/auth/data/auth_repository.dart';
import 'package:kasirku/features/auth/data/profile_repository.dart';
import 'package:kasirku/features/auth/data/store_repository.dart';

class CreateStoreScreen extends ConsumerStatefulWidget {
  const CreateStoreScreen({super.key});

  @override
  ConsumerState<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends ConsumerState<CreateStoreScreen> {
  final _storeName = TextEditingController();
  final _address = TextEditingController();
  final _code = TextEditingController();
  bool _joinMode = false; // false = buat toko, true = gabung pakai kode
  bool _loading = false;

  @override
  void dispose() {
    _storeName.dispose();
    _address.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Validasi sederhana
    if (!_joinMode && _storeName.text.trim().isEmpty) {
      _showError('Nama toko wajib diisi.');
      return;
    }
    if (_joinMode && _code.text.trim().length != 6) {
      _showError('Kode undangan terdiri dari 6 karakter.');
      return;
    }

    setState(() => _loading = true);
    final repo = ref.read(storeRepositoryProvider);
    try {
      if (_joinMode) {
        await repo.joinStore(_code.text);
      } else {
        await repo.createStore(
          name: _storeName.text.trim(),
          address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        );
      }
      // Ambil ulang profil → store_id sudah terisi → router pindah ke Kasir.
      ref.invalidate(myProfileProvider);
    } catch (e) {
      _showError(friendlyStoreError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = ref.watch(myProfileProvider).asData?.value?.name ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Siapkan toko'),
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
            name.isEmpty ? 'Halo!' : 'Halo, $name!',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            _joinMode
                ? 'Masukkan kode undangan dari pemilik toko.'
                : 'Buat toko baru. Kamu akan jadi pemilik toko ini.',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Buat toko')),
              ButtonSegment(value: true, label: Text('Gabung toko')),
            ],
            selected: {_joinMode},
            onSelectionChanged: _loading
                ? null
                : (s) => setState(() => _joinMode = s.first),
          ),
          const SizedBox(height: 24),
          if (!_joinMode) ...[
            TextField(
              controller: _storeName,
              decoration: const InputDecoration(labelText: 'Nama toko'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Alamat (opsional)'),
            ),
          ] else
            TextField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'Kode undangan (6 karakter)'),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(_joinMode ? 'Gabung' : 'Buat toko'),
          ),
        ],
      ),
    );
  }
}