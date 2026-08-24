import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/bluetooth_service.dart';
import '../services/mqtt_service.dart';
import '../services/database_helper.dart';
import '../services/theme_provider.dart';
import '../theme/theme.dart';
import 'day_detail_overview_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  double _selectedDuration = 30.0;

  @override
  Widget build(BuildContext context) {
    final btService = Provider.of<BluetoothService>(context);
    final mqttService = Provider.of<MqttService>(context);
    final dbHelper = Provider.of<DatabaseHelper>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final isBleConnected = btService.isConnected;
    final isMqttConnected = mqttService.isConnected && mqttService.isEspOnline;
    final isDark = themeProvider.isDarkMode;

    // Fallback logic: Prefer BLE if connected, else MQTT
    final status = isBleConnected
        ? btService.deviceStatus
        : (isMqttConnected && mqttService.latestStatus != null
            ? mqttService.latestStatus!
            : btService.deviceStatus);

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
              // 1. HEADER (Profile & Interactive Connection Badge)
              _buildHeader(context, isBleConnected, isMqttConnected, dbHelper, btService, mqttService, isDark),
              const SizedBox(height: AppTheme.spacingLG),

              // 2. HERO DAY CARD with Top-Right Navigation Arrow & Smooth Auto-Scrolling Ticker
              _buildHeroDayCard(context, status, isDark),
              const SizedBox(height: AppTheme.spacingLG),

              // 3. SOLAR & BATTERY CARD (Sistem Daya Kebun)
              _buildSolarBatteryCard(context, status, isDark),
              const SizedBox(height: AppTheme.spacingLG),

              // 4. PUMP CONTROL CARD
              _buildPumpControlCard(context, btService, mqttService, dbHelper, status, isBleConnected, isMqttConnected, isDark),
              const SizedBox(height: AppTheme.spacingLG),

              // 5. METRIC GRID CARDS (2x2 Grid)
              _buildMetricGrid(context, status, isDark),
              const SizedBox(height: AppTheme.spacingXL),

              // 6. STATISTIC BAR CHART
              _buildStatisticChartCard(context, isDark),
              const SizedBox(height: 80),
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
    const pumpDebit = '5.0 ml/s';

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
                'Selamat Pagi! 🌱',
                style: TextStyle(
                  fontFamily: 'Utendo',
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Smart Sprayer AI',
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isBle
                      ? 'Terhubung via Bluetooth (BLE)'
                      : (isMqtt ? 'Terhubung via Cloud (MQTT)' : 'Perangkat Terputus! Silakan buka menu Device.'),
                ),
              ),
            );
          },
          child: _buildConnectionBadge(isBle, isMqtt, isDark),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () async {
            final schedules = await dbHelper.getAllSchedules();
            if (isBle) {
              btService.syncSchedules(schedules);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Jadwal tersinkron via BLE')),
              );
            } else if (isMqtt) {
              mqttService.syncSchedules(schedules);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Jadwal tersinkron via MQTT')),
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
            child: Icon(Icons.sync, size: 20, color: isDark ? primaryAccent : AppTheme.textDark),
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

  // --- 2. SOLAR & BATTERY CARD ---
  Widget _buildSolarBatteryCard(BuildContext context, dynamic status, bool isDark) {
    final battery = status.batteryPercentage;
    final isSolar = status.isSolarCharging;
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
                        'Sistem Daya Kebun',
                        style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, fontSize: 16, color: titleColor),
                      ),
                      Text(
                        'Baterai 18650 & Panel Surya',
                        style: TextStyle(fontFamily: 'Utendo', fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? primaryAccent : (isSolar ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isSolar ? '⚡ Solar Charging' : '🔋 Battery Only',
                  style: TextStyle(
                    fontFamily: 'Utendo',
                    color: isDark ? ThemeProvider.blackColor : (isSolar ? const Color(0xFFB45309) : const Color(0xFF15803D)),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
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
    final isRunning = status.isPumpRunning;
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
                        isRunning ? 'Status: Menyemprot' : 'Status: Standby',
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
                  '~5 ml/detik',
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
                '${_selectedDuration.toInt()} Detik (${(_selectedDuration * 5).toInt()} ml)',
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
              onChanged: (val) => setState(() => _selectedDuration = val),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (isBle || isMqtt)
                  ? () {
                      if (isBle) {
                        btService.startSpraying(
                          durationSeconds: _selectedDuration.toInt(),
                          dbHelper: dbHelper,
                          mode: 'Manual App',
                        );
                      } else if (isMqtt) {
                        mqttService.startSpraying(durationSeconds: _selectedDuration.toInt());
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryAccent,
                foregroundColor: isDark ? ThemeProvider.blackColor : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                (isBle || isMqtt) ? 'SEMPROT SEKARANG' : 'SAMBUNGKAN KONEKSI DULU',
                style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? ThemeProvider.blackColor : Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. METRIC GRID ---
  Widget _buildMetricGrid(BuildContext context, dynamic status, bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildMetricItem(
          icon: Icons.opacity,
          iconColor: isDark ? ThemeProvider.blackColor : const Color(0xFF0284C7),
          iconBg: isDark ? ThemeProvider.greenAccentColor : const Color(0xFFE0F2FE),
          title: 'Total Volume',
          value: '${status.totalVolumeTodayMl.toInt()} ml',
          subtitle: 'Hari ini',
          isDark: isDark,
        ),
        _buildMetricItem(
          icon: Icons.repeat,
          iconColor: isDark ? ThemeProvider.blackColor : const Color(0xFF16A34A),
          iconBg: isDark ? ThemeProvider.greenAccentColor : const Color(0xFFDCFCE7),
          title: 'Total Sesi',
          value: '${status.totalSesiToday} Sesi',
          subtitle: 'Penyemprotan',
          isDark: isDark,
        ),
        _buildMetricItem(
          icon: status.isSolarCharging ? Icons.solar_power : Icons.battery_charging_full,
          iconColor: isDark ? ThemeProvider.blackColor : const Color(0xFFD97706),
          iconBg: isDark ? ThemeProvider.greenAccentColor : const Color(0xFFFEF3C7),
          title: 'Baterai 18650',
          value: '${status.batteryPercentage}%',
          subtitle: '${status.batteryVoltage.toStringAsFixed(1)}V • ${status.isSolarCharging ? "Solar" : "Batt"}',
          isDark: isDark,
        ),
        _buildMetricItem(
          icon: Icons.speed,
          iconColor: isDark ? ThemeProvider.blackColor : const Color(0xFF9333EA),
          iconBg: isDark ? ThemeProvider.greenAccentColor : const Color(0xFFF3E8FF),
          title: 'Debit Pompa',
          value: '5.0 ml/s',
          subtitle: 'Kalibrasi Presisi',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? ThemeProvider.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? [] : AppTheme.shadowSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Utendo',
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Utendo',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontFamily: 'Utendo', fontSize: 10, color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 5. STATISTIC BAR CHART ---
  Widget _buildStatisticChartCard(BuildContext context, bool isDark) {
    final titleColor = isDark ? Colors.white : AppTheme.textDark;
    final primaryAccent = isDark ? ThemeProvider.greenAccentColor : AppTheme.primaryColor;

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
                    'Minggu Ini • Total 1.250 ml',
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
                      'Target 1.500 ml',
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
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => isDark ? const Color(0xFF2C2D30) : Colors.white,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
                      final percentages = [44, 34, 110, 47, 32, 79, 24];
                      final vols = [440, 340, 1100, 470, 320, 790, 240];
                      return BarTooltipItem(
                        '${days[groupIndex]}\n${vols[groupIndex]} ml (${percentages[groupIndex]}%)',
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
                        final isWed = idx == 2;
                        final style = TextStyle(
                          fontFamily: 'Utendo',
                          color: isWed ? primaryAccent : (isDark ? Colors.grey.shade400 : Colors.grey),
                          fontWeight: isWed ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        );
                        String text;
                        switch (idx) {
                          case 0: text = 'Mon'; break;
                          case 1: text = 'Tue'; break;
                          case 2: text = 'Wed'; break;
                          case 3: text = 'Thu'; break;
                          case 4: text = 'Fri'; break;
                          case 5: text = 'Sat'; break;
                          case 6: text = 'Sun'; break;
                          default: text = ''; break;
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(text, style: style),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeBarGroup(0, 44, isHighlighted: false, isDark: isDark),
                  _makeBarGroup(1, 34, isHighlighted: false, isDark: isDark),
                  _makeBarGroup(2, 110, isHighlighted: true, isDark: isDark),
                  _makeBarGroup(3, 47, isHighlighted: false, isDark: isDark),
                  _makeBarGroup(4, 32, isHighlighted: false, isDark: isDark),
                  _makeBarGroup(5, 79, isHighlighted: false, isDark: isDark),
                  _makeBarGroup(6, 24, isHighlighted: false, isDark: isDark),
                ],
              ),
            ),
          ),
        ],
      ),
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
