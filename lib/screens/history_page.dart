import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/spray_log.dart';
import '../services/database_helper.dart';
import '../theme/theme.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dbHelper = Provider.of<DatabaseHelper>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F6),
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
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.history, color: AppTheme.primaryColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Database Lokal HP',
                            style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Riwayat Semprot',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
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
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: AppTheme.shadowSM,
                      ),
                      child: const Icon(Icons.delete_sweep, size: 20, color: AppTheme.errorColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingLG),

              FutureBuilder<List<SprayLog>>(
                future: dbHelper.getAllLogs(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                  }
                  final logs = snapshot.data ?? [];

                  if (logs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: AppTheme.shadowSM,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text('Belum ada riwayat penyemprotan tersimpan.', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(
                              'Riwayat otomatis tersimpan di SQLite HP setelah disemprot.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final totalVolume = logs.fold<double>(0, (sum, l) => sum + l.volumeMl);
                  final totalSesi = logs.length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary cards
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: AppTheme.shadowSM,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Sesi', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$totalSesi Sesi',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Volume', style: TextStyle(fontSize: 12, color: Color(0xFF15803D))),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${totalVolume.toInt()} ml',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF14532D)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingLG),

                      // Chart Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: AppTheme.shadowSM,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Grafik Aktivitas Penyemprotan',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 180,
                              child: _buildBarChart(logs),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingLG),

                      // History List
                      const Text(
                        'Daftar Riwayat Sesi',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: AppTheme.shadowSM,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: log.status == 'Success'
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    log.status == 'Success' ? Icons.water_drop : Icons.error_outline,
                                    color: log.status == 'Success' ? AppTheme.primaryColor : AppTheme.errorColor,
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
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        '$dateStr • Mode: ${log.mode} • via ${log.communicationMethod}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: log.status == 'Success' ? AppTheme.successColor : AppTheme.errorColor,
                                      ),
                                    ),
                                    Text(
                                      '🔋 ${log.batteryPercentage}%',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
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

  Widget _buildBarChart(List<SprayLog> logs) {
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
                return Text('${d.day}/${d.month}', style: const TextStyle(fontSize: 10, color: Colors.grey));
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
                color: AppTheme.primaryColor,
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
