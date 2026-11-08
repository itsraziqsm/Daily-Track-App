import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/activity.dart';
import '../models/agenda_item.dart';
import '../providers/agenda_provider.dart';
import '../theme/app_theme.dart';

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
    final c = AppColors.of(context);
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus agenda ini?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.ink)),
        content: Text(
          item.isRepeating
              ? '"${item.title}" berulang ${item.repeatLabel.toLowerCase()}. Hapus hanya untuk ${DateFormat('d MMMM', 'id_ID').format(widget.day)}, atau semua jadwalnya?'
              : '"${item.title}" akan dihapus.',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.inkMuted3, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Batal', style: TextStyle(color: c.inkMuted, fontWeight: FontWeight.w700)),
          ),
          if (item.isRepeating)
            TextButton(
              onPressed: () => Navigator.of(context).pop('once'),
              child: Text('Tanggal ini', style: TextStyle(color: c.orangeChipInk, fontWeight: FontWeight.w800)),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('all'),
            child: Text(item.isRepeating ? 'Semua' : 'Hapus', style: TextStyle(color: c.orangeChipInk, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
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
                Text(
                  _isNew ? 'Agenda baru' : 'Edit agenda',
                  style: TextStyle(fontFamily: AppFonts.title, fontSize: 18, fontWeight: FontWeight.w800, color: c.ink, letterSpacing: -0.4),
                ),
                if (!_isNew && _original!.isRepeating) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Perubahan berlaku untuk semua tanggal agenda ini.',
                    style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 12, fontWeight: FontWeight.w600, color: c.inkMuted),
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: _title,
                  autofocus: _isNew,
                  onChanged: (_) => setState(() {}),
                  decoration: _inputDecoration(c, 'Judul agenda'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.ink),
                ),
                const SizedBox(height: 9),
                TextField(
                  controller: _note,
                  minLines: 1,
                  maxLines: 3,
                  decoration: _inputDecoration(c, 'Catatan (opsional)'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink),
                ),
                const SizedBox(height: 16),
                const _Label('TANGGAL'),
                _FieldBox(label: _repeat == AgendaRepeat.none ? 'Tanggal' : 'Mulai', value: dateLabel, onTap: () => _pickDate(until: false)),
                const SizedBox(height: 16),
                const _Label('WAKTU'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(label: 'Seharian', selected: _allDay, onTap: () => _setAllDay(true)),
                    _Chip(label: 'Atur jam', selected: !_allDay, onTap: () => _setAllDay(false)),
                  ],
                ),
                if (!_allDay) ...[
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(child: _FieldBox(label: 'Mulai', value: _start, onTap: () => _pickTime(true))),
                      const SizedBox(width: 10),
                      Expanded(child: _FieldBox(label: 'Selesai', value: _end, onTap: () => _pickTime(false))),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const _Label('ULANGI'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in AgendaRepeat.values) _Chip(label: r.label, selected: _repeat == r, onTap: () => _setRepeat(r)),
                  ],
                ),
                if (_repeat == AgendaRepeat.weekly) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (var d = 1; d <= 7; d++) ...[
                        Expanded(
                          child: _Chip(
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
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Chip(label: 'Tanpa akhir', selected: _until == null, onTap: () => setState(() => _until = null)),
                      _Chip(
                        label: _until == null ? 'Sampai tanggal…' : 'Sampai ${DateFormat('d MMM yyyy', 'id_ID').format(_until!)}',
                        selected: _until != null,
                        onTap: () => _pickDate(until: true),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const _Label('PENGINGAT'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(label: 'Tanpa', selected: _reminder == null, onTap: () => setState(() => _reminder = null)),
                    for (final e in reminders.entries)
                      _Chip(label: e.value, selected: _reminder == e.key, onTap: () => setState(() => _reminder = e.key)),
                  ],
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _canSave ? _save : null,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _canSave ? c.orange : c.lineSoft2,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _canSave ? 'Simpan agenda' : (_title.text.trim().isEmpty ? 'Isi judul agenda' : 'Pilih hari pengulangan'),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _canSave ? Colors.white : c.inkMuted2),
                    ),
                  ),
                ),
                if (!_isNew) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _delete,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: c.line, width: 1.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text('Hapus agenda', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.orangeChipInk)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static InputDecoration _inputDecoration(AppColors c, String hint) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: color, width: 1.5),
        );
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: c.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      border: border(c.line),
      enabledBorder: border(c.line),
      focusedBorder: border(c.ink),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(text, style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: c.inkMuted)),
    );
  }
}

class _FieldBox extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _FieldBox({required this.label, required this.value, required this.onTap});

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

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, required this.onTap, this.compact = false});

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
