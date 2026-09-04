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
          if (syncAllowed)
            FilledButton.icon(
              onPressed: () => _syncSchedulesNow(),
              icon: const Icon(Icons.sync, size: 16),
              label: const Text('Sinkron', style: TextStyle(fontFamily: 'Utendo')),
            ),
        ]),
      ),
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
                padding: const EdgeInsets.all(16),
                child: Text(
                  syncAllowed
                      ? 'Belum ada jadwal tersimpan utk unit ini. Ketuk “Sinkron” untuk menarik dari perangkat.'
                      : 'Belum ada jadwal tersimpan utk unit ini. Sambungkan unit BLE lalu ketuk Sinkron.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Utendo', color: Colors.grey),
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
                        Text('${s.hour}:${s.minute.toString().padLeft(2, '0')} · ${s.durationSeconds} dtk',
                            style: TextStyle(fontFamily: 'Utendo', color: Colors.grey, fontSize: 12)),
                      ])),
                      Text(s.isActive ? 'Aktif' : 'Off',
                          style: TextStyle(
                              fontFamily: 'Utendo',
                              fontSize: 12,
                              color: s.isActive ? accent : Colors.grey)),
                    ]),
                  ),
              ],
            );
          },
        ),
      ),
    ]);
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
    return FutureBuilder<List<SprayLog>>(
      future: context.read<DatabaseHelper>().getLogsForDevice(widget.deviceKey),
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
