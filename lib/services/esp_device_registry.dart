import 'package:flutter/foundation.dart';
import '../models/esp_device.dart';
import 'database_helper.dart';

/// Registry perangkat ESP: daftar device yang pernah dikenal aplikasi
/// (persisten di SQLite). Berfungsi sebagai cache di memori + titik akses
/// untuk operasi identitas (nama, last seen, favorit, hapus).
///
/// M0: service ini belum di-*provide* ke pohon widget; siap dipakai ketika
/// layer UI (dashboard/Perangkat, lihat rencana M3/M5) mulai membaca daftar.
class EspDeviceRegistry extends ChangeNotifier {
  final DatabaseHelper _db;

  EspDeviceRegistry({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper.instance;

  List<EspDevice> _devices = const [];
  List<EspDevice> get devices => List.unmodifiable(_devices);

  bool _loaded = false;

  /// Muat semua device dari DB ke memori. Aman dipanggil ulang.
  Future<void> reload() async {
    _devices = await _db.getAllRegisteredDevices();
    _loaded = true;
    notifyListeners();
  }

  bool get isLoaded => _loaded;

  EspDevice? byKey(String deviceKey) {
    for (final d in _devices) {
      if (d.deviceKey == deviceKey) return d;
    }
    return null;
  }

  /// Simpan (tambah/update) satu device dari hasil scan/koneksi. Bila
  /// deviceKey sudah ada, metadata dilengkapi; nama memakai yang tersimpan.
  Future<void> registerOrUpdate(EspDevice device) async {
    final existing = byKey(device.deviceKey);
    final merged = existing == null
        ? device
        : existing.copyWith(
            serviceUuid: device.serviceUuid,
            bleAdvertisedName: device.bleAdvertisedName ?? existing.bleAdvertisedName,
            lastSeenAt: device.lastSeenAt,
            lastBattery: device.lastBattery,
            lastVolumeMl: device.lastVolumeMl,
          );
    await _db.upsertDevice(merged);
    await reload();
  }

  /// Catat waktu terakhir kontak + snapshot opsional tanpa mengganti nama.
  Future<bool> markSeen(String deviceKey,
      {DateTime? at, int? battery, double? volumeMl}) async {
    final rows = await _db.updateDeviceLastSeen(
      deviceKey,
      lastSeenAt: at,
      battery: battery,
      volumeMl: volumeMl,
    );
    if (rows > 0) await reload();
    return rows > 0;
  }

  Future<bool> rename(String deviceKey, String name) async {
    if (name.trim().isEmpty) return false;
    final existing = byKey(deviceKey);
    if (existing == null) return false;
    final rows = await _db.updateDeviceName(deviceKey, name.trim());
    if (rows > 0) await reload();
    return rows > 0;
  }

  Future<bool> toggleFavorite(String deviceKey) async {
    final existing = byKey(deviceKey);
    if (existing == null) return false;
    await _db.setDeviceFavorite(deviceKey, !existing.isFavorite);
    await reload();
    return true;
  }

  Future<void> remove(String deviceKey) async {
    await _db.removeDevice(deviceKey);
    await reload();
  }
}
