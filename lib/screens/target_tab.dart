import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/target.dart';
import '../providers/finance_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/target_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/target_card.dart';
import '../widgets/target_sheets.dart';
import 'target_detail_screen.dart';

/// Tab "Target" — streak yang dihitung otomatis dari log harian, serta goal
/// yang dicatat manual (angka seperti berat badan, atau hitungan seperti buku
/// yang dibaca). Ketuk kartu untuk detail dan riwayatnya.
class TargetTab extends StatefulWidget {
  const TargetTab({super.key});

  @override
  State<TargetTab> createState() => _TargetTabState();
}

class _TargetTabState extends State<TargetTab> {
  bool _showArchived = false;

  /// Tombol cepat di kartu: catat/+1 untuk angka dan hitungan, "Sudah dibeli"
  /// untuk target finansial yang dananya sudah cukup.
  Widget? _actionFor(Target t, TargetProgress p) {
    if (t.archived) return null;
    return switch (t.kind) {
      TargetKind.streak => null,
      TargetKind.finance => p.status == TargetStatus.fundsAmple || p.status == TargetStatus.fundsEnough ? PurchaseButton(target: t, progress: p) : null,
      _ => TargetEntryButton(target: t),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final targets = context.watch<TargetProvider>();
    // Target streak ikut berubah saat kegiatan dicentang di Hari Ini.
    context.watch<ScheduleProvider>();
    // Target finansial membaca saldo tabungan dari Keuangan.
    context.watch<FinanceProvider>();
    final active = targets.active;
    final archived = targets.archived;

    Widget card(Target t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TargetCard(
            target: t,
            progress: targets.progressOf(t),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TargetDetailScreen(targetId: t.id))),
            action: _actionFor(t, targets.progressOf(t)),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
      children: [
        Text(
          'SASARAN',
          style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: c.inkMuted),
        ),
        const SizedBox(height: 5),
        Text(
          'Target',
          style: TextStyle(fontFamily: AppFonts.title, fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: c.ink),
        ),
        const SizedBox(height: 18),
        if (active.isEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: c.card,
              border: Border.all(color: c.line, width: 1.5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Belum ada target', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.ink)),
                const SizedBox(height: 5),
                Text(
                  'Buat streak hari beruntun, target angka seperti berat badan atau beban gym, '
                  'atau hitungan seperti buku yang dibaca.',
                  style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 12, fontWeight: FontWeight.w600, color: c.inkMuted, height: 1.45),
                ),
              ],
            ),
          ),
        for (final t in active) card(t),
        GestureDetector(
          onTap: () => showTargetSheet(context),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.lineSoft, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.plus, size: 17, color: c.inkMuted),
                const SizedBox(width: 8),
                Text('Tambah target', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.inkMuted)),
              ],
            ),
          ),
        ),
        if (archived.isNotEmpty) ...[
          const SizedBox(height: 22),
          GestureDetector(
            onTap: () => setState(() => _showArchived = !_showArchived),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Row(
                children: [
                  Text(
                    'DIARSIPKAN (${archived.length})',
                    style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: c.inkMuted),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _showArchived ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(LucideIcons.chevronDown, size: 15, color: c.inkMuted2),
                  ),
                ],
              ),
            ),
          ),
          if (_showArchived)
            for (final t in archived) Opacity(opacity: 0.75, child: card(t)),
        ],
      ],
    );
  }
}
