class DeviceConfig {
  String ssid;
  String password;
  bool mqttEnabled;
  int sprayDurationSeconds;

  DeviceConfig({
    required this.ssid,
    required this.password,
    this.mqttEnabled = false,
    this.sprayDurationSeconds = 30,
  });

  Map<String, dynamic> toJson() {
    return {
      'ssid': ssid,
      'password': password,
      'mqtt_enabled': mqttEnabled ? 1 : 0,
      'spray_duration': sprayDurationSeconds,
    };
  }

  factory DeviceConfig.fromJson(Map<String, dynamic> json) {
    return DeviceConfig(
      ssid: json['ssid'] ?? '',
      password: json['password'] ?? '',
      mqttEnabled: json['mqtt_enabled'] == 1 || json['mqtt_enabled'] == true,
      sprayDurationSeconds: json['spray_duration'] ?? 30,
    );
  }
}
