import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/device_status.dart';
import '../models/spray_log.dart';
import '../models/spray_schedule.dart';
import '../models/device_config.dart';
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

  // Dynamic Topics
  String get topicStatus => 'sprayer/$_deviceId/status';
  String get topicCommand => 'sprayer/$_deviceId/command';
  String get topicConfig => 'sprayer/$_deviceId/config';
  String get topicLog => 'sprayer/$_deviceId/log';

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
    debugPrint('Subscribed to $topicStatus & $topicLog');
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

  void disconnect() {
    _cancelReconnectTimer();
    client.disconnect();
    // _statusStreamController.close(); // Don't close if we want to reuse the service
  }
}
