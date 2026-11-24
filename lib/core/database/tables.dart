import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

const uuidGenerator = Uuid();
/// Kolom yang ada di semua tabel yang disinkron ke Supabase.
mixin SyncColumns on Table {
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// 'pending' = belum terkirim, 'synced' = sudah di server, 'failed' = gagal
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
}

@DataClassName('ProductCategory') // bukan 'Category' supaya tidak bentrok dengan Flutter
class Categories extends Table with SyncColumns {
  TextColumn get id => text().clientDefault(() => uuidGenerator.v4())();
  TextColumn get storeId => text()();
  TextColumn get name => text()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Products extends Table with SyncColumns {
  TextColumn get id => text().clientDefault(() => uuidGenerator.v4())();
  TextColumn get storeId => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get barcode => text().nullable()();
  IntColumn get costPrice => integer().withDefault(const Constant(0))(); // rupiah
  IntColumn get sellPrice => integer().withDefault(const Constant(0))(); // rupiah
  IntColumn get minStock => integer().withDefault(const Constant(0))();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  TextColumn get imageUrl => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TransactionData')
class Transactions extends Table with SyncColumns {
  TextColumn get id => text().clientDefault(() => uuidGenerator.v4())();
  TextColumn get storeId => text()();
  TextColumn get cashierId => text()();
  TextColumn get deviceId => text()();
  TextColumn get invoiceNo => text()();
  IntColumn get subtotal => integer()();
  IntColumn get discount => integer().withDefault(const Constant(0))();
  IntColumn get total => integer()();
  IntColumn get paid => integer()();
  IntColumn get change => integer().withDefault(const Constant(0))();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get status => text().withDefault(const Constant('paid'))(); // paid / void
  TextColumn get voidReason => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class TransactionItems extends Table with SyncColumns {
  TextColumn get id => text().clientDefault(() => uuidGenerator.v4())();
  TextColumn get storeId => text()();
  TextColumn get transactionId => text()();
  TextColumn get productId => text().nullable()();
  TextColumn get productName => text()(); // snapshot nama saat transaksi
  IntColumn get price => integer()();      // snapshot harga jual
  IntColumn get costPrice => integer().withDefault(const Constant(0))();
  IntColumn get qty => integer()();
  IntColumn get discount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class StockMovements extends Table with SyncColumns {
  TextColumn get id => text().clientDefault(() => uuidGenerator.v4())();
  TextColumn get storeId => text()();
  TextColumn get productId => text()();
  TextColumn get type => text()(); // sale / restock / adjust / void
  IntColumn get qtyDelta => integer()(); // + masuk, - keluar
  TextColumn get refId => text().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Antrean data yang harus dikirim ke server (outbox pattern).
/// Hanya ada di HP, tidak ada di Supabase.
@DataClassName('SyncQueueEntry')
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entity => text()();     // nama tabel, mis. 'products'
  TextColumn get entityId => text()();   // id baris
  TextColumn get operation => text()();  // 'upsert' / 'insert'
  TextColumn get payload => text()();    // data dalam JSON
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}