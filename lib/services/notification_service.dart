import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  /// Menjadi false bila sisi native plugin tidak tersedia — misalnya setelah
  /// hot restart yang menambahkan plugin tanpa build ulang. Notifikasi adalah
  /// fitur sampingan, jadi kegagalannya tidak boleh menjatuhkan aplikasi.
  bool _available = true;

  static const _channelId = 'jadwal_harian';
  static const _channelName = 'Jadwal Harian';
  static const _channelDescription = 'Pengingat kegiatan dan ringkasan harian';

  /// Rentang id agar tiap jenis notifikasi tidak saling menimpa.
  static const _activityIdBase = 1000;
  static const _morningId = 10;
  static const _nightId = 11;
  static const _testId = 1;
  static const _testScheduledId = 2;

  /// Alarm presis dipakai selama sistem mengizinkan. Pengingat "10 menit
  /// sebelum mulai" kehilangan gunanya kalau digeser Doze berjam-jam, jadi
  /// mode inexact hanya dipakai sebagai cadangan.
  bool _exactAlarms = true;

  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  /// False bila plugin gagal disiapkan; dipakai UI untuk memberi pesan yang tepat.
  bool get isAvailable => _available;

  Future<void> init() async {
    if (_ready || !_available || !isSupported) return;
    try {
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
    } on MissingPluginException catch (e) {
      _available = false;
      debugPrint(
        'Notifikasi dimatikan: sisi native plugin belum terpasang. '
        'Hentikan aplikasi lalu jalankan ulang (bukan hot restart). $e',
      );
    } catch (e) {
      _available = false;
      debugPrint('Notifikasi dimatikan: gagal inisialisasi. $e');
    }
  }

  /// Meminta izin notifikasi ke sistem. Di Android 13+ ini memunculkan dialog
  /// POST_NOTIFICATIONS; di versi lama izinnya sudah melekat saat pemasangan.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await init();
    if (!_ready) return false;
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
    if (!_ready) return false;
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
    if (!_ready) return;
    _exactAlarms = true;
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
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int minutesOfDay,
  }) async {
    await _schedule(
      id: id,
      title: title,
      body: body,
      at: _nextInstantUtc(minutesOfDay % (24 * 60)),
      repeatDaily: true,
    );
  }

  /// Menjadwalkan satu notifikasi. Bila sistem menolak alarm presis, sisanya
  /// dijadwalkan dengan mode inexact alih-alih gagal seluruhnya.
  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime at,
    required bool repeatDaily,
  }) async {
    Future<void> attempt(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id,
          title,
          body,
          at,
          _details,
          androidScheduleMode: mode,
          matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
        );

    if (!_exactAlarms) {
      await attempt(AndroidScheduleMode.inexactAllowWhileIdle);
      return;
    }
    try {
      await attempt(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException catch (e) {
      if (e.code != 'exact_alarms_not_permitted') rethrow;
      _exactAlarms = false;
      debugPrint('Alarm presis tidak diizinkan; beralih ke mode inexact.');
      await attempt(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  /// Notifikasi uji: satu tampil seketika, satu lagi lewat jalur terjadwal
  /// beberapa detik kemudian. Kalau yang pertama muncul tapi yang kedua tidak,
  /// masalahnya ada di jalur alarm — biasanya receiver yang belum terdaftar di
  /// AndroidManifest, atau pembatasan baterai dari pabrikan.
  Future<bool> sendTest({Duration delay = const Duration(seconds: 10)}) async {
    if (!isSupported) return false;
    await init();
    if (!_ready) return false;
    await _plugin.show(_testId, 'Notifikasi aktif', 'Ini tampil langsung tanpa penjadwalan.', _details);
    await _schedule(
      id: _testScheduledId,
      title: 'Uji pengingat terjadwal',
      body: 'Dijadwalkan ${delay.inSeconds} detik lalu — jalur alarm bekerja.',
      at: tz.TZDateTime.from(DateTime.now().toUtc().add(delay), tz.UTC),
      repeatDaily: false,
    );
    return true;
  }

  /// Jumlah notifikasi yang benar-benar tersimpan di antrean sistem.
  Future<int> pendingCount() async {
    if (!isSupported) return 0;
    await init();
    if (!_ready) return 0;
    return (await _plugin.pendingNotificationRequests()).length;
  }

  /// Apakah sistem masih mengizinkan alarm presis.
  Future<bool> canScheduleExact() async {
    if (!isSupported || !Platform.isAndroid) return true;
    await init();
    if (!_ready) return false;
    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? false;
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
