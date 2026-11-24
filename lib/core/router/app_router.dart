import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kasirku/core/widgets/home_shell.dart';
import 'package:kasirku/features/auth/data/auth_repository.dart';
import 'package:kasirku/features/auth/data/profile_repository.dart';
import 'package:kasirku/features/auth/presentation/create_store_screen.dart';
import 'package:kasirku/features/auth/presentation/login_screen.dart';
import 'package:kasirku/features/auth/presentation/splash_screen.dart';
import 'package:kasirku/features/cart/presentation/kasir_screen.dart';
import 'package:kasirku/features/product/presentation/product_form_screen.dart';
import 'package:kasirku/features/product/presentation/product_list_screen.dart';
import 'package:kasirku/features/report/presentation/laporan_screen.dart';
import 'package:kasirku/features/transaction/presentation/riwayat_screen.dart';

class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const createStore = '/create-store';
  static const kasir = '/kasir';
  static const riwayat = '/riwayat';
  static const produk = '/produk';
  static const laporan = '/laporan';
}

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _authSub = _ref.read(authRepositoryProvider).authChanges.listen((_) {
      _ref.invalidate(myProfileProvider);
      notifyListeners();
    });
    _ref.listen(myProfileProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
  late final StreamSubscription<dynamic> _authSub;

  String? redirect(BuildContext context, GoRouterState state) {
    final loc = state.matchedLocation;
    final loggedIn = _ref.read(authRepositoryProvider).isLoggedIn;

    if (!loggedIn) return loc == AppRoutes.login ? null : AppRoutes.login;

    final profileAsync = _ref.read(myProfileProvider);
    final data = profileAsync.asData;
    if (profileAsync.hasError || data == null) {
      return loc == AppRoutes.splash ? null : AppRoutes.splash;
    }

    final hasStore = data.value?.hasStore ?? false;
    if (!hasStore) {
      return loc == AppRoutes.createStore ? null : AppRoutes.createStore;
    }

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

      // Form produk tampil penuh (tanpa bottom nav)
      GoRoute(path: '/produk/tambah', builder: (_, __) => const ProductFormScreen()),
      GoRoute(
        path: '/produk/edit/:id',
        builder: (_, state) => ProductFormScreen(productId: state.pathParameters['id']),
      ),

      // 4 tab dengan bottom nav
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: AppRoutes.kasir, builder: (_, __) => const KasirScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: AppRoutes.riwayat, builder: (_, __) => const RiwayatScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: AppRoutes.produk, builder: (_, __) => const ProductListScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: AppRoutes.laporan, builder: (_, __) => const LaporanScreen())]),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    notifier.dispose();
    router.dispose();
  });
  return router;
});