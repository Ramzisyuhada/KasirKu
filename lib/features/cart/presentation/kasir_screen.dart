import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class KasirScreen extends StatelessWidget {
  const KasirScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Warung Bu Sri')),
      body: Center(
        child: TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Keluar (sementara)'),
        ),
      ),
    );
  }
}