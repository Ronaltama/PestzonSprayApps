import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/device_ack.dart';
import '../models/device_status.dart';
import '../models/daily_volume_stat.dart';
import '../models/spray_schedule.dart';
import 'bluetooth_service.dart';
import 'mqtt_service.dart';
import 'database_helper.dart';

enum DeviceChannel { none, ble, mqtt }

/// Repositori tingkat UI yang memilih kanal komunikasi aktif (BLE lebih
/// diutamakan, fallback MQTT) dan membungkus mekanisme request/response ke
/// perangkat ESP dengan timeout otomatis.
///
/// Dashboard & halaman jadwal cukup menonton repositori ini tanpa perlu tahu
/// kanal mana yang sedang dipakai. Service BLE/MQTT tetap diakses langsung
/// untuk aksi kontrol (semprot, config, dll).
class DeviceRepository extends ChangeNotifier {
  final BluetoothService _bt;
  final MqttService _mqtt;

  static const Duration _requestTimeout = Duration(seconds: 4);

  List<DailyVolumeStat>? _stats;
  List<SpraySchedule>? _schedules;
  DeviceAck? _lastAck;

  bool _isRefreshing = false;
  bool _isPushing = false;
  bool _refreshInFlight = false;

  DeviceChannel _lastActiveChannel = DeviceChannel.none;
  bool _wasPumpRunning = false;

  final bool _enableDemoData;
  List<DailyVolumeStat>? _demoStats;

  // ---- M2: cache status & snapshot per perangkat ----
  /// Status terakhir yang diterima per `device_key` (sesi BLE aktif).
  final Map<String, DeviceStatus> _statusByDevice = {};
  final DatabaseHelper _db = DatabaseHelper.instance;

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final List<Future<void> Function()> _pushQueue = [];
  bool _pushQueueRunning = false;

  DeviceRepository({
    required BluetoothService bluetoothService,
    required MqttService mqttService,
    bool enableDemoData = false,
  })  : _bt = bluetoothService,
        _mqtt = mqttService,
        _enableDemoData = enableDemoData {
    _demoStats = _buildDemoStats();
    _bt.addListener(_onServiceChanged);
    _mqtt.addListener(_onServiceChanged);

    // Cache hasil response (persistent listener, tetap jalan meski ada waiter).
    _subscriptions.add(_bt.statsStream.listen((v) {
      _stats = v;
      notifyListeners();
    }));
    _subscriptions.add(_bt.schedulesStream.listen((v) {
      _schedules = v;
      notifyListeners();
    }));
    _subscriptions.add(_bt.ackStream.listen((v) {
      _lastAck = v;
      notifyListeners();
    }));
    // Persist summary per aktif device saat diterima (M2.2/M2.5).
    _subscriptions.add(_bt.summaryStream.listen(_onBleSummary));
    _subscriptions.add(_mqtt.statusStream.listen(_onMqttSummary));
    _subscriptions.add(_mqtt.statsStream.listen((v) {
      _stats = v;
      notifyListeners();
    }));
    _subscriptions.add(_mqtt.schedulesStream.listen((v) {
      _schedules = v;
      notifyListeners();
    }));
    _subscriptions.add(_mqtt.ackStream.listen((v) {
      _lastAck = v;
      notifyListeners();
    }));
  }

  // ---- Kanal aktif ----

  DeviceChannel get activeChannel {
    if (_bt.isConnected) return DeviceChannel.ble;
    if (_mqtt.isConnected && _mqtt.isEspOnline) return DeviceChannel.mqtt;
    return DeviceChannel.none;
  }

  bool get isConnected => activeChannel != DeviceChannel.none;
  bool get isRefreshing => _isRefreshing;
  bool get isPushing => _isPushing;

  /// Status perangkat terbaik saat ini (mempertahankan perilaku fallback lama:
  /// BLE dulu, lalu MQTT, terakhir nilai lokal sebagai placeholder).
  DeviceStatus get summary {
    switch (activeChannel) {
      case DeviceChannel.ble:
        return _bt.deviceStatus;
      case DeviceChannel.mqtt:
        return _mqtt.latestStatus ?? _bt.deviceStatus;
      case DeviceChannel.none:
        return _bt.deviceStatus;
    }
  }

  // ---- M2: akses status per perangkat & penyimpanan snapshot ----

  /// Status terakhir (dari sesi aktif / event penting) untuk [deviceKey].
  /// Cache ringan di memori; untuk membaca riwayat persisten gunakan
  /// [loadLastSnapshot]. Return `null` bila belum ada data di sesi ini.
  DeviceStatus? statusOf(String deviceKey) => _statusByDevice[deviceKey];

  /// Snapshot persisten terlast untuk [deviceKey] bila pernah disimpan
  /// (mis. sesi lama atau saat sedang offline).
  Future<DeviceStatus?> loadLastSnapshot(String deviceKey) async {
    try {
      final snap = await _db.latestDeviceSnapshot(deviceKey);
      if (snap == null) return null;
      return DeviceStatus.fromJson(snap.payload);
    } catch (_) {
      return null;
    }
  }

