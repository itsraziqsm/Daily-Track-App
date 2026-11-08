import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/activity.dart';
import '../models/agenda_item.dart';
import '../providers/agenda_provider.dart';
import '../theme/app_theme.dart';
import 'sheet_parts.dart';

const _weekdayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

/// Pilihan pengingat untuk agenda berjam: menit sebelum mulai.
const _timedReminders = <int, String>{0: 'Saat mulai', 5: '5 mnt', 10: '10 mnt', 15: '15 mnt', 30: '30 mnt', 60: '1 jam', 1440: '1 hari'};

/// Pilihan pengingat untuk agenda sepanjang hari, dihitung dari 00.00.
const _allDayReminders = <int, String>{-360: 'Hari H 06.00', 240: 'H-1 20.00'};

/// Membuka sheet untuk membuat agenda baru pada [day], atau menyunting [item].
/// Penyimpanan dan penghapusan dilakukan langsung lewat [AgendaProvider].
Future<void> showAgendaSheet(BuildContext context, {required DateTime day, AgendaItem? item}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AgendaSheet(day: day, item: item),
  );
}

class _AgendaSheet extends StatefulWidget {
  final DateTime day;
  final AgendaItem? item;
  const _AgendaSheet({required this.day, this.item});

  @override
  State<_AgendaSheet> createState() => _AgendaSheetState();
}

class _AgendaSheetState extends State<_AgendaSheet> {
  late final AgendaItem? _original = widget.item;
  late final _title = TextEditingController(text: _original?.title ?? '');
  late final _note = TextEditingController(text: _original?.note ?? '');
  late DateTime _date = _original?.date ?? widget.day;
  late bool _allDay = _original?.isAllDay ?? false;
  late String _start = _original?.startTime ?? '09.00';
  late String _end = _original?.endTime ?? '10.00';
  late AgendaRepeat _repeat = _original?.repeat ?? AgendaRepeat.none;
  late Set<int> _repeatDays = {...?_original?.repeatDays};
  late DateTime? _until = _original?.repeatUntil;
  late int? _reminder = _original?.reminderMinutes;
  bool _saving = false;

