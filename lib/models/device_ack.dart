/// Konfirmasi (ack) dari perangkat ESP untuk request tulis seperti
/// `set_schedules`.
class DeviceAck {
  /// Tipe request yang dikonfirmasi, mis. `set_schedules`.
  final String ref;

  /// `true` jika perangkat berhasil mengeksekusi request.
  final bool ok;

  /// Pesan error singkat (hanya ada saat `ok == false`).
  final String? error;

  const DeviceAck({
    required this.ref,
    required this.ok,
    this.error,
  });

  factory DeviceAck.fromJson(Map<String, dynamic> json) {
    return DeviceAck(
      ref: json['ref'] as String? ?? json['cmd'] as String? ?? '',
      ok: json['ok'] == 1 || json['ok'] == true || json['status'] == 'ok' || json['status'] == 1,
      error: json['err'] as String? ?? json['error'] as String?,
    );
  }
}
