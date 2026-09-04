import 'package:flutter_test/flutter_test.dart';
import 'package:alburdat_dashboard/models/esp_device.dart';

void main() {
  group('EspDevice', () {
    test('toMap → fromMap berkisar lengkap', () {
      final dev = EspDevice(
        deviceKey: 'AA:BB:CC:DD:EE:FF',
        name: 'ESP-SH25-01',
        serviceUuid: '4fa1c691-e9a5-4307-9a45-500f7a6a0a9c',
        bleAdvertisedName: 'ESP32-SH25',
        lastSeenAt: DateTime.utc(2026, 9, 4, 3, 30),
        lastBattery: 87,
        lastVolumeMl: 1234.5,
        isFavorite: true,
        createdAt: DateTime.utc(2026, 9, 1),
      );

      final round = EspDevice.fromMap(dev.toMap());
      expect(round.deviceKey, dev.deviceKey);
      expect(round.name, dev.name);
      expect(round.serviceUuid, dev.serviceUuid);
      expect(round.bleAdvertisedName, dev.bleAdvertisedName);
      expect(round.lastSeenAt, dev.lastSeenAt);
      expect(round.lastBattery, 87);
      expect(round.lastVolumeMl, closeTo(1234.5, 0.001));
      expect(round.isFavorite, isTrue);
      expect(round.createdAt, dev.createdAt);
    });

    test('toMap mendefaultkan isFavorite=false', () {
      final dev = EspDevice(deviceKey: 'x', name: 'ESP-0');
      final map = dev.toMap();
      expect(map['is_favorite'], 0);
      expect(EspDevice.fromMap(map).isFavorite, isFalse);
    });

    test('fromMap toleran field opsional null', () {
      final dev = EspDevice.fromMap({'device_key': 'x', 'name': 'ESP-x'});
      expect(dev.deviceKey, 'x');
      expect(dev.serviceUuid, isNull);
      expect(dev.lastBattery, isNull);
      expect(dev.lastVolumeMl, isNull);
      expect(dev.lastSeenAt, isNull);
      expect(dev.isFavorite, isFalse);
    });
    test('copyWith menyunting field tanpa mengubah key', () {
      final dev = EspDevice(deviceKey: 'MAC', name: 'Asli')
          .copyWith(name: 'Baru', isFavorite: true);
      expect(dev.deviceKey, 'MAC');
      expect(dev.name, 'Baru');
      expect(dev.isFavorite, isTrue);
    });
  });
}