  bool get _isNew => _original == null;
  bool get _canSave =>
      _title.text.trim().isNotEmpty && (_repeat != AgendaRepeat.weekly || _repeatDays.isNotEmpty);

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool until}) async {
    final initial = until ? (_until ?? _date) : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: until ? _date : DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (until) {
        _until = picked;
      } else {
        _date = picked;
        if (_until != null && _until!.isBefore(picked)) _until = picked;
      }
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final minutes = Activity.parseMinutes(isStart ? _start : _end);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final value = Activity.formatMinutes(picked.hour * 60 + picked.minute);
    setState(() {
      if (isStart) {
        // Geser jam selesai bersama jam mulai supaya durasinya tetap.
        final duration = Activity.parseMinutes(_end) - Activity.parseMinutes(_start);
        _start = value;
        _end = Activity.formatMinutes(picked.hour * 60 + picked.minute + (duration > 0 ? duration : 60));
      } else {
        _end = value;
      }
    });
  }

  void _setRepeat(AgendaRepeat repeat) {
    setState(() {
      _repeat = repeat;
      if (repeat == AgendaRepeat.weekly && _repeatDays.isEmpty) _repeatDays = {_date.weekday};
    });
  }

  void _setAllDay(bool allDay) {
    setState(() {
      _allDay = allDay;
      // Pilihan pengingat berbeda untuk kedua jenis, jadi yang lama dibuang.
      _reminder = null;
    });
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    final agenda = context.read<AgendaProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final note = _note.text.trim();
    final item = AgendaItem(
      id: _original?.id ?? 0,
      title: _title.text.trim(),
      note: note.isEmpty ? null : note,
      date: _date,
      startTime: _allDay ? null : _start,
      endTime: _allDay ? null : _end,
      repeat: _repeat,
      repeatDays: _repeat == AgendaRepeat.weekly ? (_repeatDays.toList()..sort()) : const [],
      repeatUntil: _repeat == AgendaRepeat.none ? null : _until,
      reminderMinutes: _reminder,
    );
    if (_reminder != null && !await agenda.ensureReminderPermission()) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Izin notifikasi belum diberikan, jadi pengingatnya belum akan muncul. Aktifkan lewat pengaturan sistem.'),
      ));
    }
    await agenda.save(item);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final agenda = context.read<AgendaProvider>();
    final item = _original!;
    final choice = await showConfirmDialog(
      context,
      title: 'Hapus agenda ini?',
      message: item.isRepeating
          ? '"${item.title}" berulang ${item.repeatLabel.toLowerCase()}. Hapus hanya untuk ${DateFormat('d MMMM', 'id_ID').format(widget.day)}, atau semua jadwalnya?'
          : '"${item.title}" akan dihapus.',
      actions: item.isRepeating ? const {'once': 'Tanggal ini', 'all': 'Semua'} : const {'all': 'Hapus'},
    );
    if (choice == null) return;
    if (choice == 'once') {
      await agenda.skipOn(item, widget.day);
    } else {
      await agenda.delete(item);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final reminders = _allDay ? _allDayReminders : _timedReminders;
    final dateLabel = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_date);

    return SheetScaffold(
      children: [
        SheetTitle(
          _isNew ? 'Agenda baru' : 'Edit agenda',
          subtitle: !_isNew && _original!.isRepeating ? 'Perubahan berlaku untuk semua tanggal agenda ini.' : null,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _title,
          autofocus: _isNew,
          onChanged: (_) => setState(() {}),
          decoration: sheetInputDecoration(c, 'Judul agenda'),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.ink),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _note,
          minLines: 1,
          maxLines: 3,
          decoration: sheetInputDecoration(c, 'Catatan (opsional)'),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink),
        ),
        const SizedBox(height: 16),
        const SheetLabel('TANGGAL'),
        SheetFieldBox(label: _repeat == AgendaRepeat.none ? 'Tanggal' : 'Mulai', value: dateLabel, onTap: () => _pickDate(until: false)),
        const SizedBox(height: 16),
        const SheetLabel('WAKTU'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SheetChip(label: 'Seharian', selected: _allDay, onTap: () => _setAllDay(true)),
            SheetChip(label: 'Atur jam', selected: !_allDay, onTap: () => _setAllDay(false)),
          ],
        ),
        if (!_allDay) ...[
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(child: SheetFieldBox(label: 'Mulai', value: _start, onTap: () => _pickTime(true))),
              const SizedBox(width: 10),
              Expanded(child: SheetFieldBox(label: 'Selesai', value: _end, onTap: () => _pickTime(false))),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const SheetLabel('ULANGI'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in AgendaRepeat.values) SheetChip(label: r.label, selected: _repeat == r, onTap: () => _setRepeat(r)),
          ],
        ),
        if (_repeat == AgendaRepeat.weekly) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              for (var d = 1; d <= 7; d++) ...[
                Expanded(
                  child: SheetChip(
                    label: _weekdayLabels[d - 1],
                    selected: _repeatDays.contains(d),
                    compact: true,
                    onTap: () => setState(() => _repeatDays.contains(d) ? _repeatDays.remove(d) : _repeatDays.add(d)),
                  ),
                ),
                if (d < 7) const SizedBox(width: 5),
              ],
            ],
          ),
        ],
        if (_repeat != AgendaRepeat.none) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SheetChip(label: 'Tanpa akhir', selected: _until == null, onTap: () => setState(() => _until = null)),
              SheetChip(
                label: _until == null ? 'Sampai tanggal…' : 'Sampai ${DateFormat('d MMM yyyy', 'id_ID').format(_until!)}',
                selected: _until != null,
                onTap: () => _pickDate(until: true),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const SheetLabel('PENGINGAT'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SheetChip(label: 'Tanpa', selected: _reminder == null, onTap: () => setState(() => _reminder = null)),
            for (final e in reminders.entries)
              SheetChip(label: e.value, selected: _reminder == e.key, onTap: () => setState(() => _reminder = e.key)),
          ],
        ),
        const SizedBox(height: 20),
        SheetPrimaryButton(
          label: 'Simpan agenda',
          disabledLabel: _title.text.trim().isEmpty ? 'Isi judul agenda' : 'Pilih hari pengulangan',
          onTap: _canSave ? _save : null,
        ),
        if (!_isNew) ...[
          const SizedBox(height: 10),
          SheetSecondaryButton(label: 'Hapus agenda', destructive: true, onTap: _delete),
        ],
      ],
    );
  }
}
