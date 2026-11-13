import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/target.dart';
import '../providers/target_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_time.dart';
import '../utils/number_format.dart';
import '../utils/rupiah_input.dart';
import 'sheet_parts.dart';

DateTime get _today {
  final n = AppTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Membuka sheet untuk membuat target baru, atau menyunting [target].
/// Mengembalikan true bila target dihapus, supaya layar detailnya bisa ikut
/// ditutup.
Future<bool?> showTargetSheet(BuildContext context, {Target? target}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _TargetSheet(target: target),
  );
}

class _TargetSheet extends StatefulWidget {
  final Target? target;
  const _TargetSheet({this.target});

  @override
  State<_TargetSheet> createState() => _TargetSheetState();
}

class _TargetSheetState extends State<_TargetSheet> {
  late final Target? _original = widget.target;
  late TargetKind _kind = _original?.kind ?? TargetKind.value;
  late final _title = TextEditingController(text: _original?.title ?? '');
  late final _unit = TextEditingController(text: _original?.unit ?? '');
  late final _start = TextEditingController(text: _number(_original?.startValue));
  late final _goal = TextEditingController(
    text: _original?.kind == TargetKind.finance ? formatNumber(_original!.targetValue) : _number(_original?.targetValue),
  );
  late TargetPeriod _period = _original?.period ?? TargetPeriod.week;
  late DateTime? _deadline = _original?.deadline;

  static String _number(double? v) => v == null ? '' : formatNumber(v).replaceAll('.', '');

  bool get _isNew => _original == null;

  /// Tenggat berlaku untuk target yang tidak direset per periode.
  bool get _hasDeadline => _kind != TargetKind.count || _period == TargetPeriod.total;

  bool get _isFinance => _kind == TargetKind.finance;

  /// Angka target: rupiah untuk target finansial (titik sebagai pemisah
  /// ribuan), angka biasa untuk lainnya.
  double? get _goalValue => _isFinance ? parseRupiah(_goal.text) : parseNumber(_goal.text);

  String? get _problem {
    if (_title.text.trim().isEmpty) return 'Isi nama target';
    final goal = _goalValue;
    if (goal == null || goal <= 0 && _kind != TargetKind.value) return 'Isi angka target';
    if (_kind == TargetKind.value) {
      final start = parseNumber(_start.text);
      if (start == null) return 'Isi nilai awal';
      if (start == goal) return 'Nilai awal sama dengan target';
    }
    return null;
  }

  @override
  void dispose() {
    _title.dispose();
    _unit.dispose();
    _start.dispose();
    _goal.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? _today.add(const Duration(days: 30)),
      firstDate: _today,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    final targets = context.read<TargetProvider>();
    final unit = _unit.text.trim();
    await targets.save(Target(
      id: _original?.id ?? 0,
      kind: _kind,
      title: _title.text.trim(),
      unit: _kind == TargetKind.streak || _isFinance || unit.isEmpty ? null : unit,
      startValue: _kind == TargetKind.value ? parseNumber(_start.text) : null,
      targetValue: _goalValue!,
      period: _kind == TargetKind.count ? _period : TargetPeriod.total,
      deadline: _hasDeadline ? _deadline : null,
      createdAt: _original?.createdAt ?? _today,
      archived: _original?.archived ?? false,
    ));
    if (mounted) Navigator.of(context).pop(false);
  }

  Future<void> _archive() async {
    final targets = context.read<TargetProvider>();
    await targets.setArchived(_original!, !_original!.archived);
    if (mounted) Navigator.of(context).pop(false);
  }

