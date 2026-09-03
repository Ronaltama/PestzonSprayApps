class SpraySchedule {
  final int? id;
  final String title;
  final int hour; // 0..23
  final int minute; // 0..59
  final int durationSeconds;
  final bool isActive;

  SpraySchedule({
    this.id,
    required this.title,
    required this.hour,
    required this.minute,
    required this.durationSeconds,
    this.isActive = true,
  });

  String get timeFormatted {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m WIB';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'hour': hour,
      'minute': minute,
      'durationSeconds': durationSeconds,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory SpraySchedule.fromMap(Map<String, dynamic> map) {
    return SpraySchedule(
      id: map['id'] as int?,
      title: map['title'] as String? ?? 'Penyemprotan',
      hour: map['hour'] as int,
      minute: map['minute'] as int,
      durationSeconds: map['durationSeconds'] as int,
      isActive: (map['isActive'] as int) == 1,
    );
  }

  /// Serialisasi untuk dikirim ke perangkat ESP (kontrak `set_schedules` /
  /// response `schedules`). Kunci & satuan mengikuti kontrak perangkat,
  /// bukan skema tabel SQLite lokal.
  Map<String, dynamic> toDeviceJson() {
    return {
      'id': id,
      'title': title,
      'hour': hour,
      'minute': minute,
      'duration': durationSeconds,
      'active': isActive ? 1 : 0,
    };
  }

  factory SpraySchedule.fromDeviceJson(Map<String, dynamic> map) {
    return SpraySchedule(
      id: (map['id'] as num?)?.toInt(),
      title: map['title'] as String? ?? 'Penyemprotan',
      hour: (map['hour'] as num).toInt(),
      minute: (map['minute'] as num).toInt(),
      durationSeconds: (map['duration'] as num?)?.toInt() ?? 0,
      isActive: map['active'] == 1 || map['active'] == true,
    );
  }

  /// Parse daftar jadwal dari payload response `{"t":"schedules","schedules":[...]}`.
  static List<SpraySchedule> listFromDevicePayload(List<dynamic> items) {
    return items
        .whereType<Map<String, dynamic>>()
        .map(SpraySchedule.fromDeviceJson)
        .toList();
  }

  SpraySchedule copyWith({
    int? id,
    String? title,
    int? hour,
    int? minute,
    int? durationSeconds,
    bool? isActive,
  }) {
    return SpraySchedule(
      id: id ?? this.id,
      title: title ?? this.title,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isActive: isActive ?? this.isActive,
    );
  }
}
