import 'package:drift/drift.dart';

import 'package:kasirku/core/database/app_database.dart';

/// HP pakai camelCase + DateTime, Supabase pakai snake_case + teks ISO 8601.
/// File ini menerjemahkan dua arah.

String _iso(DateTime d) => d.toUtc().toIso8601String();
String? _isoOrNull(DateTime? d) => d == null ? null : _iso(d);
DateTime _dt(dynamic v) => DateTime.parse(v as String).toLocal();
DateTime? _dtOrNull(dynamic v) => v == null ? null : _dt(v);
int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

// ================= HP → Supabase =================

Map<String, dynamic> categoryToServer(ProductCategory c) => {
      'id': c.id,
      'store_id': c.storeId,
      'name': c.name,
      'created_at': _iso(c.createdAt),
      'updated_at': _iso(c.updatedAt),
      'deleted_at': _isoOrNull(c.deletedAt),
    };

Map<String, dynamic> productToServer(Product p) => {
      'id': p.id,
      'store_id': p.storeId,
      'category_id': p.categoryId,
      'name': p.name,
      'barcode': p.barcode,
      'cost_price': p.costPrice,
      'sell_price': p.sellPrice,
      'min_stock': p.minStock,
      'unit': p.unit,
      'image_url': p.imageUrl,
      'created_at': _iso(p.createdAt),
      'updated_at': _iso(p.updatedAt),
      'deleted_at': _isoOrNull(p.deletedAt),
    };

Map<String, dynamic> transactionToServer(TransactionData t) => {
      'id': t.id,
      'store_id': t.storeId,
      'cashier_id': t.cashierId,
      'device_id': t.deviceId,
      'invoice_no': t.invoiceNo,
      'subtotal': t.subtotal,
      'discount': t.discount,
      'total': t.total,
      'paid': t.paid,
      'change': t.change,
      'payment_method': t.paymentMethod,
      'status': t.status,
      'void_reason': t.voidReason,
      'created_at': _iso(t.createdAt),
      'updated_at': _iso(t.updatedAt),
    };

Map<String, dynamic> itemToServer(TransactionItem i) => {
      'id': i.id,
      'store_id': i.storeId,
      'transaction_id': i.transactionId,
      'product_id': i.productId,
      'product_name': i.productName,
      'price': i.price,
      'cost_price': i.costPrice,
      'qty': i.qty,
      'discount': i.discount,
      'created_at': _iso(i.createdAt),
      'updated_at': _iso(i.updatedAt),
    };

Map<String, dynamic> movementToServer(StockMovement m, String userId) => {
      'id': m.id,
      'store_id': m.storeId,
      'product_id': m.productId,
      'type': m.type,
      'qty_delta': m.qtyDelta,
      'ref_id': m.refId,
      'note': m.note,
      'created_by': userId,
      'created_at': _iso(m.createdAt),
      'updated_at': _iso(m.updatedAt),
    };

// ================= Supabase → HP =================

CategoriesCompanion categoryFromServer(Map<String, dynamic> r) => CategoriesCompanion(
      id: Value(r['id'] as String),
      storeId: Value(r['store_id'] as String),
      name: Value(r['name'] as String),
      createdAt: Value(_dt(r['created_at'])),
      updatedAt: Value(_dt(r['updated_at'])),
      deletedAt: Value(_dtOrNull(r['deleted_at'])),
      syncStatus: const Value('synced'),
    );

ProductsCompanion productFromServer(Map<String, dynamic> r) => ProductsCompanion(
      id: Value(r['id'] as String),
      storeId: Value(r['store_id'] as String),
      categoryId: Value(r['category_id'] as String?),
      name: Value(r['name'] as String),
      barcode: Value(r['barcode'] as String?),
      costPrice: Value(_int(r['cost_price'])),
      sellPrice: Value(_int(r['sell_price'])),
      minStock: Value(_int(r['min_stock'])),
      unit: Value((r['unit'] as String?) ?? 'pcs'),
      imageUrl: Value(r['image_url'] as String?),
      createdAt: Value(_dt(r['created_at'])),
      updatedAt: Value(_dt(r['updated_at'])),
      deletedAt: Value(_dtOrNull(r['deleted_at'])),
      syncStatus: const Value('synced'),
    );

TransactionsCompanion transactionFromServer(Map<String, dynamic> r) => TransactionsCompanion(
      id: Value(r['id'] as String),
      storeId: Value(r['store_id'] as String),
      cashierId: Value(r['cashier_id'] as String),
      deviceId: Value(r['device_id'] as String),
      invoiceNo: Value(r['invoice_no'] as String),
      subtotal: Value(_int(r['subtotal'])),
      discount: Value(_int(r['discount'])),
      total: Value(_int(r['total'])),
      paid: Value(_int(r['paid'])),
      change: Value(_int(r['change'])),
      paymentMethod: Value(r['payment_method'] as String),
      status: Value(r['status'] as String),
      voidReason: Value(r['void_reason'] as String?),
      createdAt: Value(_dt(r['created_at'])),
      updatedAt: Value(_dt(r['updated_at'])),
      syncStatus: const Value('synced'),
    );

TransactionItemsCompanion itemFromServer(Map<String, dynamic> r) => TransactionItemsCompanion(
      id: Value(r['id'] as String),
      storeId: Value(r['store_id'] as String),
      transactionId: Value(r['transaction_id'] as String),
      productId: Value(r['product_id'] as String?),
      productName: Value(r['product_name'] as String),
      price: Value(_int(r['price'])),
      costPrice: Value(_int(r['cost_price'])),
      qty: Value(_int(r['qty'])),
      discount: Value(_int(r['discount'])),
      createdAt: Value(_dt(r['created_at'])),
      updatedAt: Value(_dt(r['updated_at'])),
      syncStatus: const Value('synced'),
    );

StockMovementsCompanion movementFromServer(Map<String, dynamic> r) => StockMovementsCompanion(
      id: Value(r['id'] as String),
      storeId: Value(r['store_id'] as String),
      productId: Value(r['product_id'] as String),
      type: Value(r['type'] as String),
      qtyDelta: Value(_int(r['qty_delta'])),
      refId: Value(r['ref_id'] as String?),
      note: Value(r['note'] as String?),
      createdAt: Value(_dt(r['created_at'])),
      updatedAt: Value(_dt(r['updated_at'])),
      syncStatus: const Value('synced'),
    );