  Future<void> _delete() async {
    final targets = context.read<TargetProvider>();
    final choice = await showConfirmDialog(
      context,
      title: 'Hapus target ini?',
      message: '"${_original!.title}" beserta semua catatannya akan dihapus. Kalau hanya ingin menyimpannya, arsipkan saja.',
      actions: const {'delete': 'Hapus'},
    );
    if (choice == null) return;
    await targets.delete(_original!);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    const numberKeyboard = TextInputType.numberWithOptions(decimal: true);
    final unit = _unit.text.trim().isEmpty ? null : _unit.text.trim();
    final problem = _problem;

    final (titleHint, unitHint) = switch (_kind) {
      TargetKind.streak => ('mis. Konsisten 2 minggu', ''),
      TargetKind.value => ('mis. Turun berat badan', 'mis. kg'),
      TargetKind.count => ('mis. Baca buku', 'mis. buku'),
      TargetKind.finance => ('mis. Laptop baru atau dana darurat', ''),
    };

    return SheetScaffold(
      children: [
        SheetTitle(_isNew ? 'Target baru' : 'Edit target', subtitle: _kind.description),
        const SizedBox(height: 14),
        if (_isNew) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in TargetKind.values)
                SheetChip(
                  label: k.label,
                  selected: _kind == k,
                  onTap: () => setState(() {
                    // Format angkanya berbeda (rupiah vs desimal), jadi isian
                    // dikosongkan saat berpindah ke atau dari Finansial.
                    if ((k == TargetKind.finance) != _isFinance) _goal.clear();
                    _kind = k;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: _title,
          autofocus: _isNew,
          onChanged: (_) => setState(() {}),
          decoration: sheetInputDecoration(c, titleHint),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.ink),
        ),
        if (_kind != TargetKind.streak && !_isFinance) ...[
          const SizedBox(height: 9),
          TextField(
            controller: _unit,
            onChanged: (_) => setState(() {}),
            decoration: sheetInputDecoration(c, 'Satuan ($unitHint)'),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink),
          ),
        ],
        const SizedBox(height: 16),
        SheetLabel(switch (_kind) {
          TargetKind.streak => 'TARGET HARI BERUNTUN',
          TargetKind.value => 'DARI → KE',
          TargetKind.count => 'TARGET JUMLAH',
          TargetKind.finance => 'DANA YANG DIBUTUHKAN',
        }),
        Row(
          children: [
            if (_kind == TargetKind.value) ...[
              Expanded(
                child: TextField(
                  controller: _start,
                  keyboardType: numberKeyboard,
                  onChanged: (_) => setState(() {}),
                  decoration: sheetInputDecoration(c, 'Awal', suffix: unit),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.ink),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: TextField(
                controller: _goal,
                keyboardType: _isFinance ? TextInputType.number : numberKeyboard,
                inputFormatters: _isFinance ? [RupiahInputFormatter()] : null,
                onChanged: (_) => setState(() {}),
                decoration: sheetInputDecoration(c, _isFinance ? '0' : 'Target', suffix: _kind == TargetKind.streak ? 'hari' : (_isFinance ? null : unit)).copyWith(
                  prefixText: _isFinance ? 'Rp ' : null,
                ),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.ink),
              ),
            ),
          ],
        ),
        if (_kind == TargetKind.count) ...[
          const SizedBox(height: 16),
          const SheetLabel('DIHITUNG'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in TargetPeriod.values) SheetChip(label: p.label, selected: _period == p, onTap: () => setState(() => _period = p)),
            ],
          ),
        ],
        if (_hasDeadline) ...[
          const SizedBox(height: 16),
          const SheetLabel('TENGGAT'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SheetChip(label: 'Tanpa tenggat', selected: _deadline == null, onTap: () => setState(() => _deadline = null)),
              SheetChip(
                label: _deadline == null ? 'Pilih tanggal…' : DateFormat('d MMM yyyy', 'id_ID').format(_deadline!),
                selected: _deadline != null,
                onTap: _pickDeadline,
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        SheetPrimaryButton(label: 'Simpan target', disabledLabel: problem ?? '', onTap: problem == null ? _save : null),
        if (!_isNew) ...[
          const SizedBox(height: 10),
          SheetSecondaryButton(label: _original!.archived ? 'Aktifkan lagi' : 'Arsipkan', onTap: _archive),
          const SizedBox(height: 10),
          SheetSecondaryButton(label: 'Hapus target', destructive: true, onTap: _delete),
        ],
      ],
    );
  }
}

/// Membuka sheet untuk mencatat angka (target angka) atau menambah hitungan
/// (target hitungan).
Future<void> showTargetEntrySheet(BuildContext context, Target target) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _EntrySheet(target: target),
  );
}

class _EntrySheet extends StatefulWidget {
  final Target target;
  const _EntrySheet({required this.target});

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  late final bool _isCount = widget.target.kind == TargetKind.count;
  late final _value = TextEditingController(text: _isCount ? '1' : '');
  final _note = TextEditingController();
  DateTime _date = _today;

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _valid {
    final v = parseNumber(_value.text);
    return v != null && (!_isCount || v > 0);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: _today,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final note = _note.text.trim();
    await context.read<TargetProvider>().addEntry(TargetEntry(
          targetId: widget.target.id,
          date: _date,
          value: parseNumber(_value.text)!,
          note: note.isEmpty ? null : note,
        ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = widget.target;
    return SheetScaffold(
      children: [
        SheetTitle(_isCount ? 'Tambah ${t.unit ?? 'hitungan'}' : 'Catat ${t.title.toLowerCase()}', subtitle: t.title),
        const SizedBox(height: 14),
        SheetLabel(_isCount ? 'JUMLAH' : 'NILAI TERBARU'),
        TextField(
          controller: _value,
          autofocus: !_isCount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: sheetInputDecoration(c, _isCount ? '1' : 'mis. ${formatNumber(t.startValue ?? 0)}', suffix: t.unit),
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.ink),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _note,
          decoration: sheetInputDecoration(c, _isCount ? 'Catatan, mis. judul buku (opsional)' : 'Catatan (opsional)'),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink),
        ),
        const SizedBox(height: 16),
        const SheetLabel('TANGGAL'),
        SheetFieldBox(label: 'Tanggal', value: DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_date), onTap: _pickDate),
        const SizedBox(height: 20),
        SheetPrimaryButton(label: 'Simpan', disabledLabel: 'Isi angkanya', onTap: _valid ? _save : null),
      ],
    );
  }
}
