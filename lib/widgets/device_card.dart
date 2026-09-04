import 'package:flutter/material.dart';
import '../models/esp_device.dart';
import '../models/device_snapshot.dart';
import '../theme/theme.dart';
import '../services/theme_provider.dart';

/// Membaca ringkasan terakhir yang tersimpan untuk kartu (snapshot JSON).
///
/// M3: kartu menampilkan data persisten meski sedang offline; field dari
/// snapshot DB `{ battery, totalSesi, totalVolume, ts }` didekode ringan.
class DeviceSnapshotSummary {
  final int battery;
  final int totalSesi;
  final double totalVolumeMl;

  const DeviceSnapshotSummary({
    this.battery = 0,
    this.totalSesi = 0,
    this.totalVolumeMl = 0,
  });

  factory DeviceSnapshotSummary.fromSnapshot(DeviceSnapshot? snap) {
    final p = snap?.payload;
    return DeviceSnapshotSummary(
      battery: (p?['battery'] as num?)?.toInt() ?? 0,
      totalSesi: (p?['totalSesi'] as num?)?.toInt() ?? 0,
      totalVolumeMl: (p?['totalVolume'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Kartu ringkas satu perangkat pada Dashboard (fleet) / registry nanti.
///
/// M3: menampilkan identitas + ringkasan snapshot tersimpan; bila sesi BLE
/// aktif menandai "Live" dan mengaktifkan tombol Semprot.
class DeviceCard extends StatelessWidget {
  final EspDevice device;
  final Future<DeviceSnapshot?> snapshotFuture;
  final bool isLive;
  final VoidCallback? onSprayNow;
  final VoidCallback? onShowDetail;

  const DeviceCard({
    super.key,
    required this.device,
    required this.snapshotFuture,
    this.isLive = false,
    this.onSprayNow,
    this.onShowDetail,
  });

  String get _mac => device.deviceKey;

  @override
  Widget build(BuildContext context) {
    // Hindari dependency theme provider agar widget mudah diuji.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppTheme.textDark;
    final sub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final accent =
        isDark ? ThemeProvider.greenAccentColor : AppTheme.primaryColor;
    final cardColor = isDark ? ThemeProvider.darkCardColor : Colors.white;
    final borderColor =
        isLive ? accent : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE9ECEF));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: isLive ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isLive
                      ? accent
                      : (isDark ? const Color(0xFF2C2D32) : const Color(0xFFEEF2F6)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.sensors,
                    color: isLive
                        ? ThemeProvider.blackColor
                        : (isDark ? Colors.grey.shade400 : AppTheme.primaryColor),
                    size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(device.name.isEmpty ? 'Perangkat' : device.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: 'Utendo',
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                            fontSize: 15)),
                    Text(_mac,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: 'Utendo', color: sub, fontSize: 11)),
                  ],
                ),
              ),
              if (isLive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Live',
                      style: TextStyle(
                          fontFamily: 'Utendo',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? ThemeProvider.blackColor : Colors.white)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          FutureBuilder<DeviceSnapshot?>(
            future: snapshotFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Row(children: [
                  SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Memuat data terakhir…',
                      style: TextStyle(fontFamily: 'Utendo', fontSize: 12)),
                ]);
              }
              final s = DeviceSnapshotSummary.fromSnapshot(snap.data);
              return Row(children: [
                _Metric(label: 'Hari ini', value: '${s.totalVolumeMl.toInt()} ml'),
                const SizedBox(width: 18),
                _Metric(label: 'Sesi', value: '${s.totalSesi}'),
                const Spacer(),
                if (device.lastBattery != null)
                  _Metric(label: 'Baterai', value: '${device.lastBattery}%'),
              ]);
            },
          ),
          const SizedBox(height: 14),
          Row(children: [
            OutlinedButton.icon(
              onPressed: onShowDetail,
              icon: const Icon(Icons.read_more, size: 16),
              label: const Text('Detail', style: TextStyle(fontFamily: 'Utendo')),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    isLive ? accent : (isDark ? Colors.grey.shade300 : AppTheme.primaryColor),
              ),
            ),
            const Spacer(),
            if (onSprayNow != null) ...[
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onSprayNow,
                icon: const Icon(Icons.water_drop, size: 16),
                label: const Text('Semprot', style: TextStyle(fontFamily: 'Utendo')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: isDark ? ThemeProvider.blackColor : Colors.white,
                ),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(fontFamily: 'Utendo', color: sub, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontFamily: 'Utendo',
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textDark,
                fontSize: 14)),
      ],
    );
  }
}
