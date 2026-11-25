import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kasirku/core/database/app_database.dart';
import 'package:kasirku/core/database/database_provider.dart';
import 'package:kasirku/core/theme/app_colors.dart';
import 'package:kasirku/core/widgets/sync_chip.dart';
import 'package:kasirku/features/auth/data/auth_repository.dart';
import 'package:kasirku/features/auth/data/profile_repository.dart';
import 'package:kasirku/features/auth/data/store_repository.dart';
import 'package:kasirku/features/cart/application/cart_controller.dart';
import 'package:kasirku/features/cart/presentation/widgets/cart_widgets.dart';
import 'package:kasirku/features/cart/presentation/widgets/product_tile.dart';
import 'package:kasirku/features/product/presentation/barcode_scanner_screen.dart';

class KasirScreen extends ConsumerStatefulWidget {
  const KasirScreen({super.key});

  @override
  ConsumerState<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends ConsumerState<KasirScreen> {
  String _query = '';
  String? _categoryId; // null = Semua

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  /// Tambah ke keranjang, tapi tolak kalau melebihi stok.
  void _addToCart(Product product) {
    final stock = ref.read(stockByProductProvider).asData?.value[product.id] ?? 0;
    final inCart = ref.read(cartProvider).qtyOf(product.id);
    if (inCart >= stock) {
      _snack(stock <= 0 ? '${product.name} habis' : 'Stok ${product.name} tinggal $stock');
      return;
    }
    ref.read(cartProvider.notifier).add(product);
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !mounted) return;

    final product = await ref.read(appDatabaseProvider).findByBarcode(code);
    if (!mounted) return;
    if (product == null) {
      _snack('Produk dengan barcode $code tidak ditemukan');
      return;
    }
    _addToCart(product);
    _snack('${product.name} ditambahkan');
  }

  void _openCart() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => CartSheet(
        onCheckout: () {
          Navigator.pop(sheetContext); // tutup lembar keranjang
          context.push('/pembayaran'); // buka layar Pembayaran
        },
      ),
    );
  }

  Future<void> _createInvite() async {
    try {
      final code = await ref.read(storeRepositoryProvider).createInvite();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Kode undangan kasir'),
          content: SelectableText(
            code,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: 4),
          ),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
              child: const Text('Salin'),
            ),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          ],
        ),
      );
    } catch (e) {
      _snack(friendlyStoreError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider).asData?.value;
    final pending = ref.watch(pendingSyncCountProvider).asData?.value ?? 0;
    final productsAsync = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider).asData?.value ?? <ProductCategory>[];
    final stock = ref.watch(stockByProductProvider).asData?.value ?? {};
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(profile?.storeName ?? 'KasirKu'),
            Text(
              '${profile?.isOwner == true ? 'Pemilik' : 'Kasir'}: ${profile?.name ?? ''}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          SyncChip(pending: pending),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'invite') _createInvite();
              if (v == 'logout') ref.read(authRepositoryProvider).signOut();
            },
            itemBuilder: (_) => [
              if (profile?.isOwner == true)
                const PopupMenuItem(value: 'invite', child: Text('Undang kasir')),
              const PopupMenuItem(value: 'logout', child: Text('Keluar')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ---------- Pencarian + scan ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Cari produk atau barcode',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: IconButton.filled(
                        tooltip: 'Scan barcode',
                        style: IconButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _scan,
                      ),
                    ),
                  ],
                ),
              ),

              // ---------- Filter kategori ----------
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('Semua'),
                        selected: _categoryId == null,
                        onSelected: (_) => setState(() => _categoryId = null),
                      ),
                    ),
                    for (final c in categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c.name),
                          selected: _categoryId == c.id,
                          onSelected: (_) => setState(() => _categoryId = c.id),
                        ),
                      ),
                  ],
                ),
              ),

              // ---------- Grid produk ----------
              Expanded(
                child: productsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (all) {
                    final q = _query.toLowerCase();
                    final list = all.where((p) {
                      final matchQuery =
                          q.isEmpty || p.name.toLowerCase().contains(q) || (p.barcode ?? '').contains(q);
                      final matchCategory = _categoryId == null || p.categoryId == _categoryId;
                      return matchQuery && matchCategory;
                    }).toList();

                    if (list.isEmpty) {
                      return Center(
                        child: Text(
                          all.isEmpty ? 'Belum ada produk.\nTambah produk di tab Produk.' : 'Produk tidak ditemukan.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, cart.isEmpty ? 16 : 96),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final p = list[i];
                        return ProductTile(
                          product: p,
                          stock: stock[p.id] ?? 0,
                          qtyInCart: cart.qtyOf(p.id),
                          onTap: () => _addToCart(p),
                          onLongPress: () => ref.read(cartProvider.notifier).decrement(p.id),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // ---------- Bar keranjang ----------
          if (!cart.isEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: CartBar(cart: cart, onTap: _openCart),
            ),
        ],
      ),
    );
  }
}