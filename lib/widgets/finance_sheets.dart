import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/finance.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/number_format.dart';
import '../utils/rupiah_input.dart';
import 'sheet_parts.dart';

Future<void> _show(BuildContext context, Widget sheet) => showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => sheet,
    );

/// Kolom jumlah rupiah dengan pemisah ribuan otomatis.
class _RupiahField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  const _RupiahField({required this.controller, required this.onChanged, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [RupiahInputFormatter()],
      onChanged: onChanged,
      decoration: sheetInputDecoration(c, '0').copyWith(
        prefixText: 'Rp ',
        prefixStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.inkMuted),
      ),
      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.ink),
    );
  }
}

String _initial(double? v) => v == null || v == 0 ? '' : formatNumber(v);

/// Mencatat atau menyunting pengeluaran tidak tetap / pemasukan lain.
Future<void> showFinanceEntrySheet(BuildContext context, {required FinanceEntryKind kind, required DateTime date, FinanceEntry? entry}) =>
    _show(context, _EntrySheet(kind: entry?.kind ?? kind, date: entry?.date ?? date, entry: entry));

class _EntrySheet extends StatefulWidget {
  final FinanceEntryKind kind;
  final DateTime date;
  final FinanceEntry? entry;
  const _EntrySheet({required this.kind, required this.date, this.entry});

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  late final _amount = TextEditingController(text: _initial(widget.entry?.amount));
  late final _note = TextEditingController(text: widget.entry?.note ?? '');
  late DateTime _date = widget.date;
  late String _category = widget.entry?.category ?? ExpenseCategories.all.first;

  bool get _isExpense => widget.kind == FinanceEntryKind.expense;
  bool get _valid => (parseRupiah(_amount.text) ?? 0) > 0;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final finance = context.read<FinanceProvider>();
    final note = _note.text.trim();
    final entry = FinanceEntry(
      id: widget.entry?.id ?? 0,
      kind: widget.kind,
      date: _date,
      amount: parseRupiah(_amount.text)!,
      category: _isExpense ? _category : null,
      note: note.isEmpty ? null : note,
    );
    if (widget.entry == null) {
      await finance.addEntry(entry);
    } else {
      await finance.updateEntry(entry);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final finance = context.read<FinanceProvider>();
    final choice = await showConfirmDialog(
      context,
      title: 'Hapus catatan ini?',
      message: '${formatRupiah(widget.entry!.amount)} pada ${DateFormat('d MMMM yyyy', 'id_ID').format(widget.entry!.date)} akan dihapus.',
      actions: const {'delete': 'Hapus'},
    );
    if (choice == null) return;
    await finance.deleteEntry(widget.entry!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isNew = widget.entry == null;
    return SheetScaffold(
      children: [
        SheetTitle(
          _isExpense ? (isNew ? 'Catat pengeluaran' : 'Edit pengeluaran') : (isNew ? 'Pemasukan lain' : 'Edit pemasukan'),
          subtitle: _isExpense ? 'Pengeluaran tidak tetap, mis. makan atau bensin' : 'Di luar gaji, mis. bonus atau freelance',
        ),
        const SizedBox(height: 14),
        _RupiahField(controller: _amount, autofocus: isNew, onChanged: (_) => setState(() {})),
        const SizedBox(height: 9),
        TextField(
          controller: _note,
          decoration: sheetInputDecoration(c, _isExpense ? 'Catatan, mis. makan siang (opsional)' : 'Sumber, mis. bonus proyek (opsional)'),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink),
        ),
        if (_isExpense) ...[
          const SizedBox(height: 16),
          const SheetLabel('KATEGORI'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final cat in ExpenseCategories.all) SheetChip(label: cat, selected: _category == cat, onTap: () => setState(() => _category = cat)),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const SheetLabel('TANGGAL'),
        SheetFieldBox(label: 'Tanggal', value: DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_date), onTap: _pickDate),
        const SizedBox(height: 20),
        SheetPrimaryButton(label: 'Simpan', disabledLabel: 'Isi jumlahnya', onTap: _valid ? _save : null),
        if (!isNew) ...[
          const SizedBox(height: 10),
          SheetSecondaryButton(label: 'Hapus catatan', destructive: true, onTap: _delete),
        ],
      ],
    );
  }
}

