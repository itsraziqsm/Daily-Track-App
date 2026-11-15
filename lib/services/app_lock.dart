import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../db/database_helper.dart';

/// Seberapa luas kunci aplikasi berlaku.
enum LockScope { none, all, selected }

extension LockScopeInfo on LockScope {
  String get label => switch (this) {
        LockScope.none => 'Tidak ada',
        LockScope.all => 'Semua',
        LockScope.selected => 'Pilih bagian',
      };

  String get description => switch (this) {
        LockScope.none => 'Aplikasi terbuka tanpa kode',
        LockScope.all => 'Kode diminta setiap kali aplikasi dibuka',
        LockScope.selected => 'Kode diminta saat membuka bagian tertentu',
      };
}

/// Bagian aplikasi yang bisa dikunci satu per satu.
enum LockArea { finance, wallet, target, agenda }

extension LockAreaInfo on LockArea {
  String get label => switch (this) {
        LockArea.finance => 'Keuangan',
        LockArea.wallet => 'Dompet Saya',
        LockArea.target => 'Target',
        LockArea.agenda => 'Agenda',
      };
}

/// Pembungkus sensor biometrik perangkat, supaya bisa diganti di test.
class BiometricAuth {
  const BiometricAuth();

  /// Perangkat punya sensor dan setidaknya satu biometrik terdaftar.
  Future<bool> isAvailable() async {
    try {
      final auth = LocalAuthentication();
      return await auth.isDeviceSupported() && (await auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }

  /// Menampilkan dialog biometrik sistem; true bila berhasil.
  Future<bool> authenticate(String reason) async {
    try {
      return await LocalAuthentication().authenticate(localizedReason: reason, biometricOnly: true);
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }
}

/// Kunci aplikasi: cakupan, kode, biometrik, dan status terbuka sesi ini.
///
/// Ini kunci tampilan, bukan enkripsi: data di database tidak ikut
/// dienkripsi. Kode disimpan sebagai hash SHA-256 bergaram, bukan teks asli.
class AppLock extends ChangeNotifier {
  static const pinLength = 6;

  /// Aplikasi terkunci lagi bila ditinggal di latar belakang selama ini.
  static const relockAfter = Duration(minutes: 1);

  /// Setelah sekian kali salah berturut-turut, kode dikunci sementara.
  static const maxAttempts = 5;
  static const lockoutStep = Duration(seconds: 30);

  static const _scopeKey = 'auth.scope';
  static const _areasKey = 'auth.areas';
  static const _hashKey = 'auth.pinHash';
  static const _saltKey = 'auth.pinSalt';
  static const _biometricKey = 'auth.biometric';
  static const _failsKey = 'auth.fails';
  static const _lockoutKey = 'auth.lockoutUntil';

  final DatabaseHelper _db = DatabaseHelper.instance;
  final BiometricAuth biometrics;

  /// Sumber waktu; diganti di test.
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  AppLock({this.biometrics = const BiometricAuth()});

  LockScope _scope = LockScope.none;
  Set<LockArea> _areas = {};
  String? _hash;
  String? _salt;
  bool _biometric = false;
  int _fails = 0;
  DateTime? _lockoutUntil;
  bool _unlocked = false;
  DateTime? _backgroundedAt;

  LockScope get scope => _scope;
  Set<LockArea> get areas => Set.unmodifiable(_areas);
  bool get hasPin => _hash != null;
  bool get biometricEnabled => _biometric;

  /// Kunci berlaku: cakupan dipilih dan kode sudah dibuat.
  bool get enabled => _scope != LockScope.none && hasPin;

  bool get isUnlocked => _unlocked;

  /// Seluruh aplikasi tertutup layar kunci sampai dibuka.
  bool get lockedAtLaunch => enabled && _scope == LockScope.all && !_unlocked;

  /// Membuka [area] butuh autentikasi lebih dulu.
  bool requiresAuth(LockArea area) {
    if (!enabled || _unlocked) return false;
    return _scope == LockScope.all || _areas.contains(area);
  }

  /// Sisa waktu kode dikunci karena terlalu sering salah; null bila tidak.
  Duration? get lockoutRemaining {
    final until = _lockoutUntil;
    if (until == null) return null;
    final left = until.difference(clock());
    return left.isNegative ? null : left;
  }

  /// Dibaca sebelum aplikasi digambar, supaya isi yang dikunci tidak sempat
  /// terlihat.
  Future<void> load() async {
    final scope = await _db.getSetting(_scopeKey);
    _scope = LockScope.values.firstWhere((s) => s.name == scope, orElse: () => LockScope.none);
    final areas = await _db.getSetting(_areasKey) ?? '';
    _areas = {
      for (final name in areas.split(',').where((n) => n.isNotEmpty))
        if (LockArea.values.any((a) => a.name == name)) LockArea.values.byName(name),
    };
    _hash = await _db.getSetting(_hashKey);
    _salt = await _db.getSetting(_saltKey);
    _biometric = (await _db.getSetting(_biometricKey)) == 'true';
    _fails = int.tryParse(await _db.getSetting(_failsKey) ?? '') ?? 0;
    final until = await _db.getSetting(_lockoutKey);
    _lockoutUntil = until == null || until.isEmpty ? null : DateTime.tryParse(until);
    notifyListeners();
  }

  // ---- Pengaturan ----

  Future<void> setScope(LockScope scope) async {
    _scope = scope;
    await _db.setSetting(_scopeKey, scope.name);
    notifyListeners();
  }

  Future<void> setAreas(Set<LockArea> areas) async {
    _areas = {...areas};
    await _db.setSetting(_areasKey, [for (final a in LockArea.values) if (areas.contains(a)) a.name].join(','));
    notifyListeners();
  }

  Future<void> setBiometric(bool enabled) async {
    _biometric = enabled;
    await _db.setSetting(_biometricKey, '$enabled');
    notifyListeners();
  }

  static String _digest(String salt, String pin) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  /// Membuat atau mengganti kode. Sesi ini dianggap sudah terbuka, karena
  /// pengguna baru saja membuktikan dirinya dengan membuat kode.
  Future<void> setPin(String pin) async {
    assert(pin.length == pinLength);
    final random = Random.secure();
    final salt = base64Encode(List<int>.generate(16, (_) => random.nextInt(256)));
    _salt = salt;
    _hash = _digest(salt, pin);
    await _db.setSetting(_saltKey, salt);
    await _db.setSetting(_hashKey, _hash!);
    await _resetFails();
    _unlocked = true;
    notifyListeners();
  }

  /// Mencocokkan kode. Benar → sesi terbuka. Salah berulang → kode dikunci
  /// sementara, makin lama tiap kesalahan berikutnya.
  Future<bool> verifyPin(String pin) async {
    if (_hash == null || _salt == null || lockoutRemaining != null) return false;
    if (_digest(_salt!, pin) == _hash) {
      await _resetFails();
      _unlocked = true;
      notifyListeners();
      return true;
    }
    _fails++;
    await _db.setSetting(_failsKey, '$_fails');
    if (_fails >= maxAttempts) {
      _lockoutUntil = clock().add(lockoutStep * (_fails - maxAttempts + 1));
      await _db.setSetting(_lockoutKey, _lockoutUntil!.toIso8601String());
    }
    notifyListeners();
    return false;
  }

  /// Sisa percobaan sebelum kode dikunci sementara.
  int get attemptsLeft => max(0, maxAttempts - _fails);

  Future<void> _resetFails() async {
    if (_fails == 0 && _lockoutUntil == null) return;
    _fails = 0;
    _lockoutUntil = null;
    await _db.setSetting(_failsKey, '0');
    await _db.setSetting(_lockoutKey, '');
  }

  /// Membuka dengan biometrik, bila diaktifkan.
  Future<bool> unlockWithBiometrics(String reason) async {
    if (!_biometric) return false;
    final ok = await biometrics.authenticate(reason);
    if (ok) {
      await _resetFails();
      _unlocked = true;
      notifyListeners();
    }
    return ok;
  }

  /// Membuktikan identitas dengan biometrik tanpa membuka sesi, mis. untuk
  /// membuat kode baru saat lupa.
  Future<bool> confirmWithBiometrics(String reason) => _biometric ? biometrics.authenticate(reason) : Future.value(false);

  // ---- Siklus hidup ----

  /// Dipanggil saat aplikasi masuk ke latar belakang.
  void onBackgrounded() => _backgroundedAt ??= clock();

  /// Dipanggil saat aplikasi kembali; terkunci lagi bila ditinggal cukup lama.
  void onResumed() {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since != null && enabled && _unlocked && clock().difference(since) >= relockAfter) {
      _unlocked = false;
      notifyListeners();
    }
  }

  void lockNow() {
    _unlocked = false;
    notifyListeners();
  }
}
