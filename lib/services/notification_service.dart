import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/activity.dart';
import '../utils/app_time.dart';

/// Pengingat agenda yang sudah dihitung ke instan UTC.
class AgendaReminder {
  final String title;
  final String body;
  final DateTime at;

  const AgendaReminder({required this.title, required this.body, required this.at});
}

/// Notifikasi lokal terjadwal: pengingat tiap kegiatan, ringkasan pagi,
/// ringkasan malam, dan pengingat agenda.
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
  static const _channelName = 'GroU';
  static const _channelDescription = 'Pengingat kegiatan dan ringkasan harian';

  /// Rentang id agar tiap jenis notifikasi tidak saling menimpa.
  static const _activityIdBase = 1000;
  static const _morningId = 10;
  static const _nightId = 11;
  static const _agendaIdBase = 100000;

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

  // Dua sumber jadwal disimpan terpisah, tapi selalu dijadwalkan ulang
  // bersama: menjadwal ulang berarti membatalkan semua, jadi menjadwalkan satu
  // sumber saja akan menghapus pengingat sumber lainnya.
  _ActivityReminders? _activityConfig;
  List<AgendaReminder> _agendaReminders = const [];
  Future<void> _pending = Future.value();

  /// Menjadwal ulang pengingat kegiatan sesuai template hari ini dan
  /// preferensi. Dipanggil setiap kali template, zona waktu, atau toggle berubah.
  Future<void> reschedule({
    required List<Activity> activities,
    required bool eachActivity,
    required bool morningSummary,
    required bool nightSummary,
    required int minutesBefore,
  }) {
    _activityConfig = _ActivityReminders(activities, eachActivity, morningSummary, nightSummary, minutesBefore);
    return _rescheduleAll();
  }

  /// Mengganti seluruh pengingat agenda. Dipanggil setiap kali agenda, status
  /// selesainya, atau zona waktu berubah.
  Future<void> setAgendaReminders(List<AgendaReminder> reminders) {
    _agendaReminders = reminders;
    return _rescheduleAll();
  }

  // Panggilan berurutan, supaya dua penjadwalan ulang yang tumpang tindih tidak
  // saling membatalkan di tengah jalan. Di platform tanpa notifikasi (test,
  // desktop) antreannya dilewati sama sekali.
  Future<void> _rescheduleAll() {
    if (!isSupported) return Future.value();
    return _pending = _pending.then((_) => _scheduleEverything()).catchError((Object e) {
      debugPrint('Gagal menjadwalkan notifikasi: $e');
    });
  }

  Future<void> _scheduleEverything() async {
    await init();
    if (!_ready) return;
    _exactAlarms = true;
    await _plugin.cancelAll();

    final nowUtc = DateTime.now().toUtc();
    for (final (i, r) in _agendaReminders.indexed) {
      if (!r.at.isAfter(nowUtc)) continue;
      await _schedule(
        id: _agendaIdBase + i,
        title: r.title,
        body: r.body,
        at: tz.TZDateTime.from(r.at, tz.UTC),
        repeatDaily: false,
      );
    }

    final config = _activityConfig;
    if (config == null) return;
    final _ActivityReminders(:activities, :eachActivity, :morningSummary, :nightSummary, :minutesBefore) = config;

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

class _ActivityReminders {
  final List<Activity> activities;
  final bool eachActivity;
  final bool morningSummary;
  final bool nightSummary;
  final int minutesBefore;

  const _ActivityReminders(this.activities, this.eachActivity, this.morningSummary, this.nightSummary, this.minutesBefore);
}
