import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/activity.dart';
import '../utils/app_time.dart';

/// Notifikasi lokal terjadwal: pengingat tiap kegiatan, ringkasan pagi, dan
/// ringkasan malam.
///
/// Penjadwalan dilakukan dalam UTC. Jam jadwal dihitung pada zona waktu pilihan
/// pengguna lalu dikonversi ke instan UTC, sehingga pengingat tetap jatuh pada
/// jam yang benar meskipun zona waktu perangkat berbeda.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'jadwal_harian';
  static const _channelName = 'Jadwal Harian';
  static const _channelDescription = 'Pengingat kegiatan dan ringkasan harian';

  /// Rentang id agar tiap jenis notifikasi tidak saling menimpa.
  static const _activityIdBase = 1000;
  static const _morningId = 10;
  static const _nightId = 11;

  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  Future<void> init() async {
    if (_ready || !isSupported) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Meminta izin notifikasi ke sistem. Di Android 13+ ini memunculkan dialog
  /// POST_NOTIFICATIONS; di versi lama izinnya sudah melekat saat pemasangan.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await init();
    if (Platform.isAndroid) {
      final android =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission() ?? false;
      // Alarm persis dibutuhkan agar pengingat jatuh tepat pada menitnya.
      await android?.requestExactAlarmsPermission();
      return granted;
    }
    final ios =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    await init();
    if (!Platform.isAndroid) return true;
    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? false;
  }

  /// Menjadwal ulang semua notifikasi sesuai template hari ini dan preferensi.
  /// Dipanggil setiap kali template, zona waktu, atau toggle berubah.
  Future<void> reschedule({
    required List<Activity> activities,
    required bool eachActivity,
    required bool morningSummary,
    required bool nightSummary,
    required int minutesBefore,
  }) async {
    if (!isSupported) return;
    await init();
    await _plugin.cancelAll();

    if (eachActivity) {
      for (final a in activities) {
        final at = a.startMinutes - minutesBefore;
        await _scheduleDaily(
          id: _activityIdBase + a.id,
          title: a.title,
          body: 'Mulai ${a.startTime} · $minutesBefore menit lagi',
          minutesOfDay: at,
        );
      }
    }

    if (morningSummary) {
      await _scheduleDaily(
        id: _morningId,
        title: 'Ringkasan pagi',
        body: activities.isEmpty
            ? 'Belum ada kegiatan untuk hari ini.'
            : '${activities.length} kegiatan hari ini, mulai ${activities.first.startTime}.',
        minutesOfDay: 6 * 60,
      );
    }

    if (nightSummary) {
      await _scheduleDaily(
        id: _nightId,
        title: 'Ringkasan malam',
        body: 'Cek rekap hari ini dan catat kegiatan yang batal.',
        minutesOfDay: 21 * 60 + 30,
      );
    }
  }

  Future<void> cancelAll() async {
    if (!isSupported) return;
    await init();
    await _plugin.cancelAll();
  }

  Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int minutesOfDay,
  }) async {
    final normalized = minutesOfDay % (24 * 60);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstantUtc(normalized),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Instan UTC berikutnya untuk [minutesOfDay] pada zona waktu aplikasi.
  tz.TZDateTime _nextInstantUtc(int minutesOfDay) {
    final offset = AppTime.zone.offset;
    final nowLocalZone = AppTime.now();
    var target = DateTime.utc(
      nowLocalZone.year,
      nowLocalZone.month,
      nowLocalZone.day,
      minutesOfDay ~/ 60,
      minutesOfDay % 60,
    ).subtract(offset);
    final nowUtc = DateTime.now().toUtc();
    if (!target.isAfter(nowUtc)) target = target.add(const Duration(days: 1));
    return tz.TZDateTime.from(target, tz.UTC);
  }
}
