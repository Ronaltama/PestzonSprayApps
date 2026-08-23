import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../services/mqtt_service.dart';
import '../models/device_config.dart';
import '../theme/theme.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Konfigurasi WiFi dikirim ke ESP32 via BLE!')),
    );
  }

  void _connectMqtt(MqttService mqttService) {
    final devId = _deviceIdController.text.trim();
    if (devId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode Perangkat tidak boleh kosong!')),
      );
      return;
    }
    mqttService.setDeviceId(devId);
    mqttService.connect();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Menghubungkan ke Perangkat $devId via Cloud...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final btService = Provider.of<BluetoothService>(context);
    final mqttService = Provider.of<MqttService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F6),
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
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.memory, color: AppTheme.primaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Koneksi & Setup',
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Manajemen Perangkat',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
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
                  color: const Color(0xFFE5E7EB),
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
                            color: _selectedModeIndex == 0 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _selectedModeIndex == 0 ? AppTheme.shadowSM : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bluetooth,
                                size: 18,
                                color: _selectedModeIndex == 0 ? AppTheme.primaryColor : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Mode BLE (Lokal)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _selectedModeIndex == 0 ? AppTheme.textDark : Colors.grey,
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
                            color: _selectedModeIndex == 1 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _selectedModeIndex == 1 ? AppTheme.shadowSM : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud,
                                size: 18,
                                color: _selectedModeIndex == 1 ? AppTheme.primaryColor : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Mode Cloud (Internet)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _selectedModeIndex == 1 ? AppTheme.textDark : Colors.grey,
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
                _buildBleSection(context, btService),
              ],

              // CONTENT TAB 1: CLOUD (MQTT & WIFI)
              if (_selectedModeIndex == 1) ...[
                _buildCloudSection(context, mqttService, btService),
              ],

              const SizedBox(height: AppTheme.spacingXL),

              // Hardware Specs Footer
              _buildHardwareInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  // --- BLE SECTION ---
  Widget _buildBleSection(BuildContext context, BluetoothService btService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status BLE Card with Emerald Light background
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: btService.isConnected ? const Color(0xFFDCFCE7) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppTheme.shadowSM,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: btService.isConnected ? AppTheme.primaryColor : const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  btService.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: btService.isConnected ? Colors.white : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      btService.isConnected ? 'Terhubung via BLE' : 'Bluetooth Terputus',
                      style: TextStyle(
                        fontSize: 12,
                        color: btService.isConnected ? const Color(0xFF15803D) : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      btService.connectedDeviceName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Putuskan'),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingLG),

        // Scan Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pindai Perangkat Terdekat',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: btService.isScanning ? null : () => btService.startScan(),
              icon: btService.isScanning
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.search, size: 18),
              label: Text(btService.isScanning ? 'Memindai...' : 'Pindai BLE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Devices List
        if (btService.scanResults.isEmpty && btService.mockFoundDevices.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Text(
                'Tekan "Pindai BLE" untuk mencari ESP32 di dekat Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: btService.scanResults.length + btService.mockFoundDevices.length,
            itemBuilder: (context, index) {
              String devName;
              dynamic actualDevice;

              if (index < btService.scanResults.length) {
                final sr = btService.scanResults[index];
                devName = sr.device.platformName.isNotEmpty ? sr.device.platformName : sr.device.remoteId.str;
                actualDevice = sr.device;
              } else {
                devName = btService.mockFoundDevices[index - btService.scanResults.length];
              }

              final isThisConnected = btService.isConnected && btService.connectedDeviceName == devName;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppTheme.shadowSM,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.memory, color: AppTheme.primaryColor, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(devName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const Text('ESP32-WROOM-32 • Ready', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    isThisConnected
                        ? const Icon(Icons.check_circle, color: AppTheme.successColor)
                        : ElevatedButton(
                            onPressed: () => btService.connectToDevice(devName, device: actualDevice),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Hubungkan'),
                          ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // --- CLOUD SECTION (MQTT / WIFI SETUP) ---
  Widget _buildCloudSection(BuildContext context, MqttService mqttService, BluetoothService btService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card 1: ID Perangkat
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppTheme.shadowSM,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.cloud, color: Color(0xFF1D4ED8), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Koneksi Cloud (Jarak Jauh)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _deviceIdController,
                decoration: InputDecoration(
                  labelText: 'Kode / ID Perangkat Alat',
                  hintText: 'Contoh: SPRAYER-001',
                  prefixIcon: const Icon(Icons.qr_code),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _connectMqtt(mqttService),
                  icon: Icon(mqttService.isConnected ? Icons.cloud_done : Icons.cloud_queue),
                  label: Text(
                    mqttService.isConnected ? 'TERHUBUNG KE CLOUD' : 'HUBUNGKAN KE CLOUD',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mqttService.isConnected ? const Color(0xFF16A34A) : AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingLG),

        // Card 2: Pengaturan WiFi ESP32
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppTheme.shadowSM,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📶 Konfigurasi WiFi Alat',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Masukkan nama WiFi dan password kebun agar alat ESP32 dapat online.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ssidController,
                decoration: InputDecoration(
                  labelText: 'Nama WiFi (SSID)',
                  prefixIcon: const Icon(Icons.wifi),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pwdController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password WiFi',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: btService.isConnected
                      ? () => _syncConfigToBle(btService)
                      : null,
                  icon: const Icon(Icons.send),
                  label: Text(
                    btService.isConnected
                        ? 'Kirim Setting WiFi ke ESP32 (via BLE)'
                        : 'Hubungkan BLE Dulu untuk Kirim WiFi',
                  ),
                  style: OutlinedButton.styleFrom(
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

  // --- HARDWARE INFO FOOTER ---
  Widget _buildHardwareInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTheme.shadowSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Informasi Komponen Perangkat',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          _HwInfoRow(label: 'Mikrokontroler', value: 'ESP32-WROOM-32 Dual Core'),
          Divider(),
          _HwInfoRow(label: 'Sistem Daya', value: 'Solar Cell + Baterai 18650'),
          Divider(),
          _HwInfoRow(label: 'Pompa Water', value: 'Mini Pump 310 DC (Nozzle Misting)'),
        ],
      ),
    );
  }
}

class _HwInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _HwInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(value, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }
}
