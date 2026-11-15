import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/app_lock.dart';
import '../theme/app_theme.dart';
import '../widgets/lock_screen.dart';
import '../widgets/section_parts.dart';

/// Halaman "Autentikasi" (Pengaturan → Keamanan): bagian mana yang dikunci,
/// kode, dan biometrik.
class AuthSettingsScreen extends StatefulWidget {
  const AuthSettingsScreen({super.key});

  @override
  State<AuthSettingsScreen> createState() => _AuthSettingsScreenState();
}

class _AuthSettingsScreenState extends State<AuthSettingsScreen> {
  bool? _biometricAvailable;

  @override
  void initState() {
    super.initState();
    context.read<AppLock>().biometrics.isAvailable().then((ok) {
      if (mounted) setState(() => _biometricAvailable = ok);
    });
  }

  /// Mengubah cakupan. Mengaktifkan kunci untuk pertama kali meminta kode
  /// dibuat dulu; bila dibatalkan, cakupan tidak berubah.
  Future<void> _setScope(LockScope scope) async {
    final lock = context.read<AppLock>();
    if (scope != LockScope.none && !lock.hasPin) {
      if (!await showCreatePinScreen(context)) return;
    }
    if (scope == LockScope.selected && lock.areas.isEmpty) await lock.setAreas(LockArea.values.toSet());
    await lock.setScope(scope);
  }

  Future<void> _toggleArea(LockArea area) async {
    final lock = context.read<AppLock>();
    final areas = {...lock.areas};
    areas.contains(area) ? areas.remove(area) : areas.add(area);
    await lock.setAreas(areas);
    // Tanpa satu bagian pun, "Pilih bagian" sama dengan tidak ada kunci.
    if (areas.isEmpty) await lock.setScope(LockScope.none);
  }

  Future<void> _changePin() async {
    final lock = context.read<AppLock>();
    if (lock.hasPin && !await showUnlockScreen(context, reason: 'Masukkan kode lama dulu')) return;
    if (!mounted) return;
    await showCreatePinScreen(context, title: lock.hasPin ? 'Kode baru' : 'Buat kode baru');
  }

  Future<void> _toggleBiometric(bool on) async {
    final lock = context.read<AppLock>();
    if (on && !await lock.biometrics.authenticate('Aktifkan biometrik untuk GroU')) return;
    await lock.setBiometric(on);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final lock = context.watch<AppLock>();
    final scope = lock.hasPin ? lock.scope : LockScope.none;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          'Autentikasi',
          style: TextStyle(fontFamily: AppFonts.title, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: c.ink),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
        children: [
          const SectionLabel('KUNCI APLIKASI'),
          for (final s in LockScope.values) ...[
            _ChoiceRow(
              label: s.label,
              sub: s.description,
              selected: scope == s,
              radio: true,
              onTap: () => _setScope(s),
            ),
            if (s == LockScope.selected && scope == LockScope.selected)
              Padding(
                padding: const EdgeInsets.only(left: 18, top: 2, bottom: 4),
                child: Column(
                  children: [
                    for (final a in LockArea.values)
                      _ChoiceRow(
                        label: a.label,
                        selected: lock.areas.contains(a),
                        radio: false,
                        dense: true,
                        onTap: () => _toggleArea(a),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 14),
          const SectionLabel('METODE'),
          _ChoiceRow(
            label: lock.hasPin ? 'Ubah kode' : 'Buat kode',
            sub: '${AppLock.pinLength} digit angka · selalu bisa dipakai, juga saat biometrik gagal',
            icon: LucideIcons.keyRound,
            onTap: _changePin,
          ),
          const SizedBox(height: 8),
          _ChoiceRow(
            label: 'Biometrik',
            sub: switch (_biometricAvailable) {
              null => 'Memeriksa sensor…',
              false => 'Tidak tersedia: perangkat tanpa sensor, atau belum ada sidik jari/wajah terdaftar',
              true => lock.hasPin ? 'Sidik jari atau wajah, dengan kode sebagai cadangan' : 'Buat kode dulu sebagai cadangan',
            },
            icon: LucideIcons.fingerprint,
            toggle: lock.biometricEnabled,
            onTap: _biometricAvailable == true && lock.hasPin ? () => _toggleBiometric(!lock.biometricEnabled) : null,
          ),
          const SizedBox(height: 20),
          SectionHint(
            'Setelah dibuka, aplikasi tetap terbuka sampai ditinggal di latar belakang lebih dari '
            '${AppLock.relockAfter.inMinutes} menit. Kunci ini melindungi tampilan; datanya tetap tersimpan '
            'di perangkat tanpa enkripsi.',
          ),
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  final String label;
  final String? sub;
  final IconData? icon;
  final bool? selected;
  final bool radio;
  final bool dense;
  final bool? toggle;
  final VoidCallback? onTap;

  const _ChoiceRow({
    required this.label,
    this.sub,
    this.icon,
    this.selected,
    this.radio = true,
    this.dense = false,
    this.toggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final disabled = onTap == null;
    final on = selected ?? false;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: dense ? const EdgeInsets.only(top: 6) : EdgeInsets.zero,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 11 : 14),
          decoration: BoxDecoration(
            color: on && !dense ? c.cardWarm : c.card,
            border: Border.all(color: on && !dense ? c.yellowBorder2 : c.line, width: 1.5),
            borderRadius: BorderRadius.circular(dense ? 14 : 18),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 19, color: c.inkMuted3),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: dense ? 13.5 : 14, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: c.ink)),
                    if (sub != null) ...[
                      const SizedBox(height: 3),
                      Text(sub!, style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11.5, fontWeight: FontWeight.w600, color: c.inkMuted, height: 1.35)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (toggle != null)
                _Switch(on: toggle!)
              else if (selected != null)
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: radio ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: radio ? null : BorderRadius.circular(6),
                    color: !radio && on ? c.orange : null,
                    border: Border.all(color: on ? (radio ? c.ink : c.orange) : c.lineSoft, width: 2),
                  ),
                  child: !on
                      ? null
                      : radio
                          ? Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: c.ink))
                          : const Icon(LucideIcons.check, size: 13, color: Colors.white),
                )
              else
                Icon(LucideIcons.chevronRight, size: 18, color: c.inkMuted2),
            ],
          ),
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  final bool on;
  const _Switch({required this.on});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 42,
      height: 25,
      padding: const EdgeInsets.all(3),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(color: on ? c.orange : c.cancelledDot, borderRadius: BorderRadius.circular(99)),
      child: Container(
        width: 19,
        height: 19,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [BoxShadow(color: c.shadow.withValues(alpha: 0.22), blurRadius: 3, offset: const Offset(0, 1))],
        ),
      ),
    );
  }
}
