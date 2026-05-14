import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../models/supplier.dart';
import '../models/import_order.dart';
import '../models/customer.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<String> getDbPath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'nha_sach_thao_nguyen.db');
  }

  Future<void> closeAndReset() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'nha_sach_thao_nguyen.db');

    return await openDatabase(
      path,
      version: 10,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id TEXT PRIMARY KEY,
            username TEXT UNIQUE NOT NULL,
            email TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            display_name TEXT,
            created_at TEXT NOT NULL,
            is_active INTEGER DEFAULT 1,
            role TEXT DEFAULT 'cashier',
            department TEXT,
            hire_date TEXT,
            last_login TEXT,
            is_suspended INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE activity_logs (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            action TEXT,
            resource_type TEXT,
            resource_id TEXT,
            old_value TEXT,
            new_value TEXT,
            timestamp TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE products (
            id TEXT PRIMARY KEY,
            ma_hang TEXT,
            ma_vach TEXT,
            ten_hang TEXT NOT NULL,
            thuong_hieu TEXT,
            gia_ban INTEGER DEFAULT 0,
            gia_von INTEGER DEFAULT 0,
            ton_kho INTEGER DEFAULT 0,
            nhom_hang TEXT,
            loai_hang TEXT,
            hinh_anh TEXT,
            mo_ta TEXT,
            dang_kinh_doanh INTEGER DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE orders (
            id TEXT PRIMARY KEY,
            ngay_tao TEXT,
            tong_tien INTEGER,
            tong_von INTEGER DEFAULT 0,
            giam_gia INTEGER DEFAULT 0,
            khach_dua INTEGER,
            tien_thua INTEGER,
            ghi_chu TEXT,
            trang_thai TEXT DEFAULT 'hoan_thanh',
            khach_hang_id TEXT,
            ten_khach TEXT DEFAULT 'Khách lẻ',
            nguoi_tao TEXT DEFAULT ''
          )
        ''');

        await db.execute('''
          CREATE TABLE order_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id TEXT,
            product_id TEXT,
            ten_hang TEXT,
            so_luong INTEGER,
            don_gia INTEGER,
            thanh_tien INTEGER,
            gia_von INTEGER DEFAULT 0,
            FOREIGN KEY (order_id) REFERENCES orders(id)
          )
        ''');
        await _createSupplierTables(db);
        await _createCustomerTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE users (
              id TEXT PRIMARY KEY,
              username TEXT UNIQUE NOT NULL,
              email TEXT UNIQUE NOT NULL,
              password_hash TEXT NOT NULL,
              display_name TEXT,
              created_at TEXT NOT NULL,
              is_active INTEGER DEFAULT 1
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE users ADD COLUMN role TEXT DEFAULT "cashier"');
          await db.execute('ALTER TABLE users ADD COLUMN department TEXT');
          await db.execute('ALTER TABLE users ADD COLUMN hire_date TEXT');
          await db.execute('ALTER TABLE users ADD COLUMN last_login TEXT');
          await db.execute('ALTER TABLE users ADD COLUMN is_suspended INTEGER DEFAULT 0');

          await db.execute('''
            CREATE TABLE activity_logs (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              action TEXT,
              resource_type TEXT,
              resource_id TEXT,
              old_value TEXT,
              new_value TEXT,
              timestamp TEXT NOT NULL,
              FOREIGN KEY (user_id) REFERENCES users(id)
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute(
              "UPDATE users SET role = 'admin' WHERE username = 'admin'");
        }
        if (oldVersion < 5) {
          await _createSupplierTables(db);
        }
        if (oldVersion < 6) {
          await _createCustomerTable(db);
        }
        if (oldVersion < 7) {
          await db.execute("ALTER TABLE orders ADD COLUMN tong_von INTEGER DEFAULT 0");
          await db.execute("ALTER TABLE orders ADD COLUMN khach_hang_id TEXT");
          await db.execute("ALTER TABLE orders ADD COLUMN ten_khach TEXT DEFAULT 'Khách lẻ'");
          await db.execute("ALTER TABLE order_items ADD COLUMN gia_von INTEGER DEFAULT 0");
        }
        if (oldVersion < 8) {
          await db.execute("ALTER TABLE orders ADD COLUMN giam_gia INTEGER DEFAULT 0");
        }
        if (oldVersion < 9) {
          await db.execute("ALTER TABLE import_orders ADD COLUMN tien_ship INTEGER DEFAULT 0");
        }
        if (oldVersion < 10) {
          await db.execute("ALTER TABLE orders ADD COLUMN nguoi_tao TEXT DEFAULT ''");
        }
      },
      onOpen: (db) async {
        final users = await db.rawQuery("SELECT COUNT(*) as c FROM users");
        if ((users.first['c'] as int) == 0) {
          final id = const Uuid().v4();
          final now = DateTime.now().toIso8601String();
          await db.insert('users', {
            'id': id,
            'username': 'admin',
            'email': 'admin@admin.com',
            'password_hash':
                '7676aaafb027c825bd9abab78b234070e702752f625b752e55e55b48e607e358',
            'role': 'admin',
            'is_active': 1,
            'created_at': now,
          });
        }
      },
    );
  }

  // ========== PRODUCTS ==========

  Future<void> insertProduct(Product product) async {
    final db = await database;
    await db.insert('products', product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertProducts(List<Product> products) async {
    final db = await database;
    final batch = db.batch();
    for (final p in products) {
      batch.insert('products', p.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Product>> getProducts() async {
    final db = await database;
    final maps = await db.query('products', where: 'dang_kinh_doanh = 1');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final maps = await db.query('products');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<void> updateProduct(Product product) async {
    final db = await database;
    await db.update('products', product.toMap(),
        where: 'id = ?', whereArgs: [product.id]);
  }

  Future<void> deleteProduct(String id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateStock(String id, int newStock) async {
    final db = await database;
    await db.update('products', {'ton_kho': newStock},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getProductCount() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM products WHERE dang_kinh_doanh = 1');
    return result.first['count'] as int;
  }

  // ========== ORDERS ==========

  Future<void> insertOrder(
      String id,
      DateTime ngayTao,
      int tongTien,
      int khachDua,
      int tienThua,
      String ghiChu,
      List<Map<String, dynamic>> items,
      {String trangThai = 'hoan_thanh',
      int tongVon = 0,
      int giamGia = 0,
      String? khachHangId,
      String tenKhach = 'Khách lẻ',
      String nguoiTao = ''}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('orders', {
        'id': id,
        'ngay_tao': ngayTao.toIso8601String(),
        'tong_tien': tongTien,
        'tong_von': tongVon,
        'giam_gia': giamGia,
        'khach_dua': khachDua,
        'tien_thua': tienThua,
        'ghi_chu': ghiChu,
        'trang_thai': trangThai,
        'khach_hang_id': khachHangId,
        'ten_khach': tenKhach,
        'nguoi_tao': nguoiTao,
      });
      for (final item in items) {
        await txn.insert('order_items', {'order_id': id, ...item});
        final pid = item['product_id'] as String?;
        final qty = (item['so_luong'] as int?) ?? 0;
        if (pid != null && pid.isNotEmpty && qty > 0) {
          await txn.rawUpdate(
            'UPDATE products SET ton_kho = MAX(0, ton_kho - ?) WHERE id = ?',
            [qty, pid],
          );
        }
      }
    });
  }

  Future<void> deleteOrder(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      final items =
          await txn.query('order_items', where: 'order_id = ?', whereArgs: [id]);
      for (final item in items) {
        final pid = item['product_id'] as String?;
        final qty = (item['so_luong'] as int?) ?? 0;
        if (pid != null && pid.isNotEmpty && qty > 0) {
          await txn.rawUpdate(
            'UPDATE products SET ton_kho = ton_kho + ? WHERE id = ?',
            [qty, pid],
          );
        }
      }
      await txn.delete('order_items', where: 'order_id = ?', whereArgs: [id]);
      await txn.delete('orders', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> updateOrder(
    String id, {
    required List<Map<String, dynamic>> newItems,
    required int tongTien,
    required int tongVon,
    required int giamGia,
    required int khachDua,
    required int tienThua,
    String ghiChu = '',
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // Restore stock for old items
      final oldItems =
          await txn.query('order_items', where: 'order_id = ?', whereArgs: [id]);
      for (final item in oldItems) {
        final pid = item['product_id'] as String?;
        final qty = (item['so_luong'] as int?) ?? 0;
        if (pid != null && pid.isNotEmpty && qty > 0) {
          await txn.rawUpdate(
            'UPDATE products SET ton_kho = ton_kho + ? WHERE id = ?',
            [qty, pid],
          );
        }
      }
      // Replace items
      await txn.delete('order_items', where: 'order_id = ?', whereArgs: [id]);
      for (final item in newItems) {
        await txn.insert('order_items', {'order_id': id, ...item});
        final pid = item['product_id'] as String?;
        final qty = (item['so_luong'] as int?) ?? 0;
        if (pid != null && pid.isNotEmpty && qty > 0) {
          await txn.rawUpdate(
            'UPDATE products SET ton_kho = MAX(0, ton_kho - ?) WHERE id = ?',
            [qty, pid],
          );
        }
      }
      // Update order header
      await txn.update(
        'orders',
        {
          'tong_tien': tongTien,
          'tong_von': tongVon,
          'giam_gia': giamGia,
          'khach_dua': khachDua,
          'tien_thua': tienThua,
          'ghi_chu': ghiChu,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<bool> orderExists(String id) async {
    final db = await database;
    final result = await db.query('orders', where: 'id = ?', whereArgs: [id], limit: 1);
    return result.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getOrders() async {
    final db = await database;
    return await db.query('orders', orderBy: 'ngay_tao DESC');
  }

  Future<List<Map<String, dynamic>>> getOrderItems(String orderId) async {
    final db = await database;
    return await db
        .query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
  }

  Future<Map<String, dynamic>> getRevenueStats() async {
    final db = await database;
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final monthStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}';

    final todayRow = await db.rawQuery(
        "SELECT COALESCE(SUM(tong_tien),0) as rev, COALESCE(SUM(tong_von),0) as von FROM orders WHERE trang_thai='hoan_thanh' AND ngay_tao LIKE '$todayStr%'");
    final monthRow = await db.rawQuery(
        "SELECT COALESCE(SUM(tong_tien),0) as rev, COALESCE(SUM(tong_von),0) as von FROM orders WHERE trang_thai='hoan_thanh' AND ngay_tao LIKE '$monthStr%'");
    final totalRow = await db.rawQuery(
        "SELECT COALESCE(SUM(tong_tien),0) as rev, COALESCE(SUM(tong_von),0) as von FROM orders WHERE trang_thai='hoan_thanh'");
    final orderCount = await db.rawQuery(
        "SELECT COUNT(*) as count FROM orders WHERE trang_thai='hoan_thanh'");

    final todayRev = (todayRow.first['rev'] as num?)?.toInt() ?? 0;
    final todayVon = (todayRow.first['von'] as num?)?.toInt() ?? 0;
    final monthRev = (monthRow.first['rev'] as num?)?.toInt() ?? 0;
    final monthVon = (monthRow.first['von'] as num?)?.toInt() ?? 0;
    final totalRev = (totalRow.first['rev'] as num?)?.toInt() ?? 0;

    return {
      'hom_nay': todayRev,
      'von_hom_nay': todayVon,
      'loi_nhuan_hom_nay': todayRev - todayVon,
      'thang_nay': monthRev,
      'von_thang_nay': monthVon,
      'loi_nhuan_thang_nay': monthRev - monthVon,
      'tong_cong': totalRev,
      'so_don': orderCount.first['count'],
    };
  }

  Future<List<Map<String, dynamic>>> getRevenueByAccount(
      DateTime from, DateTime to) async {
    final db = await database;
    String pad(int n) => n.toString().padLeft(2, '0');
    final f = '${from.year}-${pad(from.month)}-${pad(from.day)}';
    // Use exclusive upper bound with the next day to handle ISO timestamps (T separator)
    final toNext = to.add(const Duration(days: 1));
    final tExcl = '${toNext.year}-${pad(toNext.month)}-${pad(toNext.day)}';

    final rows = await db.rawQuery('''
      SELECT
        COALESCE(nguoi_tao, '') AS nguoi_tao,
        COUNT(*) AS so_don,
        COALESCE(SUM(tong_tien), 0) AS doanh_thu,
        COALESCE(SUM(tong_von), 0) AS tong_von,
        COALESCE(SUM(giam_gia), 0) AS giam_gia
      FROM orders
      WHERE trang_thai = 'hoan_thanh'
        AND ngay_tao >= ?
        AND ngay_tao < ?
      GROUP BY nguoi_tao
      ORDER BY doanh_thu DESC
    ''', [f, tExcl]);

    return rows.map((r) {
      final rev = (r['doanh_thu'] as num?)?.toInt() ?? 0;
      final von = (r['tong_von'] as num?)?.toInt() ?? 0;
      return {
        'nguoiTao': (r['nguoi_tao'] as String?) ?? '',
        'soDon': (r['so_don'] as num?)?.toInt() ?? 0,
        'doanhThu': rev,
        'tongVon': von,
        'loiNhuan': rev - von,
        'giamGia': (r['giam_gia'] as num?)?.toInt() ?? 0,
      };
    }).toList();
  }

  // ========== USERS ==========

  Future<void> insertUser(User user) async {
    final db = await database;
    await db.insert('users', user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<User?> getUserById(String id) async {
    final db = await database;
    final maps = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<User?> getUserByUsername(String username) async {
    final db = await database;
    final maps = await db.query('users',
        where: 'username = ? AND is_active = 1', whereArgs: [username]);
    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final maps = await db.query('users',
        where: 'email = ? AND is_active = 1', whereArgs: [email]);
    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<bool> usernameExists(String username) async {
    final db = await database;
    final maps =
        await db.query('users', where: 'username = ?', whereArgs: [username]);
    return maps.isNotEmpty;
  }

  Future<bool> emailExists(String email) async {
    final db = await database;
    final maps =
        await db.query('users', where: 'email = ?', whereArgs: [email]);
    return maps.isNotEmpty;
  }

  Future<void> updateUser(User user) async {
    final db = await database;
    await db
        .update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final maps = await db.query('users', orderBy: 'created_at DESC');
    return maps.map((m) => User.fromMap(m)).toList();
  }

  Future<void> updateUserRole(String userId, String role) async {
    final db = await database;
    await db.update('users', {'role': role},
        where: 'id = ?', whereArgs: [userId]);
  }

  Future<void> suspendUser(String userId) async {
    final db = await database;
    await db.update('users', {'is_suspended': 1},
        where: 'id = ?', whereArgs: [userId]);
  }

  Future<void> activateUser(String userId) async {
    final db = await database;
    await db.update('users', {'is_suspended': 0},
        where: 'id = ?', whereArgs: [userId]);
  }

  Future<void> updateLastLogin(String userId) async {
    final db = await database;
    await db.update('users', {'last_login': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [userId]);
  }

  Future<void> updatePassword(String userId, String newPasswordHash) async {
    final db = await database;
    await db.update('users', {'password_hash': newPasswordHash},
        where: 'id = ?', whereArgs: [userId]);
  }

  Future<void> deleteUser(String userId) async {
    final db = await database;
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
  }

  // ========== ACTIVITY LOGS ==========

  Future<void> logActivity({
    required String userId,
    required String action,
    required String resourceType,
    String? resourceId,
    String? oldValue,
    String? newValue,
  }) async {
    final db = await database;
    final uuid = DateTime.now().millisecondsSinceEpoch.toString();
    await db.insert('activity_logs', {
      'id': uuid,
      'user_id': userId,
      'action': action,
      'resource_type': resourceType,
      'resource_id': resourceId,
      'old_value': oldValue,
      'new_value': newValue,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getActivityLogs({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (userId != null) {
      whereClause = 'user_id = ?';
      whereArgs.add(userId);
    }

    if (startDate != null && endDate != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'timestamp BETWEEN ? AND ?';
      whereArgs.addAll([startDate.toIso8601String(), endDate.toIso8601String()]);
    }

    return await db.query(
      'activity_logs',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  // ========== INTERNAL HELPERS ==========

  static Future<void> _createSupplierTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY,
        ten_ncc TEXT NOT NULL,
        ma_ncc TEXT,
        dia_chi TEXT,
        so_dien_thoai TEXT,
        email TEXT,
        website TEXT,
        ghi_chu TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS import_orders (
        id TEXT PRIMARY KEY,
        supplier_id TEXT,
        ten_ncc TEXT,
        ngay_nhap TEXT NOT NULL,
        tong_tien INTEGER DEFAULT 0,
        tien_ship INTEGER DEFAULT 0,
        ghi_chu TEXT,
        trang_thai TEXT DEFAULT 'da_nhap',
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS import_order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        import_order_id TEXT NOT NULL,
        product_id TEXT,
        ten_hang TEXT NOT NULL,
        so_luong INTEGER NOT NULL,
        don_gia INTEGER NOT NULL,
        thanh_tien INTEGER NOT NULL,
        FOREIGN KEY (import_order_id) REFERENCES import_orders(id)
      )
    ''');
  }

  // ========== SUPPLIERS ==========

  Future<void> insertSupplier(Supplier supplier) async {
    final db = await database;
    await db.insert('suppliers', supplier.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Supplier>> getSuppliers() async {
    final db = await database;
    final maps =
        await db.query('suppliers', where: 'is_active = 1', orderBy: 'ten_ncc ASC');
    return maps.map((m) => Supplier.fromMap(m)).toList();
  }

  Future<void> updateSupplier(Supplier supplier) async {
    final db = await database;
    await db.update('suppliers', supplier.toMap(),
        where: 'id = ?', whereArgs: [supplier.id]);
  }

  Future<void> deleteSupplier(String id) async {
    final db = await database;
    await db.update('suppliers', {'is_active': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> supplierCodeExists(String maNCC, {String? excludeId}) async {
    final db = await database;
    final q = excludeId != null
        ? await db.query('suppliers',
            where: 'ma_ncc = ? AND id != ?', whereArgs: [maNCC, excludeId])
        : await db.query('suppliers', where: 'ma_ncc = ?', whereArgs: [maNCC]);
    return q.isNotEmpty;
  }

  // ========== IMPORT ORDERS ==========

  Future<void> insertImportOrder(
      ImportOrder order, List<ImportOrderItem> items,
      {Map<String, int> giaVonMap = const {}}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('import_orders', order.toMap());
      for (final item in items) {
        await txn.insert('import_order_items',
            {...item.toMap(), 'import_order_id': order.id});
        if (item.productId != null && item.productId!.isNotEmpty) {
          final giaVon = giaVonMap[item.productId!] ?? item.donGia;
          await txn.rawUpdate(
            'UPDATE products SET ton_kho = ton_kho + ?, gia_von = ? WHERE id = ?',
            [item.soLuong, giaVon, item.productId],
          );
        }
      }
    });
  }

  Future<void> deleteImportOrder(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      final items = await txn.query('import_order_items',
          where: 'import_order_id = ?', whereArgs: [id]);
      for (final item in items) {
        final pid = item['product_id'] as String?;
        final qty = (item['so_luong'] as int?) ?? 0;
        if (pid != null && pid.isNotEmpty && qty > 0) {
          await txn.rawUpdate(
            'UPDATE products SET ton_kho = MAX(0, ton_kho - ?) WHERE id = ?',
            [qty, pid],
          );
        }
      }
      await txn.delete('import_order_items',
          where: 'import_order_id = ?', whereArgs: [id]);
      await txn.delete('import_orders', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> updateImportOrder(
    String id, {
    required List<Map<String, dynamic>> newItems,
    required int tongTien,
    int tienShip = 0,
    String? ghiChu,
    String? supplierId,
    String? tenNCC,
    required DateTime ngayNhap,
    Map<String, int> giaVonMap = const {},
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // Restore old stock
      final oldItems = await txn.query('import_order_items',
          where: 'import_order_id = ?', whereArgs: [id]);
      for (final item in oldItems) {
        final pid = item['product_id'] as String?;
        final qty = (item['so_luong'] as int?) ?? 0;
        if (pid != null && pid.isNotEmpty && qty > 0) {
          await txn.rawUpdate(
            'UPDATE products SET ton_kho = MAX(0, ton_kho - ?) WHERE id = ?',
            [qty, pid],
          );
        }
      }
      await txn.delete('import_order_items',
          where: 'import_order_id = ?', whereArgs: [id]);
      // Insert new items & update stock + gia_von
      for (final item in newItems) {
        await txn.insert('import_order_items', {'import_order_id': id, ...item});
        final pid = item['product_id'] as String?;
        final qty = (item['so_luong'] as int?) ?? 0;
        if (pid != null && pid.isNotEmpty && qty > 0) {
          final giaVon = giaVonMap[pid] ?? (item['don_gia'] as int? ?? 0);
          await txn.rawUpdate(
            'UPDATE products SET ton_kho = ton_kho + ?, gia_von = ? WHERE id = ?',
            [qty, giaVon, pid],
          );
        }
      }
      await txn.update(
        'import_orders',
        {
          'tong_tien': tongTien,
          'tien_ship': tienShip,
          'ghi_chu': ghiChu,
          'supplier_id': supplierId,
          'ten_ncc': tenNCC,
          'ngay_nhap': ngayNhap.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<List<ImportOrder>> getImportOrders() async {
    final db = await database;
    final maps =
        await db.query('import_orders', orderBy: 'ngay_nhap DESC');
    return maps.map((m) => ImportOrder.fromMap(m)).toList();
  }

  Future<List<ImportOrderItem>> getImportOrderItems(String orderId) async {
    final db = await database;
    final maps = await db.query('import_order_items',
        where: 'import_order_id = ?', whereArgs: [orderId]);
    return maps.map((m) => ImportOrderItem.fromMap(m)).toList();
  }

  Future<int> getImportOrderCount() async {
    final db = await database;
    final r = await db
        .rawQuery('SELECT COUNT(*) as c FROM import_orders');
    return r.first['c'] as int;
  }

  // ========== BULK CLEAR ==========

  Future<int> countProducts() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM products');
    return r.first['c'] as int;
  }

  Future<int> countOrders() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM orders');
    return r.first['c'] as int;
  }

  Future<int> countSuppliers() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM suppliers');
    return r.first['c'] as int;
  }

  Future<int> countImportOrders() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM import_orders');
    return r.first['c'] as int;
  }

  Future<void> clearProducts() async {
    final db = await database;
    await db.delete('products');
  }

  Future<void> clearOrders() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('order_items');
      await txn.delete('orders');
    });
  }

  Future<void> clearSuppliers() async {
    final db = await database;
    await db.delete('suppliers');
  }

  Future<void> clearImportOrders() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('import_order_items');
      await txn.delete('import_orders');
    });
  }

  // ========== CUSTOMERS ==========

  static Future<void> _createCustomerTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY,
        ma_khach_hang TEXT UNIQUE,
        ten_khach_hang TEXT NOT NULL,
        loai_khach TEXT DEFAULT 'ca_nhan',
        dien_thoai TEXT,
        email TEXT,
        dia_chi TEXT,
        khu_vuc TEXT,
        phuong_xa TEXT,
        cong_ty TEXT,
        ma_so_thue TEXT,
        so_cmnd TEXT,
        ngay_sinh TEXT,
        gioi_tinh TEXT,
        facebook TEXT,
        nhom_khach_hang TEXT,
        ghi_chu TEXT,
        nguoi_tao TEXT,
        ngay_tao TEXT NOT NULL,
        is_active INTEGER DEFAULT 1
      )
    ''');
  }

  Future<String> getNextCustomerCode() async {
    final db = await database;
    final r = await db.rawQuery(
        "SELECT ma_khach_hang FROM customers WHERE ma_khach_hang LIKE 'KH%' ORDER BY ma_khach_hang DESC LIMIT 1");
    if (r.isEmpty) return 'KH000001';
    final last = r.first['ma_khach_hang'] as String;
    final num = int.tryParse(last.substring(2)) ?? 0;
    return 'KH${(num + 1).toString().padLeft(6, '0')}';
  }

  Future<void> insertCustomer(Customer customer) async {
    final db = await database;
    await db.insert('customers', customer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Customer>> getCustomers() async {
    final db = await database;
    final maps = await db.query('customers',
        where: 'is_active = 1', orderBy: 'ngay_tao DESC');
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<void> updateCustomer(Customer customer) async {
    final db = await database;
    await db.update('customers', customer.toMap(),
        where: 'id = ?', whereArgs: [customer.id]);
  }

  Future<void> deleteCustomer(String id) async {
    final db = await database;
    await db.update('customers', {'is_active': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> customerCodeExists(String code, {String? excludeId}) async {
    final db = await database;
    final q = excludeId != null
        ? await db.query('customers',
            where: 'ma_khach_hang = ? AND id != ?',
            whereArgs: [code, excludeId])
        : await db.query('customers',
            where: 'ma_khach_hang = ?', whereArgs: [code]);
    return q.isNotEmpty;
  }

  Future<int> countCustomers() async {
    final db = await database;
    final r = await db
        .rawQuery('SELECT COUNT(*) as c FROM customers WHERE is_active = 1');
    return r.first['c'] as int;
  }

  Future<void> clearCustomers() async {
    final db = await database;
    await db.delete('customers');
  }
}
