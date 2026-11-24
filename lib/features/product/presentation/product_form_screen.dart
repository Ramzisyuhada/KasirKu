import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kasirku/core/database/app_database.dart';
import 'package:kasirku/core/database/database_provider.dart';
import 'package:kasirku/core/utils/format.dart';
import 'package:kasirku/features/auth/data/profile_repository.dart';
import 'package:kasirku/features/product/presentation/barcode_scanner_screen.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  /// null = tambah produk baru, terisi = edit produk.
  final String? productId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _barcode = TextEditingController();
  final _unit = TextEditingController(text: 'pcs');
  final _costPrice = TextEditingController();
  final _sellPrice = TextEditingController();
  final _stock = TextEditingController(text: '0');
  final _minStock = TextEditingController(text: '0');

  String? _categoryId;
  Product? _product;
  bool _loading = false;

  bool get _isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadProduct();
  }

  Future<void> _loadProduct() async {
    final db = ref.read(appDatabaseProvider);
    final p = await db.getProduct(widget.productId!);
    if (p == null || !mounted) return;
    final stock = await db.getStock(p.id);
    setState(() {
      _product = p;
      _name.text = p.name;
      _barcode.text = p.barcode ?? '';
      _unit.text = p.unit;
      _costPrice.text = p.costPrice.toString();
      _sellPrice.text = p.sellPrice.toString();
      _stock.text = stock.toString();
      _minStock.text = p.minStock.toString();
      _categoryId = p.categoryId;
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _barcode, _unit, _costPrice, _sellPrice, _stock, _minStock]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code != null) setState(() => _barcode.text = code);
  }

  Future<void> _addCategory(String storeId) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kategori baru'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Mis. Minuman'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Simpan')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final category = await ref.read(appDatabaseProvider).addCategory(storeId: storeId, name: name);
    setState(() => _categoryId = category.id);
  }

  Future<void> _save(String storeId) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final db = ref.read(appDatabaseProvider);
    final barcode = _barcode.text.trim().isEmpty ? null : _barcode.text.trim();
    final unit = _unit.text.trim().isEmpty ? 'pcs' : _unit.text.trim();

    try {
      if (_isEdit && _product != null) {
        await db.updateProduct(
          product: _product!,
          name: _name.text.trim(),
          sellPrice: parseRupiah(_sellPrice.text),
          costPrice: parseRupiah(_costPrice.text),
          unit: unit,
          minStock: parseRupiah(_minStock.text),
          barcode: barcode,
          categoryId: _categoryId,
          newStock: parseRupiah(_stock.text),
        );
      } else {
        await db.addProductWithStock(
          storeId: storeId,
          name: _name.text.trim(),
          sellPrice: parseRupiah(_sellPrice.text),
          costPrice: parseRupiah(_costPrice.text),
          unit: unit,
          minStock: parseRupiah(_minStock.text),
          barcode: barcode,
          categoryId: _categoryId,
          initialStock: parseRupiah(_stock.text),
        );
      }
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus produk?'),
        content: Text('"${_product!.name}" tidak akan tampil lagi di daftar produk.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(appDatabaseProvider).softDeleteProduct(_product!);
    if (mounted) context.pop();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null;

  @override
  Widget build(BuildContext context) {
    final storeId = ref.watch(myProfileProvider).asData?.value?.storeId;
    final categories = ref.watch(categoriesProvider).asData?.value ?? <ProductCategory>[];
    final numberOnly = [FilteringTextInputFormatter.digitsOnly];

    if (_isEdit && _product == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit produk' : 'Tambah produk'),
        actions: [
          if (_isEdit) IconButton(tooltip: 'Hapus', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nama produk *'),
              validator: _required,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _barcode,
              decoration: InputDecoration(
                labelText: 'Barcode (opsional)',
                suffixIcon: IconButton(
                  tooltip: 'Scan',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scan,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tanpa kategori')),
                      for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Kategori baru',
                  icon: const Icon(Icons.add),
                  onPressed: storeId == null ? null : () => _addCategory(storeId),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _costPrice,
                    decoration: const InputDecoration(labelText: 'Harga modal', prefixText: 'Rp '),
                    keyboardType: TextInputType.number,
                    inputFormatters: numberOnly,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sellPrice,
                    decoration: const InputDecoration(labelText: 'Harga jual *', prefixText: 'Rp '),
                    keyboardType: TextInputType.number,
                    inputFormatters: numberOnly,
                    validator: (v) => parseRupiah(v ?? '') <= 0 ? 'Isi harga jual' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stock,
                    decoration: InputDecoration(labelText: _isEdit ? 'Stok saat ini' : 'Stok awal'),
                    keyboardType: TextInputType.number,
                    inputFormatters: numberOnly,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minStock,
                    decoration: const InputDecoration(labelText: 'Stok minimum'),
                    keyboardType: TextInputType.number,
                    inputFormatters: numberOnly,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: _unit,
                    decoration: const InputDecoration(labelText: 'Satuan'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Stok minimum: produk ditandai "Menipis" kalau stok sama atau di bawah angka ini.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: (_loading || storeId == null) ? null : () => _save(storeId),
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}