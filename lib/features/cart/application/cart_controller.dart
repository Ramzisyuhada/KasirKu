import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kasirku/core/database/app_database.dart';

class CartItem {
  const CartItem({required this.product, required this.qty});

  final Product product;
  final int qty;

  int get subtotal => product.sellPrice * qty;

  CartItem copyWith({int? qty}) => CartItem(product: product, qty: qty ?? this.qty);
}

class CartState {
  const CartState({this.items = const [], this.discount = 0});

  final List<CartItem> items;
  final int discount; // diskon per nota (rupiah)

  bool get isEmpty => items.isEmpty;
  int get itemCount => items.fold(0, (sum, i) => sum + i.qty);
  int get subtotal => items.fold(0, (sum, i) => sum + i.subtotal);
  int get total => (subtotal - discount).clamp(0, subtotal);

  int qtyOf(String productId) {
    for (final i in items) {
      if (i.product.id == productId) return i.qty;
    }
    return 0;
  }

  CartState copyWith({List<CartItem>? items, int? discount}) =>
      CartState(items: items ?? this.items, discount: discount ?? this.discount);
}

/// Keranjang belanja. Disimpan di RAM (Riverpod), belum ke database.
class CartController extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void add(Product product) {
    final current = state.qtyOf(product.id);
    if (current == 0) {
      state = state.copyWith(items: [...state.items, CartItem(product: product, qty: 1)]);
    } else {
      setQty(product.id, current + 1);
    }
  }

  void setQty(String productId, int qty) {
    if (qty <= 0) {
      remove(productId);
      return;
    }
    state = state.copyWith(
      items: [
        for (final i in state.items) i.product.id == productId ? i.copyWith(qty: qty) : i,
      ],
    );
  }

  void increment(String productId) => setQty(productId, state.qtyOf(productId) + 1);
  void decrement(String productId) => setQty(productId, state.qtyOf(productId) - 1);

  void remove(String productId) {
    state = state.copyWith(items: state.items.where((i) => i.product.id != productId).toList());
  }

  void setDiscount(int discount) => state = state.copyWith(discount: discount < 0 ? 0 : discount);

  void clear() => state = const CartState();
}

final cartProvider = NotifierProvider<CartController, CartState>(CartController.new);