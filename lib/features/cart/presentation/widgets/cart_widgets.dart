import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kasirku/core/database/database_provider.dart';
import 'package:kasirku/core/theme/app_colors.dart';
import 'package:kasirku/core/utils/format.dart';
import 'package:kasirku/features/cart/application/cart_controller.dart';

/// Bar hijau di bawah layar Kasir: "3 item · Rp11.000 · Bayar →"
class CartBar extends StatelessWidget {
  const CartBar({super.key, required this.cart, required this.onTap});

  final CartState cart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryDark,
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${cart.itemCount} item',
                          style: const TextStyle(color: AppColors.primarySoft, fontSize: 12)),
                      Text(rupiah(cart.total),
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const Text('Bayar  →',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lembar dari bawah: ubah qty, hapus item, kosongkan keranjang.
class CartSheet extends ConsumerWidget {
  const CartSheet({super.key, required this.onCheckout});

  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final controller = ref.read(cartProvider.notifier);
    final stock = ref.watch(stockByProductProvider).asData?.value ?? {};

    if (cart.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Keranjang kosong')),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Keranjang (${cart.itemCount} item)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                TextButton(
                  onPressed: () {
                    controller.clear();
                    Navigator.pop(context);
                  },
                  child: const Text('Kosongkan'),
                ),
              ],
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final item in cart.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text('${rupiah(item.product.sellPrice)} · ${rupiah(item.subtotal)}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          _QtyButton(icon: Icons.remove, onTap: () => controller.decrement(item.product.id)),
                          SizedBox(
                            width: 36,
                            child: Text('${item.qty}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                          _QtyButton(
                            icon: Icons.add,
                            primary: true,
                            onTap: () {
                              if (item.qty >= (stock[item.product.id] ?? 0)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Stok ${item.product.name} tidak cukup')),
                                );
                                return;
                              }
                              controller.increment(item.product.id);
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text(rupiah(cart.total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onCheckout, child: const Text('Lanjut ke pembayaran')),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap, this.primary = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? AppColors.primaryLight : AppColors.background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: primary ? AppColors.primaryDark : AppColors.textPrimary),
        ),
      ),
    );
  }
}