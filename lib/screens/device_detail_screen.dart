import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/esp_device.dart';
import '../models/spray_log.dart';
import '../models/spray_schedule.dart';
import '../models/device_snapshot.dart';
import '../services/database_helper.dart';
import '../services/device_repository.dart';
import '../services/bluetooth_service.dart';
import '../services/esp_device_registry.dart';
import '../services/theme_provider.dart';
import '../theme/theme.dart';
import '../utils/app_notification.dart';

/// Layar detail satu perangkat: Ringkasan / Jadwal / Riwayat (M4).
///
/// Data dibaca dari snapshot/log yang tersimpan per `device_key` supaya
/// tampil meski perangkat offline; tombol sinkron memaksakan pull saat unit
/// sedang tersambung BLE.
class DeviceDetailScreen extends StatefulWidget {
  final String deviceKey;
  const DeviceDetailScreen({super.key, required this.deviceKey});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  String _tab = 'Ringkasan';

  EspDevice? _device;

  @override
  void initState() {
    super.initState();
    final reg = context.read<EspDeviceRegistry>();
    Future.microtask(() {
      if (mounted) setState(() { _device = reg.byKey(widget.deviceKey); });
    });
  }

  bool get _deviceIsActive =>
      Provider.of<BluetoothService>(context).isConnected &&
      Provider.of<BluetoothService>(context).activeDeviceKey == widget.deviceKey;

  Future<DeviceSnapshot?> _latestSnapshot() =>
      context.read<DatabaseHelper>().latestDeviceSnapshot(widget.deviceKey);

