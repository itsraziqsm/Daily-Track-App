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
    final c = AppColors.of(context);
    final canConfirm = _selected != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
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
                  color: c.lineSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              'Kenapa dibatalkan?',
              style: TextStyle(fontFamily: AppFonts.title, fontSize: 18, fontWeight: FontWeight.w800, color: c.ink, letterSpacing: -0.4),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.activityLabel} · dicatat ke riwayat',
              style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 12, fontWeight: FontWeight.w600, color: c.inkMuted),
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
                      color: selected ? c.orangeChipBg : c.card,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: selected ? c.orange : c.line, width: 1.5),
                    ),
                    child: Text(
                      reason,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? c.orangeChipInk : c.inkMuted3,
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
                  fillColor: c.card,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: c.line, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: c.line, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: c.yellow, width: 1.5),
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
                    color: canConfirm ? c.orange : c.lineSoft2,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    canConfirm ? 'Catat pembatalan' : 'Pilih alasan dulu',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: canConfirm ? Colors.white : c.inkMuted2,
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
