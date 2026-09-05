import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/spray_schedule.dart';
import '../services/database_helper.dart';
import '../services/device_repository.dart';
import '../services/bluetooth_service.dart';
import '../services/mqtt_service.dart';
import '../services/theme_provider.dart';
import '../theme/theme.dart';
import '../utils/app_notification.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  DatabaseHelper? _db;
  DeviceRepository? _repo;

  bool _lastConnected = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _db = context.read<DatabaseHelper>();
    _repo = context.read<DeviceRepository>();
    _lastConnected = _repo!.isConnected;
    _repo!.addListener(_onRepoChanged);
    // Kalau app dibuka saat perangkat sudah terhubung, tarik jadwal langsung.
    if (_repo!.isConnected) {
      _pullFromDevice();
    }
  }

  @override
  void dispose() {
    _repo?.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    final connected = _repo!.isConnected;
    if (connected && !_lastConnected) {
      _lastConnected = true;
      _pullFromDevice();
    } else if (!connected && _lastConnected) {
      _lastConnected = false;
    }
  }

  /// Notifikasi hanya ditampilkan jika halaman ini sedang terlihat
  /// (IndexedStack menyembunyikan halaman lain dengan TickerMode).
  void _notify(String message, {bool isError = false}) {
    if (!mounted || !TickerMode.of(context)) return;
    AppNotification.show(context, message, isError: isError);
  }

  /// Tarik jadwal dari ESP saat connect dan jadikan daftar alat sebagai
  /// sumber kebenaran (menimpa DB lokal).
  ///
  /// Aksi ini otomatis (saat connect/membuka halaman), jadi tidak menampilkan
  /// toast agar tidak berderau; kegagalan cukup diam dan UI tetap menampilkan
  /// data cache/SQLite.
  Future<void> _pullFromDevice() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final pulled = await _repo!.pullSchedules();
    if (!mounted) return;
    setState(() => _syncing = false);

    if (pulled == null) {
      // Tidak ada respon — biarkan daftar lokal tersaji tanpa popup error.
      return;
    }

    // ESP kosong (mis. perangkat baru): dorong jadwal bawaan lokal sekali ke
    // alat secara senyap (tanpa toast). Setelah itu daftar kosong dihormati.
    if (pulled.isEmpty) {
      final local = await _db!.getAllSchedules();
      if (!mounted) return;
      if (local.isNotEmpty) {
        await _repo!.pushSchedules(local);
      }
      return;
    }

    await _db!.replaceAllSchedules(pulled);
  }

  /// Kirim daftar jadwal lokal (DB) ke alat. Dipakai untuk kirim ulang manual
  /// dan setiap perubahan lokal (tambah/hapus/nyalakan/matikan).
  Future<void> _pushLocalToDevice(String successMessage) async {
    if (!_repo!.isConnected) {
      _notify('Alat tidak terhubung. Perubahan tersimpan lokal saja.',
          isError: true);
      return;
    }
    final bt = context.read<BluetoothService>();
    final activeKey = bt.activeDeviceKey;
    final schedules = activeKey != null
        ? await _db!.getSchedulesForDevice(activeKey)
        : await _db!.getAllSchedules();
    final ack = await _repo!.pushSchedules(schedules);
    if (!mounted) return;
    if (ack == null) {
      _notify(
          'Gagal: alat tidak merespons (timeout). Perubahan tersimpan lokal.',
          isError: true);
      return;
    }
    if (!ack.ok) {
      _notify('Gagal disimpan di alat${ack.error != null ? ': ${ack.error}' : ''}.',
          isError: true);
      return;
    }
    _notify(successMessage);
  }

  @override
  Widget build(BuildContext context) {
    // watch: rebuild saat DB lokal berubah / repo menarik data baru.
    final dbHelper = Provider.of<DatabaseHelper>(context);
    final btService = Provider.of<BluetoothService>(context);
    final mqttService = Provider.of<MqttService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final primaryAccent = isDark ? ThemeProvider.greenAccentColor : AppTheme.primaryColor;
    final cardBg = isDark ? ThemeProvider.darkCardColor : Colors.white;
    final titleColor = isDark ? Colors.white : AppTheme.textDark;

    final isBle = btService.isConnected;
    final isMqtt = mqttService.isConnected;

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
                        tooltip: 'Kirim ulang jadwal ke alat',
                        onPressed: (_syncing || !isBle && !isMqtt)
                            ? null
                            : () => _pushLocalToDevice('Jadwal berhasil dikirim ke alat'),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cardBg,
                            shape: BoxShape.circle,
                            boxShadow: isDark ? [] : AppTheme.shadowSM,
                          ),
                          child: _syncing
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: primaryAccent,
                                  ),
                                )
                              : Icon(Icons.sync, size: 20, color: isDark ? primaryAccent : AppTheme.textDark),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _showAddScheduleDialog(isDark: isDark, primaryAccent: primaryAccent),
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
                              onPressed: () => _showAddScheduleDialog(isDark: isDark, primaryAccent: primaryAccent),
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
                                await _pushLocalToDevice(
                                  val
                                      ? 'Jadwal "${sched.title}" diaktifkan & disimpan di alat'
                                      : 'Jadwal "${sched.title}" dinonaktifkan & disimpan di alat',
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                              onPressed: () async {
                                if (sched.id != null) {
                                  await dbHelper.deleteSchedule(sched.id!);
                                  await _pushLocalToDevice('Jadwal "${sched.title}" dihapus dari alat');
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

  void _showAddScheduleDialog({required bool isDark, required Color primaryAccent}) {
    final titleController = TextEditingController(text: 'Semprot Otomatis');
    TimeOfDay selectedTime = TimeOfDay.now();
    double durationSeconds = 30.0;

    showDialog(
      context: context,
      builder: (dialogContext) {
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
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal', style: TextStyle(fontFamily: 'Utendo', color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    final bt = context.read<BluetoothService>();
                    final activeKey = bt.activeDeviceKey ?? 'default';

                    final newSched = SpraySchedule(
                      title: title,
                      hour: selectedTime.hour,
                      minute: selectedTime.minute,
                      durationSeconds: durationSeconds.toInt(),
                      isActive: true,
                    );
                    final row = newSched.toMap();
                    row['device_key'] = activeKey;
                    if (row['id'] == null) row.remove('id');
                    await (await _db!.database).insert('spray_schedules', row);

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                    await _pushLocalToDevice('Jadwal "$title" ditambahkan & disimpan di alat');
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
