import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kasirku/features/auth/presentation/create_store_screen.dart';
import 'package:kasirku/features/cart/presentation/kasir_screen.dart';
import 'package:kasirku/features/auth/presentation/login_screen.dart';

class AppRoutes {
  static const login = '/login';
  static const createStore = '/create-store';
  static const kasir = '/kasir';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.login,
    routes: [
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.createStore, builder: (_, __) => const CreateStoreScreen()),
      GoRoute(path: AppRoutes.kasir, builder: (_, __) => const KasirScreen()),
    ],
  );
});