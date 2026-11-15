import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/app_lock.dart';
import '../theme/app_theme.dart';

/// Papan angka untuk kode: titik isian dan tombol 0–9, hapus, dan
/// (opsional) biometrik. Memanggil [onCompleted] begitu digit terakhir
/// diketik, lalu mengosongkan isian.
class PinPad extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? error;
  final bool enabled;
  final ValueChanged<String> onCompleted;
  final VoidCallback? onBiometric;

  const PinPad({
    super.key,
    required this.title,
    this.subtitle,
    this.error,
    this.enabled = true,
    required this.onCompleted,
    this.onBiometric,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _digits = '';
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

  @override
  void didUpdateWidget(PinPad old) {
    super.didUpdateWidget(old);
    // Kesalahan baru: getarkan titik isian.
    if (widget.error != null && widget.error != old.error) {
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _tap(String digit) {
    if (!widget.enabled || _digits.length >= AppLock.pinLength) return;
    HapticFeedback.selectionClick();
    setState(() => _digits += digit);
    if (_digits.length == AppLock.pinLength) {
      final pin = _digits;
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        setState(() => _digits = '');
        widget.onCompleted(pin);
      });
    }
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, textAlign: TextAlign.center, style: TextStyle(fontFamily: AppFonts.title, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: c.ink)),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          child: Text(
            widget.error ?? widget.subtitle ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.subtitle,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: widget.error != null ? c.orangeChipInk : c.inkMuted,
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _shake,
          builder: (context, dots) => Transform.translate(
            offset: Offset(math.sin(_shake.value * math.pi * 6) * 10 * (1 - _shake.value), 0),
            child: dots,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < AppLock.pinLength; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _digits.length ? c.orange : Colors.transparent,
                    border: Border.all(color: i < _digits.length ? c.orange : c.lineSoft, width: 2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(mainAxisSize: MainAxisSize.min, children: [for (final d in row) _Key(label: d, onTap: () => _tap(d))]),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.onBiometric == null
                ? const SizedBox(width: _Key.size + 24, height: _Key.size + 12)
                : _Key(icon: LucideIcons.fingerprint, tooltip: 'Pakai biometrik', onTap: widget.onBiometric!),
            _Key(label: '0', onTap: () => _tap('0')),
            _Key(icon: LucideIcons.delete, tooltip: 'Hapus', onTap: _backspace, plain: true),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  static const size = 70.0;

  final String? label;
  final IconData? icon;
  final String? tooltip;
  final bool plain;
  final VoidCallback onTap;

  const _Key({this.label, this.icon, this.tooltip, this.plain = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final key = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: plain || icon != null ? Colors.transparent : c.card,
        shape: CircleBorder(side: plain || icon != null ? BorderSide.none : BorderSide(color: c.line, width: 1.5)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: label != null
                  ? Text(label!, style: TextStyle(fontFamily: AppFonts.title, fontSize: 26, fontWeight: FontWeight.w700, color: c.ink))
                  : Icon(icon, size: 26, color: c.ink),
            ),
          ),
        ),
      ),
    );
    // Label aksesibilitas, bukan Tooltip: layar kunci penuh berada di atas
    // Navigator, tempat Tooltip tidak punya Overlay untuk ditampilkan.
    return tooltip == null ? key : Semantics(label: tooltip, button: true, excludeSemantics: true, child: key);
  }
}

/// Layar buka kunci: kode, atau biometrik bila diaktifkan (langsung
/// ditawarkan begitu layar muncul). Memanggil [onUnlocked] setelah berhasil.
class UnlockView extends StatefulWidget {
  final String title;
  final String reason;
  final VoidCallback onUnlocked;

  const UnlockView({super.key, this.title = 'Masukkan kode', required this.reason, required this.onUnlocked});

  @override
  State<UnlockView> createState() => _UnlockViewState();
}

class _UnlockViewState extends State<UnlockView> {
  String? _error;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    final lock = context.read<AppLock>();
    if (lock.biometricEnabled) WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Selama kode dikunci sementara, layar diperbarui tiap detik untuk
  /// hitung mundurnya.
  void _syncTicker() {
    final locked = context.read<AppLock>().lockoutRemaining != null;
    if (locked && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (context.read<AppLock>().lockoutRemaining == null) {
          _ticker?.cancel();
          _ticker = null;
        }
      });
    }
  }

  Future<void> _biometric() async {
    if (await context.read<AppLock>().unlockWithBiometrics(widget.reason)) widget.onUnlocked();
  }

  Future<void> _submit(String pin) async {
    final lock = context.read<AppLock>();
    if (await lock.verifyPin(pin)) {
      widget.onUnlocked();
      return;
    }
    if (!mounted) return;
    setState(() {
      _error = lock.lockoutRemaining != null
          ? 'Terlalu sering salah'
          : 'Kode salah · ${lock.attemptsLeft} percobaan lagi sebelum dikunci sementara';
    });
    _syncTicker();
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLock>();
    final lockout = lock.lockoutRemaining;
    return PinPad(
      title: widget.title,
      subtitle: widget.reason,
      error: lockout != null ? 'Terlalu sering salah. Coba lagi dalam ${lockout.inSeconds + 1} detik.' : _error,
      enabled: lockout == null,
      onCompleted: _submit,
      onBiometric: lock.biometricEnabled ? _biometric : null,
    );
  }
}

