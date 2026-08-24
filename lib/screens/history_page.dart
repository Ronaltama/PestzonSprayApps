import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/spray_log.dart';
import '../services/database_helper.dart';
import '../services/theme_provider.dart';
import '../theme/theme.dart';
import '../utils/app_notification.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime _selectedDate = DateTime.now();

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
                  final allLogs = snapshot.data ?? [];
                  final logs = allLogs.where((log) {
                    return log.timestamp.year == _selectedDate.year &&
                        log.timestamp.month == _selectedDate.month &&
                        log.timestamp.day == _selectedDate.day;
                  }).toList();

                  if (logs.isEmpty) {
                    final dateFormattedStr = DateFormat('dd MMM yyyy').format(_selectedDate);
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
                            Text(
                              'Belum ada riwayat penyemprotan tersimpan pada $dateFormattedStr.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, color: titleColor),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Riwayat otomatis tersimpan di SQLite HP setelah disemprot.',
                              textAlign: TextAlign.center,
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
                        'Daftar Riwayat Sesi (${DateFormat('dd MMM yyyy').format(_selectedDate)})',
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
    final monthText = '${monthNames[_selectedDate.month - 1]} ${_selectedDate.year}';
    final titleColor = isDark ? Colors.white : AppTheme.textDark;
    final primaryAccent = isDark ? ThemeProvider.greenAccentColor : AppTheme.primaryColor;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monday = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)
        .subtract(Duration(days: _selectedDate.weekday - 1));
    final daysAbbr = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

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
            // Tombol Icon Calendar (Menggantikan tombol panah)
            GestureDetector(
              onTap: () => _showCalendarModal(context, isDark),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? ThemeProvider.darkCardColor : Colors.white,
                  shape: BoxShape.circle,
                  border: isDark ? Border.all(color: primaryAccent.withValues(alpha: 0.3)) : null,
                  boxShadow: isDark ? [] : AppTheme.shadowSM,
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  size: 20,
                  color: isDark ? ThemeProvider.greenAccentColor : AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          children: List.generate(7, (index) {
            final dayDate = monday.add(Duration(days: index));
            final dayLetter = daysAbbr[index];
            final dateNum = DateFormat('dd').format(dayDate);
            final isSelected = dayDate.year == _selectedDate.year &&
                dayDate.month == _selectedDate.month &&
                dayDate.day == _selectedDate.day;
            final isFuture = dayDate.isAfter(todayStart);

            return _buildDateItem(
              dayLetter,
              dateNum,
              dayDate,
              isSelected: isSelected,
              isFuture: isFuture,
              isDark: isDark,
            );
          }),
        ),
      ],
    );
  }

  // Custom styled Calendar Modal matching application theme
  Future<void> _showCalendarModal(BuildContext context, bool isDark) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _selectedDate.isAfter(today) ? today : _selectedDate;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: today, // Rule: Future dates (hari esok) cannot be selected!
      helpText: 'PILIH TANGGAL RIWAYAT',
      cancelText: 'BATAL',
      confirmText: 'PILIH',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: ThemeProvider.greenAccentColor,
                    onPrimary: ThemeProvider.blackColor,
                    surface: ThemeProvider.darkCardColor,
                    onSurface: Colors.white,
                    secondary: ThemeProvider.greenAccentColor,
                  )
                : ColorScheme.light(
                    primary: AppTheme.primaryColor,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AppTheme.textDark,
                  ),
            dialogTheme: DialogThemeData(
              backgroundColor: isDark ? ThemeProvider.darkBgColor : Colors.white,
            ),
            datePickerTheme: DatePickerThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              headerBackgroundColor: isDark ? ThemeProvider.darkCardColor : AppTheme.primaryColor,
              headerForegroundColor: isDark ? ThemeProvider.greenAccentColor : Colors.white,
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return isDark ? ThemeProvider.greenAccentColor : AppTheme.primaryColor;
                }
                return null;
              }),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return isDark ? Colors.grey.shade700 : Colors.grey.shade400;
                }
                if (states.contains(WidgetState.selected)) {
                  return isDark ? ThemeProvider.blackColor : Colors.white;
                }
                return isDark ? Colors.white : AppTheme.textDark;
              }),
              todayBorder: BorderSide(color: isDark ? ThemeProvider.greenAccentColor : AppTheme.primaryColor),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: isDark ? ThemeProvider.greenAccentColor : AppTheme.primaryColor,
                textStyle: const TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Widget _buildDateItem(
    String dayLetter,
    String dateNum,
    DateTime dayDate, {
    required bool isSelected,
    required bool isFuture,
    required bool isDark,
  }) {
    final activeBg = isDark ? ThemeProvider.greenAccentColor : const Color(0xFFDCFCE7);
    final activeBorder = isDark ? ThemeProvider.greenAccentColor : AppTheme.primaryColor;
    final activeText = isDark ? ThemeProvider.blackColor : const Color(0xFF14532D);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (isFuture) {
            AppNotification.show(
              context,
              'Hari esok belum dapat dipilih.',
              isError: true,
            );
            return;
          }
          setState(() {
            _selectedDate = dayDate;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? activeBg
                : (isFuture
                    ? (isDark ? const Color(0xFF181818) : const Color(0xFFF3F4F6))
                    : (isDark ? ThemeProvider.darkCardColor : Colors.white)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? activeBorder : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: (isSelected || isDark || isFuture) ? [] : AppTheme.shadowSM,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                dayLetter,
                style: TextStyle(
                  fontFamily: 'Utendo',
                  fontSize: 10,
                  color: isSelected
                      ? activeText
                      : (isFuture
                          ? (isDark ? Colors.grey.shade700 : Colors.grey.shade400)
                          : Colors.grey.shade500),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateNum,
                style: TextStyle(
                  fontFamily: 'Utendo',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? activeText
                      : (isFuture
                          ? (isDark ? Colors.grey.shade700 : Colors.grey.shade400)
                          : (isDark ? Colors.white : AppTheme.textDark)),
                ),
              ),
            ],
          ),
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
}
