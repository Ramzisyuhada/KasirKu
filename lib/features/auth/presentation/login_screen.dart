import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kasirku/core/theme/app_colors.dart';
import 'package:kasirku/features/auth/data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    final auth = ref.read(authRepositoryProvider);
    try {
      if (_isRegister) {
        await auth.signUp(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await auth.signIn(email: _email.text.trim(), password: _password.text);
      }
      // Tidak perlu pindah layar manual: router otomatis redirect.
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Tidak bisa terhubung. Cek koneksi internet.');
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

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Text(
              _isRegister ? 'Daftar akun pemilik' : 'Masuk ke KasirKu',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Kasir warung yang tetap jalan walau internet putus.',
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            if (_isRegister) ...[
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nama'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Password (min. 6 karakter)'),
              obscureText: true,
              onSubmitted: (_) => _submit(),
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
                  : Text(_isRegister ? 'Daftar' : 'Masuk'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loading ? null : () => setState(() => _isRegister = !_isRegister),
              child: Text(_isRegister ? 'Sudah punya akun? Masuk' : 'Belum punya akun? Daftar'),
            ),
          ],
        ),
      ),
    );
  }
}