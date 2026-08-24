import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/spray_schedule.dart';
import '../services/database_helper.dart';
import '../services/bluetooth_service.dart';
import '../services/mqtt_service.dart';
import '../services/theme_provider.dart';
import '../theme/theme.dart';
import '../utils/app_notification.dart';

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    final dbHelper = Provider.of<DatabaseHelper>(context);
    final btService = Provider.of<BluetoothService>(context);
    final mqttService = Provider.of<MqttService>(context);
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
              // Header Title
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
                        child: Icon(Icons.alarm, color: isDark ? ThemeProvider.blackColor : AppTheme.primaryColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Penyemprotan Otomatis',
                            style: TextStyle(fontFamily: 'Utendo', fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Jadwal Semprot',
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
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Sinkronisasi Jadwal ke Alat',
                        onPressed: () async {
                          final schedules = await dbHelper.getAllSchedules();
                          if (btService.isConnected) {
                            btService.syncSchedules(schedules);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Sinkronisasi Jadwal (BLE) Berhasil')),
                              );
                            }
                          } else if (mqttService.isConnected) {
                            mqttService.syncSchedules(schedules);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Sinkronisasi Jadwal (MQTT) Berhasil')),
                              );
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Gagal! Tidak ada koneksi ke Alat.')),
                              );
                            }
                          }
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cardBg,
                            shape: BoxShape.circle,
                            boxShadow: isDark ? [] : AppTheme.shadowSM,
                          ),
                          child: Icon(Icons.sync, size: 20, color: isDark ? primaryAccent : AppTheme.textDark),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _showAddScheduleDialog(context, dbHelper, isDark, primaryAccent),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryAccent,
                            shape: BoxShape.circle,
                            boxShadow: isDark ? [] : AppTheme.shadowSM,
                          ),
                          child: Icon(Icons.add, size: 20, color: isDark ? ThemeProvider.blackColor : Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingLG),

              // Schedules List
              FutureBuilder<List<SpraySchedule>>(
                future: dbHelper.getAllSchedules(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: primaryAccent));
                  }
                  final schedules = snapshot.data ?? [];

                  if (schedules.isEmpty) {
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
                            Icon(Icons.alarm_off, size: 48, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada jadwal penyemprotan otomatis.',
                              style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, color: titleColor),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tambahkan jadwal rutin agar ESP32 menyemprot otomatis.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'Utendo', fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showAddScheduleDialog(context, dbHelper, isDark, primaryAccent),
                              icon: Icon(Icons.add, color: isDark ? ThemeProvider.blackColor : Colors.white),
                              label: Text('Tambah Jadwal Baru', style: TextStyle(fontFamily: 'Utendo', color: isDark ? ThemeProvider.blackColor : Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ],
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
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: isDark ? [] : AppTheme.shadowSM,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: sched.isActive
                                    ? (isDark ? primaryAccent : const Color(0xFFDCFCE7))
                                    : (isDark ? const Color(0xFF2C2D30) : const Color(0xFFF3F4F6)),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.schedule,
                                color: sched.isActive
                                    ? (isDark ? ThemeProvider.blackColor : AppTheme.primaryColor)
                                    : Colors.grey,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sched.timeFormatted,
                                    style: TextStyle(
                                      fontFamily: 'Utendo',
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: sched.isActive ? titleColor : Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    '${sched.title} • Durasi: ${sched.durationSeconds} Detik',
                                    style: TextStyle(fontFamily: 'Utendo', fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: sched.isActive,
                              activeTrackColor: primaryAccent,
                              activeThumbColor: isDark ? ThemeProvider.blackColor : null,
                              onChanged: (val) async {
                                final updated = sched.copyWith(isActive: val);
                                await dbHelper.updateSchedule(updated);
                                if (context.mounted) {
                                  AppNotification.show(
                                    context,
                                    val ? 'Jadwal "${sched.title}" diaktifkan' : 'Jadwal "${sched.title}" dinonaktifkan',
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                              onPressed: () async {
                                if (sched.id != null) {
                                  await dbHelper.deleteSchedule(sched.id!);
                                  if (context.mounted) {
                                    AppNotification.show(
                                      context,
                                      'Jadwal "${sched.title}" dihapus',
                                    );
                                  }
                                }
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
          ),
        ),
      ),
    );
  }

  void _showAddScheduleDialog(BuildContext context, DatabaseHelper dbHelper, bool isDark, Color primaryAccent) {
    final titleController = TextEditingController(text: 'Semprot Otomatis');
    TimeOfDay selectedTime = TimeOfDay.now();
    double durationSeconds = 30.0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Tambah Jadwal Semprot', style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Jadwal',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    tileColor: isDark ? const Color(0xFF2C2D30) : const Color(0xFFF3F4F6),
                    leading: Icon(Icons.access_time, color: primaryAccent),
                    title: const Text('Waktu Semprot', style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold)),
                    subtitle: Text(selectedTime.format(context), style: const TextStyle(fontFamily: 'Utendo')),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedTime = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Durasi:', style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold)),
                      Text('${durationSeconds.toInt()} Detik', style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold, color: primaryAccent)),
                    ],
                  ),
                  Slider(
                    value: durationSeconds,
                    min: 5,
                    max: 120,
                    divisions: 23,
                    activeColor: primaryAccent,
                    onChanged: (val) {
                      setDialogState(() {
                        durationSeconds = val;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal', style: TextStyle(fontFamily: 'Utendo', color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    if (titleController.text.trim().isNotEmpty) {
                      final newSched = SpraySchedule(
                        title: titleController.text.trim(),
                        hour: selectedTime.hour,
                        minute: selectedTime.minute,
                        durationSeconds: durationSeconds.toInt(),
                        isActive: true,
                      );
                      await dbHelper.insertSchedule(newSched);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: Text('Simpan', style: TextStyle(fontFamily: 'Utendo', color: isDark ? ThemeProvider.blackColor : Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
