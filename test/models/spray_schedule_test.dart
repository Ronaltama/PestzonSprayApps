import 'package:flutter_test/flutter_test.dart';
import 'package:alburdat_dashboard/models/spray_schedule.dart';

void main() {
  group('SpraySchedule (kontrak perangkat)', () {
    test('toDeviceJson memakai kunci kontrak duration/active + title', () {
      final sched = SpraySchedule(
        id: 3,
        title: 'Semprot Malam',
        hour: 19,
        minute: 30,
        durationSeconds: 45,
        isActive: true,
      );
      expect(sched.toDeviceJson(), {
        'id': 3,
        'title': 'Semprot Malam',
        'hour': 19,
        'minute': 30,
        'duration': 45,
        'active': 1,
      });
    });

    test('fromDeviceJson membaca kunci kontrak', () {
      final sched = SpraySchedule.fromDeviceJson({
        'id': 2,
        'title': 'Semprot Sore',
        'hour': 16,
        'minute': 0,
        'duration': 30,
        'active': 0,
      });
      expect(sched.id, 2);
      expect(sched.title, 'Semprot Sore');
      expect(sched.hour, 16);
      expect(sched.minute, 0);
      expect(sched.durationSeconds, 30);
      expect(sched.isActive, isFalse);
    });

    test('fromDeviceJson default title saat kosong & aktif saat 1', () {
      final sched = SpraySchedule.fromDeviceJson({'id': 1, 'hour': 7, 'minute': 0, 'duration': 30, 'active': 1});
      expect(sched.title, 'Penyemprotan');
      expect(sched.isActive, isTrue);
    });

    test('listFromDevicePayload memetakan daftar & mengabaikan non-map', () {
      final parsed = SpraySchedule.listFromDevicePayload([
        {'id': 1, 'title': 'Semprot Pagi', 'hour': 7, 'minute': 0, 'duration': 30, 'active': 1},
        'bukan-map',
      ]);
      expect(parsed.length, 1);
      expect(parsed.first.timeFormatted, '07:00 WIB');
    });

    test('round-trip toDeviceJson -> fromDeviceJson mempertahankan field', () {
      final original = SpraySchedule(
        id: 5,
        title: 'Semprot Siang',
        hour: 12,
        minute: 15,
        durationSeconds: 60,
        isActive: false,
      );
      final restored = SpraySchedule.fromDeviceJson(original.toDeviceJson());
      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.hour, original.hour);
      expect(restored.minute, original.minute);
      expect(restored.durationSeconds, original.durationSeconds);
      expect(restored.isActive, original.isActive);
    });
  });
}
