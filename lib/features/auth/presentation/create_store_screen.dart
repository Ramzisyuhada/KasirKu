import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CreateStoreScreen extends StatelessWidget {
  const CreateStoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Toko')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: FilledButton(
          onPressed: () => context.go('/kasir'),
          child: const Text('Simpan toko (sementara)'),
        ),
      ),
    );
  }
}