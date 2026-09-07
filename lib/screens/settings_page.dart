import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../services/mqtt_service.dart';
import '../services/theme_provider.dart';
import '../theme/theme.dart';
import 'category_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _deviceIdController = TextEditingController(text: 'SPRAYER-001');

  @override
  void dispose() {
    _deviceIdController.dispose();
    super.dispose();
  }

  // Custom Route with Slide Animation:
  // Push: Right to Left (Offset(1.0, 0.0) -> Offset.zero)
  // Pop: Left to Right (Offset.zero -> Offset(1.0, 0.0))
  Route _createSlideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    final btService = Provider.of<BluetoothService>(context);
    final mqttService = Provider.of<MqttService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final isBleConnected = btService.isConnected;
    final isMqttConnected = mqttService.isConnected && mqttService.isEspOnline;
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: ThemeProvider.darkBgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLG,
            vertical: AppTheme.spacingMD,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ThemeProvider.greenAccentColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.settings,
                          color: ThemeProvider.blackColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Konfigurasi & Preferensi',
                            style: TextStyle(
                              fontFamily: 'Utendo',
                              fontSize: 12,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Text(
                            'Pengaturan',
                            style: TextStyle(
                              fontFamily: 'Utendo',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isBleConnected || isMqttConnected
                          ? ThemeProvider.greenAccentColor
                          : Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isBleConnected
                              ? Icons.bluetooth_connected
                              : (isMqttConnected ? Icons.cloud_done : Icons.cloud_off),
                          size: 14,
                          color: isBleConnected || isMqttConnected
                              ? ThemeProvider.blackColor
                              : Colors.orange.shade800,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isBleConnected
                              ? 'BLE Terhubung'
                              : (isMqttConnected ? 'Cloud Online' : 'Offline'),
                          style: TextStyle(
                            fontFamily: 'Utendo',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isBleConnected || isMqttConnected
                                ? ThemeProvider.blackColor
                                : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacingLG),

              // Category Card Button 1: Koneksi & Perangkat
              _buildCategoryCardButton(
                context: context,
                isDark: isDark,
                icon: Icons.sensors,
                title: 'Koneksi & Perangkat',
                subtitle: 'ID Perangkat (${_deviceIdController.text}), Server MQTT & Auto-Connect',
                onTap: () {
                  Navigator.push(
                    context,
                    _createSlideRoute(
                      const CategorySettingsPage(
                        categoryId: 'koneksi',
                        title: 'Koneksi & Perangkat',
                        icon: Icons.sensors,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Category Card Button 2: Penyemprotan & AI
              _buildCategoryCardButton(
                context: context,
                isDark: isDark,
                icon: Icons.psychology,
                title: 'Penyemprotan & AI',
                subtitle: 'Kalibrasi Debit, Durasi Default & Dosis AI',
                onTap: () {
                  Navigator.push(
                    context,
                    _createSlideRoute(
                      const CategorySettingsPage(
                        categoryId: 'semprot',
                        title: 'Penyemprotan & AI',
                        icon: Icons.psychology,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Category Card Button 3: Notifikasi & Peringatan
              _buildCategoryCardButton(
                context: context,
                isDark: isDark,
                icon: Icons.notifications_none,
                title: 'Notifikasi & Peringatan',
                subtitle: 'Pengingat Jadwal, Suara & Alarm Perangkat Offline',
                onTap: () {
                  Navigator.push(
                    context,
                    _createSlideRoute(
                      const CategorySettingsPage(
                        categoryId: 'notifikasi',
                        title: 'Notifikasi & Peringatan',
                        icon: Icons.notifications_none,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Category Card Button 4: Penyimpanan & Database
              _buildCategoryCardButton(
                context: context,
                isDark: isDark,
                icon: Icons.storage_rounded,
                title: 'Penyimpanan & Database',
                subtitle: 'Ekspor Data CSV, Bersihkan Cache & Hapus Riwayat',
                onTap: () {
                  Navigator.push(
                    context,
                    _createSlideRoute(
                      const CategorySettingsPage(
                        categoryId: 'storage',
                        title: 'Penyimpanan & Database',
                        icon: Icons.storage_rounded,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Category Card Button 5: Informasi Aplikasi
              _buildCategoryCardButton(
                context: context,
                isDark: isDark,
                icon: Icons.info_outline,
                title: 'Informasi Aplikasi',
                subtitle: 'Versi v1.0.1, Panduan & Tentang Pestzon Spray',
                onTap: () {
                  Navigator.push(
                    context,
                    _createSlideRoute(
                      const CategorySettingsPage(
                        categoryId: 'info',
                        title: 'Informasi Aplikasi',
                        icon: Icons.info_outline,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCardButton({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailingWidget,
    required VoidCallback onTap,
  }) {
    const bgColor = Color(0xFF1E1E1E);
    const iconBg = ThemeProvider.greenAccentColor;
    const iconColor = ThemeProvider.blackColor;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(10),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Utendo',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Utendo',
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailingWidget != null)
                trailingWidget
              else
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
