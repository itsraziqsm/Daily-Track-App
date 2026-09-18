import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/daily_log.dart';
import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int? _activityFilter;
  String? _reasonFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleProvider>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    var logs = provider.skippedLogs;
    if (_activityFilter != null) {
      logs = logs.where((l) => l.activityId == _activityFilter).toList();
    }
    if (_reasonFilter != null) {
      logs = logs.where((l) => (l.reason ?? 'Lainnya') == _reasonFilter).toList();
    }

    final activityOptions = {
      for (final l in provider.skippedLogs) l.activityId: provider.activityById(l.activityId)?.title ?? '-',
    };
    final reasonOptions = provider.skippedLogs.map((l) => l.reason ?? 'Lainnya').toSet().toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat')),
      body: Column(
        children: [
          if (provider.skippedLogs.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ringkasan', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Paling sering dilewati: ${provider.mostSkippedActivityTitle ?? '-'}',
                      style: const TextStyle(fontSize: 13)),
                  Text('Alasan paling umum: ${provider.mostCommonReason ?? '-'}',
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _activityFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Kegiatan', isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Semua kegiatan')),
                      ...activityOptions.entries.map(
                        (e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _activityFilter = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _reasonFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Alasan', isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Semua alasan')),
                      ...reasonOptions.map(
                        (r) => DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _reasonFilter = v),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 20),
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Text('Belum ada riwayat yang dibatalkan.', style: TextStyle(color: AppColors.inkMuted)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) => _LogRow(log: logs[index], provider: provider),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final DailyLog log;
  final ScheduleProvider provider;

  const _LogRow({required this.log, required this.provider});

  @override
  Widget build(BuildContext context) {
    final title = provider.activityById(log.activityId)?.title ?? 'Kegiatan tidak dikenal';
    final dateLabel = DateFormat('d MMM yyyy', 'id_ID').format(DateTime.parse(log.date));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Text('$dateLabel · ${log.reason ?? '-'}', style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
