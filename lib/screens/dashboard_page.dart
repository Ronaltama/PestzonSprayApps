import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/bluetooth_service.dart';
import '../services/mqtt_service.dart';
import '../services/database_helper.dart';
import '../services/theme_provider.dart';
import '../models/spray_schedule.dart';
import '../theme/theme.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  double _selectedDuration = 30.0;
  int _selectedDayIndex = 3; // Default to Wednesday 10
  DateTime _currentMonth = DateTime(2025, 8, 1); // August 2025

  final List<Map<String, String>> _weekDays = [
    {'day': 'S', 'date': '07'},
    {'day': 'M', 'date': '08'},
    {'day': 'T', 'date': '09'},
    {'day': 'W', 'date': '10'},
    {'day': 'T', 'date': '11'},
    {'day': 'F', 'date': '12'},
    {'day': 'S', 'date': '13'},
  ];

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

              // 2. INTERACTIVE DATE STRIP & TIMELINE SCHEDULE (Moved to top above Solar Battery card)
              _buildDateAndScheduleSection(context, dbHelper, isDark),
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
            ],
          ),
        ),
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

  // --- 6. INTERACTIVE DATE STRIP & TIMELINE SCHEDULE ---
  Widget _buildDateAndScheduleSection(BuildContext context, DatabaseHelper dbHelper, bool isDark) {
    final monthNames = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final monthText = '${monthNames[_currentMonth.month - 1]} ${_currentMonth.year}';
    final titleColor = isDark ? Colors.white : AppTheme.textDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              monthText,
              style: TextStyle(
                fontFamily: 'Utendo',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
                    });
                  },
                  child: _buildCircleArrow(Icons.chevron_left, isDark),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
                    });
                  },
                  child: _buildCircleArrow(Icons.chevron_right, isDark),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_weekDays.length, (index) {
            final item = _weekDays[index];
            final isSelected = _selectedDayIndex == index;
            return _buildDateItem(item['day']!, item['date']!, index, isSelected: isSelected, isDark: isDark);
          }),
        ),
        const SizedBox(height: 20),

        FutureBuilder<List<SpraySchedule>>(
          future: dbHelper.getAllSchedules(),
          builder: (context, snapshot) {
            final schedules = snapshot.data ?? [];
            final cardBg = isDark ? ThemeProvider.darkCardColor : Colors.white;

            if (schedules.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'Belum ada jadwal otomatis untuk hari ini.',
                    style: TextStyle(fontFamily: 'Utendo', color: isDark ? Colors.grey.shade400 : Colors.grey, fontSize: 13),
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: schedules.length,
              itemBuilder: (context, index) {
                final sched = schedules[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isDark ? [] : AppTheme.shadowSM,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? (sched.isActive ? ThemeProvider.greenAccentColor : const Color(0xFF2C2D30))
                              : (sched.isActive ? const Color(0xFFFEF3C7) : const Color(0xFFF3F4F6)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.alarm,
                          color: isDark
                              ? (sched.isActive ? ThemeProvider.blackColor : Colors.grey)
                              : (sched.isActive ? const Color(0xFFD97706) : Colors.grey),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sched.title,
                              style: TextStyle(
                                fontFamily: 'Utendo',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : AppTheme.textDark,
                              ),
                            ),
                            Text(
                              '${sched.timeFormatted} • Durasi ${sched.durationSeconds} Detik',
                              style: TextStyle(fontFamily: 'Utendo', fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: sched.isActive,
                        activeTrackColor: isDark ? ThemeProvider.greenAccentColor : AppTheme.primaryColor,
                        activeThumbColor: isDark ? ThemeProvider.blackColor : null,
                        onChanged: (val) async {
                          final updated = sched.copyWith(isActive: val);
                          await dbHelper.updateSchedule(updated);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCircleArrow(IconData icon, bool isDark) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isDark ? ThemeProvider.darkCardColor : Colors.white,
        shape: BoxShape.circle,
        boxShadow: isDark ? [] : AppTheme.shadowSM,
      ),
      child: Icon(icon, size: 18, color: isDark ? Colors.white : AppTheme.textDark),
    );
  }

  Widget _buildDateItem(String dayLetter, String dateNum, int index, {required bool isSelected, required bool isDark}) {
    final activeBg = isDark ? ThemeProvider.greenAccentColor : const Color(0xFFDCFCE7);
    final activeBorder = isDark ? ThemeProvider.greenAccentColor : AppTheme.primaryColor;
    final activeText = isDark ? ThemeProvider.blackColor : const Color(0xFF14532D);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDayIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : (isDark ? ThemeProvider.darkCardColor : Colors.white),
          borderRadius: BorderRadius.circular(10), // Squared rectangular date chips
          border: Border.all(
            color: isSelected ? activeBorder : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: (isSelected || isDark) ? [] : AppTheme.shadowSM,
        ),
        child: Column(
          children: [
            Text(
              dayLetter,
              style: TextStyle(
                fontFamily: 'Utendo',
                fontSize: 11,
                color: isSelected ? activeText : Colors.grey.shade500,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dateNum,
              style: TextStyle(
                fontFamily: 'Utendo',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isSelected ? activeText : (isDark ? Colors.white : AppTheme.textDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
