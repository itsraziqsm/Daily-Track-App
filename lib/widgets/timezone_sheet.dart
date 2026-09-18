import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/app_time.dart';

/// Modal pemilih zona waktu. Mengembalikan zona terpilih, atau null bila
/// ditutup tanpa memilih.
Future<AppTimeZone?> showTimeZoneSheet(BuildContext context, AppTimeZone current) {
  return showModalBottomSheet<AppTimeZone>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _TimeZoneSheet(current: current),
  );
}

class _TimeZoneSheet extends StatelessWidget {
  final AppTimeZone current;
  const _TimeZoneSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      // SafeArea menampung bilah navigasi sistem, dan isinya digulung bila
      // layarnya pendek — tanpa ini baris terakhir bisa meluber.
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.lineSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const Text(
                'Zona waktu',
                style: TextStyle(fontFamily: AppFonts.title, fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.4),
              ),
              const SizedBox(height: 4),
              const Text(
                'Menentukan jam berjalan, batas hari, dan hitungan terlambat',
                style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 16),
              for (final zone in AppTimeZone.values) ...[
                _ZoneRow(zone: zone, selected: zone == current),
                if (zone != AppTimeZone.values.last) const SizedBox(height: 9),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoneRow extends StatelessWidget {
  final AppTimeZone zone;
  final bool selected;

  const _ZoneRow({required this.zone, required this.selected});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(zone),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.rowBg : AppColors.card,
          border: Border.all(color: selected ? AppColors.ink : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? AppColors.ink : AppColors.lineSoft, width: 2),
              ),
              child: selected
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ink),
                    )
                  : null,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${zone.code} · ${zone.label}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: AppColors.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    zone.sample,
                    style: const TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
