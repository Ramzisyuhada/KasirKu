import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kasirku/core/database/database_provider.dart';
import 'sync_engine.dart';

enum SyncPhase { idle, syncing, offline, error }

class SyncState {
  const SyncState({this.phase = SyncPhase.idle, this.lastSyncedAt, this.lastError});

  final SyncPhase phase;
  final DateTime? lastSyncedAt;
  final String? lastError;

  bool get isSyncing => phase == SyncPhase.syncing;
}

/// Menentukan KAPAN sinkron dijalankan:
/// 1. saat aplikasi dibuka, 2. saat internet kembali, 3. tiap 1 menit,
/// 4. sebentar setelah ada data baru di antrean, 5. saat user mengetuk chip.
/// Kalau gagal: coba lagi dengan jeda 15 dtk → 30 dtk → 1 mnt → … maks 15 mnt.
class SyncController extends Notifier<SyncState> {
  Timer? _periodic;
  Timer? _retry;
  Timer? _debounce;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _online = true;
  bool _disposed = false;
  int _failures = 0;

  @override
  SyncState build() {
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      final cameBack = online && !_online;
      _online = online;
      if (!online) {
        _set(SyncState(phase: SyncPhase.offline, lastSyncedAt: state.lastSyncedAt));
      } else if (cameBack) {
        syncNow();
      }
    });

    _periodic = Timer.periodic(const Duration(minutes: 1), (_) => syncNow());

    // Ada data baru masuk antrean → sinkron 2 detik kemudian.
    ref.listen(pendingSyncCountProvider, (prev, next) {
      final before = prev?.asData?.value ?? 0;
      final after = next.asData?.value ?? 0;
      if (after > before) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(seconds: 2), syncNow);
      }
    });

    ref.onDispose(() {
      _disposed = true;
      _periodic?.cancel();
      _retry?.cancel();
      _debounce?.cancel();
      _connSub?.cancel();
    });

    Future.microtask(syncNow); // sinkron pertama saat aplikasi dibuka
    return const SyncState();
  }

  void _set(SyncState s) {
    if (!_disposed) state = s;
  }

  Future<void> syncNow() async {
    if (_disposed || state.isSyncing) return;

    final results = await Connectivity().checkConnectivity();
    _online = results.any((r) => r != ConnectivityResult.none);
    if (!_online) {
      _set(SyncState(phase: SyncPhase.offline, lastSyncedAt: state.lastSyncedAt));
      return;
    }

    _set(SyncState(phase: SyncPhase.syncing, lastSyncedAt: state.lastSyncedAt));
    try {
      await ref.read(syncEngineProvider).run();
      _failures = 0;
      _retry?.cancel();
      _set(SyncState(phase: SyncPhase.idle, lastSyncedAt: DateTime.now()));
    } catch (e) {
      _failures++;
      final seconds = min(15 * pow(2, _failures - 1), 900).toInt();
      _retry?.cancel();
      _retry = Timer(Duration(seconds: seconds), syncNow);
      _set(SyncState(phase: SyncPhase.error, lastSyncedAt: state.lastSyncedAt, lastError: e.toString()));
    }
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(SyncController.new);