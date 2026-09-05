class SprayLog {
  final int? id;
  final DateTime timestamp;
  final int durationSeconds;
  final double volumeMl;
  final int batteryPercentage;
  final bool isSolarCharging;
  final String mode; // 'Manual' or 'Auto Schedule'
  final String status; // 'Success', 'Failed'
  final String communicationMethod; // 'BLE', 'MQTT', 'Local'

  /// Identitas perangkat pemilik log (MAC / `device_key` pada DB). Dipakai
  /// untuk menghimpun riwayat per perangkat (M2). Kosong/null berarti legacy
  /// & akan disimpan sebagai `'default'`.
  final String? deviceKey;

  SprayLog({
    this.id,
    required this.timestamp,
    required this.durationSeconds,
    required this.volumeMl,
    required this.batteryPercentage,
    required this.isSolarCharging,
    required this.mode,
    required this.status,
    required this.communicationMethod,
    this.deviceKey,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'durationSeconds': durationSeconds,
      'volumeMl': volumeMl,
      'batteryPercentage': batteryPercentage,
      'isSolarCharging': isSolarCharging ? 1 : 0,
      'mode': mode,
      'status': status,
      'communicationMethod': communicationMethod,
      'device_key': deviceKey ?? 'default',
    };
  }

  factory SprayLog.fromMap(Map<String, dynamic> map) {
    return SprayLog(
      id: map['id'] as int?,
      timestamp: map['timestamp'] != null && (map['timestamp'] as String).isNotEmpty
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      volumeMl: (map['volumeMl'] as num?)?.toDouble() ?? 0.0,
      batteryPercentage: (map['batteryPercentage'] as num?)?.toInt() ?? 0,
      isSolarCharging: map['isSolarCharging'] == 1 || map['isSolarCharging'] == true,
      mode: map['mode'] as String? ?? 'Manual',
      status: map['status'] as String? ?? 'Success',
      communicationMethod: map['communicationMethod'] as String? ?? 'BLE',
      deviceKey: map['device_key'] as String?,
    );
  }

  SprayLog copyWith({
    int? id,
    DateTime? timestamp,
    int? durationSeconds,
    double? volumeMl,
    int? batteryPercentage,
    bool? isSolarCharging,
    String? mode,
    String? status,
    String? communicationMethod,
    String? deviceKey,
  }) {
    return SprayLog(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      volumeMl: volumeMl ?? this.volumeMl,
      batteryPercentage: batteryPercentage ?? this.batteryPercentage,
      isSolarCharging: isSolarCharging ?? this.isSolarCharging,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      communicationMethod: communicationMethod ?? this.communicationMethod,
      deviceKey: deviceKey ?? this.deviceKey,
    );
  }
}
