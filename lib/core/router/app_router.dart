import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kasirku/features/auth/data/auth_repository.dart';
import 'package:kasirku/features/auth/data/profile_repository.dart';
import 'package:kasirku/features/auth/presentation/create_store_screen.dart';
import 'package:kasirku/features/auth/presentation/login_screen.dart';
import 'package:kasirku/features/auth/presentation/splash_screen.dart';
import 'package:kasirku/features/cart/presentation/kasir_screen.dart';

class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const createStore = '/create-store';
  static const kasir = '/kasir';
}

/// Mendengarkan status login + profil, lalu menyuruh router cek ulang.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    // Setiap login/keluar: ambil ulang profil, lalu cek ulang redirect.
    _authSub = _ref.read(authRepositoryProvider).authChanges.listen((_) {
      _ref.invalidate(myProfileProvider);
      notifyListeners();
    });
    // Setiap profil berubah (loading → data, buat toko, dll.): cek ulang.
    _ref.listen(myProfileProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
  late final StreamSubscription<dynamic> _authSub;

  String? redirect(BuildContext context, GoRouterState state) {
    final loc = state.matchedLocation;
    final loggedIn = _ref.read(authRepositoryProvider).isLoggedIn;

    // 1. Belum login → Login
    if (!loggedIn) return loc == AppRoutes.login ? null : AppRoutes.login;

    // 2. Profil masih dimuat / gagal → Splash
    final profileAsync = _ref.read(myProfileProvider);
    final data = profileAsync.asData;
    if (profileAsync.hasError || data == null) {
      return loc == AppRoutes.splash ? null : AppRoutes.splash;
    }

    // 3. Belum punya toko → Buat/Gabung Toko
    final hasStore = data.value?.hasStore ?? false;
    if (!hasStore) {
      return loc == AppRoutes.createStore ? null : AppRoutes.createStore;
    }

    // 4. Sudah punya toko, tapi masih di layar awal → Kasir
    if (loc == AppRoutes.login || loc == AppRoutes.splash || loc == AppRoutes.createStore) {
      return AppRoutes.kasir;
    }
    return null;
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.createStore, builder: (_, __) => const CreateStoreScreen()),
      GoRoute(path: AppRoutes.kasir, builder: (_, __) => const KasirScreen()),
    ],
  );

  ref.onDispose(() {
    notifier.dispose();
    router.dispose();
  });
  return router;
});