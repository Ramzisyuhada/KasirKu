import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class App extends ConsumerWidget {
  const App({super.key, required this.env});

  final Env env;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'KasirKu',
      debugShowCheckedModeBanner: env == Env.dev,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}