/// Membuka layar kunci penuh; true bila berhasil dibuka.
Future<bool> showUnlockScreen(BuildContext context, {required String reason}) async {
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (context) {
      final c = AppColors.of(context);
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(),
        body: Center(
          child: SingleChildScrollView(
            child: UnlockView(reason: reason, onUnlocked: () => Navigator.of(context).pop(true)),
          ),
        ),
      );
    },
  ));
  return ok == true;
}

/// Meminta autentikasi bila [area] dikunci dan sesi belum terbuka.
Future<bool> ensureUnlocked(BuildContext context, LockArea area) {
  if (!context.read<AppLock>().requiresAuth(area)) return Future.value(true);
  return showUnlockScreen(context, reason: 'Buka ${area.label}');
}

/// Membuat kode baru: diketik dua kali untuk konfirmasi. True bila tersimpan.
Future<bool> showCreatePinScreen(BuildContext context, {String title = 'Buat kode baru'}) async {
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => _CreatePinScreen(title: title),
  ));
  return ok == true;
}

class _CreatePinScreen extends StatefulWidget {
  final String title;
  const _CreatePinScreen({required this.title});

  @override
  State<_CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<_CreatePinScreen> {
  String? _first;
  String? _error;

  Future<void> _entered(String pin) async {
    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
      });
      return;
    }
    if (pin != _first) {
      setState(() {
        _first = null;
        _error = 'Kode tidak sama. Ulangi dari awal.';
      });
      return;
    }
    await context.read<AppLock>().setPin(pin);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(),
      body: Center(
        child: SingleChildScrollView(
          child: PinPad(
            key: ValueKey(_first == null),
            title: _first == null ? widget.title : 'Ketik ulang kode',
            subtitle: _first == null ? '${AppLock.pinLength} digit angka' : 'Untuk memastikan tidak salah ketik',
            error: _error,
            onCompleted: _entered,
          ),
        ),
      ),
    );
  }
}

/// Ditaruh di MaterialApp.builder: menutup seluruh aplikasi — termasuk
/// layar yang sedang dibuka — selama kunci "Semua" belum dibuka, dan
/// mengunci lagi setelah aplikasi ditinggal cukup lama.
class AppLockOverlay extends StatefulWidget {
  final Widget child;
  const AppLockOverlay({super.key, required this.child});

  @override
  State<AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends State<AppLockOverlay> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = context.read<AppLock>();
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) lock.onBackgrounded();
    if (state == AppLifecycleState.resumed) lock.onResumed();
  }

  @override
  Widget build(BuildContext context) {
    final locked = context.select<AppLock, bool>((l) => l.lockedAtLaunch);
    return Stack(
      children: [
        // Isi aplikasi tetap terpasang supaya posisinya tidak hilang, tapi
        // tidak bisa disentuh dan tidak dibacakan selama terkunci.
        ExcludeSemantics(excluding: locked, child: AbsorbPointer(absorbing: locked, child: widget.child)),
        if (locked)
          Positioned.fill(
            child: Builder(builder: (context) {
              final c = AppColors.of(context);
              return Material(
                color: c.bg,
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Icon(LucideIcons.lock, size: 26, color: c.orange),
                          const SizedBox(height: 14),
                          UnlockView(
                            title: 'GroU terkunci',
                            reason: 'Masukkan kode untuk membuka',
                            onUnlocked: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}

/// Membungkus bagian yang bisa dikunci. Selama terkunci, isinya diganti
/// keterangan dan tombol untuk membukanya.
class LockedArea extends StatelessWidget {
  final LockArea area;
  final Widget child;

  /// Untuk halaman sendiri (bukan tab): keterangan terkunci diberi app bar
  /// supaya tetap bisa kembali.
  final bool page;
  const LockedArea({super.key, required this.area, required this.child, this.page = false});

  @override
  Widget build(BuildContext context) {
    final locked = context.select<AppLock, bool>((l) => l.requiresAuth(area));
    if (!locked) return child;
    final c = AppColors.of(context);
    final placeholder = Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.yellowChipBg, shape: BoxShape.circle),
              child: Icon(LucideIcons.lock, size: 24, color: c.yellowInk2),
            ),
            const SizedBox(height: 14),
            Text('${area.label} terkunci', style: TextStyle(fontFamily: AppFonts.title, fontSize: 20, fontWeight: FontWeight.w800, color: c.ink)),
            const SizedBox(height: 6),
            Text(
              'Masukkan kode untuk melihat isinya.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 12.5, fontWeight: FontWeight.w600, color: c.inkMuted),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: c.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
              onPressed: () => ensureUnlocked(context, area),
              icon: const Icon(LucideIcons.lockOpen, size: 17),
              label: const Text('Buka', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    return page ? Scaffold(backgroundColor: c.bg, appBar: AppBar(), body: placeholder) : placeholder;
  }
}
