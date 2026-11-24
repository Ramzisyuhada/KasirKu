import 'package:flutter/material.dart';

import 'bootstrap.dart';

class App extends StatelessWidget {
  const App({super.key, required this.env});

  final Env env;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KasirKu',
      debugShowCheckedModeBanner: env == Env.dev,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'KasirKu siap!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Mode: ${env.name}'),
            ],
          ),
        ),
      ),
    );
  }
}