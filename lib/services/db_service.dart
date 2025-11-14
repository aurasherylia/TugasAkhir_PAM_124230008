import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DBService {
  static Database? _db;

  // ========================== INIT DATABASE ==========================
  static Future<Database> get database async {
    if (_db != null) return _db!;

    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'aormed.db');
    print('Persistent DB path: $path');

    _db = await openDatabase(
      path,
      version: 35, 
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    await _ensureColumnsExist(_db!);
    return _db!;
  }

  // ========================== CREATE TABLES ==========================
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT,
        email TEXT UNIQUE,
        password TEXT,
        photo TEXT        
      )
    ''');

    await db.execute('''
      CREATE TABLE appointments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        doctor_name TEXT,
        doctor_specialist TEXT,
        doctor_image TEXT,
        date TEXT,
        slot TEXT,
        complaint TEXT,
        payment_method TEXT,
        total_price TEXT,
        invoice_number TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE chats(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        appointment_id INTEGER,
        sender TEXT,
        message TEXT,
        timestamp TEXT
      )
    ''');

    print('All tables created successfully (clean version)');
  }

  // ========================== UPGRADE HANDLER ==========================
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _ensureColumnsExist(db);
  }

  // ========================== CHECK & FIX TABLE STRUCTURE ==========================
  static Future<void> _ensureColumnsExist(Database db) async {
    final userCols = await db.rawQuery("PRAGMA table_info(users)");
    final colNames = userCols.map((e) => e['name'] as String).toList();

    if (!colNames.contains('photo')) {
      await db.execute("ALTER TABLE users ADD COLUMN photo TEXT;");
      print('Added missing column: photo');
    }

    final appCols = await db.rawQuery("PRAGMA table_info(appointments)");
    final appNames = appCols.map((e) => e['name'] as String).toList();

    if (!appNames.contains('doctor_image')) {
      await db.execute("ALTER TABLE appointments ADD COLUMN doctor_image TEXT;");
      print('Added missing column: doctor_image');
    }
  }

  // ========================== UTILITIES ==========================
  static String encrypt(String text) {
    return sha256.convert(utf8.encode(text)).toString();
  }

  static String generateInvoiceNumber() {
    final now = DateTime.now();
    final rand = now.millisecondsSinceEpoch % 100000;
    return 'INV-${now.year}${now.month}${now.day}-$rand';
  }

  // ========================== USERS ==========================
  static Future<String?> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final db = await database;
    final normalizedEmail = email.trim().toLowerCase();

    try {
      final existing = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [normalizedEmail],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        return 'Email sudah terdaftar! Gunakan email lain.';
      }

      await db.insert('users', {
        'username': username,
        'email': normalizedEmail,
        'password': encrypt(password),
        'photo': null,
      });

      print('User baru ditambahkan: $normalizedEmail');
      return null;
    } catch (e) {
      return 'Gagal registrasi: $e';
    }
  }

  static Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    final db = await database;
    final res = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email.trim().toLowerCase(), encrypt(password)],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  static Future<List<Map<String, dynamic>>> getRecentUsers({int limit = 3}) async {
    final db = await database;
    final users = await db.query(
      'users',
      orderBy: 'id DESC',
      limit: limit,
    );
    return users;
  }

  // ========================== FOTO PROFIL (CRUD) ==========================
  static Future<void> saveUserPhoto(int userId, Uint8List bytes) async {
    final db = await database;
    final base64Img = base64Encode(bytes);

    await db.update(
      'users',
      {'photo': base64Img},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  static Future<void> removeUserPhoto(int userId) async {
    final db = await database;

    await db.update(
      'users',
      {'photo': null},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  static Future<Uint8List?> getUserPhoto(int userId) async {
    final db = await database;
    final res = await db.query(
      'users',
      columns: ['photo'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (res.isEmpty) return null;

    final base64Str = res.first['photo']?.toString() ?? '';
    if (base64Str.isEmpty) return null;

    try {
      return base64Decode(base64Str);
    } catch (_) {
      return null;
    }
  }

  // ========================== APPOINTMENTS ==========================
  static Future<int> addAppointment({
    required int userId,
    required String doctorName,
    required String doctorSpecialist,
    String? doctorImage,
    required String date,
    required String slot,
    required String complaint,
    required String paymentMethod,
    required String totalPrice,
  }) async {
    final db = await database;
    final invoice = generateInvoiceNumber();

    return await db.insert('appointments', {
      'user_id': userId,
      'doctor_name': doctorName,
      'doctor_specialist': doctorSpecialist,
      'doctor_image': doctorImage ?? '',
      'date': date,
      'slot': slot,
      'complaint': complaint,
      'payment_method': paymentMethod,
      'total_price': totalPrice,
      'invoice_number': invoice,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getAppointmentsByUser(int userId) async {
    final db = await database;
    return await db.query(
      'appointments',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'datetime(created_at) DESC',
    );
  }

  static Future<void> deleteAppointment(int id) async {
    final db = await database;
    await db.delete('chats', where: 'appointment_id = ?', whereArgs: [id]);
    await db.delete('appointments', where: 'id = ?', whereArgs: [id]);
  }

  // ========================== CHATS ==========================
  static Future<void> insertChat(int appointmentId, String sender, String message) async {
    final db = await database;
    await db.insert('chats', {
      'appointment_id': appointmentId,
      'sender': sender,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getChatsByAppointment(int appointmentId) async {
    final db = await database;
    return await db.query(
      'chats',
      where: 'appointment_id = ?',
      whereArgs: [appointmentId],
      orderBy: 'datetime(timestamp) ASC',
    );
  }
}
