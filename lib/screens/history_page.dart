import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/spray_log.dart';
import '../services/database_helper.dart';
import '../services/theme_provider.dart';
import '../theme/theme.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int _selectedDayIndex = 1; // Default to Senin 08
  DateTime _currentMonth = DateTime(2025, 8, 1); // August 2025

  final List<Map<String, String>> _weekDays = [
    {'day': 'M', 'date': '07', 'fullDay': 'Minggu', 'fullDate': '07/08/2025'},
    {'day': 'S', 'date': '08', 'fullDay': 'Senin', 'fullDate': '08/08/2025'},
    {'day': 'S', 'date': '09', 'fullDay': 'Selasa', 'fullDate': '09/08/2025'},
    {'day': 'R', 'date': '10', 'fullDay': 'Rabu', 'fullDate': '10/08/2025'},
    {'day': 'K', 'date': '11', 'fullDay': 'Kamis', 'fullDate': '11/08/2025'},
    {'day': 'J', 'date': '12', 'fullDay': 'Jumat', 'fullDate': '12/08/2025'},
    {'day': 'S', 'date': '13', 'fullDay': 'Sabtu', 'fullDate': '13/08/2025'},
  ];

  @override
  Widget build(BuildContext context) {
    final dbHelper = Provider.of<DatabaseHelper>(context);
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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? primaryAccent : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.history, color: isDark ? ThemeProvider.blackColor : AppTheme.primaryColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Database Lokal HP',
                            style: TextStyle(fontFamily: 'Utendo', fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Riwayat Semprot',
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
                  IconButton(
                    tooltip: 'Hapus Semua Riwayat',
                    onPressed: () => _confirmClearLogs(context, dbHelper),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cardBg,
                        shape: BoxShape.circle,
                        boxShadow: isDark ? [] : AppTheme.shadowSM,
                      ),
                      child: const Icon(Icons.delete_sweep, size: 20, color: AppTheme.errorColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingLG),

              // Calendar Date Strip Section
              _buildDateStripSection(context, isDark),
              const SizedBox(height: AppTheme.spacingLG),

              FutureBuilder<List<SprayLog>>(
                future: dbHelper.getAllLogs(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: primaryAccent));
                  }
                  final logs = snapshot.data ?? [];

                  if (logs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: isDark ? [] : AppTheme.shadowSM,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off, size: 48, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('Belum ada riwayat penyemprotan tersimpan.', style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, color: titleColor)),
                            const SizedBox(height: 8),
                            Text(
                              'Riwayat otomatis tersimpan di SQLite HP setelah disemprot.',
                              style: TextStyle(fontFamily: 'Utendo', fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Chart Card
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
                              'Grafik Aktivitas Penyemprotan',
                              style: TextStyle(fontFamily: 'Utendo', fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 180,
                              child: _buildBarChart(logs, isDark, primaryAccent),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingLG),

                      // History List
                      Text(
                        'Daftar Riwayat Sesi',
                        style: TextStyle(fontFamily: 'Utendo', fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
                      ),
                      const SizedBox(height: 10),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(log.timestamp);

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
                                    color: log.status == 'Success'
                                        ? (isDark ? primaryAccent : const Color(0xFFDCFCE7))
                                        : const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    log.status == 'Success' ? Icons.water_drop : Icons.error_outline,
                                    color: log.status == 'Success'
                                        ? (isDark ? ThemeProvider.blackColor : AppTheme.primaryColor)
                                        : AppTheme.errorColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${log.volumeMl.toInt()} ml (${log.durationSeconds} Detik)',
                                        style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, fontSize: 14, color: titleColor),
                                      ),
                                      Text(
                                        '$dateStr • Mode: ${log.mode} • via ${log.communicationMethod}',
                                        style: TextStyle(fontFamily: 'Utendo', fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      log.status,
                                      style: TextStyle(
                                        fontFamily: 'Utendo',
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: log.status == 'Success' ? (isDark ? primaryAccent : AppTheme.successColor) : AppTheme.errorColor,
                                      ),
                                    ),
                                    Text(
                                      '🔋 ${log.batteryPercentage}%',
                                      style: TextStyle(fontFamily: 'Utendo', fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 80),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- CALENDAR DATE STRIP SECTION ---
  Widget _buildDateStripSection(BuildContext context, bool isDark) {
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
          borderRadius: BorderRadius.circular(10),
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

  Widget _buildBarChart(List<SprayLog> logs, bool isDark, Color primaryAccent) {
    final recent = logs.take(7).toList().reversed.toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (recent.map((e) => e.volumeMl).reduce((a, b) => a > b ? a : b) * 1.2),
        barTouchData: const BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= recent.length) return const SizedBox();
                final d = recent[idx].timestamp;
                return Text(
                  '${d.day}/${d.month}',
                  style: TextStyle(fontFamily: 'Utendo', fontSize: 10, color: isDark ? Colors.grey.shade400 : Colors.grey),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: recent.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: item.volumeMl,
                color: primaryAccent,
                width: 16,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _confirmClearLogs(BuildContext context, DatabaseHelper dbHelper) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Hapus Semua Riwayat?'),
        content: const Text(
          'Semua catatan riwayat penyemprotan di database lokal HP akan dihapus permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await dbHelper.clearAllLogs();
              if (context.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
