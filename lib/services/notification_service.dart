import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Service untuk mengelola notifikasi lokal di HP.
///
/// Mendukung:
/// - Notifikasi jadwal semprot (terjadwal harian berdasarkan jam:menit)
/// - Notifikasi instan (peringatan/info)
/// - Cancel notifikasi per jadwal atau semua sekaligus
class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _channelIdSchedule = 'sprayer_schedule';
  static const String _channelNameSchedule = 'Jadwal Semprot';
  static const String _channelIdAlert = 'sprayer_alert';
  static const String _channelNameAlert = 'Peringatan Sprayer';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionGranted = false;

  bool get isInitialized => _initialized;
  bool get permissionGranted => _permissionGranted;

  /// Inisialisasi plugin sekali saat app launch.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Inisialisasi timezone data
      tz_data.initializeTimeZones();
      final jakarta = tz.getLocation('Asia/Jakarta');
      tz.setLocalLocation(jakarta);
    } catch (e) {
      debugPrint('[NotificationService] Timezone init warning: $e');
    }

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const linuxInit = LinuxInitializationSettings(
        defaultActionName: 'Open',
      );

      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
        linux: linuxInit,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      _initialized = true;

      // Request permission Android 13+ secara aman
      if (Platform.isAndroid) {
        try {
          final androidPlugin =
              _plugin.resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();
          final granted = await androidPlugin?.requestNotificationsPermission();
          _permissionGranted = granted ?? false;
        } catch (pe) {
          debugPrint('[NotificationService] Permission request warning: $pe');
          _permissionGranted = false;
        }
      } else {
        _permissionGranted = true;
      }
    } catch (e) {
      debugPrint('[NotificationService] Initialize error: $e');
    }

    notifyListeners();
    debugPrint('[NotificationService] Initialized. Permission: $_permissionGranted');
  }

  void _onNotificationTap(NotificationResponse details) {
    debugPrint('[NotificationService] Notification tapped: ${details.payload}');
  }

  // ---- Notification Detail builders ----

  NotificationDetails _scheduleDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelIdSchedule,
        _channelNameSchedule,
        channelDescription: 'Pengingat jadwal penyemprotan otomatis',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: 'SCHEDULE',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  NotificationDetails _alertDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelIdAlert,
        _channelNameAlert,
        channelDescription: 'Peringatan status perangkat sprayer',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: 'ALERT',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  // ---- API Publik ----

  /// Tampilkan notifikasi instan (langsung muncul).
  Future<void> showInstant({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool isAlert = false,
  }) async {
    if (!_initialized || !_permissionGranted) return;
    await _plugin.show(
      id,
      title,
      body,
      isAlert ? _alertDetails() : _scheduleDetails(),
      payload: payload,
    );
  }

  /// Jadwalkan notifikasi harian pada [hour]:[minute] setiap hari.
  /// [id] harus unik per jadwal agar bisa di-cancel satu-persatu.
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    if (!_initialized || !_permissionGranted) return;

    // Hitung waktu terdekat berikutnya
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      _scheduleDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Ulangi setiap hari
      payload: payload,
    );

    debugPrint(
        '[NotificationService] Scheduled daily notification id=$id at $hour:$minute → next: $scheduled');
  }

  /// Batalkan notifikasi terjadwal berdasarkan [id].
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
    debugPrint('[NotificationService] Cancelled notification id=$id');
  }

  /// Batalkan SEMUA notifikasi terjadwal (mis. saat semua jadwal dinonaktifkan).
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('[NotificationService] All notifications cancelled');
  }

  /// Sinkronkan notifikasi terjadwal dengan daftar jadwal aktif dari aplikasi.
  ///
  /// Mekanisme: cancel semua notif schedule lama, lalu re-schedule semua
  /// jadwal yang [isActive] = true (jika [scheduleNotifEnabled] = true).
  ///
  /// [schedules] adalah List<Map> dengan minimal key: id, hour, minute.
  Future<void> syncScheduleNotifications({
    required List<Map<String, dynamic>> schedules,
    required bool scheduleNotifEnabled,
  }) async {
    if (!_initialized) return;

    // Cancel semua notifikasi jadwal lama (pakai ID range 1000–1999)
    for (int i = 1000; i < 1100; i++) {
      await _plugin.cancel(i);
    }

    if (!scheduleNotifEnabled || !_permissionGranted) return;

    for (final s in schedules) {
      final id = 1000 + ((s['id'] as int? ?? 0) % 100);
      final hour = s['hour'] as int? ?? 0;
      final minute = s['minute'] as int? ?? 0;
      final isActive = s['isActive'] as bool? ?? s['active'] == 1;
      final duration = s['durationSeconds'] as int? ?? s['duration'] as int? ?? 0;

      if (isActive) {
        await scheduleDaily(
          id: id,
          title: '💦 Jadwal Semprot Otomatis',
          body:
              'Waktunya semprot! Jadwal ${_pad(hour)}:${_pad(minute)} akan berjalan ${duration}s.',
          hour: hour,
          minute: minute,
          payload: 'schedule:$id',
        );
      }
    }

    debugPrint(
        '[NotificationService] Synced ${schedules.where((s) => s['isActive'] == true || s['active'] == 1).length} schedule notifications');
  }

  String _pad(int val) => val.toString().padLeft(2, '0');

  // ---- Notifikasi Perangkat ----

  /// Notifikasi: Pompa selesai semprot
  Future<void> notifySprayDone({
    required int durationSec,
    required double volumeMl,
  }) => showInstant(
        id: 2001,
        title: '✅ Semprot Selesai',
        body:
            'Durasi: ${durationSec}s • Volume: ${volumeMl.toStringAsFixed(0)} ml',
        payload: 'spray_done',
      );

  /// Notifikasi: Perangkat offline
  Future<void> notifyDeviceOffline(String deviceName) => showInstant(
        id: 2002,
        title: '⚠️ Perangkat Tidak Terhubung',
        body: '$deviceName tidak merespons. Periksa koneksi.',
        isAlert: true,
        payload: 'device_offline',
      );

  /// Notifikasi: WiFi berhasil dikonfigurasi ke ESP32
  Future<void> notifyWifiConfigSent(String ssid) => showInstant(
        id: 2003,
        title: '📡 Konfigurasi WiFi Terkirim',
        body: 'SSID "$ssid" berhasil dikirim ke ESP32 via BLE.',
        payload: 'wifi_config',
      );
}
