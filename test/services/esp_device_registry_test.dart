import 'package:flutter_test/flutter_test.dart';
import 'package:alburdat_dashboard/models/esp_device.dart';
import 'package:alburdat_dashboard/services/esp_device_registry.dart';
import 'package:alburdat_dashboard/services/database_helper.dart';

void main() {
  group('M0: EspDeviceRegistry & DatabaseHelper registry', () {
    final registry = EspDeviceRegistry(databaseHelper: DatabaseHelper.instance);

    setUp(() async {
      // Flush perangkat uji agar ekspektasi deterministik bila ada sisa
      // dari pengujian lain pada proses yang sama.
      await registry.reload();
      if (registry.byKey('TEST:MAC:1') != null) await registry.remove('TEST:MAC:1');
      if (registry.byKey('TEST:MAC:2') != null) await registry.remove('TEST:MAC:2');
    });

    test('Database berisi tabel esp_devices & device_snapshots (skema v3)',
        () async {
      final db = await DatabaseHelper.instance.database;
      final esp = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='esp_devices'");
      expect(esp.length, 1);
      final snap = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='device_snapshots'");
      expect(snap.length, 1);

      final logsCols = await db.rawQuery("PRAGMA table_info('spray_logs')");
      expect(logsCols.map((c) => c['name']), contains('device_key'));
      final schedCols =
          await db.rawQuery("PRAGMA table_info('spray_schedules')");
      expect(schedCols.map((c) => c['name']), contains('device_key'));
    });

    test('save & baca snapshot terbaru per perangkat', () async {
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.saveDeviceSnapshot('TEST:MAC:1',
          capturedAt: DateTime.utc(2026, 9, 4),
          payload: {'battery': 88, 'totalSesi': 3, 'totalVolume': 600.0});
      final snap = await dbHelper.latestDeviceSnapshot('TEST:MAC:1');
      expect(snap, isNotNull);
      expect(snap!.payload['battery'], 88);
      expect(snap.payload['totalVolume'], 600.0);
    });

    test('register + reload menyimpan & membaca device', () async {
      await registry.registerOrUpdate(EspDevice(
        deviceKey: 'TEST:MAC:1',
        name: 'ESP-1',
        serviceUuid: '4fa1c691-e9a5-4307-9a45-500f7a6a0a9c',
      ));
      await registry.reload();
      final dev = registry.byKey('TEST:MAC:1');
      expect(dev, isNotNull);
      expect(dev!.name, 'ESP-1');
      expect(dev.serviceUuid, '4fa1c691-e9a5-4307-9a45-500f7a6a0a9c');
    });

    test('register ulang memperbarui metadata tanpa menggandakan', () async {
      await registry.registerOrUpdate(EspDevice(deviceKey: 'TEST:MAC:2', name: 'ESP-2'));
      await registry.registerOrUpdate(EspDevice(
        deviceKey: 'TEST:MAC:2',
        name: 'ESP-2',
        lastBattery: 90,
        lastVolumeMl: 500.0,
      ));
      await registry.reload();
      expect(registry.devices.where((d) => d.deviceKey == 'TEST:MAC:2').length, 1);
      expect(registry.byKey('TEST:MAC:2')!.lastBattery, 90);
    });

    test('rename & hapus bekerja', () async {
      await registry.registerOrUpdate(EspDevice(deviceKey: 'TEST:MAC:1', name: 'Xolo'));
      final renamed = await registry.rename('TEST:MAC:1', 'Nama Baru');
      expect(renamed, isTrue);
      expect(registry.byKey('TEST:MAC:1')!.name, 'Nama Baru');

      await registry.remove('TEST:MAC:1');
      expect(registry.byKey('TEST:MAC:1'), isNull);
    });
  });
}
