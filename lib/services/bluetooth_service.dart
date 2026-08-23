import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/device_status.dart';
import '../models/spray_log.dart';
import '../models/spray_schedule.dart';
import '../models/device_config.dart';
import 'database_helper.dart';

class BluetoothService extends ChangeNotifier {
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String _connectedDeviceName = 'Tidak Terhubung';
  String get connectedDeviceName => _connectedDeviceName;

  DeviceStatus _deviceStatus = DeviceStatus();
  DeviceStatus get deviceStatus => _deviceStatus;

  Timer? _sprayTimer;

  // List of discovered devices
  List<ScanResult> _scanResults = [];
  List<ScanResult> get scanResults => _scanResults;
  
  // Mock devices for unsupported platforms (Linux/Windows)
  List<String> _mockFoundDevices = [];
  List<String> get mockFoundDevices => _mockFoundDevices;

  BluetoothDevice? _connectedDevice;

  void startScan() async {
    _isScanning = true;
    _mockFoundDevices = [];
    _scanResults = [];
    notifyListeners();

    // Check if platform is supported by flutter_blue_plus
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      try {
        // Stop any existing scan
        await FlutterBluePlus.stopScan();
        
        // Listen to scan results
        FlutterBluePlus.scanResults.listen((results) {
          _scanResults = results;
          notifyListeners();
        });

        // Start scanning
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
        
        // Wait for scan to finish
        await Future.delayed(const Duration(seconds: 4));
      } catch (e) {
        if (kDebugMode) {
          print('Error scanning BLE: $e');
        }
      }
    } else {
      // Simulate scanning for Unsupported Platforms (Linux, Windows, Web)
      await Future.delayed(const Duration(seconds: 2));
      _mockFoundDevices = [
        'ESP32_SmartSprayer_01',
        'ESP32_Sprayer_Solar_02',
        'ESP32_Pump_Misting',
      ];
    }
    
    _isScanning = false;
    notifyListeners();
  }

  void connectToDevice(String deviceName, {BluetoothDevice? device}) async {
    _connectedDeviceName = 'Connecting...';
    notifyListeners();

    if (device != null) {
      try {
        await device.connect();
        _connectedDevice = device;
        _connectedDeviceName = device.platformName.isNotEmpty ? device.platformName : 'Unknown ESP32';
      } catch (e) {
        if (kDebugMode) {
          print('Failed to connect: $e');
        }
        _connectedDeviceName = 'Gagal Terhubung';
        notifyListeners();
        return;
      }
    } else {
      // Mock Connection
      await Future.delayed(const Duration(seconds: 1));
      _connectedDeviceName = deviceName;
    }

    _isConnected = true;
    _deviceStatus = _deviceStatus.copyWith(
      connectionState: 'Connected (BLE)',
      batteryPercentage: 88,
      batteryVoltage: 4.1,
      isSolarCharging: true,
    );
    notifyListeners();
  }

  void disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
    }
    
    _isConnected = false;
    _connectedDeviceName = 'Tidak Terhubung';
    _deviceStatus = _deviceStatus.copyWith(connectionState: 'Disconnected');
    notifyListeners();
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

    // In a real app, send start command via BLE here
    
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
    // In a real app, send stop command via BLE here
    
    _deviceStatus = _deviceStatus.copyWith(
      isPumpRunning: false,
      activeDurationSeconds: 0,
    );
    notifyListeners();
  }

  void sendConfiguration(DeviceConfig config) {
    if (!_isConnected) return;
    
    // In a real app, you would send this to the ESP32 via BLE Characteristics
    // e.g., bleCharacteristic.write(config.toJson().toString().codeUnits);
    
    if (kDebugMode) {
      print('Config sent to ESP32: ${config.toJson()}');
    }
  }

  void syncSchedules(List<SpraySchedule> schedules) {
    if (!_isConnected) return;

    final payload = {
      'action': 'sync_schedule',
      'schedules': schedules.map((s) => {
        'id': s.id,
        'hour': s.hour,
        'minute': s.minute,
        'duration': s.durationSeconds,
        'active': s.isActive ? 1 : 0
      }).toList()
    };
    
    // In a real app, send via BLE Characteristics
    if (kDebugMode) {
      print('Schedules synced to ESP32 via BLE: $payload');
    }
  }
}
