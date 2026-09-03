import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../models/device_status.dart';
import '../models/spray_log.dart';
import '../models/spray_schedule.dart';
import '../models/device_config.dart';
import '../models/device_ack.dart';
import '../models/daily_volume_stat.dart';
import 'database_helper.dart';

class BluetoothService extends ChangeNotifier {
  // Service & Characteristic UUIDs for ESP32 Smart Sprayer BLE
  static const String serviceUuid = "4fa1c691-e9a5-4307-9a45-500f7a6a0a9c";
  static const String rxCharUuid = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"; // Write
  static const String txCharUuid = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"; // Notify/Read

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  String _connectedDeviceName = 'Tidak Terhubung';
  String get connectedDeviceName => _connectedDeviceName;

  fbp.BluetoothAdapterState _adapterState = fbp.BluetoothAdapterState.unknown;
  fbp.BluetoothAdapterState get adapterState => _adapterState;

  // Bluetooth dianggap ON jika adapter ON atau jika ditemukan perangkat terdaftar/scan
  bool get isBluetoothOn =>
      _adapterState == fbp.BluetoothAdapterState.on ||
      _scanResults.isNotEmpty ||
      _systemDevices.isNotEmpty;

  DeviceStatus _deviceStatus = DeviceStatus();
  DeviceStatus get deviceStatus => _deviceStatus;

  // ---- Request/Response streams (kontrak perangkat baru) ----
  final _summaryStreamController = StreamController<DeviceStatus>.broadcast();
  final _statsStreamController =
      StreamController<List<DailyVolumeStat>>.broadcast();
  final _schedulesStreamController =
      StreamController<List<SpraySchedule>>.broadcast();
  final _ackStreamController = StreamController<DeviceAck>.broadcast();

  Stream<DeviceStatus> get summaryStream => _summaryStreamController.stream;
  Stream<List<DailyVolumeStat>> get statsStream => _statsStreamController.stream;
  Stream<List<SpraySchedule>> get schedulesStream =>
      _schedulesStreamController.stream;
  Stream<DeviceAck> get ackStream => _ackStreamController.stream;

  // Buffer untuk transport newline-delimited JSON dari firmware BLE.
  final StringBuffer _incomingBuffer = StringBuffer();

  Timer? _sprayTimer;

  // List of discovered devices dynamically from active live BLE scan
  List<fbp.ScanResult> _scanResults = [];
  List<fbp.ScanResult> get scanResults => _scanResults;

  // System devices that are ACTIVE / Ready to connect (Unbonded / Not Set Up)
  List<fbp.BluetoothDevice> _systemDevices = [];
  List<fbp.BluetoothDevice> get systemDevices => _systemDevices;

  fbp.BluetoothDevice? _connectedDevice;
  fbp.BluetoothCharacteristic? _rxCharacteristic;
  fbp.BluetoothCharacteristic? _txCharacteristic;

  StreamSubscription<List<fbp.ScanResult>>? _scanSubscription;
  StreamSubscription<fbp.BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<fbp.BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _notifySubscription;

  BluetoothService() {
    _initBluetoothStateListener();
  }

  void _initBluetoothStateListener() {
    // Di lingkungan flutter test, plugin BLE tidak terdaftar (UnsupportedError)
    // dan tidak ada adapter nyata — cukup tandai adapter sebagai on.
    final isTestEnv = Platform.environment['FLUTTER_TEST'] == 'true';
    if (!kIsWeb && !isTestEnv) {
      _adapterStateSubscription = fbp.FlutterBluePlus.adapterState.listen((state) {
        _adapterState = state;
        notifyListeners();
        if (state == fbp.BluetoothAdapterState.on) {
          startScan();
        }
      });
    } else {
      _adapterState = fbp.BluetoothAdapterState.on;
    }
  }

