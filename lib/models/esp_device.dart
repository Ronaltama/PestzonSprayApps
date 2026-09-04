/// Entri registry (daftar) sebuah perangkat ESP yang pernah dikenal aplikasi.
///
/// Identitas utamanya adalah [deviceKey] (= alamat MAC BLE / `remoteId.str`)
/// yang stabil antar sesi dan unik di dunia. Field lain hanyalah metadata
/// tampilan/last-known yang memperkaya daftar devices.
///
/// M0: cukup sebagai model storage; belum dipakai langsung oleh layar.
class EspDevice {
  /// Kunci primer; alamat BLE (`xx:xx:xx:xx:xx:xx`) atau fallback identifier.
  final String deviceKey;

  /// Nama tampilan (nama broadcast saat scan / nama yang diedit pengguna).
  final String name;

  /// Service UUID GATT yang dipakai perangkat (boleh kosong bila tidak
  /// dikenal / memakai UUID bersama). Disimpan sebagai metadata saja,
  /// bukan penentu identitas.
  final String? serviceUuid;

  /// Nama asli yang terlihat saat BLE scan, untuk membantu reconnect.
  final String? bleAdvertisedName;

  /// Waktu terakhir aplikasi tersambung / menarik data dari perangkat.
  final DateTime? lastSeenAt;

  /// Baterai (%) pada snapshot terakhir yang berhasil diambil.
  final int? lastBattery;

  /// Total volume (ml) pada snapshot terakhir.
  final double? lastVolumeMl;

  /// Penanda favorit agar naik urutan pada daftar.
  final bool isFavorite;

  /// Waktu perangkat pertama kali dikenal/terdaftar.
  final DateTime? createdAt;

  const EspDevice({
    required this.deviceKey,
    required this.name,
    this.serviceUuid,
    this.bleAdvertisedName,
    this.lastSeenAt,
    this.lastBattery,
    this.lastVolumeMl,
    this.isFavorite = false,
    this.createdAt,
  });

  // Format string standar pendukung DB (ISO).
  static String _encDate(DateTime? d) => d?.toIso8601String() ?? '';
  static DateTime? _decDate(Object? s) {
    if (s == null) return null;
    return DateTime.tryParse(s.toString());
  }

  static int? _intOrNull(Object? v) {
    if (v is num) return v.toInt();
    if (v is String && v.isNotEmpty) return int.tryParse(v);
    return null;
  }

  static double? _doubleOrNull(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String && v.isNotEmpty) return double.tryParse(v);
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'device_key': deviceKey,
      'name': name,
      'service_uuid': serviceUuid,
      'ble_advertised_name': bleAdvertisedName,
      'last_seen_at': _encDate(lastSeenAt),
      'last_battery': lastBattery,
      'last_volume_ml': lastVolumeMl,
      'is_favorite': isFavorite ? 1 : 0,
      'created_at': _encDate(createdAt),
    };
  }

  factory EspDevice.fromMap(Map<String, dynamic> map) {
    return EspDevice(
      deviceKey: map['device_key'] as String,
      name: (map['name'] as String?) ?? '',
      serviceUuid: map['service_uuid'] as String?,
      bleAdvertisedName: map['ble_advertised_name'] as String?,
      lastSeenAt: _decDate(map['last_seen_at']),
      lastBattery: _intOrNull(map['last_battery']),
      lastVolumeMl: _doubleOrNull(map['last_volume_ml']),
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      createdAt: _decDate(map['created_at']),
    );
  }

  EspDevice copyWith({
    String? name,
    String? serviceUuid,
    String? bleAdvertisedName,
    DateTime? lastSeenAt,
    bool clearLastSeenAt = false,
    int? lastBattery,
    bool clearLastBattery = false,
    double? lastVolumeMl,
    bool clearLastVolumeMl = false,
    bool? isFavorite,
    DateTime? createdAt,
  }) {
    return EspDevice(
      deviceKey: deviceKey,
      name: name ?? this.name,
      serviceUuid: serviceUuid ?? this.serviceUuid,
      bleAdvertisedName: bleAdvertisedName ?? this.bleAdvertisedName,
      lastSeenAt: clearLastSeenAt ? null : (lastSeenAt ?? this.lastSeenAt),
      lastBattery: clearLastBattery ? null : (lastBattery ?? this.lastBattery),
      lastVolumeMl:
          clearLastVolumeMl ? null : (lastVolumeMl ?? this.lastVolumeMl),
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
