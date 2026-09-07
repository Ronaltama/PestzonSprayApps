import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/device_status.dart';
import '../models/spray_log.dart';
import '../models/spray_schedule.dart';
import '../models/device_config.dart';
import '../models/device_ack.dart';
import '../models/daily_volume_stat.dart';
import 'database_helper.dart';

class MqttService extends ChangeNotifier {
  late MqttServerClient client;
  final String broker = 'broker.emqx.io';
  final int port = 1883;
  final String clientIdentifier =
      'SmartSprayerApp_${DateTime.now().millisecondsSinceEpoch}';

  String _deviceId = 'SPRAYER-001'; // Default device ID
  String get deviceId => _deviceId;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  DeviceStatus? _latestStatus;
  DateTime? _lastStatusTime;
  DeviceStatus? get latestStatus => _latestStatus;
  
  bool get isEspOnline =>
      _lastStatusTime != null &&
      DateTime.now().difference(_lastStatusTime!).inSeconds < 30;

  final _statusStreamController = StreamController<DeviceStatus>.broadcast();
  Stream<DeviceStatus> get statusStream => _statusStreamController.stream;

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

  // Dynamic Topics
  String get topicStatus => 'sprayer/$_deviceId/status';
  String get topicCommand => 'sprayer/$_deviceId/command';
  String get topicConfig => 'sprayer/$_deviceId/config';
  String get topicLog => 'sprayer/$_deviceId/log';
  String get topicRequest => 'sprayer/$_deviceId/request';
  String get topicResponse => 'sprayer/$_deviceId/response';

  // Untuk reconnection logic
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _reconnectInterval = Duration(seconds: 5);
  
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  MqttService() {
    _initClient();
  }

  void _initClient() {
    client = MqttServerClient(broker, clientIdentifier);
    client.port = port;
    client.useWebSocket = false;
    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.onDisconnected = _onDisconnected;
    client.onConnected = _onConnected;
    client.onSubscribed = _onSubscribed;
    client.pongCallback = _pong;
  }

  void setDeviceId(String newId) {
    _deviceId = newId;
    if (_isConnected) {
      // Re-subscribe to new topics
      client.unsubscribe('sprayer/+/status');
      client.unsubscribe('sprayer/+/log');
      client.unsubscribe('sprayer/+/response');
      _subscribeToTopics();
    }
  }

  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;
    _reconnectAttempts = 0;
    notifyListeners();
    
