import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';
import '../services/database_helper.dart';
import '../services/theme_provider.dart';
import '../theme/theme.dart';

class CategorySettingsPage extends StatefulWidget {
  final String categoryId;
  final String title;
  final IconData icon;

  const CategorySettingsPage({
    super.key,
    required this.categoryId,
    required this.title,
    required this.icon,
  });

  @override
  State<CategorySettingsPage> createState() => _CategorySettingsPageState();
}

class _CategorySettingsPageState extends State<CategorySettingsPage> {
  // Local states
  bool _autoConnect = true;
  bool _aiRecommendationEnabled = true;
  bool _lowTankWarning = true;
  bool _scheduleNotification = true;
  bool _alertSound = true;
  bool _deviceOfflineAlert = true;

  final TextEditingController _deviceIdController = TextEditingController(text: 'SPRAYER-001');
  final TextEditingController _mqttHostController = TextEditingController(text: 'broker.emqx.io');
  int _defaultDuration = 30;

  @override
  void dispose() {
    _deviceIdController.dispose();
    _mqttHostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final mqttService = Provider.of<MqttService>(context);
    final dbHelper = Provider.of<DatabaseHelper>(context);

    const isDark = true;

    return Scaffold(
      backgroundColor: ThemeProvider.darkBgColor,
      appBar: AppBar(
        backgroundColor: ThemeProvider.darkBgColor,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: ThemeProvider.greenAccentColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ThemeProvider.greenAccentColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.icon,
                size: 18,
                color: ThemeProvider.blackColor,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.title,
              style: const TextStyle(
                fontFamily: 'Utendo',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLG,
            vertical: AppTheme.spacingMD,
          ),
          child: _buildCategoryContent(context, isDark, themeProvider, mqttService, dbHelper),
        ),
      ),
    );
  }

  Widget _buildCategoryContent(
    BuildContext context,
    bool isDark,
    ThemeProvider themeProvider,
    MqttService mqttService,
    DatabaseHelper dbHelper,
  ) {
    const titleColor = Colors.white;
    final subtitleColor = Colors.grey.shade400;

    Widget buildIconBox(IconData icon) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ThemeProvider.greenAccentColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: ThemeProvider.blackColor, size: 20),
      );
    }

    switch (widget.categoryId) {
      case 'tampilan':
        return _buildCardContainer([
          ListTile(
            leading: buildIconBox(Icons.dark_mode),
            title: const Text(
              'Mode Tampilan Aplikasi',
              style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, color: titleColor),
            ),
            subtitle: Text(
              'Mode Gelap Permanen (#0F0F0F & #D5FF40)',
              style: TextStyle(fontFamily: 'Utendo', fontSize: 12, color: subtitleColor),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ThemeProvider.greenAccentColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Permanen',
                style: TextStyle(
                  fontFamily: 'Utendo',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: ThemeProvider.blackColor,
                ),
              ),
            ),
          ),
        ]);

      case 'koneksi':
        return _buildCardContainer([
          ListTile(
            leading: buildIconBox(Icons.perm_identity),
            title: const Text(
              'ID Perangkat Default',
              style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, color: titleColor),
            ),
            subtitle: Text(
              _deviceIdController.text,
              style: TextStyle(fontFamily: 'Utendo', color: subtitleColor),
            ),
            trailing: Icon(Icons.edit_outlined, size: 20, color: Colors.grey.shade400),
            onTap: () {
              _showEditDialog('ID Perangkat', _deviceIdController, (val) {
                setState(() {});
                mqttService.setDeviceId(val);
              });
            },
          ),
          Divider(height: 1, indent: 56, color: Colors.grey.shade800),
          ListTile(
            leading: buildIconBox(Icons.dns_outlined),
            title: const Text(
              'Host Server MQTT Broker',
              style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, color: titleColor),
            ),
            subtitle: Text(
              _mqttHostController.text,
              style: TextStyle(fontFamily: 'Utendo', color: subtitleColor),
            ),
            trailing: Icon(Icons.edit_outlined, size: 20, color: Colors.grey.shade400),
            onTap: () {
              _showEditDialog('Host MQTT Broker', _mqttHostController, (val) {
                setState(() {});
              });
            },
          ),
          Divider(height: 1, indent: 56, color: Colors.grey.shade800),
          SwitchListTile(
            value: _autoConnect,
            onChanged: (val) => setState(() => _autoConnect = val),
            activeTrackColor: ThemeProvider.greenAccentColor,
            activeThumbColor: ThemeProvider.blackColor,
            title: const Text(
              'Auto-Connect Perangkat',
              style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, color: titleColor),
            ),
            subtitle: Text(
              'Otomatis hubungkan ke ESP32 saat aplikasi terbuka',
              style: TextStyle(fontFamily: 'Utendo', fontSize: 12, color: subtitleColor),
            ),
            secondary: buildIconBox(Icons.sync),
          ),
        ]);

      case 'semprot':
        return _buildCardContainer([
          ListTile(
            leading: buildIconBox(Icons.timer_outlined),
            title: const Text(
              'Durasi Default Penyemprotan',
              style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, color: titleColor),
            ),
            subtitle: Text(
              '$_defaultDuration Detik per sesi',
              style: TextStyle(fontFamily: 'Utendo', color: subtitleColor),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
            onTap: () => _showDurationPicker(),
          ),
          Divider(height: 1, indent: 56, color: Colors.grey.shade800),
          SwitchListTile(
            value: _aiRecommendationEnabled,
            onChanged: (val) => setState(() => _aiRecommendationEnabled = val),
            activeTrackColor: ThemeProvider.greenAccentColor,
            activeThumbColor: ThemeProvider.blackColor,
            title: const Text(
              'Mode Rekomendasi Dosis AI',
              style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, color: titleColor),
            ),
            subtitle: Text(
              'Hitung dosis otomatis berdasarkan kondisi lingkungan',
              style: TextStyle(fontFamily: 'Utendo', fontSize: 12, color: subtitleColor),
            ),
            secondary: buildIconBox(Icons.auto_awesome),
          ),
          Divider(height: 1, indent: 56, color: Colors.grey.shade800),
          SwitchListTile(
            value: _lowTankWarning,
            onChanged: (val) => setState(() => _lowTankWarning = val),
            activeTrackColor: ThemeProvider.greenAccentColor,
            activeThumbColor: ThemeProvider.blackColor,
            title: const Text(
              'Peringatan Cairan Rendah',
              style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, color: titleColor),
            ),
            subtitle: Text(
              'Notifikasi jika tangki tersisa kurang dari 15%',
              style: TextStyle(fontFamily: 'Utendo', fontSize: 12, color: subtitleColor),
            ),
            secondary: buildIconBox(Icons.warning_amber_rounded),
          ),
        ]);

      case 'notifikasi':
        return _buildCardContainer([
          SwitchListTile(
            value: _scheduleNotification,
            onChanged: (val) => setState(() => _scheduleNotification = val),
            activeTrackColor: ThemeProvider.greenAccentColor,
            activeThumbColor: ThemeProvider.blackColor,
            title: const Text(
              'Pengingat Jadwal Semprot',
              style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, color: titleColor),
            ),
            subtitle: Text(
              'Kirim notifikasi sebelum jadwal semprot dimulai',
              style: TextStyle(fontFamily: 'Utendo', fontSize: 12, color: subtitleColor),
            ),
            secondary: buildIconBox(Icons.alarm),
          ),
          Divider(height: 1, indent: 56, color: Colors.grey.shade800),
          SwitchListTile(
            value: _alertSound,
            onChanged: (val) => setState(() => _alertSound = val),
            activeTrackColor: ThemeProvider.greenAccentColor,
            activeThumbColor: ThemeProvider.blackColor,
            title: const Text(
              'Suara & Efek Peringatan',
              style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, color: titleColor),
            ),
            subtitle: Text(
              'Mainkan suara saat terjadi kegagalan atau status tangki',
              style: TextStyle(fontFamily: 'Utendo', fontSize: 12, color: subtitleColor),
            ),
            secondary: buildIconBox(Icons.volume_up_outlined),
          ),
          Divider(height: 1, indent: 56, color: Colors.grey.shade800),
          SwitchListTile(
            value: _deviceOfflineAlert,
            onChanged: (val) => setState(() => _deviceOfflineAlert = val),
            activeTrackColor: ThemeProvider.greenAccentColor,
            activeThumbColor: ThemeProvider.blackColor,
            title: const Text(
              'Peringatan Perangkat Offline',
              style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, color: titleColor),
            ),
            subtitle: Text(
              'Notifikasi saat koneksi ke ESP32 terputus',
              style: TextStyle(fontFamily: 'Utendo', fontSize: 12, color: subtitleColor),
            ),
            secondary: buildIconBox(Icons.wifi_off_rounded),
          ),
        ]);

      case 'storage':
        return _buildCardContainer([
          ListTile(
            leading: buildIconBox(Icons.download_rounded),
            title: const Text(
              'Ekspor Data Riwayat',
              style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, color: titleColor),
            ),
            subtitle: Text(
              'Simpan riwayat semprot dalam format CSV/Excel',
              style: TextStyle(fontFamily: 'Utendo', color: subtitleColor),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data riwayat semprot berhasil diekspor!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          Divider(height: 1, indent: 56, color: Colors.grey.shade800),
          ListTile(
            leading: buildIconBox(Icons.cleaning_services_outlined),
            title: const Text(
              'Bersihkan Cache Aplikasi',
              style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, color: titleColor),
            ),
            subtitle: Text(
              'Hapus data sementara untuk membebaskan ruang',
              style: TextStyle(fontFamily: 'Utendo', color: subtitleColor),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache aplikasi berhasil dibersihkan!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          Divider(height: 1, indent: 56, color: Colors.grey.shade800),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
            title: Text(
              'Hapus Semua Riwayat Semprot',
              style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, color: Colors.red.shade400),
            ),
            subtitle: Text(
              'Kosongkan database lokal riwayat semprot',
              style: TextStyle(fontFamily: 'Utendo', color: subtitleColor),
            ),
            onTap: () => _confirmClearHistory(dbHelper),
          ),
        ]);

      case 'info':
        return _buildCardContainer([
          ListTile(
            leading: buildIconBox(Icons.code),
            title: const Text(
              'Versi Aplikasi',
              style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, color: titleColor),
            ),
            subtitle: Text(
              'v1.0.1 (Build 2026.08)',
              style: TextStyle(fontFamily: 'Utendo', color: subtitleColor),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: ThemeProvider.greenAccentColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Terbaru',
                style: TextStyle(
                  fontFamily: 'Utendo',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: ThemeProvider.blackColor,
                ),
              ),
            ),
          ),
          Divider(height: 1, indent: 56, color: Colors.grey.shade800),
          ListTile(
            leading: buildIconBox(Icons.help_outline),
            title: const Text(
              'Bantuan & Tentang Aplikasi',
              style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, color: titleColor),
            ),
            subtitle: Text(
              'Informasi pengembang dan panduan penggunaan',
              style: TextStyle(fontFamily: 'Utendo', color: subtitleColor),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
            onTap: () => _showAboutDialog(context),
          ),
        ]);

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Material(
      color: ThemeProvider.darkCardColor,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: Column(children: children),
    );
  }

  void _showEditDialog(String fieldName, TextEditingController controller, Function(String) onSave) {
    final textCtrl = TextEditingController(text: controller.text);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Ubah $fieldName', style: const TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, fontSize: 18)),
          content: TextField(
            controller: textCtrl,
            style: const TextStyle(fontFamily: 'Utendo'),
            decoration: InputDecoration(
              hintText: 'Masukkan $fieldName baru',
              filled: true,
              fillColor: const Color(0xFF2C2D30),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(fontFamily: 'Utendo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeProvider.greenAccentColor,
                foregroundColor: ThemeProvider.blackColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (textCtrl.text.trim().isNotEmpty) {
                  controller.text = textCtrl.text.trim();
                  onSave(textCtrl.text.trim());
                  Navigator.pop(context);
                }
              },
              child: const Text('Simpan', style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showDurationPicker() {
    double tempVal = _defaultDuration.toDouble();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Durasi Default Penyemprotan', style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${tempVal.toInt()} Detik',
                    style: const TextStyle(fontFamily: 'Utendo', fontSize: 28, fontWeight: FontWeight.bold, color: ThemeProvider.greenAccentColor),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: tempVal,
                    min: 5,
                    max: 120,
                    divisions: 23,
                    activeColor: ThemeProvider.greenAccentColor,
                    onChanged: (val) {
                      setDialogState(() {
                        tempVal = val;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal', style: TextStyle(fontFamily: 'Utendo', color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeProvider.greenAccentColor,
                    foregroundColor: ThemeProvider.blackColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    setState(() {
                      _defaultDuration = tempVal.toInt();
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Simpan', style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmClearHistory(DatabaseHelper dbHelper) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Hapus Riwayat?', style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: const Text(
            'Apakah Anda yakin ingin menghapus seluruh data riwayat penyemprotan? Tindakan ini tidak dapat dibatalkan.',
            style: TextStyle(fontFamily: 'Utendo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(fontFamily: 'Utendo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await dbHelper.clearAllLogs();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Semua riwayat semprot telah dihapus.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Hapus Semua', style: TextStyle(fontFamily: 'Utendo', color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Smart Sprayer AI & IoT',
      applicationVersion: '1.0.1',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ThemeProvider.greenAccentColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.eco, color: ThemeProvider.blackColor, size: 32),
      ),
      children: [
        const SizedBox(height: 12),
        const Text(
          'Aplikasi kontrol dan pemantauan penyemprotan tanaman cerdas berbasis AI dan IoT ESP32.\n\nFitur Utama:\n- Dosis otomatis sistem pakar AI\n- Pemantauan tangki & baterai real-time\n- Kontrol dual-mode BLE & MQTT Cloud\n- Penjadwalan & Riwayat Semprot',
          style: TextStyle(fontFamily: 'Utendo', fontSize: 13),
        ),
      ],
    );
  }
}
