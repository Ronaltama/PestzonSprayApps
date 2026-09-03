import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../models/device_status.dart';
import '../models/spray_log.dart';
import '../models/spray_schedule.dart';
import '../models/device_config.dart';
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
    if (!kIsWeb) {
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

  void connectToDevice(String deviceName, {required fbp.BluetoothDevice device}) async {
    _isConnecting = true;
    _connectedDeviceName = 'Connecting...';
    notifyListeners();

    try {
      // Stop scan and let bluetooth controller settle
      await stopScan();
      await Future.delayed(const Duration(milliseconds: 100));

      // Instant direct connection (autoConnect: false)
      await device.connect(timeout: const Duration(seconds: 5), autoConnect: false);
      _connectedDevice = device;
      _connectedDeviceName = device.platformName.isNotEmpty ? device.platformName : device.remoteId.str;

      // Monitor connection state
      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == fbp.BluetoothConnectionState.disconnected) {
          _onDisconnected();
        }
      });

      // Discover services
      List<fbp.BluetoothService> services = await device.discoverServices();
      _setupCharacteristics(services);

      _isConnected = true;
      _isConnecting = false;
      _deviceStatus = _deviceStatus.copyWith(
        connectionState: 'Connected (BLE)',
        batteryPercentage: 90,
        batteryVoltage: 4.15,
        isSolarCharging: true,
      );
      notifyListeners();
      return;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to connect to BLE device: $e');
      }
      final errStr = e.toString();
      if (errStr.contains('ProfileUnavailable') || errStr.contains('BREDR')) {
        _onDisconnected(customMessage: 'Gagal: Gunakan Firmware ESP32 BLE');
      } else {
        _onDisconnected(customMessage: 'Gagal Terhubung');
      }
      return;
    }
  }

  void _setupCharacteristics(List<fbp.BluetoothService> services) async {
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

  void _handleIncomingData(List<int> data) {
    try {
      final message = utf8.decode(data);
      if (kDebugMode) print('BLE Received: $message');
      
      final json = jsonDecode(message);
      if (json is Map<String, dynamic>) {
        _deviceStatus = _deviceStatus.copyWith(
          batteryPercentage: json['battery'] ?? _deviceStatus.batteryPercentage,
          batteryVoltage: (json['voltage'] as num?)?.toDouble() ?? _deviceStatus.batteryVoltage,
          isSolarCharging: json['solar'] ?? _deviceStatus.isSolarCharging,
          isPumpRunning: json['pump'] ?? _deviceStatus.isPumpRunning,
        );
        notifyListeners();
      }
    } catch (_) {
      // Non-JSON or raw text notification
    }
  }

  void _sendBleMessage(Map<String, dynamic> payload) async {
    if (_rxCharacteristic != null) {
      try {
        final jsonStr = jsonEncode(payload);
        final bytes = utf8.encode(jsonStr);
        await _rxCharacteristic!.write(bytes, withoutResponse: _rxCharacteristic!.properties.writeWithoutResponse);
        if (kDebugMode) print('Sent BLE bytes: $jsonStr');
      } catch (e) {
        if (kDebugMode) print('Error writing BLE characteristic: $e');
      }
    }
  }

  void _onDisconnected({String customMessage = 'Tidak Terhubung'}) {
    _notifySubscription?.cancel();
    _connectionSubscription?.cancel();
    _connectedDevice = null;
    _rxCharacteristic = null;
    _txCharacteristic = null;
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
        
        // Pump stops
        final estimatedVolumeMl = durationSeconds * 5.0; // 5 ml/detik debit pompa misting
        final newTotalSesi = _deviceStatus.totalSesiToday + 1;
        final newTotalVolume = _deviceStatus.totalVolumeTodayMl + estimatedVolumeMl;

        _deviceStatus = _deviceStatus.copyWith(
          isPumpRunning: false,
          activeDurationSeconds: 0,
          totalSesiToday: newTotalSesi,
          totalVolumeTodayMl: newTotalVolume,
        );
        notifyListeners();

        // SIMPAN KE DATABASE LOKAL HP (SQLite)
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
