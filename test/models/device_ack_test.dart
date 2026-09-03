import 'package:flutter_test/flutter_test.dart';
import 'package:alburdat_dashboard/models/device_ack.dart';

void main() {
  group('DeviceAck', () {
    test('fromJson membaca ok=1 sebagai sukses', () {
      final ack = DeviceAck.fromJson({'v': 1, 't': 'ack', 'ref': 'set_schedules', 'ok': 1});
      expect(ack.ref, 'set_schedules');
      expect(ack.ok, isTrue);
      expect(ack.error, isNull);
    });

    test('fromJson membaca ok=false + err', () {
      final ack = DeviceAck.fromJson({'t': 'ack', 'ref': 'set_schedules', 'ok': 0, 'err': 'NVS penuh'});
      expect(ack.ok, isFalse);
      expect(ack.error, 'NVS penuh');
    });

    test('fromJson toleran ok berupa boolean true', () {
      final ack = DeviceAck.fromJson({'t': 'ack', 'ref': 'x', 'ok': true});
      expect(ack.ok, isTrue);
    });
  });
}