  void _onBleSummary(DeviceStatus status) {
    final key = _bt.activeDeviceKey;
    if (key == null) return;
    _statusByDevice[key] = status.copyWith(connectionState: 'Connected (BLE)');
    unawaited(_persistSummary(key, status));
    notifyListeners();
  }

  void _onMqttSummary(DeviceStatus status) {
    final id = _mqtt.deviceId;
    if (id.isEmpty) return;
    // Disimpan di cache lewat kunci berprefiks agar tak bentrok dengan MAC BLE;
    // penyimpanan persisten penuh dilakukan saat MQTT dihubungkan ke registry
    // MAC (di luar lingkup milestone ini).
    _statusByDevice['mqtt:$id'] =
        status.copyWith(connectionState: 'Connected (MQTT)');
    notifyListeners();
  }

  Future<void> _persistSummary(String mac, DeviceStatus s) async {
    try {
      final payload = <String, dynamic>{
        'battery': s.batteryPercentage,
        'voltage': s.batteryVoltage,
        'isSolar': s.isSolarCharging ? 1 : 0,
        'isPumpRunning': s.isPumpRunning ? 1 : 0,
        'durationSec': s.activeDurationSeconds,
        'totalSesi': s.totalSesiToday,
        'totalVolume': s.totalVolumeTodayMl,
        'flowRate': s.flowRateMlPerSec,
        'dailyTarget': s.dailyTargetMl,
        'connState': s.connectionState,
        'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
      await _db.saveDeviceSnapshot(
        mac,
        capturedAt: DateTime.now(),
        payload: payload,
      );
    } catch (_) {
      // Penyimpanan snapshot paling buruk gagal diam-diam: tidak boleh
      // mengganggu alur refresh yang sedang berjalan.
    }
  }

  /// Statistik volume per hari. Mengutamakan data dari perangkat (cache hasil
  /// pull). Saat mode demo aktif dan perangkat tidak terhubung (belum punya
  /// data nyata), dikembalikan statistik dummy acak 60–67 ml per hari.
  List<DailyVolumeStat>? get stats {
    if (_stats != null) return _stats;
    if (_enableDemoData && activeChannel == DeviceChannel.none) {
      return _demoStats;
    }
    return null;
  }

  /// Jadwal terakhir yang berhasil ditarik dari perangkat.
  List<SpraySchedule>? get schedules => _schedules;

  // ---- Reaksi perubahan koneksi ----

  void _onServiceChanged() {
    final channel = activeChannel;

    // Refresh data otomatis saat baru connect / pindah kanal.
    if (channel != DeviceChannel.none && channel != _lastActiveChannel) {
      _lastActiveChannel = channel;
      Future.microtask(refreshAll);
    } else if (channel == DeviceChannel.none &&
        _lastActiveChannel != DeviceChannel.none) {
      _lastActiveChannel = DeviceChannel.none;
    }

    // Setelah sesi semprot selesai, tarik kesimpulan terbaru (counter ESP).
    final pumpRunning = summary.isPumpRunning;
    if (_wasPumpRunning && !pumpRunning && isConnected) {
      Future.microtask(refreshSummary);
    }
    _wasPumpRunning = pumpRunning;

    notifyListeners();
  }

  // ---- Request & timeout ----

  /// Tunggu event pertama pada [events]; subscribe dilakukan lebih dulu agar
  /// response yang cepat tidak terlewat. Mengembalikan `true` jika ada event
  /// dalam batas waktu, `false` jika timeout.
  Future<bool> _awaitEvent(Stream<dynamic> events) {
    final completer = Completer<bool>();
    late final StreamSubscription<dynamic> sub;
    sub = events.listen((_) {
      if (!completer.isCompleted) completer.complete(true);
    });
    final timer = Timer(_requestTimeout, () {
      if (!completer.isCompleted) completer.complete(false);
    });
    return completer.future.then((value) {
      sub.cancel();
      timer.cancel();
      return value;
    });
  }

  Stream<dynamic> _summaryEvents(DeviceChannel channel) =>
      channel == DeviceChannel.ble ? _bt.summaryStream : _mqtt.statusStream;

  Stream<dynamic> _statsEvents(DeviceChannel channel) =>
      channel == DeviceChannel.ble ? _bt.statsStream : _mqtt.statsStream;

  Stream<dynamic> _schedulesEvents(DeviceChannel channel) =>
      channel == DeviceChannel.ble
          ? _bt.schedulesStream
          : _mqtt.schedulesStream;

  Stream<dynamic> _ackEvents(DeviceChannel channel) =>
      channel == DeviceChannel.ble ? _bt.ackStream : _mqtt.ackStream;

  DateTime get _mondayThisWeek {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: now.weekday - 1));
  }

  // ---- API publik ----

  /// Tarik kesimpulan hari ini + statistik volume pekan berjalan.
  Future<bool> refreshAll() async {
    if (!isConnected) return false;
    if (_refreshInFlight) return true;
    _refreshInFlight = true;
    _isRefreshing = true;
    notifyListeners();
    try {
      final okSummary = await refreshSummary();
      final okStats = await refreshStats();
      return okSummary || okStats;
    } finally {
      _refreshInFlight = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// Minta ringkasan hari ini (volume total, sesi, baterai, dll) dari ESP.
  Future<bool> refreshSummary() async {
    final channel = activeChannel;
    if (channel == DeviceChannel.none) return false;
    final future = _awaitEvent(_summaryEvents(channel));
    if (channel == DeviceChannel.ble) {
      _bt.requestSummary();
    } else {
      _mqtt.requestSummary();
    }
    return future;
  }

  /// Minta statistik volume per hari untuk pekan berjalan (Senin–Minggu).
  Future<bool> refreshStats() async {
    final channel = activeChannel;
    if (channel == DeviceChannel.none) return false;
    final monday = _mondayThisWeek;
    final future = _awaitEvent(_statsEvents(channel));
    if (channel == DeviceChannel.ble) {
      _bt.requestStats(from: monday, to: monday.add(const Duration(days: 6)));
    } else {
      _mqtt.requestStats(from: monday, to: monday.add(const Duration(days: 6)));
    }
    return future;
  }

  /// Tarik daftar jadwal dari ESP. Mengembalikan daftar terbaru, atau `null`
  /// jika tidak ada koneksi / tidak ada respon.
  Future<List<SpraySchedule>?> pullSchedules() async {
    final channel = activeChannel;
    if (channel == DeviceChannel.none) return null;
    final future = _awaitEvent(_schedulesEvents(channel));
    if (channel == DeviceChannel.ble) {
      _bt.requestSchedules();
    } else {
      _mqtt.requestSchedules();
    }
    final ok = await future;
    return ok ? _schedules : null;
  }

  /// Tulis daftar jadwal penuh ke ESP (dipakai untuk tambah/hapus/nyalakan/
  /// matikan). Mengembalikan ack perangkat, atau `null` jika timeout / offline.
  ///
  /// Push diserialkan lewat [_pushQueue]: operasi berurutan ({Queue}) sehingga
  /// ACK dari push sebelumnya tidak berpindah ke push berikutnya saat user
  /// mengetuk cepat (toggle/hapus berturut-turut).
  Future<DeviceAck?> pushSchedules(List<SpraySchedule> schedules) {
    final result = Completer<DeviceAck?>();
    _pushQueue.add(() async {
      try {
        final ack = await _pushSchedulesOnce(schedules);
        result.complete(ack);
      } catch (e) {
        result.complete(null);
      }
    });
    _drainPushQueue();
    return result.future;
  }

  Future<DeviceAck?> _pushSchedulesOnce(List<SpraySchedule> schedules) async {
    final channel = activeChannel;
    if (channel == DeviceChannel.none) return null;
    if (_isPushing) return null; // safety: tidak mungkin karena queue.
    _isPushing = true;
    _lastAck = null;
    notifyListeners();
    try {
      final future = _awaitEvent(_ackEvents(channel));
      if (channel == DeviceChannel.ble) {
        _bt.pushSchedules(schedules);
      } else {
        _mqtt.pushSchedules(schedules);
      }
      final ok = await future;
      return ok ? _lastAck : null;
    } finally {
      _isPushing = false;
      notifyListeners();
    }
  }

  void _drainPushQueue() async {
    if (_pushQueue.isNotEmpty && !_pushQueueRunning) {
      _pushQueueRunning = true;
      while (_pushQueue.isNotEmpty) {
        final op = _pushQueue.removeAt(0);
        await op();
      }
      _pushQueueRunning = false;
    }
  }

  /// Bangkitkan statistik dummy 7 hari (Senin–Minggu pekan berjalan) untuk
  /// mode demo. Volume acak per hari pada kisaran 60–67 ml; hari yang belum
  /// lewat (masa depan) dibuat 0 sehingga grafik konsisten dengan perilaku
  /// nyata (data ESP hanya ada utk hari lalu & hari ini). Dibangkitkan sekali
  /// per instance supaya chart stabil selama satu sesi app.
  ///
  /// DIMULUSI: data ini bukan data perangkat. Hanya dipakai saat mode demo
  /// aktif & tidak terhubung. Data asli selalu mengambil alih begitu device
  /// merespons.
  List<DailyVolumeStat> _buildDemoStats() {
    if (!_enableDemoData) return const [];
    final random = Random();
    final now = DateTime.now();
    final monday = _mondayThisWeek;
    final todayIdx = now.weekday - 1;
    final List<DailyVolumeStat> result = [];
    for (var i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      if (i > todayIdx) continue; // hari belum lewat → 0 (tidak dikirim)
      result.add(DailyVolumeStat(
        date: date,
        volumeMl: (60 + random.nextInt(8)).toDouble(), // 60..67
        sessions: 1 + random.nextInt(3),
      ));
    }
    return result;
  }

  @override
  void dispose() {
    _bt.removeListener(_onServiceChanged);
    _mqtt.removeListener(_onServiceChanged);
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
