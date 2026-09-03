import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/spray_log.dart';
import '../models/spray_schedule.dart';

class DatabaseHelper extends ChangeNotifier {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('spray_master.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // If running on Desktop (Linux / macOS / Windows), initialize sqflite ffi
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE spray_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        durationSeconds INTEGER NOT NULL,
        volumeMl REAL NOT NULL,
        batteryPercentage INTEGER NOT NULL,
        isSolarCharging INTEGER NOT NULL,
        mode TEXT NOT NULL,
        status TEXT NOT NULL,
        communicationMethod TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE spray_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        hour INTEGER NOT NULL,
        minute INTEGER NOT NULL,
        durationSeconds INTEGER NOT NULL,
        isActive INTEGER NOT NULL
      )
    ''');

    // Seed initial default schedules
    await db.insert('spray_schedules', {
      'title': 'Semprot Pagi',
      'hour': 7,
      'minute': 0,
      'durationSeconds': 30,
      'isActive': 1,
    });

    await db.insert('spray_schedules', {
      'title': 'Semprot Sore',
      'hour': 16,
      'minute': 0,
      'durationSeconds': 30,
      'isActive': 1,
    });
  }

  // --- SPRAY LOGS CRUD ---
  Future<int> insertLog(SprayLog log) async {
    final db = await instance.database;
    final id = await db.insert('spray_logs', log.toMap());
    notifyListeners();
    return id;
  }

  Future<List<SprayLog>> getAllLogs() async {
    final db = await instance.database;
    final maps = await db.query('spray_logs', orderBy: 'timestamp DESC');
    return maps.map((m) => SprayLog.fromMap(m)).toList();
  }

  Future<void> clearAllLogs() async {
    final db = await instance.database;
    await db.delete('spray_logs');
    notifyListeners();
  }

  // --- SPRAY SCHEDULES CRUD ---
  Future<int> insertSchedule(SpraySchedule schedule) async {
    final db = await instance.database;
    final id = await db.insert('spray_schedules', schedule.toMap());
    notifyListeners();
    return id;
  }

  Future<List<SpraySchedule>> getAllSchedules() async {
    final db = await instance.database;
    final maps = await db.query('spray_schedules', orderBy: 'hour ASC, minute ASC');
    return maps.map((m) => SpraySchedule.fromMap(m)).toList();
  }

  Future<int> updateSchedule(SpraySchedule schedule) async {
    final db = await instance.database;
    final rows = await db.update(
      'spray_schedules',
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
    notifyListeners();
    return rows;
  }

  Future<int> deleteSchedule(int id) async {
    final db = await instance.database;
    final rows = await db.delete(
      'spray_schedules',
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyListeners();
    return rows;
  }

  /// Ganti seluruh daftar jadwal lokal dengan daftar dari perangkat
  /// (id mengikuti id ESP). Dipakai saat menarik jadwal dari ESP.
  Future<void> replaceAllSchedules(List<SpraySchedule> schedules) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('spray_schedules');
      for (final s in schedules) {
        final row = s.toMap();
        if (s.id == null) {
          row.remove('id');
        }
        await txn.insert('spray_schedules', row);
      }
    });
    notifyListeners();
  }
}