  Future<List<SpraySchedule>> _schedules() async {
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    return db.getSchedulesForDevice(widget.deviceKey);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final titleColor = isDark ? Colors.white : AppTheme.textDark;
    final bg =
        isDark ? ThemeProvider.darkBgColor : const Color(0xFFF6F8F6);
    final cardBg = isDark ? ThemeProvider.darkCardColor : Colors.white;
    final accent =
        isDark ? ThemeProvider.greenAccentColor : AppTheme.primaryColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _device?.name ?? widget.deviceKey,
              style: TextStyle(
                  fontFamily: 'Utendo',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: titleColor),
            ),
            Text(widget.deviceKey,
                style: TextStyle(
                    fontFamily: 'Utendo',
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade500 : Colors.grey)),
          ],
        ),
        actions: [
          if (_deviceIsActive) ...[
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent, borderRadius: BorderRadius.circular(20)),
                  child: Text('LIVE',
                      style: TextStyle(
                          fontFamily: 'Utendo',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? ThemeProvider.blackColor : Colors.white)),
                ),
              ),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Ringkasan', icon: Icon(Icons.dashboard_outlined), label: Text('Ringkasan')),
                  ButtonSegment(value: 'Jadwal', icon: Icon(Icons.alarm), label: Text('Jadwal')),
                  ButtonSegment(value: 'Riwayat', icon: Icon(Icons.history), label: Text('Riwayat')),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: const WidgetStatePropertyAll(
                      TextStyle(fontFamily: 'Utendo', fontSize: 12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildTabBody(context, cardBg, titleColor,
                isDark: isDark, accent: accent)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBody(BuildContext context, Color cardBg, Color titleColor,
      {required bool isDark, required Color accent}) {
    switch (_tab) {
      case 'Ringkasan':
        return _buildSummary(cardBg, titleColor, accent);
      case 'Jadwal':
        return _buildSchedule(cardBg, titleColor, accent, isDark);
      default:
        return _buildHistory(cardBg, isDark);
    }
  }

  // Ringkasan — dari repository status (bila aktif) lalu snapshot persisten.
  Widget _buildSummary(Color cardBg, Color titleColor, Color accent) {
    final repo = context.watch<DeviceRepository>();
    final live = _deviceIsActive;
    final statusNow = live ? repo.statusOf(widget.deviceKey) : null;

    return FutureBuilder<DeviceSnapshot?>(
      future: _latestSnapshot(),
      builder: (context, snap) {
        final p = snap.data?.payload ?? const {};
        final has = snap.hasData && snap.data != null;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Ringkasan perangkat',
                    style: TextStyle(
                        fontFamily: 'Utendo',
                        fontSize: 12,
                        color: live
                            ? ThemeProvider.blackColor
                            : Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                    live
                        ? '${_num(statusNow?.totalVolumeTodayMl, has ? p['totalVolume'] : null)} ml hari ini'
                        : (has ? '${_num(0, p['totalVolume'])} ml hari ini' : 'Belum ada data tersimpan'),
                    style: TextStyle(
                        fontFamily: 'Utendo',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: live ? ThemeProvider.blackColor : Colors.white)),
                const SizedBox(height: 12),
                Row(children: [
                  _kv('Baterai', live ? _num(statusNow?.batteryPercentage, p['battery']) : '—', icon: Icons.battery_full_rounded),
                  const SizedBox(width: 22),
                  _kv('Sesi', live ? _num(statusNow?.totalSesiToday, p['totalSesi']) : '—', icon: Icons.water_drop),
                ]),
              ]),
            ),
            const SizedBox(height: 18),
            _kvRow("Volume hari ini (ml)", _num(live ? statusNow?.totalVolumeTodayMl : 0.0, p['totalVolume'])),
            _kvRow("Sesi hari ini", _num(live ? statusNow?.totalSesiToday : 0, p['totalSesi'])),
            _kvRow("Baterai (%)", _num(live ? statusNow?.batteryPercentage : 0, p['battery'])),
            const SizedBox(height: 8),
            Text(
                has
                    ? 'Snapshot tersimpan: ${DateFormat('dd MMM HH:mm').format(snap.data!.capturedAt.toLocal())}'
                    : 'Belum ada snapshot tersimpan untuk perangkat ini.',
                style: TextStyle(
                    fontFamily: 'Utendo',
                    fontSize: 11,
                    color: live
                        ? Colors.grey.shade300
                        : titleColor.withValues(alpha: 0.7))),
          ]),
        );
      },
    );
  }

  Widget _kvRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: const TextStyle(fontFamily: 'Utendo', fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  fontFamily: 'Utendo', fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
      );

  String _num(num? src, dynamic fallback) {
    if (src != null) return _fit(src);
    if (fallback is num) return _fit(fallback);
    return '—';
  }

  String _fit(num v) => (v is double || v is int)
      ? ((v is double) ? v.toStringAsFixed(0) : v.toString())
      : v.toString();

  Widget _kv(String label, String value, {IconData icon = Icons.sensors}) =>
      Expanded(
          child: Row(children: [
            Icon(icon, size: 20),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontFamily: 'Utendo', fontSize: 13)),
            const SizedBox(width: 6),
            Flexible(child: Text(value, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Utendo', fontSize: 13, fontWeight: FontWeight.bold))),
          ]));

  // Jadwal per perangkat
  Widget _buildSchedule(Color cardBg, Color titleColor, Color accent, bool isDark) {
    final bt = context.watch<BluetoothService>();
    final syncAllowed = bt.isConnected && bt.activeDeviceKey == widget.deviceKey;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Expanded(child: Text('Jadwal tersimpan per perangkat',
              style: TextStyle(
                  fontFamily: 'Utendo',
                  color: isDark ? Colors.grey.shade400 : Colors.grey,
                  fontSize: 12))),
          FilledButton.icon(
            onPressed: () => _addScheduleForThisDevice(accent, isDark),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Tambah', style: TextStyle(fontFamily: 'Utendo')),
            style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: isDark ? ThemeProvider.blackColor : Colors.white),
          ),
          const SizedBox(width: 8),
          if (syncAllowed)
            OutlinedButton.icon(
              onPressed: () => _syncSchedulesNow(),
              icon: const Icon(Icons.sync, size: 16),
              label: const Text('Sinkron', style: TextStyle(fontFamily: 'Utendo')),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: FutureBuilder<List<SpraySchedule>>(
          future: _schedules(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2));
            }
            final scheds = snap.data ?? const <SpraySchedule>[];
            if (scheds.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.alarm_off_outlined, size: 48, color: Colors.grey.shade600),
                      const SizedBox(height: 12),
                      Text(
                        syncAllowed
                            ? 'Belum ada jadwal tersimpan untuk unit ini.\nKetuk "+ Tambah" di atas untuk membuat jadwal baru, atau ketuk "Sinkron" untuk menarik dari ESP32.'
                            : 'Belum ada jadwal tersimpan untuk unit ini.\nKetuk "+ Tambah" di atas untuk membuat jadwal lokal.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Utendo', color: Colors.grey.shade400, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final s in scheds)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                        color: isDark ? ThemeProvider.darkCardColor : Colors.white,
                        borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: s.isActive ? accent : const Color(0x182C2D32),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(s.isActive ? Icons.alarm_on : Icons.alarm_off,
                              color: s.isActive ? (isDark ? ThemeProvider.blackColor : Colors.white) : Colors.grey)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.title,
                            style: TextStyle(fontFamily: 'Utendo',
                                fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textDark)),
                        Text('${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')} WIB · ${s.durationSeconds} dtk',
                            style: TextStyle(fontFamily: 'Utendo', color: Colors.grey, fontSize: 12)),
                      ])),
                      Switch(
                        value: s.isActive,
                        activeColor: accent,
                        onChanged: (val) async {
                          final db = context.read<DatabaseHelper>();
                          final repo = context.read<DeviceRepository>();
                          final bt = context.read<BluetoothService>();
                          if (s.id != null) {
                            await (await db.database).update(
                              'spray_schedules',
                              {'isActive': val ? 1 : 0},
                              where: 'id = ?',
                              whereArgs: [s.id],
                            );
                            final isConnected = bt.isConnected && bt.activeDeviceKey == widget.deviceKey;
                            if (isConnected) {
                              final updatedList = await db.getSchedulesForDevice(widget.deviceKey);
                              await repo.pushSchedules(updatedList);
                            }
                            if (mounted) setState(() {});
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                        onPressed: () async {
                          final db = context.read<DatabaseHelper>();
                          final repo = context.read<DeviceRepository>();
                          final bt = context.read<BluetoothService>();
                          if (s.id != null) {
                            await (await db.database).delete('spray_schedules', where: 'id = ?', whereArgs: [s.id]);
                            final isConnected = bt.isConnected && bt.activeDeviceKey == widget.deviceKey;
                            if (isConnected) {
                              final updatedList = await db.getSchedulesForDevice(widget.deviceKey);
                              await repo.pushSchedules(updatedList);
                            }
                            if (mounted) setState(() {});
                          }
                        },
                      ),
                    ]),
                  ),
              ],
            );
          },
        ),
      ),
    ]);
  }

  void _addScheduleForThisDevice(Color primaryAccent, bool isDark) {
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
              title: const Text('Tambah Jadwal Perangkat',
                  style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold)),
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
                    title: const Text('Waktu Semprot',
                        style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold)),
                    subtitle: Text(selectedTime.format(context),
                        style: const TextStyle(fontFamily: 'Utendo')),
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
                      const Text('Durasi:',
                          style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold)),
                      Text('${durationSeconds.toInt()} Detik',
                          style: TextStyle(
                              fontFamily: 'Utendo',
                              fontWeight: FontWeight.bold,
                              color: primaryAccent)),
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
                  child: const Text('Batal',
                      style: TextStyle(fontFamily: 'Utendo', color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    final db = context.read<DatabaseHelper>();
                    final repo = context.read<DeviceRepository>();
                    final bt = context.read<BluetoothService>();

                    final newSched = SpraySchedule(
                      title: title,
                      hour: selectedTime.hour,
                      minute: selectedTime.minute,
                      durationSeconds: durationSeconds.toInt(),
                      isActive: true,
                    );

                    final row = newSched.toMap();
                    row['device_key'] = widget.deviceKey;
                    if (row['id'] == null) row.remove('id');
                    await (await db.database).insert('spray_schedules', row);

                    if (dialogContext.mounted) Navigator.pop(dialogContext);

                    final isConnected = bt.isConnected && bt.activeDeviceKey == widget.deviceKey;
                    if (isConnected) {
                      final updatedList = await db.getSchedulesForDevice(widget.deviceKey);
                      await repo.pushSchedules(updatedList);
                      if (mounted) {
                        AppNotification.show(
                            context, 'Jadwal ditambahkan & terkirim ke ESP32.',
                            isError: false);
                      }
                    } else {
                      if (mounted) {
                        AppNotification.show(
                            context, 'Jadwal ditambahkan lokal (ESP32 offline).',
                            isError: false);
                      }
                    }

                    if (mounted) setState(() {});
                  },
                  child: const Text('Simpan',
                      style: TextStyle(
                          fontFamily: 'Utendo',
                          color: Colors.black,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _syncSchedulesNow() async {
    final repo = context.read<DeviceRepository>();
    final db = context.read<DatabaseHelper>();
    final list = await repo.pullSchedules();
    if (mounted && list != null) {
      await db.replaceSchedulesForDevice(widget.deviceKey, list);
      setState(() {});
      if (mounted) {
        AppNotification.show(
            context, 'Jadwal disinkronkan: ${list.length} jadwal.',
            isError: false);
      }
    } else if (mounted) {
      AppNotification.show(context,
          'Gagal menarik jadwal — pastikan unit masih tersambung.',
          isError: true);
    }
  }

  // Riwayat per perangkat
  Widget _buildHistory(Color cardBg, bool isDark) {
    final db = context.watch<DatabaseHelper>();
    return FutureBuilder<List<SprayLog>>(
      future: db.getLogsForDevice(widget.deviceKey),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final logs = snap.data ?? const <SprayLog>[];
        if (logs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Belum ada riwayat semprot untuk perangkat ini.',
                textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Utendo', color: Colors.grey)),
          );
        }
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (final log in logs)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: isDark ? ThemeProvider.darkCardColor : Colors.white,
                    borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  const Icon(Icons.water_drop, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${DateFormat('dd MMM yyyy, HH:mm').format(log.timestamp.toLocal())}',
                          style: TextStyle(fontFamily: 'Utendo', fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.textDark)),
                      Text('${log.durationSeconds} detik · ${log.volumeMl.toStringAsFixed(0)} ml · ${log.mode}',
                          style: TextStyle(fontFamily: 'Utendo', color: Colors.grey, fontSize: 12)),
                    ]),
                  ),
                  Text(log.communicationMethod,
                      style: TextStyle(fontFamily: 'Utendo', fontSize: 11, color: Colors.grey)),
                ]),
              ),
          ],
        );
      },
    );
  }
}
