import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/theme_provider.dart';
import '../theme/theme.dart';
import '../services/database_helper.dart';
import '../models/spray_log.dart';

class WeeklyDetailOverviewPage extends StatelessWidget {
  final dynamic status;

  const WeeklyDetailOverviewPage({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final dbHelper = Provider.of<DatabaseHelper>(context);
    final isDark = themeProvider.isDarkMode;

    final primaryAccent = ThemeProvider.greenAccentColor;
    final cardBg = isDark ? ThemeProvider.darkCardColor : Colors.white;
    final titleColor = isDark ? Colors.white : AppTheme.textDark;

    final daysInIndonesian = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

    final now = DateTime.now();
    final todayWeekday = now.weekday - 1; // 0 for Mon ... 6 for Sun
    final mondayStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: todayWeekday));
    final sundayDate = mondayStart.add(const Duration(days: 6));

    final weekRangeStr = '${DateFormat('dd/MM/yyyy').format(mondayStart)} - ${DateFormat('dd/MM/yyyy').format(sundayDate)}';

    return Scaffold(
      backgroundColor: isDark ? ThemeProvider.darkBgColor : const Color(0xFFF6F8F6),
      appBar: AppBar(
        backgroundColor: isDark ? ThemeProvider.darkBgColor : const Color(0xFFF6F8F6),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? primaryAccent : AppTheme.textDark,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Rincian Data Seminggu',
          style: TextStyle(
            fontFamily: 'Utendo',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<SprayLog>>(
          future: dbHelper.getAllLogs(),
          builder: (context, snapshot) {
            final allLogs = snapshot.data ?? [];

            // Group logs per day (0..6)
            final List<List<SprayLog>> dayLogs = List.generate(7, (_) => []);
            final List<double> dayVolumes = List.filled(7, 0.0);
            final List<int> daySessions = List.filled(7, 0);

            for (int i = 0; i < 7; i++) {
              final targetDate = mondayStart.add(Duration(days: i));
              final logsForDay = allLogs.where((log) {
                return log.timestamp.year == targetDate.year &&
                    log.timestamp.month == targetDate.month &&
                    log.timestamp.day == targetDate.day;
              }).toList();

              dayLogs[i] = logsForDay;
              daySessions[i] = logsForDay.length;
              dayVolumes[i] = logsForDay.fold(0.0, (sum, l) => sum + l.volumeMl);
            }

            // Update live status for today if larger
            if (status != null && status.totalVolumeTodayMl > dayVolumes[todayWeekday]) {
              dayVolumes[todayWeekday] = status.totalVolumeTodayMl;
            }
            if (status != null && status.totalSesiToday > daySessions[todayWeekday]) {
              daySessions[todayWeekday] = status.totalSesiToday;
            }

            final totalWeeklyVolume = dayVolumes.reduce((a, b) => a + b);
            final totalWeeklySessions = daySessions.reduce((a, b) => a + b);

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLG,
                vertical: AppTheme.spacingMD,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Weekly Summary Hero Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: primaryAccent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              weekRangeStr,
                              style: const TextStyle(
                                fontFamily: 'Utendo',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: ThemeProvider.blackColor,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: ThemeProvider.blackColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Target 1.500 ml',
                                style: TextStyle(
                                  fontFamily: 'Utendo',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: ThemeProvider.greenAccentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${totalWeeklyVolume.toInt()} ml',
                          style: const TextStyle(
                            fontFamily: 'Utendo',
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: ThemeProvider.blackColor,
                            letterSpacing: -1.0,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total Penyemprotan Minggu Ini ($totalWeeklySessions Sesi)',
                          style: const TextStyle(
                            fontFamily: 'Utendo',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingLG),

                  Text(
                    'Rincian Data Per Hari (Senin - Minggu)',
                    style: TextStyle(
                      fontFamily: 'Utendo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 7 Days Cards List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 7,
                    itemBuilder: (context, index) {
                      final dayName = daysInIndonesian[index];
                      final dayDate = mondayStart.add(Duration(days: index));
                      final dateFormatted = DateFormat('dd/MM/yyyy').format(dayDate);
                      final volume = dayVolumes[index];
                      final sessions = daySessions[index];
                      final logs = dayLogs[index];
                      final isToday = index == todayWeekday;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: isToday
                              ? Border.all(color: primaryAccent.withValues(alpha: 0.6), width: 1.5)
                              : null,
                          boxShadow: isDark ? [] : AppTheme.shadowSM,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Day Header Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      dayName,
                                      style: TextStyle(
                                        fontFamily: 'Utendo',
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isToday ? primaryAccent : titleColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      dateFormatted,
                                      style: TextStyle(
                                        fontFamily: 'Utendo',
                                        fontSize: 12,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                      ),
                                    ),
                                    if (isToday) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: primaryAccent.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Hari Ini',
                                          style: TextStyle(
                                            fontFamily: 'Utendo',
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: primaryAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: volume > 0
                                        ? (isDark ? primaryAccent : const Color(0xFFDCFCE7))
                                        : (isDark ? const Color(0xFF2C2D30) : const Color(0xFFF3F4F6)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    volume > 0 ? '${volume.toInt()} ml' : '0 ml',
                                    style: TextStyle(
                                      fontFamily: 'Utendo',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: volume > 0
                                          ? (isDark ? ThemeProvider.blackColor : AppTheme.primaryColor)
                                          : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Content: Logs or Empty State
                            if (volume == 0 && logs.isEmpty) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Belum ada data penyemprotan',
                                    style: TextStyle(
                                      fontFamily: 'Utendo',
                                      fontSize: 12,
                                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Text(
                                'Total $sessions Sesi Penyemprotan:',
                                style: TextStyle(
                                  fontFamily: 'Utendo',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (logs.isNotEmpty)
                                ...logs.map((log) {
                                  final timeStr = DateFormat('HH:mm').format(log.timestamp);
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.water_drop,
                                              size: 14,
                                              color: primaryAccent,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Jam $timeStr WIB (${log.volumeMl.toInt()} ml, ${log.durationSeconds}s)',
                                              style: TextStyle(
                                                fontFamily: 'Utendo',
                                                fontSize: 12,
                                                color: titleColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          log.mode,
                                          style: TextStyle(
                                            fontFamily: 'Utendo',
                                            fontSize: 11,
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                })
                              else
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.water_drop,
                                        size: 14,
                                        color: primaryAccent,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Penyemprotan hari ini (${volume.toInt()} ml)',
                                        style: TextStyle(
                                          fontFamily: 'Utendo',
                                          fontSize: 12,
                                          color: titleColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
