class DeviceStatus {
  final int batteryPercentage;
  final double batteryVoltage;
  final bool isSolarCharging;
  final bool isPumpRunning;
  final int activeDurationSeconds;
  final int totalSesiToday;
  final double totalVolumeTodayMl;
  final String connectionState; // 'Connected (BLE)', 'Connected (MQTT)', 'Disconnected'

  DeviceStatus({
    this.batteryPercentage = 85,
    this.batteryVoltage = 4.1,
    this.isSolarCharging = true,
    this.isPumpRunning = false,
    this.activeDurationSeconds = 0,
    this.totalSesiToday = 0,
    this.totalVolumeTodayMl = 0.0,
    this.connectionState = 'Disconnected',
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      batteryPercentage: (json['battery'] ?? 85) as int,
      batteryVoltage: (json['voltage'] ?? 4.1).toDouble(),
      isSolarCharging: json['isSolar'] ?? true,
      isPumpRunning: json['isPumpRunning'] ?? false,
      activeDurationSeconds: json['durationSec'] ?? 0,
      totalSesiToday: json['totalSesi'] ?? 0,
      totalVolumeTodayMl: (json['totalVolume'] ?? 0.0).toDouble(),
      connectionState: json['connState'] ?? 'Disconnected',
    );
  }

  DeviceStatus copyWith({
    int? batteryPercentage,
    double? batteryVoltage,
    bool? isSolarCharging,
    bool? isPumpRunning,
    int? activeDurationSeconds,
    int? totalSesiToday,
    double? totalVolumeTodayMl,
    String? connectionState,
  }) {
    return DeviceStatus(
      batteryPercentage: batteryPercentage ?? this.batteryPercentage,
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
      isSolarCharging: isSolarCharging ?? this.isSolarCharging,
      isPumpRunning: isPumpRunning ?? this.isPumpRunning,
      activeDurationSeconds: activeDurationSeconds ?? this.activeDurationSeconds,
      totalSesiToday: totalSesiToday ?? this.totalSesiToday,
      totalVolumeTodayMl: totalVolumeTodayMl ?? this.totalVolumeTodayMl,
      connectionState: connectionState ?? this.connectionState,
    );
  }
}