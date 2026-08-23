import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/spray_schedule.dart';
import '../services/database_helper.dart';
import '../services/bluetooth_service.dart';
import '../services/mqtt_service.dart';
import '../theme/theme.dart';

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    final dbHelper = Provider.of<DatabaseHelper>(context);
    final btService = Provider.of<BluetoothService>(context);
    final mqttService = Provider.of<MqttService>(context);

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
              // Header Title
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
                        child: const Icon(Icons.alarm, color: AppTheme.primaryColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Penyemprotan Otomatis',
                            style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Jadwal Semprot',
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
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Sinkronisasi Jadwal ke Alat',
                        onPressed: () async {
                          final schedules = await dbHelper.getAllSchedules();
                          if (btService.isConnected) {
                            btService.syncSchedules(schedules);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sinkronisasi Jadwal (BLE) Berhasil')),
                            );
                          } else if (mqttService.isConnected) {
                            mqttService.syncSchedules(schedules);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sinkronisasi Jadwal (MQTT) Berhasil')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Gagal! Tidak ada koneksi ke Alat.')),
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
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _showAddScheduleDialog(context, dbHelper),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: AppTheme.shadowSM,
                          ),
                          child: const Icon(Icons.add, size: 20, color: Colors.white),
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
                    return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                  }
                  final schedules = snapshot.data ?? [];

                  if (schedules.isEmpty) {
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
                            Icon(Icons.alarm_off, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text(
                              'Belum ada jadwal penyemprotan otomatis.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tambahkan jadwal rutin agar ESP32 menyemprot otomatis.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showAddScheduleDialog(context, dbHelper),
                              icon: const Icon(Icons.add),
                              label: const Text('Tambah Jadwal Baru'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: AppTheme.shadowSM,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: sched.isActive
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.schedule,
                                color: sched.isActive ? AppTheme.primaryColor : Colors.grey,
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
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: sched.isActive ? AppTheme.textDark : Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    '${sched.title} • Durasi: ${sched.durationSeconds} Detik',
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
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                              onPressed: () async {
                                if (sched.id != null) {
                                  await dbHelper.deleteSchedule(sched.id!);
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

  void _showAddScheduleDialog(BuildContext context, DatabaseHelper dbHelper) {
    final titleController = TextEditingController(text: 'Semprot Otomatis');
    TimeOfDay selectedTime = TimeOfDay.now();
    double duration = 30.0;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              title: const Text('Tambah Jadwal Semprot'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Nama / Label Jadwal',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Waktu Semprot:'),
                      subtitle: Text(
                        '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')} WIB',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      trailing: const Icon(Icons.access_time, color: AppTheme.primaryColor),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (t != null) {
                          setState(() => selectedTime = t);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Durasi: ${duration.toInt()} Detik (${(duration * 5).toInt()} ml)'),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppTheme.primaryColor,
                            thumbColor: AppTheme.primaryColor,
                          ),
                          child: Slider(
                            value: duration,
                            min: 5.0,
                            max: 120.0,
                            divisions: 23,
                            onChanged: (val) => setState(() => duration = val),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newSched = SpraySchedule(
                      title: titleController.text.trim(),
                      hour: selectedTime.hour,
                      minute: selectedTime.minute,
                      durationSeconds: duration.toInt(),
                      isActive: true,
                    );
                    await dbHelper.insertSchedule(newSched);
                    if (context.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
