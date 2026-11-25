import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kasirku/core/database/app_database.dart';
import 'package:kasirku/core/database/database_provider.dart';
import 'package:kasirku/core/device/device_identity.dart';
import 'package:kasirku/core/theme/app_colors.dart';
import 'package:kasirku/core/utils/format.dart';
import 'package:kasirku/features/auth/data/profile_repository.dart';
import 'package:kasirku/features/cart/application/cart_controller.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _paid = TextEditingController();
  String _method = 'cash';
  bool _saving = false;

  int get _paidValue => parseRupiah(_paid.text);

  @override
  void dispose() {
    _paid.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  List<int> _quickAmounts(int total) {
    final result = <int>{total};
    final roundUp = ((total + 4999) ~/ 5000) * 5000;
    if (roundUp > total) result.add(roundUp);
    for (final p in [10000, 20000, 50000, 100000]) {
      if (p > total) result.add(p);
    }
    final list = result.toList()..sort();
    return list.take(4).toList();
  }

  Future<void> _editDiscount(CartState cart) async {
    final controller = TextEditingController(text: cart.discount == 0 ? '' : '${cart.discount}');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Diskon per nota'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(prefixText: 'Rp ', hintText: '0'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, parseRupiah(controller.text)),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (value == null) return;
    if (value > cart.subtotal) {
      _snack('Diskon tidak boleh lebih dari subtotal');
      return;
    }
    ref.read(cartProvider.notifier).setDiscount(value);
  }

  Future<void> _submit() async {
    final profile = ref.read(myProfileProvider).asData?.value;
    if (profile?.storeId == null) {
      _snack('Data toko belum siap. Coba lagi.');
      return;
    }

    setState(() => _saving = true);
    try {
      final device = await ref.read(deviceIdentityProvider.future);
      final cart = ref.read(cartProvider);
      final paid = _method == 'cash' ? _paidValue : cart.total;

      final trx = await ref.read(appDatabaseProvider).createSale(
            storeId: profile!.storeId!,
            cashierId: profile.id,
            deviceId: device.id,
            deviceCode: device.code,
            discount: cart.discount,
            paid: paid,
            paymentMethod: _method,
            lines: [
              for (final i in cart.items)
                SaleLine(
                  productId: i.product.id,
                  productName: i.product.name,
                  price: i.product.sellPrice,
                  costPrice: i.product.costPrice,
                  qty: i.qty,
                ),
            ],
          );

      ref.read(cartProvider.notifier).clear();
      if (mounted) context.go('/transaksi/${trx.id}?baru=1');
    } catch (e) {
      _snack('Gagal menyimpan transaksi: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary)),
            Text(value),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final stock = ref.watch(stockByProductProvider).asData?.value ?? {};
    final controller = ref.read(cartProvider.notifier);

    if (cart.isEmpty && !_saving) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pembayaran')),
        body: const Center(child: Text('Keranjang kosong')),
      );
    }

    final total = cart.total;
    final change = _paidValue - total;
    final canPay = !_saving && !cart.isEmpty && (_method != 'cash' || _paidValue >= total);

    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pesanan (${cart.itemCount} item)', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
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
                                Text(
                                  '${rupiah(item.product.sellPrice)} · ${rupiah(item.subtotal)}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton.outlined(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.remove, size: 18),
                            onPressed: () => controller.decrement(item.product.id),
                          ),
                          SizedBox(
                            width: 32,
                            child: Text(
                              '${item.qty}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: () {
                              if (item.qty >= (stock[item.product.id] ?? 0)) {
                                _snack('Stok ${item.product.name} tidak cukup');
                                return;
                              }
                              controller.increment(item.product.id);
                            },
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 24),
                  _row('Subtotal', rupiah(cart.subtotal)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Diskon', style: TextStyle(color: AppColors.textSecondary)),
                      TextButton(
                        onPressed: () => _editDiscount(cart),
                        child: Text(cart.discount == 0 ? '+ Tambah diskon' : '- ${rupiah(cart.discount)}'),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(rupiah(total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Metode bayar', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'cash', label: Text('Tunai')),
              ButtonSegment(value: 'qris', label: Text('QRIS')),
              ButtonSegment(value: 'transfer', label: Text('Transfer')),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.first),
          ),
          const SizedBox(height: 16),
          if (_method == 'cash') ...[
            const Text('Uang diterima', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _paid,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(prefixText: 'Rp ', hintText: '0'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in _quickAmounts(total))
                  ChoiceChip(
                    label: Text(a == total ? 'Uang pas' : rupiah(a)),
                    selected: _paidValue == a,
                    onSelected: (_) => setState(() => _paid.text = '$a'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: change >= 0 ? AppColors.successBg : AppColors.dangerBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    change >= 0 ? 'Kembalian' : 'Kurang',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: change >= 0 ? AppColors.success : AppColors.danger,
                    ),
                  ),
                  Text(
                    rupiah(change.abs()),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: change >= 0 ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Pastikan pembayaran ${paymentLabel(_method)} sebesar ${rupiah(total)} '
                'sudah diterima sebelum menekan Selesai.',
                style: const TextStyle(color: AppColors.primaryDark),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: canPay ? _submit : null,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Selesai'),
          ),
        ),
      ),
    );
  }
}