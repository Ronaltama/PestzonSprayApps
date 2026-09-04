/// Snapshot ringkas data perangkat saat diambil (cache `summary`/`stats`
/// lengkap per `device_key`, disimpan di `device_snapshots`).
///
/// Dikenakan saat refres/bari ke DB agar histori per perangkat tetap dapat
/// ditampilkan ketika perangkat sedang offline.
class DeviceSnapshot {
  final DateTime capturedAt;
  final Map<String, dynamic> payload;

  const DeviceSnapshot({required this.capturedAt, required this.payload});
}
