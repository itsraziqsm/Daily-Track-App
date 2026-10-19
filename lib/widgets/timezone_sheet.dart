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
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
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
                    color: c.lineSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text(
                'Zona waktu',
                style: TextStyle(fontFamily: AppFonts.title, fontSize: 18, fontWeight: FontWeight.w800, color: c.ink, letterSpacing: -0.4),
              ),
              const SizedBox(height: 4),
              Text(
                'Menentukan jam berjalan, batas hari, dan hitungan terlambat',
                style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 12, fontWeight: FontWeight.w600, color: c.inkMuted),
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
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(zone),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? c.rowBg : c.card,
          border: Border.all(color: selected ? c.ink : c.line, width: 1.5),
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
                border: Border.all(color: selected ? c.ink : c.lineSoft, width: 2),
              ),
              child: selected
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: c.ink),
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: c.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    zone.sample,
                    style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11.5, fontWeight: FontWeight.w600, color: c.inkMuted),
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
