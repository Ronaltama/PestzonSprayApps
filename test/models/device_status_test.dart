import 'package:flutter_test/flutter_test.dart';
import 'package:alburdat_dashboard/models/device_status.dart';

void main() {
  group('DeviceStatus.fromJson (payload summary kontrak perangkat)', () {
    test('parse summary lengkap', () {
      final status = DeviceStatus.fromJson({
        'v': 1,
        't': 'summary',
        'battery': 87,
        'voltage': 4.12,
        'isSolar': 1,
        'isPumpRunning': 0,
        'totalVolume': 1234.5,
        'totalSesi': 6,
        'ts': 1756900000,
      });
      expect(status.batteryPercentage, 87);
      expect(status.batteryVoltage, 4.12);
      expect(status.isSolarCharging, isTrue);
      expect(status.isPumpRunning, isFalse);
      expect(status.totalVolumeTodayMl, 1234.5);
      expect(status.totalSesiToday, 6);
    });

    test('parse boolean true/false (format status MQTT lama)', () {
      final status = DeviceStatus.fromJson({
        'battery': 90,
        'voltage': 4.1,
        'isSolar': true,
        'isPumpRunning': true,
      });
      expect(status.batteryPercentage, 90);
      expect(status.isSolarCharging, isTrue);
      expect(status.isPumpRunning, isTrue);
    });

    test('nilai default saat field hilang', () {
      final status = DeviceStatus.fromJson({});
      expect(status.batteryPercentage, 85);
      expect(status.totalVolumeTodayMl, 0.0);
      expect(status.totalSesiToday, 0);
    });
  });
}
