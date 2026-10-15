import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/bluetooth_service.dart';
import '../services/mqtt_service.dart';
import '../services/database_helper.dart';
import '../services/device_repository.dart';
import '../services/esp_device_registry.dart';
import '../services/theme_provider.dart';
import '../theme/theme.dart';
import '../models/esp_device.dart';
import '../models/spray_log.dart';
import '../models/device_status.dart';
import '../widgets/device_card.dart';
import '../utils/app_notification.dart';
import '../utils/app_format.dart';
import 'bluetooth_page.dart';
import 'day_detail_overview_page.dart';
import 'device_detail_screen.dart';
import 'weekly_detail_overview_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  double _selectedDuration = 30.0;
  int _selectedBarIndex = DateTime.now().weekday - 1;
  String? _selectedDeviceKey;

  @override
  Widget build(BuildContext context) {
    final btService = Provider.of<BluetoothService>(context);
    final mqttService = Provider.of<MqttService>(context);
    final dbHelper = Provider.of<DatabaseHelper>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final deviceRepo = Provider.of<DeviceRepository>(context);

    final registry = Provider.of<EspDeviceRegistry>(context);
    final devices = registry.devices;

    final isBleConnected = btService.isConnected;
    final isMqttConnected = mqttService.isConnected && mqttService.isEspOnline;
    final isDark = themeProvider.isDarkMode;

    // Tentukan selected device
    String? currentKey = _selectedDeviceKey;
    if (currentKey == null || !devices.any((d) => d.deviceKey == currentKey)) {
      if (btService.isConnected && btService.activeDeviceKey != null) {
        currentKey = btService.activeDeviceKey;
      } else if (devices.isNotEmpty) {
        currentKey = devices.first.deviceKey;
      } else {
        currentKey = null;
      }
    }

    final selectedDevice =
        currentKey != null ? registry.byKey(currentKey) : null;

    // Cek koneksi untuk device yang dipilih
    final bool isSelectedDeviceBle = selectedDevice != null
        ? (btService.isConnected &&
            selectedDevice.deviceKey == btService.activeDeviceKey)
        : btService.isConnected;

    final bool isSelectedDeviceMqtt = selectedDevice != null
        ? (isMqttConnected &&
            (selectedDevice.deviceKey.contains(mqttService.deviceId) ||
                mqttService.deviceId == selectedDevice.name))
        : isMqttConnected;

    // Status telemetri untuk device yang dipilih
    DeviceStatus displayStatus;
    if (isSelectedDeviceBle || isSelectedDeviceMqtt || selectedDevice == null) {
      displayStatus = deviceRepo.summary;
    } else {
      final cached = deviceRepo.statusOf(selectedDevice.deviceKey);
      displayStatus = cached ??
          DeviceStatus(
            batteryPercentage: selectedDevice.lastBattery ?? 85,
            totalVolumeTodayMl: selectedDevice.lastVolumeMl ?? 0.0,
            connectionState: 'Disconnected',
          );
    }

    return Scaffold(
      backgroundColor:
          isDark ? ThemeProvider.darkBgColor : const Color(0xFFF6F8F6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLG,
            vertical: AppTheme.spacingMD,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // HEADER (Profile & Interactive Connection Badge)
              _buildHeader(context, isBleConnected, isMqttConnected, dbHelper,
                  btService, mqttService, isDark),
              const SizedBox(height: AppTheme.spacingLG),

              // DASHBOARD LENGKAP UTAMA (SELALU AKTIF & TAMPIL)
              _buildHeroDayCard(context, displayStatus, isDark),
              const SizedBox(height: AppTheme.spacingLG),
              _buildStatisticChartCard(
                context,
                dbHelper,
                displayStatus,
                deviceRepo,
                isDark,
                currentKey,
              ),
              const SizedBox(height: AppTheme.spacingLG),
              _buildSolarBatteryCard(
                context,
                displayStatus,
                isSelectedDeviceBle,
                isSelectedDeviceMqtt,
                isDark,
              ),
              const SizedBox(height: AppTheme.spacingLG),
              _buildPumpControlCard(
                context,
                btService,
                mqttService,
                dbHelper,
                displayStatus,
                isBleConnected,
                isMqttConnected,
                isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HERO DAY SUMMARY CARD (With Top-Right Arrow & Auto-Slide Animation) ---
  Widget _buildHeroDayCard(BuildContext context, dynamic status, bool isDark) {
    const cardColor = ThemeProvider.greenAccentColor; // #D5FF40 Electric Neon Green
    const textColor = ThemeProvider.blackColor;      // #0F0F0F Dark Black

    final now = DateTime.now();
    final dateFormatted = DateFormat('dd/MM/yyyy').format(now);
    final daysInIndonesian = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final dayName = daysInIndonesian[now.weekday - 1];

    final totalVolume = '${status.totalVolumeTodayMl.toInt()} ml';
    final totalSesi = '${status.totalSesiToday}';
    final battery = '${status.batteryPercentage}%';
    // Debit pompa tidak lagi konstan: default 0 sampai ESP mengirim `flowRate`.
    final pumpDebit = '${status.flowRateMlPerSec.toStringAsFixed(1)} ml/s';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1AD5FF40),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Date Header & Top-Right Detail Arrow Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateFormatted,
                style: const TextStyle(
                  fontFamily: 'Utendo',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  letterSpacing: 0.5,
                ),
              ),
              // Top-Right Arrow Navigation Button
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => DayDetailOverviewPage(
                        dayName: dayName,
                        dateFormatted: dateFormatted,
                        status: status,
                      ),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOutCubic;

                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                        return SlideTransition(
                          position: animation.drive(tween),
                          child: child,
                        );
                      },
                      transitionDuration: const Duration(milliseconds: 300),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: ThemeProvider.blackColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: ThemeProvider.greenAccentColor,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),

          // 2. Big Day Name (e.g. Senin)
          Text(
            dayName,
            style: const TextStyle(
              fontFamily: 'Utendo',
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: -1.0,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),

          // 3. Smooth Auto-scrolling Slide Animation Ticker (Left to Right to Left)
          AutoScrollingMetricsTicker(
            totalVolume: totalVolume,
            totalSesi: totalSesi,
            battery: battery,
            pumpDebit: pumpDebit,
            textColor: textColor,
          ),
        ],
      ),
    );
  }

  // --- 1. HEADER ---
  Widget _buildHeader(
    BuildContext context,
    bool isBle,
    bool isMqtt,
    DatabaseHelper dbHelper,
    BluetoothService btService,
    MqttService mqttService,
    bool isDark,
  ) {
    final primaryAccent = isDark ? ThemeProvider.greenAccentColor : AppTheme.primaryColor;

    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: primaryAccent.withValues(alpha: isDark ? 0.2 : 0.15),
          child: Icon(Icons.eco, color: primaryAccent, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selamat Pagi',
                style: TextStyle(
                  fontFamily: 'Utendo',
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Pestzon Spray',
                style: TextStyle(
                  fontFamily: 'Utendo',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textDark,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        // Connection Badge
        GestureDetector(
          onTap: () {
            AppNotification.show(
              context,
              isBle
                  ? 'Terhubung via Bluetooth (BLE)'
                  : (isMqtt ? 'Terhubung via Cloud (MQTT)' : 'Perangkat Terputus! Silakan buka menu Device.'),
              isError: !isBle && !isMqtt,
            );
          },
          child: _buildConnectionBadge(isBle, isMqtt, isDark),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Sinkronkan data dari alat',
          onPressed: () async {
            final repo =
                Provider.of<DeviceRepository>(context, listen: false);
            if (!repo.isConnected) {
              if (context.mounted) {
                AppNotification.show(
                  context,
                  'Perangkat tidak terhubung. Silakan buka menu Device.',
                  isError: true,
                );
              }
              return;
            }
            final ok = await repo.refreshAll();
            if (context.mounted) {
              AppNotification.show(
                context,
                ok
                    ? 'Data disinkronkan dari alat'
                    : 'Alat tidak merespons. Coba lagi.',
                isError: !ok,
              );
            }
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? ThemeProvider.darkCardColor : Colors.white,
              shape: BoxShape.circle,
              boxShadow: isDark ? [] : AppTheme.shadowSM,
            ),
            child: Provider.of<DeviceRepository>(context).isRefreshing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryAccent,
                    ),
                  )
                : Icon(
                    Icons.sync,
                    size: 20,
                    color: isDark ? primaryAccent : AppTheme.textDark,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionBadge(bool isBle, bool isMqtt, bool isDark) {
    Color bg;
    Color fg;
    String text;

    if (isBle) {
      bg = isDark ? ThemeProvider.greenAccentColor : const Color(0xFFDCFCE7);
      fg = isDark ? ThemeProvider.blackColor : const Color(0xFF15803D);
      text = 'BLE Active';
    } else if (isMqtt) {
      bg = isDark ? ThemeProvider.greenAccentColor : const Color(0xFFDBEAFE);
      fg = isDark ? ThemeProvider.blackColor : const Color(0xFF1D4ED8);
      text = 'MQTT Online';
    } else {
      bg = Colors.red.withValues(alpha: 0.2);
      fg = Colors.red.shade400;
      text = 'Offline';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontFamily: 'Utendo', color: fg, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildDataEmptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    final cardBg = isDark ? ThemeProvider.darkCardColor : Colors.white;
    final titleColorV = isDark ? Colors.white : AppTheme.textDark;
    final primaryA = isDark ? ThemeProvider.greenAccentColor : AppTheme.primaryColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: isDark ? [] : AppTheme.shadowSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? primaryA : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: isDark ? ThemeProvider.blackColor : Colors.grey.shade600,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, fontSize: 16, color: titleColorV),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontFamily: 'Utendo', fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.remove_circle_outline, size: 16, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Perangkat belum terhubung — data belum tersedia',
                  style: TextStyle(
                    fontFamily: 'Utendo',
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 2. SOLAR & BATTERY CARD ---
  Widget _buildSolarBatteryCard(
    BuildContext context,
    dynamic status,
    bool isBle,
    bool isMqtt,
    bool isDark,
  ) {
    if (!(isBle || isMqtt)) {
      if (status == null || (status.batteryPercentage <= 0 && status.batteryVoltage <= 0)) {
        return _buildDataEmptyCard(
          icon: Icons.battery_charging_full,
          title: 'Daya Alat',
          subtitle: 'Baterai & Panel Surya',
          isDark: isDark,
        );
      }
    }
    final battery = status.batteryPercentage;
    final isSolar = (isBle || isMqtt) ? status.isSolarCharging : false;
    final voltage = status.batteryVoltage;
    final cardBg = isDark ? ThemeProvider.darkCardColor : Colors.white;
    final titleColor = isDark ? Colors.white : AppTheme.textDark;
    final primaryAccent = isDark ? ThemeProvider.greenAccentColor : AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: isDark ? [] : AppTheme.shadowSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? primaryAccent : (isSolar ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isSolar ? Icons.solar_power : Icons.battery_charging_full,
                      color: isDark ? ThemeProvider.blackColor : (isSolar ? const Color(0xFFD97706) : AppTheme.primaryColor),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daya Alat',
                        style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, fontSize: 16, color: titleColor),
                      ),
                      Text(
                        'Baterai & Panel Surya',
                        style: TextStyle(fontFamily: 'Utendo', fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? primaryAccent
                      : ((isBle || isMqtt)
                          ? (isSolar ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7))
                          : const Color(0xFFF3F4F6)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      (isBle || isMqtt)
                          ? (isSolar ? Icons.solar_power : Icons.battery_std)
                          : Icons.inventory_2_outlined,
                      size: 13,
                      color: isDark
                          ? ThemeProvider.blackColor
                          : ((isBle || isMqtt)
                              ? (isSolar ? const Color(0xFFB45309) : const Color(0xFF15803D))
                              : Colors.grey.shade700),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      (isBle || isMqtt)
                          ? (isSolar ? 'Pengisian Surya' : 'Daya Baterai')
                          : 'Data Tersimpan',
                      style: TextStyle(
                        fontFamily: 'Utendo',
                        color: isDark
                            ? ThemeProvider.blackColor
                            : ((isBle || isMqtt)
                                ? (isSolar ? const Color(0xFFB45309) : const Color(0xFF15803D))
                                : Colors.grey.shade700),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Battery Progress Bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: battery / 100.0,
                    minHeight: 14,
                    backgroundColor: isDark ? const Color(0xFF2C2D30) : const Color(0xFFF3F4F6),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      battery > 50
                          ? primaryAccent
                          : (battery > 20 ? AppTheme.accentYellow : AppTheme.errorColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '$battery%',
                style: TextStyle(
                  fontFamily: 'Utendo',
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tegangan Baterai: ${voltage.toStringAsFixed(1)}V (Regulator 3.3V System OK)',
            style: TextStyle(fontFamily: 'Utendo', fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // --- 3. PUMP CONTROL CARD ---
  Widget _buildPumpControlCard(
    BuildContext context,
    BluetoothService btService,
    MqttService mqttService,
    DatabaseHelper dbHelper,
    dynamic status,
    bool isBle,
    bool isMqtt,
    bool isDark,
  ) {
    final isRunning = (isBle || isMqtt) ? status.isPumpRunning : false;
    final cardBg = isDark ? ThemeProvider.darkCardColor : Colors.white;
    final titleColor = isDark ? Colors.white : AppTheme.textDark;
    final primaryAccent = isDark ? ThemeProvider.greenAccentColor : AppTheme.primaryColor;
    final double flowRate = (status.flowRateMlPerSec > 0 ? status.flowRateMlPerSec : 15.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: isDark ? [] : AppTheme.shadowSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? primaryAccent : (isRunning ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.water_drop,
                      color: isDark ? ThemeProvider.blackColor : (isRunning ? AppTheme.primaryColor : Colors.grey.shade600),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pompa Misting DC',
                        style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, fontSize: 16, color: titleColor),
                      ),
                      Text(
                        isRunning
                            ? 'Status: Menyemprot (${status.activeDurationSeconds}s)'
                            : ((isBle || isMqtt)
                                ? 'Status: Standby'
                                : 'Status: Offline (Belum Tersambung)'),
                        style: TextStyle(
                          fontFamily: 'Utendo',
                          fontSize: 12,
                          color: isRunning ? primaryAccent : (isDark ? Colors.grey.shade400 : Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2D30) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${flowRate.toStringAsFixed(1)} ml/detik',
                  style: TextStyle(fontFamily: 'Utendo', fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Durasi Semprot',
                style: TextStyle(fontFamily: 'Utendo', fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
              ),
              Text(
                '${_selectedDuration.toInt()} Detik (${(_selectedDuration * flowRate).toInt()} ml)',
                style: TextStyle(
                  fontFamily: 'Utendo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryAccent,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: primaryAccent,
              inactiveTrackColor: isDark ? const Color(0xFF2C2D30) : const Color(0xFFE5E7EB),
              thumbColor: primaryAccent,
              trackHeight: 6,
            ),
            child: Slider(
              value: _selectedDuration,
              min: 5.0,
              max: 120.0,
              divisions: 23,
              onChanged: isRunning ? null : (val) => setState(() => _selectedDuration = val),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: !(isBle || isMqtt)
                  ? null
                  : () async {
                      if (isRunning) {
                        if (isBle) {
                          btService.stopSpraying();
                        } else if (isMqtt) {
                          mqttService.stopSpraying();
                        }
                        if (context.mounted) {
                          AppNotification.show(context, 'Penyemprotan dihentikan.');
                        }
                        return;
                      }

                      final dur = _selectedDuration.toInt();
                      if (isBle) {
                        btService.startSpraying(
                          durationSeconds: dur,
                          dbHelper: dbHelper,
                          mode: 'Manual App',
                        );
                      } else if (isMqtt) {
                        mqttService.startSpraying(durationSeconds: dur);
                      }
                      if (context.mounted) {
                        AppNotification.show(context, 'Penyemprotan dimulai ($dur detik)...');
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isRunning ? Colors.red.shade600 : primaryAccent,
                foregroundColor: isRunning
                    ? Colors.white
                    : (isDark ? ThemeProvider.blackColor : Colors.white),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                !(isBle || isMqtt)
                    ? 'SAMBUNGKAN KONEKSI DULU'
                    : (isRunning
                        ? 'HENTIKAN PENYEMPROTAN (${status.activeDurationSeconds}s)'
                        : 'SEMPROT SEKARANG'),
                style: TextStyle(
                  fontFamily: 'Utendo',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isRunning
                      ? Colors.white
                      : (isDark ? ThemeProvider.blackColor : Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. STATISTIC BAR CHART ---
  Widget _buildStatisticChartCard(
    BuildContext context,
    DatabaseHelper dbHelper,
    dynamic status,
    DeviceRepository repo,
    bool isDark, [
    String? selectedDeviceKey,
  ]) {
    final titleColor = isDark ? Colors.white : AppTheme.textDark;
    final primaryAccent = isDark ? ThemeProvider.greenAccentColor : AppTheme.primaryColor;

    final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final dayAbbr = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    final todayIndex = DateTime.now().weekday - 1;

    return FutureBuilder<List<SprayLog>>(
      future: (selectedDeviceKey != null && selectedDeviceKey.isNotEmpty)
          ? dbHelper.getLogsForDevice(selectedDeviceKey)
          : dbHelper.getAllLogs(),
      builder: (context, snapshot) {
        var logs = snapshot.data ?? [];

        // Daily volume data in ml computed from real logs for this week
        final List<double> volumes = List.filled(7, 0.0);
        final now = DateTime.now();
        final mondayStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        final sundayEnd = mondayStart.add(const Duration(days: 7));

        for (var log in logs) {
          if (log.timestamp.isAfter(mondayStart.subtract(const Duration(seconds: 1))) &&
              log.timestamp.isBefore(sundayEnd)) {
            final dayIdx = log.timestamp.weekday - 1;
            if (dayIdx >= 0 && dayIdx < 7) {
              volumes[dayIdx] += log.volumeMl;
            }
          }
        }

        // Sumber utama: statistik per hari yang disimpan di perangkat ESP
        // (cache hasil pull, tetap dipakai walau offline). Kalau belum pernah
        // ditarik (null), grafik memakai log SQLite lokal di atas.
        final deviceStats = repo.stats;
        if (deviceStats != null && deviceStats.isNotEmpty) {
          volumes.fillRange(0, 7, 0.0);
          for (final stat in deviceStats) {
            final date = DateTime(stat.date.year, stat.date.month, stat.date.day);
            if (!date.isBefore(mondayStart) && date.isBefore(sundayEnd)) {
              final dayIdx = stat.weekdayIndex;
              if (dayIdx >= 0 && dayIdx < 7) {
                volumes[dayIdx] = stat.volumeMl;
              }
            }
          }
        }

        // Incorporate current live status volume if larger
        if (status != null && status.totalVolumeTodayMl > volumes[todayIndex]) {
          volumes[todayIndex] = status.totalVolumeTodayMl;
        }

        final totalWeeklyVolume = volumes.reduce((a, b) => a + b);

        // Selected day index (defaults to todayIndex)
        final selectedIndex = (_selectedBarIndex >= 0 && _selectedBarIndex < 7) ? _selectedBarIndex : todayIndex;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? ThemeProvider.darkCardColor : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isDark ? [] : AppTheme.shadowSM,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statistik Volume',
                        style: TextStyle(
                          fontFamily: 'Utendo',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Minggu Ini • Total ${totalWeeklyVolume.toInt()} ml',
                        style: TextStyle(
                          fontFamily: 'Utendo',
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2D30) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 14,
                          color: primaryAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Target ${AppFormat.thousands(status.dailyTargetMl)} ml',
                          style: TextStyle(
                            fontFamily: 'Utendo',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: primaryAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 120,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchCallback: (FlTouchEvent event, barTouchResponse) {
                        if (!event.isInterestedForInteractions || barTouchResponse == null || barTouchResponse.spot == null) {
                          return;
                        }
                        final touchedIdx = barTouchResponse.spot!.touchedBarGroupIndex;
                        if (touchedIdx >= 0 && touchedIdx < 7 && touchedIdx != _selectedBarIndex) {
                          setState(() {
                            _selectedBarIndex = touchedIdx;
                          });
                        }
                      },
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) => isDark ? const Color(0xFF2C2D30) : Colors.white,
                        tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final vol = volumes[groupIndex].toInt();
                          final pct = (vol / 10).toInt();
                          return BarTooltipItem(
                            '${days[groupIndex]}\n$vol ml ($pct%)',
                            TextStyle(
                              fontFamily: 'Utendo',
                              fontWeight: FontWeight.bold,
                              color: primaryAccent,
                              fontSize: 11,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            final idx = val.toInt();
                            if (idx < 0 || idx >= 7) return const SizedBox();
                            final isSelected = idx == selectedIndex;
                            final hasData = volumes[idx] > 0;
                            final style = TextStyle(
                              fontFamily: 'Utendo',
                              color: (isSelected && hasData) ? primaryAccent : (isDark ? Colors.grey.shade400 : Colors.grey),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 12,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(dayAbbr[idx], style: style),
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(7, (index) {
                      final hasData = volumes[index] > 0;
                      final barHeight = hasData ? (volumes[index] / 10).clamp(10.0, 120.0) : 0.0;
                      return _makeBarGroup(
                        index,
                        barHeight,
                        isHighlighted: (index == selectedIndex) && hasData,
                        isDark: isDark,
                      );
                    }),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Tombol Lihat Detail di bawah bar (Tanpa Icon, Navigasi ke Rincian Seminggu)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => WeeklyDetailOverviewPage(
                        status: status,
                      ),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOutCubic;

                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                        return SlideTransition(
                          position: animation.drive(tween),
                          child: child,
                        );
                      },
                      transitionDuration: const Duration(milliseconds: 300),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2D30) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: primaryAccent.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Lihat Detail',
                      style: TextStyle(
                        fontFamily: 'Utendo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: primaryAccent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, {required bool isHighlighted, required bool isDark}) {
    final activeAccent = isDark ? ThemeProvider.greenAccentColor : const Color(0xFF10B981);
    final inactiveRod = isDark ? const Color(0xFF2C2D30) : const Color(0xFFDCFCE7);

    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: isHighlighted ? activeAccent : inactiveRod,
          width: 18,
          borderRadius: BorderRadius.circular(10),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 120,
            color: isDark ? const Color(0xFF161616) : const Color(0xFFF3F4F6),
          ),
        ),
      ],
    );
  }
}

// --- SMOOTH AUTO-SCROLLING SLIDE TICKER ANIMATION (Left <-> Right) ---
class AutoScrollingMetricsTicker extends StatefulWidget {
  final String totalVolume;
  final String totalSesi;
  final String battery;
  final String pumpDebit;
  final Color textColor;

  const AutoScrollingMetricsTicker({
    super.key,
    required this.totalVolume,
    required this.totalSesi,
    required this.battery,
    required this.pumpDebit,
    required this.textColor,
  });

  @override
  State<AutoScrollingMetricsTicker> createState() => _AutoScrollingMetricsTickerState();
}

class _AutoScrollingMetricsTickerState extends State<AutoScrollingMetricsTicker> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  bool _scrollingForward = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
    });
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(milliseconds: 3500), (timer) {
      if (!_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      if (_scrollingForward) {
        _scrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 2800),
          curve: Curves.easeInOutCubic,
        );
        _scrollingForward = false;
      } else {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 2800),
          curve: Curves.easeInOutCubic,
        );
        _scrollingForward = true;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          Text(
            'Total Volume: ${widget.totalVolume}',
            style: TextStyle(
              fontFamily: 'Utendo',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: widget.textColor,
            ),
          ),
          const Text(
            '  |  ',
            style: TextStyle(
              fontFamily: 'Utendo',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black38,
            ),
          ),
          Text(
            'Total Sesi: ${widget.totalSesi}',
            style: TextStyle(
              fontFamily: 'Utendo',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: widget.textColor,
            ),
          ),
          const Text(
            '  |  ',
            style: TextStyle(
              fontFamily: 'Utendo',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black38,
            ),
          ),
          Text(
            'Baterai: ${widget.battery}',
            style: TextStyle(
              fontFamily: 'Utendo',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: widget.textColor,
            ),
          ),
          const Text(
            '  |  ',
            style: TextStyle(
              fontFamily: 'Utendo',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black38,
            ),
          ),
          Text(
            'Debit Pompa: ${widget.pumpDebit}',
            style: TextStyle(
              fontFamily: 'Utendo',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: widget.textColor,
            ),
          ),
        ],
      ),
    );
  }
}
