import 'package:flutter_test/flutter_test.dart';
import 'package:alburdat_dashboard/models/daily_volume_stat.dart';

void main() {
  group('DailyVolumeStat', () {
    test('formatDate menghasilkan kunci YYYY-MM-DD', () {
      expect(DailyVolumeStat.formatDate(DateTime(2026, 9, 3)), '2026-09-03');
      expect(DailyVolumeStat.formatDate(DateTime(2026, 12, 31)), '2026-12-31');
      expect(DailyVolumeStat.formatDate(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('weekdayIndex: Senin = 0, Minggu = 6', () {
      // 2026-09-07 adalah Senin
      expect(DailyVolumeStat(date: DateTime(2026, 9, 7), volumeMl: 0, sessions: 0).weekdayIndex, 0);
      // 2026-09-13 adalah Minggu
      expect(DailyVolumeStat(date: DateTime(2026, 9, 13), volumeMl: 0, sessions: 0).weekdayIndex, 6);
    });

    test('fromJson memetakan kunci kontrak d/v/s', () {
      final stat = DailyVolumeStat.fromJson({'d': '2026-09-01', 'v': 1200.5, 's': 6});
      expect(stat.date, DateTime(2026, 9, 1));
      expect(stat.volumeMl, 1200.5);
      expect(stat.sessions, 6);
    });

    test('fromJson toleran terhadap nilai hilang', () {
      final stat = DailyVolumeStat.fromJson({'d': '2026-09-02'});
      expect(stat.volumeMl, 0.0);
      expect(stat.sessions, 0);
    });

    test('listFromStatsPayload mengabaikan item non-map & mengembalikan [] untuk payload tanpa days', () {
      final parsed = DailyVolumeStat.listFromStatsPayload({
        'days': [
          {'d': '2026-08-31', 'v': 900.0, 's': 4},
          'bukan-map',
        ],
      });
      expect(parsed.length, 1);
      expect(parsed.first.date, DateTime(2026, 8, 31));

      expect(DailyVolumeStat.listFromStatsPayload({'t': 'stats'}), isEmpty);
    });
  });
}
