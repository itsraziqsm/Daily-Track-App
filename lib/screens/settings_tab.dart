import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';

/// Tab "Pengaturan" — info template (tetap, tidak diedit lewat UI), jendela
/// toleransi terlambat, dan preferensi pengingat.
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final first = provider.activities.first;
    final last = provider.activities.last;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
      children: [
        const Text('PREFERENSI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: AppColors.inkMuted)),
        const SizedBox(height: 5),
        const Text('Pengaturan', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: AppColors.ink)),
        const SizedBox(height: 22),
        const Text('TEMPLATE KEGIATAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.inkMuted)),
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
                    const Text('Template Harian', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: AppColors.yellowInk)),
                    const SizedBox(height: 3),
                    Text(
                      '${provider.totalCount} kegiatan · ${first.startTime}–${last.endTime}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.yellowInk2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Template ini tetap dan tidak dapat diubah lewat aplikasi.',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.inkMuted2.withValues(alpha: 0.9)),
          ),
        ),
        const SizedBox(height: 26),
        const Text('ATURAN PELACAKAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.inkMuted)),
        const SizedBox(height: 11),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line, width: 1.5),
            borderRadius: BorderRadius.circular(18),
            color: Colors.white,
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Jendela toleransi terlambat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: AppColors.ink)),
                    SizedBox(height: 3),
                    Text('Dicentang lebih dari ini setelah rentang usai dihitung terlambat', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.yellowChipBg,
                  border: Border.all(color: AppColors.yellowChipBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${ScheduleProvider.toleranceMinutes}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.yellowInk)),
                    const SizedBox(width: 3),
                    const Text('mnt', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.yellowInk2)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line, width: 1.5),
            borderRadius: BorderRadius.circular(18),
            color: Colors.white,
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Zona waktu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: AppColors.ink)),
                    SizedBox(height: 3),
                    Text('Semua jadwal mengikuti Waktu Indonesia Barat', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.yellowChipBg,
                  border: Border.all(color: AppColors.yellowChipBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('WIB', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.yellowInk)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const Text('PENGINGAT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.inkMuted)),
        const SizedBox(height: 11),
        _ToggleRow(
          label: 'Notifikasi tiap kegiatan',
          sub: 'Muncul 10 menit sebelum jam mulai',
          value: provider.notificationPrefs['each'] ?? false,
          onTap: () => provider.toggleNotification('each'),
        ),
        const SizedBox(height: 10),
        _ToggleRow(
          label: 'Ringkasan pagi',
          sub: 'Setiap hari 06:00 · daftar kegiatan',
          value: provider.notificationPrefs['morning'] ?? false,
          onTap: () => provider.toggleNotification('morning'),
        ),
        const SizedBox(height: 10),
        _ToggleRow(
          label: 'Ringkasan malam',
          sub: 'Setiap hari 21:30 · rekap & pembatalan',
          value: provider.notificationPrefs['night'] ?? false,
          onTap: () => provider.toggleNotification('night'),
        ),
      ],
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
                  Text(sub, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
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
