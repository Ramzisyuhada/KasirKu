import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kasirku/core/database/app_database.dart';
import 'package:kasirku/core/database/database_provider.dart';
import 'package:kasirku/core/theme/app_colors.dart';
import 'package:kasirku/core/utils/format.dart';
import 'package:kasirku/features/auth/data/profile_repository.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  String _query = '';

  bool _isLow(Product p, int stock) => stock <= 0 || (p.minStock > 0 && stock <= p.minStock);

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(myProfileProvider).asData?.value?.isOwner ?? false;
    final productsAsync = ref.watch(productsProvider);
    final stock = ref.watch(stockByProductProvider).asData?.value ?? {};
    final categories = {
      for (final c in ref.watch(categoriesProvider).asData?.value ?? <ProductCategory>[]) c.id: c.name,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Produk')),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/produk/tambah'),
              icon: const Icon(Icons.add),
              label: const Text('Produk'),
            )
          : null,
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (all) {
          final q = _query.toLowerCase();
          final list = all
              .where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || (p.barcode ?? '').contains(q))
              .toList();
          final lowCount = all.where((p) => _isLow(p, stock[p.id] ?? 0)).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Cari ${all.length} produk',
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              if (lowCount > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                      const SizedBox(width: 10),
                      Text(
                        '$lowCount produk stok menipis',
                        style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Text(
                    all.isEmpty ? 'Belum ada produk.\nKetuk "+ Produk" untuk menambah.' : 'Produk tidak ditemukan.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0) const Divider(),
                        _ProductTile(
                          product: list[i],
                          stock: stock[list[i].id] ?? 0,
                          categoryName: categories[list[i].categoryId],
                          isLow: _isLow(list[i], stock[list[i].id] ?? 0),
                          onTap: isOwner ? () => context.push('/produk/edit/${list[i].id}') : null,
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.stock,
    required this.isLow,
    this.categoryName,
    this.onTap,
  });

  final Product product;
  final int stock;
  final bool isLow;
  final String? categoryName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = stock <= 0 ? AppColors.danger : (isLow ? AppColors.warning : AppColors.textPrimary);

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
        child: Text(
          initials(product.name),
          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${categoryName ?? 'Tanpa kategori'} · ${rupiah(product.sellPrice)}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('$stock ${product.unit}', style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          if (isLow)
            Text(stock <= 0 ? 'Habis' : 'Menipis', style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}