import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/schedule_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_time.dart';
import '../widgets/timezone_sheet.dart';
import 'manage_templates_screen.dart';

/// Tab "Pengaturan" — template yang aktif hari ini, pintu masuk ke Kelola
/// Template, aturan pelacakan, dan preferensi pengingat.
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final active = provider.activeTemplate;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
      children: [
        const Text('PREFERENSI', style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: AppColors.inkMuted)),
        const SizedBox(height: 5),
        const Text('Pengaturan', style: TextStyle(fontFamily: AppFonts.title, fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: AppColors.ink)),
        const SizedBox(height: 22),
        const Text('TEMPLATE KEGIATAN', style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.inkMuted)),
        const SizedBox(height: 11),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.yellowBg,
            border: Border.all(color: AppColors.yellow, width: 1.5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.orange),
                child: const Icon(LucideIcons.check, size: 12, color: Colors.white),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active?.name ?? 'Belum ada template',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: AppColors.yellowInk),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      active == null
                          ? 'Buat satu lewat Kelola Template'
                          : 'Aktif hari ini · ${active.activities.length} kegiatan · ${active.rangeLabel}',
                      style: const TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.yellowInk2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ManageTemplatesScreen()),
          ),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.line, width: 1.5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kelola Template', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: AppColors.ink)),
                      const SizedBox(height: 3),
                      Text(
                        '${provider.templates.length} template · atur kegiatan dan hari pemakaiannya',
                        style: const TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.inkMuted2),
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),
        const Text('ATURAN PELACAKAN', style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.inkMuted)),
        const SizedBox(height: 11),
        const _RuleRow(
          label: 'Jendela toleransi terlambat',
          sub: 'Dicentang lebih dari ini setelah rentang usai dihitung terlambat',
          value: '${ScheduleProvider.toleranceMinutes} mnt',
        ),
        const SizedBox(height: 9),
        _RuleRow(
          label: 'Zona waktu',
          sub: 'Semua jadwal mengikuti ${provider.timeZone.label}',
          value: provider.timeZone.code,
          onTap: () async {
            final picked = await showTimeZoneSheet(context, provider.timeZone);
            if (picked != null) await provider.setTimeZone(picked);
          },
        ),
        const SizedBox(height: 26),
        const Text('PENGINGAT', style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.inkMuted)),
        const SizedBox(height: 11),
        _ToggleRow(
          label: 'Notifikasi tiap kegiatan',
          sub: 'Muncul ${ScheduleProvider.reminderMinutesBefore} menit sebelum jam mulai',
          value: provider.notificationPrefs['each'] ?? false,
          onTap: () => _toggle(context, 'each'),
        ),
        const SizedBox(height: 10),
        _ToggleRow(
          label: 'Ringkasan pagi',
          sub: 'Setiap hari 06:00 · daftar kegiatan',
          value: provider.notificationPrefs['morning'] ?? false,
          onTap: () => _toggle(context, 'morning'),
        ),
        const SizedBox(height: 10),
        _ToggleRow(
          label: 'Ringkasan malam',
          sub: 'Setiap hari 21:30 · rekap & pembatalan',
          value: provider.notificationPrefs['night'] ?? false,
          onTap: () => _toggle(context, 'night'),
        ),
      ],
    );
  }

  /// Menyalakan pengingat sekaligus meminta izin sistem. Kalau izinnya ditolak,
  /// toggle tidak menyala dan pengguna diberi tahu.
  Future<void> _toggle(BuildContext context, String key) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<ScheduleProvider>().toggleNotification(key);
    if (ok) return;
    final unavailable = !NotificationService.instance.isAvailable;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          unavailable
              ? 'Notifikasi belum aktif di build ini. Hentikan aplikasi lalu jalankan ulang.'
              : 'Izin notifikasi belum diberikan. Aktifkan lewat pengaturan sistem.',
        ),
      ),
    );
  }
}

/// Baris aturan pelacakan. Tampil netral; menampilkan chevron dan merespons
/// ketukan hanya bila [onTap] diisi.
class _RuleRow extends StatelessWidget {
  final String label;
  final String sub;
  final String value;
  final VoidCallback? onTap;

  const _RuleRow({required this.label, required this.sub, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: AppColors.ink)),
                  const SizedBox(height: 3),
                  Text(sub, style: const TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.rowBg,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.inkMuted2),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String sub;
  final bool value;
  final VoidCallback onTap;

  const _ToggleRow({required this.label, required this.sub, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFFFFCF3) : Colors.white,
          border: Border.all(color: value ? AppColors.yellowBorder2 : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: AppColors.ink)),
                  const SizedBox(height: 3),
                  Text(sub, style: const TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 25,
              padding: const EdgeInsets.all(3),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: value ? AppColors.orange : const Color(0xFFE4DDD1),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Container(
                width: 19,
                height: 19,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Color(0x382B251E), blurRadius: 3, offset: Offset(0, 1))],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
