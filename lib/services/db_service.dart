import 'dart:convert';
import 'dart:io';
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

    // hapus versi lama di lokasi default
    final oldPath = p.join(await getDatabasesPath(), 'aormed.db');
    if (await File(oldPath).exists()) {
      await deleteDatabase(oldPath);
      print('Deleted old DB (readonly fix)');
    }

    _db = await openDatabase(
      path,
      version: 32, // naikkan versi supaya migrasi
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
        password TEXT
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

    await db.execute('''
      CREATE TABLE faces(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE,
        embedding TEXT,
        image_path TEXT,
        face_image TEXT,
        structure_json TEXT
      )
    ''');

    print('All tables created successfully');
  }

  // ========================== UPGRADE HANDLER ==========================
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _ensureColumnsExist(db);
  }

  // ========================== CHECK & FIX TABLE STRUCTURE ==========================
  static Future<void> _ensureColumnsExist(Database db) async {
    final appCols = await db.rawQuery("PRAGMA table_info(appointments)");
    final appNames = appCols.map((e) => e['name'] as String).toList();
    if (!appNames.contains('doctor_image')) {
      await db.execute("ALTER TABLE appointments ADD COLUMN doctor_image TEXT;");
      print('🩺 Added missing column doctor_image');
    }

    final faceTable = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='faces';",
    );
    if (faceTable.isEmpty) {
      await db.execute('''
        CREATE TABLE faces(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          email TEXT UNIQUE,
          embedding TEXT,
          image_path TEXT,
          face_image TEXT,
          structure_json TEXT
        )
      ''');
      print('Created missing faces table');
    } else {
      final faceCols = await db.rawQuery("PRAGMA table_info(faces)");
      final faceNames = faceCols.map((e) => e['name'] as String).toList();

      if (!faceNames.contains('face_image')) {
        await db.execute("ALTER TABLE faces ADD COLUMN face_image TEXT;");
        print('Added missing column face_image');
      }
      if (!faceNames.contains('image_path')) {
        await db.execute("ALTER TABLE faces ADD COLUMN image_path TEXT;");
        print('Added missing column image_path');
      }
      if (!faceNames.contains('structure_json')) {
        await db.execute("ALTER TABLE faces ADD COLUMN structure_json TEXT;");
        print('Added missing column structure_json');
      }
    }
  }

  // ========================== UTILITIES ==========================
  static String encrypt(String text) => sha256.convert(utf8.encode(text)).toString();

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

      await db.insert(
        'users',
        {
          'username': username,
          'email': normalizedEmail,
          'password': encrypt(password),
        },
      );
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
    final result = await db.query(
      'appointments',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'datetime(created_at) DESC',
    );
    print('Loaded ${result.length} appointments for user $userId');
    return result;
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

  // ========================== FACES (EMBEDDING) ==========================
  static Future<void> saveFaceEmbedding({
    required String email,
    required List<double> embedding,
    String? imagePath,
    Uint8List? imageBytes,
  }) async {
    final db = await database;
    String base64Image = '';
    if (imageBytes != null && imageBytes.isNotEmpty) {
      base64Image = base64Encode(imageBytes);
    }

    await db.insert(
      'faces',
      {
        'email': email.trim().toLowerCase(),
        'embedding': embedding.join(','),
        'image_path': imagePath ?? '',
        'face_image': base64Image,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<double>?> getEmbeddingByEmail(String email) async {
    final db = await database;
    final result = await db.query(
      'faces',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );

    if (result.isEmpty) return null;

    final embeddingString = result.first['embedding']?.toString() ?? '';
    final list = embeddingString
        .split(',')
        .map((e) => double.tryParse(e.trim()) ?? 0.0)
        .toList();

    return list;
  }

  // ========================== FACES (STRUCTURE) ==========================
  static Future<void> saveFaceStructure({
    required String email,
    required Map<String, double> structure,
    Uint8List? imageBytes,
  }) async {
    final db = await database;
    String base64Img = '';
    if (imageBytes != null) base64Img = base64Encode(imageBytes);

    await db.insert(
      'faces',
      {
        'email': email.trim().toLowerCase(),
        'structure_json': jsonEncode(structure),
        'face_image': base64Img,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('Struktur wajah disimpan untuk $email');
  }

  static Future<Map<String, double>?> getFaceStructureByEmail(String email) async {
    final db = await database;
    final res = await db.query(
      'faces',
      columns: ['structure_json'],
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (res.isEmpty) return null;
    final data = res.first['structure_json'] as String?;
    if (data == null || data.isEmpty) return null;
    final Map<String, dynamic> raw = jsonDecode(data);
    return raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  static Future<Uint8List?> getFaceImage(String email) async {
    final db = await database;
    final res = await db.query(
      'faces',
      columns: ['face_image'],
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );

    if (res.isEmpty) return null;

    final base64Str = res.first['face_image']?.toString() ?? '';
    if (base64Str.isEmpty) return null;

    try {
      final bytes = base64Decode(base64Str);
      return bytes;
    } catch (e) {
      print('Error decode base64: $e');
      return null;
    }
  }
}
