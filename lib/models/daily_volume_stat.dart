/// Statistik volume harian yang disimpan di perangkat ESP (7 hari terakhir).
///
/// Satu entri mewakili satu tanggal kalender. Dipakai untuk membalas request
/// `get_stats` dari aplikasi.
class DailyVolumeStat {
  /// Tanggal kalender (waktu lokal; jam tidak relevan).
  final DateTime date;

  /// Total volume semprot pada tanggal tsb (ml).
  final double volumeMl;

  /// Total jumlah sesi semprot pada tanggal tsb.
  final int sessions;

  const DailyVolumeStat({
    required this.date,
    required this.volumeMl,
    required this.sessions,
  });

  /// Index 0 = Senin .. 6 = Minggu (mengikuti bar chart dashboard).
  int get weekdayIndex => date.weekday - 1;

  /// Format tanggal menjadi kunci `YYYY-MM-DD` sesuai kontrak perangkat.
  static String formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Map<String, dynamic> toJson() {
    return {'d': formatDate(date), 'v': volumeMl, 's': sessions};
  }

  factory DailyVolumeStat.fromJson(Map<String, dynamic> json) {
    return DailyVolumeStat(
      date: DateTime.parse(json['d'] as String),
      volumeMl: (json['v'] as num?)?.toDouble() ?? 0.0,
      sessions: (json['s'] as num?)?.toInt() ?? 0,
    );
  }

  /// Parse isi payload response `{"t":"stats","days":[...]}`.
  static List<DailyVolumeStat> listFromStatsPayload(
    Map<String, dynamic> payload,
  ) {
    final rawDays = payload['days'];
    if (rawDays is! List) return const [];
    return rawDays
        .whereType<Map<String, dynamic>>()
        .map(DailyVolumeStat.fromJson)
        .toList();
  }
}
