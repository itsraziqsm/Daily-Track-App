import 'package:flutter/material.dart';

import '../data/seed_activities.dart';
import '../theme/app_theme.dart';

/// Bottom sheet "Kenapa dibatalkan?" — persis alur desain: pilih chip alasan,
/// lalu konfirmasi. Mengembalikan teks alasan, atau null jika dibatalkan.
Future<String?> showSkipReasonDialog(BuildContext context, String activityLabel) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _SkipReasonSheet(activityLabel: activityLabel),
  );
}

class _SkipReasonSheet extends StatefulWidget {
  final String activityLabel;
  const _SkipReasonSheet({required this.activityLabel});

  @override
  State<_SkipReasonSheet> createState() => _SkipReasonSheetState();
}

class _SkipReasonSheetState extends State<_SkipReasonSheet> {
  String? _selected;
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_selected == null) return;
    if (_selected == 'Lainnya') {
      final text = _customController.text.trim();
      Navigator.of(context).pop(text.isEmpty ? 'Lainnya' : text);
    } else {
      Navigator.of(context).pop(_selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _selected != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
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
              'Kenapa dibatalkan?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.4),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.activityLabel} · dicatat ke riwayat',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skipReasons.map((reason) {
                final selected = _selected == reason;
                return GestureDetector(
                  onTap: () => setState(() => _selected = reason),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.orangeChipBg : AppColors.card,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: selected ? AppColors.orange : AppColors.line, width: 1.5),
                    ),
                    child: Text(
                      reason,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.orangeChipInk : const Color(0xFF6D6354),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_selected == 'Lainnya') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Tulis alasan...',
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: AppColors.line, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: AppColors.line, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: AppColors.yellow, width: 1.5),
                  ),
                ),
                maxLines: 2,
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: canConfirm ? _confirm : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: canConfirm ? AppColors.orange : AppColors.lineSoft2,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    canConfirm ? 'Catat pembatalan' : 'Pilih alasan dulu',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: canConfirm ? Colors.white : AppColors.inkMuted2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
