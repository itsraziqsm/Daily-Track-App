import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/seed_activities.dart';
import '../models/activity.dart';
import '../models/template.dart';
import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';

const _categories = [
  Categories.ibadahDiri,
  Categories.istirahatOlahraga,
  Categories.kerjaBelajar,
  Categories.tidur,
];

/// Editor template: ubah nama, susun kegiatan, atau buat template baru.
/// [template] null berarti membuat template baru.
class TemplateEditorScreen extends StatefulWidget {
  final Template? template;
  const TemplateEditorScreen({super.key, this.template});

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.template?.name ?? '');
  late List<Activity> _draft = [...(widget.template?.activities ?? const <Activity>[])];
  bool _saving = false;

  bool get _isNew => widget.template == null;
  bool get _canSave => _nameController.text.trim().isNotEmpty && _draft.isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _sortDraft() {
    _draft.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  }

  Future<void> _editActivity(int index) async {
    final result = await showModalBottomSheet<Activity>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ActivitySheet(activity: _draft[index]),
    );
    if (result != null) {
      setState(() {
        _draft[index] = result;
        _sortDraft();
      });
    }
  }

  Future<void> _addActivity() async {
    final last = _draft.isEmpty ? null : _draft.last;
    final startMinutes = last == null ? 7 * 60 : last.endMinutes;
    final seed = Activity(
      id: 0,
      templateId: widget.template?.id ?? 0,
      startTime: Activity.formatMinutes(startMinutes),
      endTime: Activity.formatMinutes(startMinutes + 30),
      title: '',
      category: Categories.kerjaBelajar,
    );
    final result = await showModalBottomSheet<Activity>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ActivitySheet(activity: seed),
    );
    if (result != null) {
      setState(() {
        _draft.add(result);
        _sortDraft();
      });
    }
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    await context.read<ScheduleProvider>().saveTemplate(
          id: widget.template?.id,
          name: _nameController.text.trim(),
          activities: _draft,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final provider = context.read<ScheduleProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Hapus template ini?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
        content: Text(
          'Hari yang memakai "${widget.template!.name}" akan dialihkan ke template lain. Catatan harian yang sudah tersimpan tidak ikut terhapus.',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkMuted3, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal', style: TextStyle(color: AppColors.inkMuted, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.orangeChipInk, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await provider.deleteTemplate(widget.template!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final canDelete = !_isNew && provider.templates.length > 1;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          _isNew ? 'Template baru' : 'Edit template',
          style: const TextStyle(fontFamily: AppFonts.title, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.ink),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
        children: [
          const Text('NAMA TEMPLATE', style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.inkMuted)),
          const SizedBox(height: 9),
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'mis. Hari Kuliah',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              border: _fieldBorder(AppColors.line),
              enabledBorder: _fieldBorder(AppColors.line),
              focusedBorder: _fieldBorder(AppColors.ink),
            ),
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('KEGIATAN', style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.inkMuted)),
              Text('${_draft.length} item', style: const TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkMuted2)),
            ],
          ),
          const SizedBox(height: 11),
          for (var i = 0; i < _draft.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DraftRow(
                activity: _draft[i],
                onTap: () => _editActivity(i),
                onRemove: () => setState(() => _draft.removeAt(i)),
              ),
            ),
          GestureDetector(
            onTap: _addActivity,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.lineSoft, width: 1.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.plus, size: 17, color: AppColors.inkMuted),
                  SizedBox(width: 8),
                  Text('Tambah kegiatan', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.inkMuted)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _canSave ? _save : null,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _canSave ? AppColors.orange : AppColors.lineSoft2,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _canSave ? 'Simpan template' : 'Beri nama dan isi kegiatan',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _canSave ? Colors.white : AppColors.inkMuted2),
              ),
            ),
          ),
          if (canDelete) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _delete,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('Hapus template ini', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.orangeChipInk)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: color, width: 1.5),
      );
}

class _DraftRow extends StatelessWidget {
  final Activity activity;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _DraftRow({required this.activity, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 88,
              child: Text(
                '${activity.startTime}–${activity.endTime}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title.isEmpty ? '(tanpa nama)' : activity.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activity.category,
                    style: const TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(LucideIcons.trash2, size: 17, color: AppColors.inkMuted2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet untuk menyunting satu kegiatan: jam mulai, jam selesai, nama,
/// dan kategori.
class _ActivitySheet extends StatefulWidget {
  final Activity activity;
  const _ActivitySheet({required this.activity});

  @override
  State<_ActivitySheet> createState() => _ActivitySheetState();
}

class _ActivitySheetState extends State<_ActivitySheet> {
  late final TextEditingController _title = TextEditingController(text: widget.activity.title);
  late String _start = widget.activity.startTime;
  late String _end = widget.activity.endTime;
  late String _category = widget.activity.category;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final current = isStart ? widget.activity.startMinutes : widget.activity.endMinutes;
    final source = isStart ? _start : _end;
    final parts = source.split('.');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts[0]) ?? current ~/ 60,
        minute: int.tryParse(parts[1]) ?? current % 60,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final value = Activity.formatMinutes(picked.hour * 60 + picked.minute);
    setState(() {
      if (isStart) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _title.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
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
                    decoration: BoxDecoration(color: AppColors.lineSoft, borderRadius: BorderRadius.circular(99)),
                  ),
                ),
                const Text(
                  'Kegiatan',
                  style: TextStyle(fontFamily: AppFonts.title, fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.4),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _TimeField(label: 'Mulai', value: _start, onTap: () => _pickTime(true))),
                    const SizedBox(width: 10),
                    Expanded(child: _TimeField(label: 'Selesai', value: _end, onTap: () => _pickTime(false))),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  autofocus: widget.activity.title.isEmpty,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Nama kegiatan',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                    border: _border(AppColors.line),
                    enabledBorder: _border(AppColors.line),
                    focusedBorder: _border(AppColors.ink),
                  ),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                const SizedBox(height: 14),
                const Text('KATEGORI', style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.inkMuted)),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in _categories)
                      GestureDetector(
                        onTap: () => setState(() => _category = c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                          decoration: BoxDecoration(
                            color: _category == c ? AppColors.orangeChipBg : Colors.white,
                            border: Border.all(color: _category == c ? AppColors.orange : AppColors.line, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            c,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _category == c ? AppColors.orangeChipInk : AppColors.inkMuted3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: canSave
                      ? () => Navigator.of(context).pop(widget.activity.copyWith(
                            startTime: _start,
                            endTime: _end,
                            title: _title.text.trim(),
                            category: _category,
                          ))
                      : null,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: canSave ? AppColors.orange : AppColors.lineSoft2,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      canSave ? 'Simpan kegiatan' : 'Isi nama kegiatan',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: canSave ? Colors.white : AppColors.inkMuted2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: color, width: 1.5),
      );
}

class _TimeField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimeField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontFamily: AppFonts.subtitle, fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.inkMuted)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
          ],
        ),
      ),
    );
  }
}