  Future<void> turnOnBluetooth() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await fbp.FlutterBluePlus.turnOn();
      } catch (e) {
        if (kDebugMode) print('Failed to turn on bluetooth: $e');
      }
    }
  }

  void startScan() async {
    if (_isScanning) return;

    _isScanning = true;
    notifyListeners();

    if (!kIsWeb) {
      try {
        // Stop any existing scan
        await fbp.FlutterBluePlus.stopScan();

        // 1. Fetch system devices & filter ONLY active / ready-to-connect devices (Excluding bonded offline archives)
        try {
          final allSysDevs = await fbp.FlutterBluePlus.systemDevices([]);
          List<fbp.BluetoothDevice> filteredActiveSysDevs = [];
          for (var dev in allSysDevs) {
            // Exclude bonded/paired devices that are disconnected (offline archive history)
            if (dev.bondState == fbp.BluetoothBondState.bonded &&
                dev.isConnected == false) {
              continue; // Skip offline archive device!
            }
            filteredActiveSysDevs.add(dev);
          }
          _systemDevices = filteredActiveSysDevs;
          if (_systemDevices.isNotEmpty) {
            _adapterState = fbp.BluetoothAdapterState.on;
          }
          notifyListeners();
        } catch (_) {}

        // 2. Listen to active BLE scan results as they arrive live
        _scanSubscription?.cancel();
        _scanSubscription = fbp.FlutterBluePlus.scanResults.listen((results) {
          _scanResults = results;
          if (results.isNotEmpty) {
            _adapterState = fbp.BluetoothAdapterState.on;
          }
          notifyListeners();
        });

        // Start scanning for fast 3 seconds
        await fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 3));
      } catch (e) {
        if (kDebugMode) {
          print('Error scanning BLE: $e');
        }
      }
    }
    
    _isScanning = false;
    notifyListeners();
  }

  Future<void> stopScan() async {
    if (!kIsWeb) {
      await fbp.FlutterBluePlus.stopScan();
    }
    _isScanning = false;
    notifyListeners();
  }

  Future<void> connectToDevice(String deviceName,
      {required fbp.BluetoothDevice device}) async {
    // Tolak permintaan connect ganda (double-tap / UI belum update). Dua
    // attempt paralel bisa menyebabkan race & state tidak konsisten.
    if (_isConnecting) {
      if (kDebugMode) print('BLE: abaikan connect, masih connecting...');
      return;
    }
    _isConnecting = true;
    _connectedDeviceName = 'Connecting...';
    _connectedDevice = null;
    _rxCharacteristic = null;
    _txCharacteristic = null;
    _isConnected = false;
    _incomingBuffer.clear();
    notifyListeners();

    try {
      // Stop scan and let bluetooth controller settle
      await stopScan();
      await Future.delayed(const Duration(milliseconds: 200));

      // Instant direct connection (autoConnect: false). Timeout lebih panjang
      // (12s) karena ESP32 BLE kadang lambat init pada koneksi pertama setelah
      // daya baru / nyala ulang.
      await device.connect(
        timeout: const Duration(seconds: 12),
        autoConnect: false,
      );
      _connectedDevice = device;
      _connectedDeviceName = device.platformName.isNotEmpty
          ? device.platformName
          : device.remoteId.str;

      // Monitor connection state
      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        if (!_isConnecting &&
            state == fbp.BluetoothConnectionState.disconnected) {
          _onDisconnected();
        }
      });

      // Discover services; pastikan selesai sebelum dianggap connect.
      try {
        final services = await device.discoverServices();
        await _setupCharacteristics(services);
      } catch (e) {
        if (kDebugMode) print('BLE: gagal discover services: $e');
        await device.disconnect();
        _onDisconnected(
            customMessage: 'Gagal: Karakteristik BLE tidak ditemukan');
        return;
      }

      if (_rxCharacteristic == null || _txCharacteristic == null) {
        // Tidak ada karakteristik RX/TX yang cocok — bukan perangkat ESP yang
        // dimaksud, atau firmware tak lengkap.
        await device.disconnect();
        _onDisconnected(
            customMessage: 'Perangkat tidak kompatibel (GATT tidak ditemukan)');
        return;
      }

      _isConnected = true;
      _isConnecting = false;
      // Nilai baterai/tegangan/volume tidak di-set dummy di sini: data asli
      // diminta via request `get_summary` (DeviceRepository.refreshAll saat
      // connect) dan diisi dari response ESP.
      _deviceStatus = _deviceStatus.copyWith(
        connectionState: 'Connected (BLE)',
      );
      notifyListeners();
      return;
    } catch (e) {
      if (kDebugMode) print('Failed to connect to BLE device: $e');
      final errStr = e.toString();
      if (errStr.contains('ProfileUnavailable') || errStr.contains('BREDR')) {
        _onDisconnected(customMessage: 'Gagal: Gunakan Firmware ESP32 BLE');
      } else if (errStr.toLowerCase().contains('timeout') ||
          errStr.toLowerCase().contains('timed out')) {
        _onDisconnected(
            customMessage: 'Gagal Terhubung (timeout). Coba lagi / cek jarak & daya ESP.');
      } else {
        _onDisconnected(customMessage: 'Gagal Terhubung');
      }
      return;
    }
  }

  Future<void> _setupCharacteristics(List<fbp.BluetoothService> services) async {
    _rxCharacteristic = null;
    _txCharacteristic = null;

    for (var s in services) {
      for (var c in s.characteristics) {
        final uuidStr = c.uuid.toString().toLowerCase();
        if (uuidStr == rxCharUuid || c.properties.write || c.properties.writeWithoutResponse) {
          _rxCharacteristic ??= c;
        }
        if (uuidStr == txCharUuid || c.properties.notify || c.properties.indicate) {
          _txCharacteristic ??= c;
        }
      }
    }

    if (_txCharacteristic != null && _txCharacteristic!.properties.notify) {
      try {
        await _txCharacteristic!.setNotifyValue(true);
        _notifySubscription?.cancel();
        _notifySubscription = _txCharacteristic!.lastValueStream.listen((data) {
          _handleIncomingData(data);
        });
      } catch (e) {
        if (kDebugMode) print('Failed to subscribe notify: $e');
      }
    }
  }

  /// Terima data dari notifikasi BLE.
  ///
  /// Firmware baru mengirim JSON newline-delimited (`\n` di akhir pesan),
  /// sehingga pesan yang terpecah di batas MTU tetap utuh. Pesan lama (tanpa
  /// newline, format `{battery, voltage, solar, pump}`) tetap ditoleransi
  /// selama transisi: jika buffer sudah berupa JSON utuh, langsung diproses.
  void _handleIncomingData(List<int> data) {
    try {
      _incomingBuffer.write(utf8.decode(data));
      var buffered = _incomingBuffer.toString();

      // Proses semua baris lengkap (newline-delimited).
      if (buffered.contains('\n')) {
        final parts = buffered.split('\n');
        _incomingBuffer.clear();
        buffered = parts.removeLast(); // sisanya mungkin belum lengkap
        _incomingBuffer.write(buffered);
        for (final line in parts) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            _tryProcessJson(trimmed);
          }
        }
      }

      // Fallback: tanpa newline tapi sudah JSON utuh (format lama / tanpa
      // terminator). Kalau belum utuh, jsonDecode gagal dan byte dibiarkan
      // menunggu kelanjutannya.
      final remainder = _incomingBuffer.toString().trim();
      if (remainder.isNotEmpty) {
        final decoded = _tryDecode(remainder);
        if (decoded != null) {
          _incomingBuffer.clear();
          _processJson(decoded);
        }
      }
    } catch (_) {
      // Byte tidak valid UTF-8 — abaikan.
    }
  }

  Map<String, dynamic>? _tryDecode(String text) {
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  void _tryProcessJson(String line) {
    final decoded = _tryDecode(line);
    if (decoded != null) {
      _processJson(decoded);
    }
  }

  void _processJson(Map<String, dynamic> json) {
    final t = json['t'];
    if (t is String) {
      // Envelope kontrak perangkat baru.
      switch (t) {
        case 'summary':
          final status = DeviceStatus.fromJson(json)
              .copyWith(connectionState: 'Connected (BLE)');
          _deviceStatus = status;
          _summaryStreamController.add(status);
          notifyListeners();
        case 'stats':
          _statsStreamController
              .add(DailyVolumeStat.listFromStatsPayload(json));
        case 'schedules':
          _schedulesStreamController.add(SpraySchedule.listFromDevicePayload(
              json['schedules'] as List? ?? const []));
        case 'ack':
          _ackStreamController.add(DeviceAck.fromJson(json));
        default:
          if (kDebugMode) print('BLE unhandled envelope type: $t');
      }
      return;
    }

    // Format lama (push status singkat tanpa envelope).
    _deviceStatus = _deviceStatus.copyWith(
      batteryPercentage:
          (json['battery'] as num?)?.toInt() ?? _deviceStatus.batteryPercentage,
      batteryVoltage: (json['voltage'] as num?)?.toDouble() ??
          _deviceStatus.batteryVoltage,
      isSolarCharging: json['solar'] == true || json['solar'] == 1
          ? true
          : (json['solar'] == false || json['solar'] == 0
              ? false
              : _deviceStatus.isSolarCharging),
      isPumpRunning: json['pump'] == true || json['pump'] == 1
          ? true
          : (json['pump'] == false || json['pump'] == 0
              ? false
              : _deviceStatus.isPumpRunning),
    );
    notifyListeners();
  }

  Future<void> _writeRaw(String jsonStr) async {
    if (_rxCharacteristic == null) return;
    if (!_isConnected) {
      if (kDebugMode) print('Skip BLE write (tidak terhubung): $jsonStr');
      return;
    }
    try {
      final bytes = utf8.encode(jsonStr);
      await _rxCharacteristic!.write(
        bytes,
        withoutResponse: _rxCharacteristic!.properties.writeWithoutResponse,
      );
      if (kDebugMode) print('Sent BLE bytes: $jsonStr');
    } catch (e) {
      if (kDebugMode) print('Error writing BLE characteristic: $e');
    }
  }

  void _sendBleMessage(Map<String, dynamic> payload) {
    _writeRaw(jsonEncode(payload));
  }

  /// Kirim envelope kontrak perangkat baru (diakhiri `\n` sesuai framing BLE).
  void _sendBleEnvelope(Map<String, dynamic> payload) {
    _writeRaw('${jsonEncode(payload)}\n');
  }

  // ---- Request/Response (kontrak perangkat baru) ----

  /// Minta ringkasan hari ini dari ESP (volume, sesi, baterai, dll).
  void requestSummary() {
    _sendBleEnvelope({'v': 1, 't': 'get_summary'});
  }

  /// Minta statistik volume per hari pada rentang tanggal (inklusif).
  void requestStats({required DateTime from, required DateTime to}) {
    _sendBleEnvelope({
      'v': 1,
      't': 'get_stats',
      'from': DailyVolumeStat.formatDate(from),
      'to': DailyVolumeStat.formatDate(to),
    });
  }

  /// Minta daftar jadwal semprot yang tersimpan di ESP.
  void requestSchedules() {
    _sendBleEnvelope({'v': 1, 't': 'get_schedules'});
  }

  /// Tulis daftar jadwal penuh ke ESP (tambah/hapus/nyalakan/matikan).
  void pushSchedules(List<SpraySchedule> schedules) {
    _sendBleEnvelope({
      'v': 1,
      't': 'set_schedules',
      'schedules': schedules.map((s) => s.toDeviceJson()).toList(),
    });
  }

  void _onDisconnected({String customMessage = 'Tidak Terhubung'}) {
    _notifySubscription?.cancel();
    _connectionSubscription?.cancel();
    _connectedDevice = null;
    _rxCharacteristic = null;
    _txCharacteristic = null;
    _incomingBuffer.clear();
    _isConnected = false;
    _isConnecting = false;
    _connectedDeviceName = customMessage;
    _deviceStatus = _deviceStatus.copyWith(connectionState: 'Disconnected');
    notifyListeners();
  }

  void disconnect() async {
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (e) {
        if (kDebugMode) print('Error disconnecting BLE: $e');
      }
    }
    _onDisconnected();
  }

  /// Trigger penyemprotan pompa DC 310 5V selama durasiDetik
  Future<void> startSpraying({
    required int durationSeconds,
    required DatabaseHelper dbHelper,
    String mode = 'Manual',
  }) async {
    if (_deviceStatus.isPumpRunning) return;

    _deviceStatus = _deviceStatus.copyWith(
      isPumpRunning: true,
      activeDurationSeconds: durationSeconds,
    );
    notifyListeners();

    // Send START command via BLE to ESP32
    _sendBleMessage({
      'cmd': 'START',
      'duration': durationSeconds,
      'mode': mode,
    });
    
    // Timer countdown
    int remaining = durationSeconds;
    _sprayTimer?.cancel();
    _sprayTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      remaining--;
      if (remaining <= 0) {
        timer.cancel();

        // Pump berhenti. Counter total volume/sesi TIDAK dihitung lokal lagi:
        // nilainya milik ESP dan ditarik via request `get_summary` setelah
        // semprot selesai (DeviceRepository memicu refreshSummary).
        final estimatedVolumeMl = durationSeconds * 5.0; // 5 ml/detik debit pompa misting

        _deviceStatus = _deviceStatus.copyWith(
          isPumpRunning: false,
          activeDurationSeconds: 0,
        );
        notifyListeners();

        // SIMPAN KE DATABASE LOKAL HP (SQLite) untuk riwayat
        final log = SprayLog(
          timestamp: DateTime.now(),
          durationSeconds: durationSeconds,
          volumeMl: estimatedVolumeMl,
          batteryPercentage: _deviceStatus.batteryPercentage,
          isSolarCharging: _deviceStatus.isSolarCharging,
          mode: mode,
          status: 'Success',
          communicationMethod: 'BLE',
        );
        await dbHelper.insertLog(log);
      } else {
        _deviceStatus = _deviceStatus.copyWith(activeDurationSeconds: remaining);
        notifyListeners();
      }
    });
  }

  void stopSpraying() {
    _sprayTimer?.cancel();
    
    // Send STOP command via BLE to ESP32
    _sendBleMessage({'cmd': 'STOP'});
    
    _deviceStatus = _deviceStatus.copyWith(
      isPumpRunning: false,
      activeDurationSeconds: 0,
    );
    notifyListeners();
  }

  void sendConfiguration(DeviceConfig config) {
    if (!_isConnected) return;
    
    _sendBleMessage({
      'cmd': 'CONFIG',
      'ssid': config.ssid,
      'password': config.password,
      'sprayDuration': config.sprayDurationSeconds,
      'mqttEnabled': config.mqttEnabled,
    });
    
    if (kDebugMode) {
      print('Config sent to ESP32: ${config.toJson()}');
    }
  }

  void syncSchedules(List<SpraySchedule> schedules) {
    if (!_isConnected) return;

    final payload = {
      'cmd': 'SCHEDULE',
      'schedules': schedules.map((s) => {
        'id': s.id,
        'hour': s.hour,
        'minute': s.minute,
        'duration': s.durationSeconds,
        'active': s.isActive ? 1 : 0
      }).toList()
    };
    
    _sendBleMessage(payload);
    
    if (kDebugMode) {
      print('Schedules synced to ESP32 via BLE: $payload');
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _connectionSubscription?.cancel();
    _notifySubscription?.cancel();
    _sprayTimer?.cancel();
    super.dispose();
  }
}