    debugPrint('Connecting to MQTT broker...');
    try {
      await client.connect();
    } catch (e) {
      debugPrint('Connection Exception: $e');
      _isConnected = false;
      _isConnecting = false;
      notifyListeners();
      _scheduleReconnect();
      return;
    }
    _isConnecting = false;
    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      debugPrint('MQTT connected');
      _isConnected = true;
      _reconnectAttempts = 0;
      client.updates!.listen(_onMessage); // Attach listener once connected
      notifyListeners();
      _subscribeToTopics();
    } else {
      debugPrint('Connection failed - disconnecting');
      client.disconnect();
      _isConnected = false;
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void _subscribeToTopics() {
    if (!_isConnected) return;
    client.subscribe(topicStatus, MqttQos.atLeastOnce);
    client.subscribe(topicLog, MqttQos.atLeastOnce);
    client.subscribe(topicResponse, MqttQos.atLeastOnce);
    debugPrint('Subscribed to $topicStatus, $topicLog & $topicResponse');
  }

  void _onConnected() {
    debugPrint('Connected to broker');
    _isConnected = true;
    _reconnectAttempts = 0;
    _cancelReconnectTimer();
    notifyListeners();
  }

  void _onDisconnected() {
    debugPrint('Disconnected');
    _isConnected = false;
    _isConnecting = false;
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _cancelReconnectTimer();
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      debugPrint(
        'Scheduling reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts in ${_reconnectInterval.inSeconds}s',
      );
      _reconnectTimer = Timer(_reconnectInterval, () {
        if (!_isConnected && !_isConnecting) {
          connect();
        }
      });
    } else {
      debugPrint('Max reconnect attempts reached');
    }
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _onSubscribed(String topic) {
    debugPrint('Subscribed to $topic');
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    final recMessage = messages[0].payload as MqttPublishMessage;
    final topic = messages[0].topic;
    final payload = MqttPublishPayload.bytesToStringAsString(
      recMessage.payload.message,
    );

    debugPrint('Received on $topic: $payload');

    if (topic == topicStatus) {
      try {
        final jsonData = jsonDecode(payload);
        final status = DeviceStatus.fromJson(jsonData);
        // Add MQTT connection state info
        _latestStatus = status.copyWith(connectionState: 'Connected (MQTT)');
        _lastStatusTime = DateTime.now();
        _statusStreamController.add(_latestStatus!);
        notifyListeners();
      } catch (e) {
        debugPrint('JSON parse error on status: $e');
      }
    } else if (topic == topicLog) {
      try {
        final jsonData = jsonDecode(payload);
        final log = SprayLog.fromMap(jsonData);
        // Save log to local SQLite when received via MQTT
        _dbHelper.insertLog(log);
      } catch (e) {
        debugPrint('JSON parse error on log: $e');
      }
    } else if (topic == topicResponse) {
      try {
        final jsonData = jsonDecode(payload);
        if (jsonData is Map<String, dynamic>) {
          _handleEnvelope(jsonData);
        }
      } catch (e) {
        debugPrint('JSON parse error on response: $e');
      }
    }
  }

  /// Proses envelope request/response sesuai kontrak perangkat.
  void _handleEnvelope(Map<String, dynamic> jsonData) {
    final t = jsonData['t'];
    switch (t) {
      case 'summary':
        final status = DeviceStatus.fromJson(jsonData)
            .copyWith(connectionState: 'Connected (MQTT)');
        _latestStatus = status;
        _lastStatusTime = DateTime.now();
        _summaryStreamController.add(status);
        _statusStreamController.add(status);
        notifyListeners();
      case 'stats':
        final days = DailyVolumeStat.listFromStatsPayload(jsonData);
        _statsStreamController.add(days);
      case 'schedules':
        final schedules =
            SpraySchedule.listFromDevicePayload(jsonData['schedules'] as List? ?? const []);
        _schedulesStreamController.add(schedules);
      case 'ack':
        _ackStreamController.add(DeviceAck.fromJson(jsonData));
      default:
        debugPrint('Unhandled envelope type: $t');
    }
  }

  void _pong() => debugPrint('Pong received');

  void publishCommand(String topic, Map<String, dynamic> command) {
    if (!_isConnected) {
      debugPrint('Not connected');
      return;
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(command));
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    debugPrint('Published to $topic: ${jsonEncode(command)}');
  }

  // Action: Spray
  void startSpraying({required int durationSeconds}) {
    publishCommand(topicCommand, {
      'action': 'spray',
      'duration': durationSeconds,
    });
  }

  void stopSpraying() {
    publishCommand(topicCommand, {
      'action': 'stop',
    });
  }
  
  void sendConfiguration(DeviceConfig config) {
    publishCommand(topicConfig, config.toJson());
  }

  void sendCalibration({required double flowRate}) {
    publishCommand(topicCommand, {
      'v': 1,
      'cmd': 'set_calibration',
      'flowRate': flowRate,
    });
  }

  void syncSchedules(List<SpraySchedule> schedules) {
    if (!_isConnected) {
      debugPrint('Not connected, cannot sync schedules');
      return;
    }
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
    publishCommand(topicConfig, payload);
    debugPrint('Schedules synced via MQTT');
  }

  // ---- Request/Response (kontrak perangkat baru) ----

  void _publishRequest(Map<String, dynamic> payload) {
    publishCommand(topicRequest, payload);
  }

  /// Minta ringkasan hari ini dari ESP (volume, sesi, baterai, dll).
  void requestSummary() {
    _publishRequest({'v': 1, 't': 'get_summary'});
  }

  /// Minta statistik volume per hari pada rentang tanggal (inklusif).
  void requestStats({required DateTime from, required DateTime to}) {
    _publishRequest({
      'v': 1,
      't': 'get_stats',
      'from': DailyVolumeStat.formatDate(from),
      'to': DailyVolumeStat.formatDate(to),
    });
  }

  /// Minta daftar jadwal semprot yang tersimpan di ESP.
  void requestSchedules() {
    _publishRequest({'v': 1, 't': 'get_schedules'});
  }

  /// Tulis daftar jadwal penuh ke ESP (tambah/hapus/nyalakan/matikan).
  void pushSchedules(List<SpraySchedule> schedules) {
    _publishRequest({
      'v': 1,
      't': 'set_schedules',
      'schedules': schedules.map((s) => s.toDeviceJson()).toList(),
    });
  }

  void disconnect() {
    _cancelReconnectTimer();
    client.disconnect();
    // _statusStreamController.close(); // Don't close if we want to reuse the service
  }
}
