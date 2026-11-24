import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final productsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(appDatabaseProvider).watchProducts();
});

final categoriesProvider = StreamProvider<List<ProductCategory>>((ref) {
  return ref.watch(appDatabaseProvider).watchCategories();
});

final stockByProductProvider = StreamProvider<Map<String, int>>((ref) {
  return ref.watch(appDatabaseProvider).watchStockByProduct();
});

final pendingSyncCountProvider = StreamProvider<int>((ref) {
  return ref.watch(appDatabaseProvider).watchPendingSyncCount();
});