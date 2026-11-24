import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Data profil user dari tabel `profiles`.
class Profile {
  const Profile({
    required this.id,
    required this.name,
    this.role,
    this.storeId,
  });

  final String id;
  final String name;
  final String? role; // 'owner' atau 'cashier'
  final String? storeId;

  bool get hasStore => storeId != null;
  bool get isOwner => role == 'owner';

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      role: map['role'] as String?,
      storeId: map['store_id'] as String?,
    );
  }
}

class ProfileRepository {
  ProfileRepository(this._client);
  final SupabaseClient _client;

  /// Profil user yang sedang login. null kalau belum login.
  Future<Profile?> getMyProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    return row == null ? null : Profile.fromMap(row);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(Supabase.instance.client);
});

/// Profil user yang sedang login.
/// Panggil `ref.invalidate(myProfileProvider)` untuk mengambil ulang.
final myProfileProvider = FutureProvider<Profile?>((ref) {
  return ref.watch(profileRepositoryProvider).getMyProfile();
});