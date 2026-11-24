import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Memanggil fungsi database yang sudah dibuat di Supabase:
/// create_store, join_store, create_invite.
class StoreRepository {
  StoreRepository(this._client);
  final SupabaseClient _client;

  /// Pemilik membuat toko. User otomatis jadi 'owner'.
  Future<String> createStore({required String name, String? address}) async {
    final id = await _client.rpc(
      'create_store',
      params: {'p_name': name, 'p_address': address},
    );
    return id as String;
  }

  /// Kasir bergabung ke toko pakai kode undangan.
  Future<void> joinStore(String code) async {
    await _client.rpc(
      'join_store',
      params: {'p_code': code.trim().toUpperCase()},
    );
  }

  /// Pemilik membuat kode undangan 6 huruf (berlaku 7 hari).
  Future<String> createInvite() async {
    final code = await _client.rpc('create_invite');
    return code as String;
  }
}

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository(Supabase.instance.client);
});

/// Mengubah pesan error dari database jadi bahasa Indonesia.
String friendlyStoreError(Object e) {
  final msg = e is PostgrestException ? e.message : e.toString();
  if (msg.contains('invalid or expired invite code')) {
    return 'Kode undangan salah atau sudah kedaluwarsa.';
  }
  if (msg.contains('already belongs to a store')) {
    return 'Akun ini sudah terdaftar di sebuah toko.';
  }
  if (msg.contains('only owner')) {
    return 'Hanya pemilik toko yang bisa membuat kode undangan.';
  }
  return 'Terjadi kesalahan. Cek koneksi internet lalu coba lagi.';
}