import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Potongan formulir yang dipakai bersama oleh bottom sheet agenda dan target.

/// Wadah bottom sheet: sudut atas membulat, pegangan, dan isi yang bisa
/// digulung serta naik di atas keyboard.
class SheetScaffold extends StatelessWidget {
  final List<Widget> children;
  const SheetScaffold({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
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
                    decoration: BoxDecoration(color: c.lineSoft, borderRadius: BorderRadius.circular(99)),
                  ),
                ),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SheetTitle extends StatelessWidget {
  final String text;
  final String? subtitle;
  const SheetTitle(this.text, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: TextStyle(fontFamily: AppFonts.title, fontSize: 18, fontWeight: FontWeight.w800, color: c.ink, letterSpacing: -0.4)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 12, fontWeight: FontWeight.w600, color: c.inkMuted, height: 1.35)),
        ],
      ],
    );
  }
}

class SheetLabel extends StatelessWidget {
  final String text;
  const SheetLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(text, style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: c.inkMuted)),
    );
  }
}

InputDecoration sheetInputDecoration(AppColors c, String hint, {String? suffix}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: color, width: 1.5),
      );
  return InputDecoration(
    hintText: hint,
    suffixText: suffix,
    suffixStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.inkMuted),
    filled: true,
    fillColor: c.card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
    border: border(c.line),
    enabledBorder: border(c.line),
    focusedBorder: border(c.ink),
  );
}

/// Kotak bernilai yang dibuka dengan ketukan (tanggal, jam).
class SheetFieldBox extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const SheetFieldBox({super.key, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: c.card,
          border: Border.all(color: c.line, width: 1.5),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 10.5, fontWeight: FontWeight.w700, color: c.inkMuted)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.ink)),
          ],
        ),
      ),
    );
  }
}

class SheetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const SheetChip({super.key, required this.label, required this.selected, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 13, vertical: 9),
        alignment: compact ? Alignment.center : null,
        decoration: BoxDecoration(
          color: selected ? c.orangeChipBg : c.card,
          border: Border.all(color: selected ? c.orange : c.line, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? c.orangeChipInk : c.inkMuted3),
        ),
      ),
    );
  }
}

/// Tombol simpan oranye; abu dengan [disabledLabel] bila [onTap] null.
class SheetPrimaryButton extends StatelessWidget {
  final String label;
  final String disabledLabel;
  final VoidCallback? onTap;

  const SheetPrimaryButton({super.key, required this.label, required this.disabledLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? c.orange : c.lineSoft2,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          enabled ? label : disabledLabel,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: enabled ? Colors.white : c.inkMuted2),
        ),
      ),
    );
  }
}

/// Tombol garis untuk aksi sekunder seperti hapus atau arsipkan.
class SheetSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const SheetSecondaryButton({super.key, required this.label, required this.onTap, this.destructive = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: c.line, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: destructive ? c.orangeChipInk : c.inkMuted3)),
      ),
    );
  }
}

/// Dialog konfirmasi bergaya aplikasi. Mengembalikan kunci aksi yang dipilih,
/// atau null bila dibatalkan.
Future<String?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required Map<String, String> actions,
}) {
  final c = AppColors.of(context);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.ink)),
      content: Text(message, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.inkMuted3, height: 1.45)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Batal', style: TextStyle(color: c.inkMuted, fontWeight: FontWeight.w700)),
        ),
        for (final a in actions.entries)
          TextButton(
            onPressed: () => Navigator.of(context).pop(a.key),
            child: Text(a.value, style: TextStyle(color: c.orangeChipInk, fontWeight: FontWeight.w800)),
          ),
      ],
    ),
  );
}
