import 'package:flutter_test/flutter_test.dart';
import 'package:alburdat_dashboard/models/spray_log.dart';

void main() {
  group('SprayLog (M2 deviceKey)', () {
    test('toMap → fromMap mempertahankan deviceKey', () {
      final log = SprayLog(
        timestamp: DateTime.utc(2026, 9, 4, 5, 0),
        durationSeconds: 30,
        volumeMl: 150.0,
        batteryPercentage: 90,
        isSolarCharging: true,
        mode: 'Manual',
        status: 'Success',
        communicationMethod: 'BLE',
        deviceKey: 'AA:BB:CC:DD:EE:FF',
      );
      final round = SprayLog.fromMap(log.toMap());
      expect(round.deviceKey, 'AA:BB:CC:DD:EE:FF');
      expect(round.volumeMl, closeTo(150.0, 0.001));
    });

    test('deviceKey kosong diserialkan sebagai \'default\' (legacy)', () {
      final log = SprayLog(
        timestamp: DateTime.utc(2026, 9, 4),
        durationSeconds: 10,
        volumeMl: 50.0,
        batteryPercentage: 80,
        isSolarCharging: false,
        mode: 'Auto Schedule',
        status: 'Success',
        communicationMethod: 'BLE',
      );
      expect(log.toMap()['device_key'], 'default');
      expect(SprayLog.fromMap(log.toMap()).deviceKey, 'default');
    });
  });
}
