import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Profile {
  const Profile({
    required this.id,
    required this.name,
    this.role,
    this.storeId,
    this.storeName,
  });

  final String id;
  final String name;
  final String? role; // 'owner' / 'cashier'
  final String? storeId;
  final String? storeName;

  bool get hasStore => storeId != null;
  bool get isOwner => role == 'owner';

  factory Profile.fromMap(Map<String, dynamic> map) {
    final store = map['stores'] as Map<String, dynamic>?;
    return Profile(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      role: map['role'] as String?,
      storeId: map['store_id'] as String?,
      storeName: (store?['name'] as String?) ?? map['store_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'role': role,
        'store_id': storeId,
        'store_name': storeName,
      };
}

class ProfileRepository {
  ProfileRepository(this._client);
  final SupabaseClient _client;

  static const _cacheKey = 'cached_profile';

  /// Ambil profil (+ nama toko) dari server. Kalau offline, pakai salinan terakhir di HP.
  Future<Profile?> getMyProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final prefs = await SharedPreferences.getInstance();
    try {
      final row = await _client
          .from('profiles')
          .select('*, stores(name)')
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));

      if (row == null) return null;
      final profile = Profile.fromMap(row);
      await prefs.setString(_cacheKey, jsonEncode(profile.toMap()));
      return profile;
    } catch (_) {
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final profile = Profile.fromMap(jsonDecode(cached) as Map<String, dynamic>);
        if (profile.id == userId) return profile;
      }
      rethrow;
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(Supabase.instance.client);
});

final myProfileProvider = FutureProvider<Profile?>((ref) {
  return ref.watch(profileRepositoryProvider).getMyProfile();
});