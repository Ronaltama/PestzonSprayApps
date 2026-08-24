import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/theme_provider.dart';
import '../theme/theme.dart';
import '../services/database_helper.dart';
import '../models/spray_log.dart';

class DayDetailOverviewPage extends StatelessWidget {
  final String dayName;
  final String dateFormatted;
  final dynamic status;

  const DayDetailOverviewPage({
    super.key,
    required this.dayName,
    required this.dateFormatted,
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
          'Rincian Detail Hari $dayName',
          style: TextStyle(
            fontFamily: 'Utendo',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLG,
            vertical: AppTheme.spacingMD,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Summary Header Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: primaryAccent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateFormatted,
                      style: const TextStyle(
                        fontFamily: 'Utendo',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ThemeProvider.blackColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dayName,
                      style: const TextStyle(
                        fontFamily: 'Utendo',
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: ThemeProvider.blackColor,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Laporan Ringkasan Kinerja Penyemprotan & Sensor Lingkungan',
                      style: TextStyle(
                        fontFamily: 'Utendo',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingLG),

              // 4 Main Metric Breakdown Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  _buildMetricTile(
                    icon: Icons.water_drop,
                    title: 'Total Volume',
                    value: '${status.totalVolumeTodayMl.toInt()} ml',
                    subtitle: 'Target 1.500 ml',
                    isDark: isDark,
                    cardBg: cardBg,
                    titleColor: titleColor,
                  ),
                  _buildMetricTile(
                    icon: Icons.repeat,
                    title: 'Total Sesi',
                    value: '${status.totalSesiToday} Sesi',
                    subtitle: 'Penyemprotan OK',
                    isDark: isDark,
                    cardBg: cardBg,
                    titleColor: titleColor,
                  ),
                  _buildMetricTile(
                    icon: Icons.battery_charging_full,
                    title: 'Status Baterai',
                    value: '${status.batteryPercentage}%',
                    subtitle: '${status.batteryVoltage.toStringAsFixed(1)}V System',
                    isDark: isDark,
                    cardBg: cardBg,
                    titleColor: titleColor,
                  ),
                  _buildMetricTile(
                    icon: Icons.speed,
                    title: 'Debit Pompa',
                    value: '5.0 ml/s',
                    subtitle: 'Misting Flow Rate',
                    isDark: isDark,
                    cardBg: cardBg,
                    titleColor: titleColor,
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacingLG),

              // AI Expert System Status Box
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.psychology, color: ThemeProvider.blackColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Analisis AI & Rekomendasi Dosis',
                          style: TextStyle(
                            fontFamily: 'Utendo',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sistem AI mendeteksi kondisi kelembaban udara ideal. Dosis penyemprotan otomatis disesuaikan 30 detik/sesi untuk menjaga kelembaban optimal tanpa menyebabkan penggenangan.',
                      style: TextStyle(
                        fontFamily: 'Utendo',
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingLG),

              // Logs List for Day
              Text(
                'Riwayat Sesi Hari Ini',
                style: TextStyle(
                  fontFamily: 'Utendo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 10),

              FutureBuilder<List<SprayLog>>(
                future: dbHelper.getAllLogs(),
                builder: (context, snapshot) {
                  final logs = snapshot.data ?? [];
                  if (logs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          'Belum ada aktivitas penyemprotan hari ini.',
                          style: TextStyle(fontFamily: 'Utendo', color: isDark ? Colors.grey.shade400 : Colors.grey),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final timeStr = DateFormat('HH:mm WIB').format(log.timestamp);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.water_drop, color: ThemeProvider.blackColor, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${log.volumeMl.toInt()} ml ($timeStr)',
                                    style: TextStyle(
                                      fontFamily: 'Utendo',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: titleColor,
                                    ),
                                  ),
                                  Text(
                                    'Durasi ${log.durationSeconds}s • Mode ${log.mode}',
                                    style: TextStyle(
                                      fontFamily: 'Utendo',
                                      fontSize: 12,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'OK',
                                style: TextStyle(
                                  fontFamily: 'Utendo',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required bool isDark,
    required Color cardBg,
    required Color titleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ThemeProvider.greenAccentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: ThemeProvider.blackColor, size: 18),
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
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Utendo',
                  fontSize: 10,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
