import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// ID unik HP ini + kode pendek untuk nomor invoice (mis. "K7QD").
/// Dibuat sekali saat pertama dibuka, lalu disimpan di HP.
class DeviceIdentity {
  const DeviceIdentity({required this.id, required this.code});
  final String id;
  final String code;
}

Future<DeviceIdentity> _loadDeviceIdentity() async {
  final prefs = await SharedPreferences.getInstance();

  var id = prefs.getString('device_id');
  if (id == null) {
    id = const Uuid().v4();
    await prefs.setString('device_id', id);
  }

  var code = prefs.getString('device_code');
  if (code == null) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    code = List.generate(4, (_) => chars[rnd.nextInt(chars.length)]).join();
    await prefs.setString('device_code', code);
  }

  return DeviceIdentity(id: id, code: code);
}

final deviceIdentityProvider = FutureProvider<DeviceIdentity>((ref) => _loadDeviceIdentity());