/// Menambah atau menyunting pengeluaran tetap bulanan.
Future<void> showRecurringSheet(BuildContext context, {RecurringExpense? expense}) => _show(context, _RecurringSheet(expense: expense));

class _RecurringSheet extends StatefulWidget {
  final RecurringExpense? expense;
  const _RecurringSheet({this.expense});

  @override
  State<_RecurringSheet> createState() => _RecurringSheetState();
}

class _RecurringSheetState extends State<_RecurringSheet> {
  late final _title = TextEditingController(text: widget.expense?.title ?? '');
  late final _amount = TextEditingController(text: _initial(widget.expense?.amount));
  late String _category = widget.expense?.category ?? 'Tempat tinggal';

  bool get _valid => _title.text.trim().isNotEmpty && (parseRupiah(_amount.text) ?? 0) > 0;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final finance = context.read<FinanceProvider>();
    final base = widget.expense ?? RecurringExpense(title: '', category: _category, amount: 0, from: finance.currentMonth);
    await finance.saveRecurring(base.copyWith(title: _title.text.trim(), amount: parseRupiah(_amount.text), category: _category));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _stop() async {
    final finance = context.read<FinanceProvider>();
    final e = widget.expense!;
    final choice = await showConfirmDialog(
      context,
      title: 'Hentikan pengeluaran ini?',
      message: '"${e.title}" tidak dihitung lagi mulai bulan ini. Bulan-bulan sebelumnya tetap tercatat.',
      actions: const {'stop': 'Hentikan'},
    );
    if (choice == null) return;
    await finance.stopRecurring(e);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isNew = widget.expense == null;
    return SheetScaffold(
      children: [
        SheetTitle(
          isNew ? 'Pengeluaran tetap' : 'Edit pengeluaran tetap',
          subtitle: isNew
              ? 'Dihitung otomatis tiap bulan mulai bulan ini, mis. kos, cicilan, langganan'
              : 'Mengubah jumlah berlaku mulai bulan ini; bulan-bulan sebelumnya tidak berubah',
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _title,
          autofocus: isNew,
          onChanged: (_) => setState(() {}),
          decoration: sheetInputDecoration(c, 'Nama, mis. Kos'),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.ink),
        ),
        const SizedBox(height: 9),
        _RupiahField(controller: _amount, onChanged: (_) => setState(() {})),
        const SizedBox(height: 16),
        const SheetLabel('KATEGORI'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final cat in ExpenseCategories.all) SheetChip(label: cat, selected: _category == cat, onTap: () => setState(() => _category = cat)),
          ],
        ),
        const SizedBox(height: 20),
        SheetPrimaryButton(label: 'Simpan', disabledLabel: 'Isi nama dan jumlahnya', onTap: _valid ? _save : null),
        if (!isNew) ...[
          const SizedBox(height: 10),
          SheetSecondaryButton(label: 'Hentikan mulai bulan ini', destructive: true, onTap: _stop),
        ],
      ],
    );
  }
}

/// Mengisi satu angka rupiah: gaji bulanan atau saldo tabungan.
Future<void> showAmountSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required double? initial,
  required Future<void> Function(double) onSave,
}) =>
    _show(context, _AmountSheet(title: title, subtitle: subtitle, initial: initial, onSave: onSave));

class _AmountSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final double? initial;
  final Future<void> Function(double) onSave;
  const _AmountSheet({required this.title, required this.subtitle, required this.initial, required this.onSave});

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late final _amount = TextEditingController(text: _initial(widget.initial));

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      children: [
        SheetTitle(widget.title, subtitle: widget.subtitle),
        const SizedBox(height: 14),
        _RupiahField(controller: _amount, autofocus: true, onChanged: (_) => setState(() {})),
        const SizedBox(height: 20),
        SheetPrimaryButton(
          label: 'Simpan',
          disabledLabel: 'Isi jumlahnya',
          onTap: parseRupiah(_amount.text) == null
              ? null
              : () async {
                  await widget.onSave(parseRupiah(_amount.text)!);
                  if (context.mounted) Navigator.of(context).pop();
                },
        ),
      ],
    );
  }
}
