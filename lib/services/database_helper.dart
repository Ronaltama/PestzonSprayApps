import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/spray_log.dart';
import '../models/spray_schedule.dart';
import '../models/esp_device.dart';
import '../models/device_snapshot.dart';

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
    if (!kIsWeb &&
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // Saat uji (flutter test), pakai database in-memory supaya tidak
    // menulis file & tidak terkontaminasi antar proses; skema tetap sama.
    if (!kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true') {
      databaseFactory = databaseFactoryFfi;
      return openDatabase(
        inMemoryDatabasePath,
        version: 3,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onOpen: (db) async {
        await _upgradeDB(db, 0, 3);
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await _createSchemaV2(db);
  }

  /// Skema lengkap untuk DB baru (versi saat ini = 3).
  Future<void> _createSchemaV2(Database db) async {
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
        communicationMethod TEXT NOT NULL,
        device_key TEXT NOT NULL DEFAULT 'default'
      )
    ''');

    await db.execute('''
      CREATE TABLE spray_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        hour INTEGER NOT NULL,
        minute INTEGER NOT NULL,
        durationSeconds INTEGER NOT NULL,
        isActive INTEGER NOT NULL,
        device_key TEXT NOT NULL DEFAULT 'default'
      )
    ''');

    await db.execute('''
      CREATE TABLE esp_devices (
        device_key TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        service_uuid TEXT,
        ble_advertised_name TEXT,
        last_seen_at TEXT,
        last_battery INTEGER,
        last_volume_ml REAL,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_at TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_logs_device ON spray_logs(device_key)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sched_device ON spray_schedules(device_key)',
    );

    await _ensureDeviceSnapshotsTable(db);

    await _seedDefaultSchedules(db);
  }

  /// Migrasi skema DB dari versi lama ke skema v3 saat ini (menambah kolom
  /// `device_key`, tabel `esp_devices`, dan `device_snapshots`). Aman
  /// dijalankan ulang (idempoten) untuk kasus DB sebagian-termigrasi.
  Future<void> _upgradeDB(
      Database db, int oldVersion, int? newVersion) async {
    // Jalankan DDL v2 untuk memastikan kolom/tabel/indeks ada.
    // (idempoten via IF NOT EXISTS / pemeriksaan kolom di bawah)
    await _ensureColumn(db, 'spray_logs', 'status',
        "TEXT NOT NULL DEFAULT 'Success'");
    await _ensureColumn(db, 'spray_logs', 'communicationMethod',
        "TEXT NOT NULL DEFAULT 'BLE'");
    await _ensureColumn(db, 'spray_logs', 'device_key',
        "TEXT NOT NULL DEFAULT 'default'");
    await _ensureColumn(db, 'spray_schedules', 'device_key',
        "TEXT NOT NULL DEFAULT 'default'");
    await db.execute('''
      CREATE TABLE IF NOT EXISTS esp_devices (
        device_key TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        service_uuid TEXT,
        ble_advertised_name TEXT,
        last_seen_at TEXT,
        last_battery INTEGER,
        last_volume_ml REAL,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_at TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_logs_device ON spray_logs(device_key)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sched_device ON spray_schedules(device_key)',
    );
    await _ensureDeviceSnapshotsTable(db);
  }

  /// Pastikan tabel `device_snapshots` (versi 3) ada. Idempoten.
  Future<void> _ensureDeviceSnapshotsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS device_snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_key TEXT NOT NULL,
        captured_at TEXT NOT NULL,
        payload TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_snap_device ON device_snapshots(device_key)',
    );
  }

  /// Tambah kolom [column] dengan [definition] bila belum ada pada [table].
  /// Memakai pragma `table_info` agar aman & idempoten lintas platform.
  Future<void> _ensureColumn(Database db, String table, String column,
      String definition) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    final exists = rows.any((r) => r['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  /// Seed jadwal bawaan hanya dipasang saat membuat database baru (tidak
  /// diulang saat upgrade). Dipanggil dari [_createSchemaV2].
  Future<void> _seedDefaultSchedules(Database db) async {
    final existing = await db.query('spray_schedules', limit: 1);
    if (existing.isNotEmpty) return;
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
    await _upgradeDB(db, 0, 3);
    
    // Check if log already exists based on timestamp and device key to prevent duplication
    // when requesting logs history upon reconnecting
    final existing = await db.query(
      'spray_logs',
      where: 'timestamp = ? AND device_key = ?',
      whereArgs: [log.timestamp.toIso8601String(), log.deviceKey ?? 'default'],
    );
    
    if (existing.isNotEmpty) {
      return existing.first['id'] as int;
    }
    
    final id = await db.insert('spray_logs', log.toMap());
    notifyListeners();
    return id;
  }

  Future<List<SprayLog>> getAllLogs() async {
    final db = await instance.database;
    final maps = await db.query('spray_logs', orderBy: 'timestamp DESC');
    return maps.map((m) => SprayLog.fromMap(m)).toList();
  }

  /// Riwayat semprot milik perangkat tertentu (urut terbaru dulu).
  Future<List<SprayLog>> getLogsForDevice(String deviceKey) async {
    final db = await instance.database;
    final maps = await db.query(
      'spray_logs',
      where: 'LOWER(device_key) = ? OR device_key = ?',
      whereArgs: [deviceKey.toLowerCase(), 'default'],
      orderBy: 'timestamp DESC',
    );
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

  /// Daftar jadwal milik perangkat tertentu (`device_key == [deviceKey]`).
  Future<List<SpraySchedule>> getSchedulesForDevice(String deviceKey) async {
    final db = await instance.database;
    final maps = await db.query(
      'spray_schedules',
      where: 'LOWER(device_key) = ? OR device_key = ?',
      whereArgs: [deviceKey.toLowerCase(), 'default'],
      orderBy: 'hour ASC, minute ASC',
    );
    return maps.map((m) => SpraySchedule.fromMap(m)).toList();
  }

  /// Tulis kembali daftar jadwal penuh milik [deviceKey] (hapus lalu isi), 
  /// sehingga perangkat-perangkat tidak saling menimpa seperti sebelumnya.
  Future<void> replaceSchedulesForDevice(
      String deviceKey, List<SpraySchedule> schedules) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('spray_schedules',
          where: 'device_key = ?', whereArgs: [deviceKey]);
      for (final s in schedules) {
        final row = s.toMap();
        row['device_key'] = deviceKey;
        if (s.id == null) {
          row.remove('id');
        }
        await txn.insert('spray_schedules', row);
      }
    });
    notifyListeners();
  }

  // --- ESP DEVICES REGISTRY CRUD ---

  /// Simpan (insert atau replace) satu perangkat pada registry `esp_devices`.
  /// Primary key = `device_key`.
  Future<int> upsertDevice(EspDevice device) async {
    final db = await instance.database;
    final m = device.toMap();
    return db.rawInsert('''
      INSERT OR REPLACE INTO esp_devices
        (device_key, name, service_uuid, ble_advertised_name, last_seen_at,
         last_battery, last_volume_ml, is_favorite, created_at)
      VALUES (?,?,?,?,?,?,?,?,?)
    ''', [
      m['device_key'],
      m['name'],
      m['service_uuid'],
      m['ble_advertised_name'],
      m['last_seen_at'],
      m['last_battery'],
      m['last_volume_ml'],
      m['is_favorite'],
      m['created_at'],
    ]);
  }

  /// Ambil daftar seluruh perangkat terdaftar (registry).
  Future<List<EspDevice>> getAllRegisteredDevices() async {
    final db = await instance.database;
    final maps = await db.query('esp_devices', orderBy: 'name ASC');
    return maps.map(EspDevice.fromMap).toList();
  }

  /// Ambil satu perangkat berdasarkan [deviceKey], `null` bila tak ada.
  Future<EspDevice?> getDeviceByKey(String deviceKey) async {
    final db = await instance.database;
    final maps = await db.query('esp_devices',
        where: 'device_key = ?', whereArgs: [deviceKey], limit: 1);
    if (maps.isEmpty) return null;
    return EspDevice.fromMap(maps.first);
  }

  /// Perbarui nama tampilan perangkat.
  Future<int> updateDeviceName(String deviceKey, String name) async {
    final db = await instance.database;
    final rows = await db.update('esp_devices', {'name': name},
        where: 'device_key = ?', whereArgs: [deviceKey]);
    notifyListeners();
    return rows;
  }

  /// Catat waktu terakhir terhubung + snapshot baterai/volume opsional.
  Future<int> updateDeviceLastSeen(
    String deviceKey, {
    DateTime? lastSeenAt,
    int? battery,
    double? volumeMl,
  }) async {
    final db = await instance.database;
    final values = <String, dynamic>{
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt.toIso8601String(),
      if (battery != null) 'last_battery': battery,
      if (volumeMl != null) 'last_volume_ml': volumeMl,
    };
    if (values.isEmpty) return 0;
    final rows = await db.update('esp_devices', values,
        where: 'device_key = ?', whereArgs: [deviceKey]);
    notifyListeners();
    return rows;
  }

  /// Set penanda favorit.
  Future<int> setDeviceFavorite(String deviceKey, bool favorite) async {
    final db = await instance.database;
    final rows = await db.update('esp_devices', {'is_favorite': favorite ? 1 : 0},
        where: 'device_key = ?', whereArgs: [deviceKey]);
    notifyListeners();
    return rows;
  }

  /// Hapus perangkat dari registry beserta data semprot/jadwal yang terikat
  /// pada `device_key` tersebut. Waspada: memanggil dengan `'default'` akan
  /// menghapus seluruh data turunan yang belum dipetakan ke perangkat MAC.
  Future<void> removeDevice(String deviceKey) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('esp_devices',
          where: 'device_key = ?', whereArgs: [deviceKey]);
      await txn.delete('spray_logs',
          where: 'device_key = ?', whereArgs: [deviceKey]);
      await txn.delete('spray_schedules',
          where: 'device_key = ?', whereArgs: [deviceKey]);
      await txn.delete('device_snapshots',
          where: 'device_key = ?', whereArgs: [deviceKey]);
    });
    notifyListeners();
  }

  // --- DEVICE SNAPSHOTS (M2) ---

  /// Simpan snapshot terbaru perangkat (mis. JSON `summary`/`stats`) dengan
  /// waktu pengambilan. Baris historis dibiarkan tumbuh untuk audit singkat;
  /// kebutuhan pencarian memakai [latestDeviceSnapshot].
  Future<int> saveDeviceSnapshot(
    String deviceKey, {
    required DateTime capturedAt,
    required Map<String, dynamic> payload,
  }) async {
    final db = await instance.database;
    final id = await db.insert('device_snapshots', {
      'device_key': deviceKey,
      'captured_at': capturedAt.toIso8601String(),
      'payload': jsonEncode(payload),
    });
    notifyListeners();
    return id;
  }

  /// Snapshot terbaru perangkat (`null` bila belum pernah tersimpan).
  /// Mengembalikan `{json: payload, capturedAt: ...}` versi ringkas.
  Future<DeviceSnapshot?> latestDeviceSnapshot(String deviceKey) async {
    final db = await instance.database;
    final maps = await db.query('device_snapshots',
        where: 'device_key = ?',
        whereArgs: [deviceKey],
        orderBy: 'captured_at DESC',
        limit: 1);
    if (maps.isEmpty) return null;
    final map = maps.first;
    return DeviceSnapshot(
      capturedAt: DateTime.parse(map['captured_at'] as String),
      payload:
          jsonDecode(map['payload'] as String) as Map<String, dynamic>,
    );
  }

  /// Hapus seluruh snapshot perangkat (dipakai saat menghapus unit).
  Future<void> clearDeviceSnapshots(String deviceKey) async {
    final db = await instance.database;
    await db.delete('device_snapshots',
        where: 'device_key = ?', whereArgs: [deviceKey]);
    notifyListeners();
  }
}
