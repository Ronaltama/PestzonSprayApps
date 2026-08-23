import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/bluetooth_service.dart';
import '../services/mqtt_service.dart';
import '../services/database_helper.dart';
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

    final isBleConnected = btService.isConnected;
    final isMqttConnected = mqttService.isConnected && mqttService.isEspOnline;

    // Fallback logic: Prefer BLE if connected, else MQTT
    final status = isBleConnected
        ? btService.deviceStatus
        : (isMqttConnected && mqttService.latestStatus != null
            ? mqttService.latestStatus!
            : btService.deviceStatus);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F6), // Soft off-white green tint
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
              _buildHeader(context, isBleConnected, isMqttConnected, dbHelper, btService, mqttService),
              const SizedBox(height: AppTheme.spacingLG),

              // 2. SOLAR & BATTERY CARD (Restored to original Solar Battery Card design)
              _buildSolarBatteryCard(context, status),
              const SizedBox(height: AppTheme.spacingLG),

              // 3. PUMP CONTROL CARD (Interactive Control)
              _buildPumpControlCard(context, btService, mqttService, dbHelper, status, isBleConnected, isMqttConnected),
              const SizedBox(height: AppTheme.spacingLG),

              // 4. METRIC GRID CARDS (2x2 Grid)
              _buildMetricGrid(context, status),
              const SizedBox(height: AppTheme.spacingXL),

              // 5. STATISTIC BAR CHART (Matching Right Screen Chart)
              _buildStatisticChartCard(context),
              const SizedBox(height: AppTheme.spacingXL),

              // 6. INTERACTIVE DATE STRIP & TIMELINE SCHEDULE
              _buildDateAndScheduleSection(context, dbHelper),
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
  ) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
          child: const Icon(Icons.eco, color: AppTheme.primaryColor, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selamat Pagi! 🌱',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Text(
                'Smart Sprayer AI',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        // Interactive Badge
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
          child: _buildConnectionBadge(isBle, isMqtt),
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
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: AppTheme.shadowSM,
            ),
            child: const Icon(Icons.sync, size: 20, color: AppTheme.textDark),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionBadge(bool isBle, bool isMqtt) {
    Color bg;
    Color fg;
    String text;

    if (isBle) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
      text = 'BLE Active';
    } else if (isMqtt) {
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1D4ED8);
      text = 'MQTT Online';
    } else {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
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
            style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // --- 2. RESTORED SOLAR & BATTERY CARD ---
  Widget _buildSolarBatteryCard(BuildContext context, dynamic status) {
    final battery = status.batteryPercentage;
    final isSolar = status.isSolarCharging;
    final voltage = status.batteryVoltage;

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSolar ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isSolar ? Icons.solar_power : Icons.battery_charging_full,
                      color: isSolar ? const Color(0xFFD97706) : AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sistem Daya Kebun',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Baterai 18650 & Panel Surya',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSolar ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isSolar ? '⚡ Solar Charging' : '🔋 Battery Only',
                  style: TextStyle(
                    color: isSolar ? const Color(0xFFB45309) : const Color(0xFF15803D),
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
                    backgroundColor: const Color(0xFFF3F4F6),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      battery > 50
                          ? AppTheme.primaryColor
                          : (battery > 20 ? AppTheme.accentYellow : AppTheme.errorColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '$battery%',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tegangan Baterai: ${voltage.toStringAsFixed(1)}V (Regulator 3.3V System OK)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
  ) {
    final isRunning = status.isPumpRunning;
    final remainingSec = status.activeDurationSeconds;

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isRunning ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.water_drop,
                      color: isRunning ? AppTheme.primaryColor : Colors.grey.shade600,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pompa Misting DC',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        isRunning ? 'Status: Menyemprot' : 'Status: Standby',
                        style: TextStyle(
                          fontSize: 12,
                          color: isRunning ? AppTheme.primaryColor : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '~5 ml/detik',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (isRunning) ...[
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(color: AppTheme.primaryColor),
                  const SizedBox(height: 12),
                  Text(
                    'Menyemprot... Sisa $remainingSec Detik',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (isBle) {
                          btService.stopSpraying();
                        } else if (isMqtt) {
                          mqttService.stopSpraying();
                        }
                      },
                      icon: const Icon(Icons.stop),
                      label: const Text('HENTIKAN POMPA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Durasi Semprot', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                Text(
                  '${_selectedDuration.toInt()} Detik (${(_selectedDuration * 5).toInt()} ml)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.primaryColor,
                inactiveTrackColor: const Color(0xFFE5E7EB),
                thumbColor: AppTheme.primaryColor,
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
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  (isBle || isMqtt) ? 'SEMPROT SEKARANG' : 'SAMBUNGKAN KONEKSI DULU',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- 4. METRIC GRID (2x2 Grid) ---
  Widget _buildMetricGrid(BuildContext context, dynamic status) {
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
          iconColor: const Color(0xFF0284C7),
          iconBg: const Color(0xFFE0F2FE),
          title: 'Total Volume',
          value: '${status.totalVolumeTodayMl.toInt()} ml',
          subtitle: 'Hari ini',
        ),
        _buildMetricItem(
          icon: Icons.repeat,
          iconColor: const Color(0xFF16A34A),
          iconBg: const Color(0xFFDCFCE7),
          title: 'Total Sesi',
          value: '${status.totalSesiToday} Sesi',
          subtitle: 'Penyemprotan',
        ),
        _buildMetricItem(
          icon: status.isSolarCharging ? Icons.solar_power : Icons.battery_charging_full,
          iconColor: const Color(0xFFD97706),
          iconBg: const Color(0xFFFEF3C7),
          title: 'Baterai 18650',
          value: '${status.batteryPercentage}%',
          subtitle: '${status.batteryVoltage.toStringAsFixed(1)}V • ${status.isSolarCharging ? "Solar" : "Batt"}',
        ),
        _buildMetricItem(
          icon: Icons.speed,
          iconColor: const Color(0xFF9333EA),
          iconBg: const Color(0xFFF3E8FF),
          title: 'Debit Pompa',
          value: '5.0 ml/s',
          subtitle: 'Kalibrasi Presisi',
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
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.shadowSM,
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
                    fontSize: 12,
                    color: Colors.grey.shade600,
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 5. STATISTIC BAR CHART ---
  Widget _buildStatisticChartCard(BuildContext context) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Statistik',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              Icon(Icons.more_horiz, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Volume ',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const Text(
                '1250 ml ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              Text(
                'Target: 1500 ml',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 120,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        const style = TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        );
                        String text;
                        switch (val.toInt()) {
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
                  _makeBarGroup(0, 44, "44%", isHighlighted: false),
                  _makeBarGroup(1, 34, "34%", isHighlighted: false),
                  _makeBarGroup(2, 110, "110%", isHighlighted: true),
                  _makeBarGroup(3, 47, "47%", isHighlighted: false),
                  _makeBarGroup(4, 32, "32%", isHighlighted: false),
                  _makeBarGroup(5, 79, "79%", isHighlighted: false),
                  _makeBarGroup(6, 24, "24%", isHighlighted: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, String label, {required bool isHighlighted}) {
    return BarChartGroupData(
      x: x,
      showingTooltipIndicators: [0],
      barRods: [
        BarChartRodData(
          toY: y,
          color: isHighlighted ? const Color(0xFF10B981) : const Color(0xFFDCFCE7),
          width: 18,
          borderRadius: BorderRadius.circular(10),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 120,
            color: const Color(0xFFF3F4F6),
          ),
        ),
      ],
    );
  }

  // --- 6. INTERACTIVE DATE STRIP & TIMELINE SCHEDULE ---
  Widget _buildDateAndScheduleSection(BuildContext context, DatabaseHelper dbHelper) {
    final monthNames = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final monthText = '${monthNames[_currentMonth.month - 1]} ${_currentMonth.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Selector Header with Interactive Arrows
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              monthText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
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
                  child: _buildCircleArrow(Icons.chevron_left),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
                    });
                  },
                  child: _buildCircleArrow(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Fully Interactive Horizontal Date Strip
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_weekDays.length, (index) {
            final item = _weekDays[index];
            final isSelected = _selectedDayIndex == index;
            return _buildDateItem(item['day']!, item['date']!, index, isSelected: isSelected);
          }),
        ),
        const SizedBox(height: 20),

        // Schedule Timeline List for Selected Day
        FutureBuilder<List<SpraySchedule>>(
          future: dbHelper.getAllSchedules(),
          builder: (context, snapshot) {
            final schedules = snapshot.data ?? [];

            if (schedules.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text(
                    'Belum ada jadwal otomatis untuk hari ini.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.shadowSM,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: sched.isActive
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.alarm,
                          color: sched.isActive
                              ? const Color(0xFFD97706)
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
                              sched.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${sched.timeFormatted} • Durasi ${sched.durationSeconds} Detik',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: sched.isActive,
                        activeColor: AppTheme.primaryColor,
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

  Widget _buildCircleArrow(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: AppTheme.shadowSM,
      ),
      child: Icon(icon, size: 18, color: AppTheme.textDark),
    );
  }

  Widget _buildDateItem(String dayLetter, String dateNum, int index, {required bool isSelected}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDayIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDCFCE7) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected ? [] : AppTheme.shadowSM,
        ),
        child: Column(
          children: [
            Text(
              dayLetter,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dateNum,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isSelected ? const Color(0xFF14532D) : AppTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
