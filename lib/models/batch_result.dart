/// Hasil eksekusi *Semprot Sekarang* pada beberapa perangkat sekaligus.
///
/// Koneksi BLE aktif pada aplikasi ini satu-per-satu (M1). Batch dijalankan
/// berurutan terhadap unit yang *sedang terjangkau* versi sesi saat ini;
/// unit yang tidak terjangkau (tidak Live) dilaporkan di [skipped] agar UI\n/// maupun panggilan programatis dapat memberi tahu operator.
class BatchSprayResult {
  /// `device_key` yang perintah semprotnya berhasil dimulai.
  final List<String> started;

  /// `device_key` yang dilewati karena tidak terjangkau (unit tidak live /
  /// bukan sesi BLE aktif saat proses berjalan).
  final List<String> skipped;

  const BatchSprayResult({required this.started, required this.skipped});

  bool get allOk => started.isNotEmpty && skipped.isEmpty;
  int get total => started.length + skipped.length;
}
