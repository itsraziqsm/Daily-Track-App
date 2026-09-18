import 'package:flutter/material.dart';

import '../data/seed_activities.dart';
import '../theme/app_theme.dart';

/// Dialog memilih alasan saat kegiatan ditandai tidak dijalankan.
/// Mengembalikan teks alasan, atau null jika dibatalkan.
Future<String?> showSkipReasonDialog(BuildContext context, String activityTitle) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    isScrollControlled: true,
    builder: (context) => _SkipReasonSheet(activityTitle: activityTitle),
  );
}

class _SkipReasonSheet extends StatefulWidget {
  final String activityTitle;
  const _SkipReasonSheet({required this.activityTitle});

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

  void _submit() {
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
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kenapa "${widget.activityTitle}" tidak dijalankan?',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Sekadar catatan, bukan penilaian.',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: skipReasons.map((reason) {
              final selected = _selected == reason;
              return ChoiceChip(
                label: Text(reason),
                selected: selected,
                onSelected: (_) => setState(() => _selected = reason),
                selectedColor: AppColors.accent.withValues(alpha: 0.18),
                labelStyle: TextStyle(
                  color: selected ? AppColors.accent : AppColors.ink,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
                side: BorderSide(color: selected ? AppColors.accent : AppColors.line),
                backgroundColor: Colors.transparent,
              );
            }).toList(),
          ),
          if (_selected == 'Lainnya') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customController,
              decoration: const InputDecoration(
                hintText: 'Tulis alasan...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selected == null ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Simpan'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
