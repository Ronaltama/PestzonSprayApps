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
      timestamp: DateTime.parse(map['timestamp'] as String),
      durationSeconds: map['durationSeconds'] as int,
      volumeMl: (map['volumeMl'] as num).toDouble(),
      batteryPercentage: map['batteryPercentage'] as int,
      isSolarCharging: (map['isSolarCharging'] as int) == 1,
      mode: map['mode'] as String? ?? 'Manual',
      status: map['status'] as String? ?? 'Success',
      communicationMethod: map['communicationMethod'] as String? ?? 'BLE',
      deviceKey: map['device_key'] as String?,
    );
  }
}
