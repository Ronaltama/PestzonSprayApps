import 'package:flutter_test/flutter_test.dart';
import 'package:alburdat_dashboard/models/spray_schedule.dart';
import 'package:alburdat_dashboard/services/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper db;

  setUp(() async {
    db = DatabaseHelper.instance;
    // Bersihkan isi tabel jadwal sebelum tiap tes
    final database = await db.database;
    await database.delete('spray_schedules');
  });

  test('DatabaseHelper jadwal dimulai bersih tanpa jadwal dummy otomatis', () async {
    final schedules = await db.getAllSchedules();
    expect(schedules, isEmpty);
  });

  test('insertSchedule menyimpan jadwal baru dan menotifikasi listener', () async {
    bool notified = false;
    void listener() => notified = true;
    db.addListener(listener);

    final sched = SpraySchedule(
      title: 'Uji Jadwal',
      hour: 8,
      minute: 30,
      durationSeconds: 25,
      isActive: true,
    );

    final id = await db.insertSchedule(sched, deviceKey: 'ESP32_DEV_1');
    expect(id, isPositive);
    expect(notified, isTrue);

    final list = await db.getSchedulesForDevice('ESP32_DEV_1');
    expect(list.length, equals(1));
    expect(list.first.title, equals('Uji Jadwal'));
    expect(list.first.hour, equals(8));
    expect(list.first.minute, equals(30));
    expect(list.first.durationSeconds, equals(25));
    expect(list.first.isActive, isTrue);

    db.removeListener(listener);
  });

  test('updateSchedule dan deleteSchedule berfungsi dengan baik', () async {
    final sched = SpraySchedule(
      title: 'Jadwal Siang',
      hour: 12,
      minute: 0,
      durationSeconds: 15,
      isActive: true,
    );
    final id = await db.insertSchedule(sched, deviceKey: 'dev_1');

    final updated = sched.copyWith(id: id, isActive: false);
    await db.updateSchedule(updated);

    var list = await db.getSchedulesForDevice('dev_1');
    expect(list.first.isActive, isFalse);

    await db.deleteSchedule(id);
    list = await db.getSchedulesForDevice('dev_1');
    expect(list, isEmpty);
  });
}
