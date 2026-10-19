import 'package:flutter/material.dart';

import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';

/// Label ringkas jendela toleransi, mis. "35 mnt" atau "1,5 jam".
String toleranceLabel(int minutes) {
  if (minutes < 60) return '$minutes mnt';
  final hours = minutes / 60;
  return '${hours == hours.roundToDouble() ? hours.round() : hours.toString().replaceAll('.', ',')} jam';
}

/// Modal pemilih jendela toleransi terlambat. Mengembalikan menit terpilih,
/// atau null bila ditutup tanpa memilih.
Future<int?> showToleranceSheet(BuildContext context, int current) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _ToleranceSheet(current: current),
  );
}

class _ToleranceSheet extends StatelessWidget {
  final int current;
  const _ToleranceSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: c.lineSoft, borderRadius: BorderRadius.circular(99)),
                ),
              ),
              Text(
                'Toleransi terlambat',
                style: TextStyle(fontFamily: AppFonts.title, fontSize: 18, fontWeight: FontWeight.w800, color: c.ink, letterSpacing: -0.4),
              ),
              const SizedBox(height: 4),
              Text(
                'Kegiatan yang dicentang lebih lama dari ini setelah jam selesainya dihitung terlambat',
                style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 12, fontWeight: FontWeight.w600, color: c.inkMuted, height: 1.35),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final minutes in ScheduleProvider.toleranceOptions)
                    _OptionChip(
                      label: toleranceLabel(minutes),
                      selected: minutes == current,
                      onTap: () => Navigator.of(context).pop(minutes),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Berlaku untuk centang berikutnya. Status yang sudah tercatat tidak berubah.',
                style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11.5, fontWeight: FontWeight.w600, color: c.inkMuted2, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 74,
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.yellowChipBg : c.card,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? c.yellow : c.line, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: selected ? c.yellowInk : c.inkMuted3),
        ),
      ),
    );
  }
}
