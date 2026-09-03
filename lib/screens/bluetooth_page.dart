import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../services/bluetooth_service.dart';
import '../services/mqtt_service.dart';
import '../services/theme_provider.dart';
import '../models/device_config.dart';
import '../theme/theme.dart';
import '../utils/app_notification.dart';

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  int _selectedModeIndex = 0; // 0: Bluetooth (BLE), 1: Cloud (MQTT & WiFi)

  final _deviceIdController = TextEditingController(text: 'SPRAYER-001');
  final _ssidController = TextEditingController();
  final _pwdController = TextEditingController();
  double _sprayDuration = 30.0;

  @override
  void dispose() {
    _deviceIdController.dispose();
    _ssidController.dispose();
    _pwdController.dispose();
    super.dispose();
  }

  void _syncConfigToBle(BluetoothService btService) {
    final config = DeviceConfig(
      ssid: _ssidController.text.trim(),
      password: _pwdController.text.trim(),
      mqttEnabled: true,
      sprayDurationSeconds: _sprayDuration.toInt(),
    );
    btService.sendConfiguration(config);
    AppNotification.show(context, 'Konfigurasi WiFi dikirim ke ESP32 via BLE!');
  }

  void _connectMqtt(MqttService mqttService) {
    final devId = _deviceIdController.text.trim();
    if (devId.isEmpty) {
      AppNotification.show(context, 'Kode Perangkat tidak boleh kosong!', isError: true);
      return;
    }
    mqttService.setDeviceId(devId);
    mqttService.connect();
    AppNotification.show(context, 'Menghubungkan ke Perangkat $devId via Cloud...');
  }

  @override
  Widget build(BuildContext context) {
    final btService = Provider.of<BluetoothService>(context);
    final mqttService = Provider.of<MqttService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final primaryAccent = isDark ? ThemeProvider.greenAccentColor : AppTheme.primaryColor;
    final cardBg = isDark ? ThemeProvider.darkCardColor : Colors.white;
    final titleColor = isDark ? Colors.white : AppTheme.textDark;

    return Scaffold(
      backgroundColor: isDark ? ThemeProvider.darkBgColor : const Color(0xFFF6F8F6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLG,
            vertical: AppTheme.spacingMD,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? primaryAccent : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.memory, color: isDark ? ThemeProvider.blackColor : AppTheme.primaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Koneksi & Setup',
                        style: TextStyle(fontFamily: 'Utendo', fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Manajemen Perangkat',
                        style: TextStyle(
                          fontFamily: 'Utendo',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingLG),

              // Mode Connection Selector (Segmented Bar)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedModeIndex = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedModeIndex == 0 ? (isDark ? primaryAccent : Colors.white) : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: (_selectedModeIndex == 0 && !isDark) ? AppTheme.shadowSM : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bluetooth,
                                size: 18,
                                color: _selectedModeIndex == 0
                                    ? (isDark ? ThemeProvider.blackColor : AppTheme.primaryColor)
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Mode BLE (Lokal)',
                                style: TextStyle(
                                  fontFamily: 'Utendo',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _selectedModeIndex == 0
                                      ? (isDark ? ThemeProvider.blackColor : AppTheme.textDark)
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedModeIndex = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedModeIndex == 1 ? (isDark ? primaryAccent : Colors.white) : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: (_selectedModeIndex == 1 && !isDark) ? AppTheme.shadowSM : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud,
                                size: 18,
                                color: _selectedModeIndex == 1
                                    ? (isDark ? ThemeProvider.blackColor : AppTheme.primaryColor)
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Mode Cloud (Internet)',
                                style: TextStyle(
                                  fontFamily: 'Utendo',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _selectedModeIndex == 1
                                      ? (isDark ? ThemeProvider.blackColor : AppTheme.textDark)
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingXL),

              // CONTENT TAB 0: BLUETOOTH (BLE)
              if (_selectedModeIndex == 0) ...[
                _buildBleSection(context, btService, isDark, cardBg, primaryAccent, titleColor),
              ],

              // CONTENT TAB 1: CLOUD (MQTT & WIFI)
              if (_selectedModeIndex == 1) ...[
                _buildCloudSection(context, mqttService, btService, isDark, cardBg, primaryAccent, titleColor),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- BLE SECTION ---
  Widget _buildBleSection(BuildContext context, BluetoothService btService, bool isDark, Color cardBg, Color primaryAccent, Color titleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!btService.isBluetoothOn)
          Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706)),
            ),
            child: Row(
              children: [
                Icon(Icons.bluetooth_disabled, color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bluetooth HP Anda mati. Aktifkan untuk memindai.',
                    style: TextStyle(
                      fontFamily: 'Utendo',
                      color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => btService.turnOnBluetooth(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Nyalakan',
                    style: TextStyle(
                      fontFamily: 'Utendo',
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFB45309),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: btService.isConnected
                ? (isDark ? primaryAccent : const Color(0xFFDCFCE7))
                : cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark ? [] : AppTheme.shadowSM,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: btService.isConnected
                      ? (isDark ? ThemeProvider.blackColor : AppTheme.primaryColor)
                      : const Color(0xFF2C2D30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  btService.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: btService.isConnected ? Colors.white : Colors.grey.shade400,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      btService.isConnected ? 'Terhubung via BLE' : 'Bluetooth Terputus',
                      style: TextStyle(
                        fontFamily: 'Utendo',
                        fontSize: 11,
                        color: btService.isConnected
                            ? (isDark ? ThemeProvider.blackColor : const Color(0xFF15803D))
                            : Colors.grey.shade400,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      btService.connectedDeviceName,
                      style: TextStyle(
                        fontFamily: 'Utendo',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: btService.isConnected && isDark ? ThemeProvider.blackColor : titleColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (btService.isConnected)
                OutlinedButton(
                  onPressed: () => btService.disconnect(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: const BorderSide(color: AppTheme.errorColor),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Putuskan', style: TextStyle(fontFamily: 'Utendo', fontSize: 12)),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingLG),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pindai Perangkat Terdekat',
              style: TextStyle(fontFamily: 'Utendo', fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
            ),
            IconButton(
              tooltip: 'Pindai Ulang BLE',
              onPressed: btService.isScanning ? null : () => btService.startScan(),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? primaryAccent : const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: btService.isScanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: ThemeProvider.blackColor),
                      )
                    : Icon(
                        Icons.refresh_rounded,
                        size: 20,
                        color: isDark ? ThemeProvider.blackColor : AppTheme.primaryColor,
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Dynamic combining of active system devices (ready to connect) and live scan results
        () {
          final List<dynamic> allDevices = [];

          // 1. Add active unbonded / ready-to-connect system devices
          for (var sysDev in btService.systemDevices) {
            allDevices.add(sysDev);
          }

          // 2. Add active live BLE scan results (avoiding duplicates)
          for (var sr in btService.scanResults) {
            bool alreadyAdded = allDevices.any((d) {
              if (d is fbp.BluetoothDevice) {
                return d.remoteId == sr.device.remoteId;
              }
              if (d is fbp.ScanResult) {
                return d.device.remoteId == sr.device.remoteId;
              }
              return false;
            });
            if (!alreadyAdded) {
              allDevices.add(sr);
            }
          }

          if (allDevices.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  btService.isScanning
                      ? 'Memindai perangkat Bluetooth di sekitar...'
                      : 'Tidak ada perangkat aktif ditemukan. Pastikan ESP32 dalam keadaan menyala dan tekan tombol pindaian di kanan atas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Utendo', color: isDark ? Colors.grey.shade400 : Colors.grey, fontSize: 13),
                ),
              ),
            );
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allDevices.length,
            itemBuilder: (context, index) {
              String devName;
              fbp.BluetoothDevice deviceObj;
              int? rssi;

              final item = allDevices[index];
              if (item is fbp.ScanResult) {
                deviceObj = item.device;
                rssi = item.rssi;
                devName = deviceObj.platformName.isNotEmpty 
                    ? deviceObj.platformName 
                    : (item.advertisementData.advName.isNotEmpty 
                        ? item.advertisementData.advName 
                        : deviceObj.remoteId.str);
              } else if (item is fbp.BluetoothDevice) {
                deviceObj = item;
                devName = deviceObj.platformName.isNotEmpty 
                    ? deviceObj.platformName 
                    : deviceObj.remoteId.str;
              } else {
                return const SizedBox.shrink();
              }

              final isThisConnected = btService.isConnected && (
                btService.connectedDeviceName == devName ||
                btService.connectedDeviceName == deviceObj.platformName ||
                btService.connectedDeviceName == deviceObj.remoteId.str
              );

              String subtitleText;
              if (isThisConnected) {
                subtitleText = 'Status: Terhubung';
              } else if (rssi != null) {
                subtitleText = 'Ready to Connect (Sinyal: $rssi dBm)';
              } else {
                subtitleText = 'Ready to Connect (${deviceObj.remoteId.str})';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: isDark ? [] : AppTheme.shadowSM,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isThisConnected
                            ? (isDark ? primaryAccent : const Color(0xFFDCFCE7))
                            : (isDark ? const Color(0xFF2C2D30) : const Color(0xFFF3F4F6)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.bluetooth,
                        color: isThisConnected
                            ? (isDark ? ThemeProvider.blackColor : AppTheme.primaryColor)
                            : Colors.grey,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            devName,
                            style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, fontSize: 15, color: titleColor),
                          ),
                          Text(
                            subtitleText,
                            style: TextStyle(
                              fontFamily: 'Utendo',
                              fontSize: 12,
                              color: isThisConnected ? primaryAccent : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: (isThisConnected || btService.isConnecting)
                          ? null
                          : () {
                              btService.connectToDevice(devName, device: deviceObj);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryAccent,
                        foregroundColor: isDark ? ThemeProvider.blackColor : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        isThisConnected
                            ? 'Terhubung'
                            : (btService.isConnecting && btService.connectedDeviceName == 'Connecting...' ? 'Menghubungkan...' : 'Sambungkan'),
                        style: const TextStyle(fontFamily: 'Utendo'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }(),
      ],
    );
  }

  // --- CLOUD SECTION ---
  Widget _buildCloudSection(BuildContext context, MqttService mqttService, BluetoothService btService, bool isDark, Color cardBg, Color primaryAccent, Color titleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: mqttService.isConnected && mqttService.isEspOnline
                ? (isDark ? primaryAccent : const Color(0xFFDBEAFE))
                : cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark ? [] : AppTheme.shadowSM,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mqttService.isConnected && mqttService.isEspOnline
                      ? (isDark ? ThemeProvider.blackColor : const Color(0xFF1D4ED8))
                      : const Color(0xFF2C2D30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  mqttService.isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: mqttService.isConnected ? Colors.white : Colors.grey.shade400,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mqttService.isConnected && mqttService.isEspOnline
                          ? 'Terhubung via Cloud MQTT'
                          : 'Koneksi Cloud Terputus',
                      style: TextStyle(
                        fontFamily: 'Utendo',
                        fontSize: 11,
                        color: mqttService.isConnected && mqttService.isEspOnline
                            ? (isDark ? ThemeProvider.blackColor : const Color(0xFF1E40AF))
                            : Colors.grey.shade400,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Perangkat ${mqttService.deviceId}',
                      style: TextStyle(
                        fontFamily: 'Utendo',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: mqttService.isConnected && mqttService.isEspOnline && isDark ? ThemeProvider.blackColor : titleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingLG),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(28),
            boxShadow: isDark ? [] : AppTheme.shadowSM,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Konfigurasi Cloud MQTT',
                style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, fontSize: 16, color: titleColor),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _deviceIdController,
                style: TextStyle(fontFamily: 'Utendo', color: titleColor),
                decoration: const InputDecoration(
                  labelText: 'Kode ID Perangkat (e.g. SPRAYER-001)',
                  prefixIcon: Icon(Icons.perm_identity),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _connectMqtt(mqttService),
                  icon: Icon(Icons.cloud_sync, color: isDark ? ThemeProvider.blackColor : Colors.white),
                  label: Text('Hubungkan ke Cloud', style: TextStyle(fontFamily: 'Utendo', color: isDark ? ThemeProvider.blackColor : Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingLG),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(28),
            boxShadow: isDark ? [] : AppTheme.shadowSM,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kirim Konfigurasi WiFi via BLE',
                style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, fontSize: 16, color: titleColor),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ssidController,
                style: TextStyle(fontFamily: 'Utendo', color: titleColor),
                decoration: const InputDecoration(
                  labelText: 'Nama WiFi (SSID)',
                  prefixIcon: Icon(Icons.wifi),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pwdController,
                obscureText: true,
                style: TextStyle(fontFamily: 'Utendo', color: titleColor),
                decoration: const InputDecoration(
                  labelText: 'Password WiFi',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: btService.isConnected ? () => _syncConfigToBle(btService) : null,
                  icon: const Icon(Icons.send),
                  label: const Text('Kirim ke ESP32 via BLE', style: TextStyle(fontFamily: 'Utendo')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryAccent,
                    foregroundColor: isDark ? ThemeProvider.blackColor : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
