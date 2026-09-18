import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_tile.dart';
import '../widgets/skip_reason_dialog.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleProvider>().loadToday();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final todayLabel = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Harian'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Riwayat',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(todayLabel, style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${provider.doneCount}/${provider.totalCount} selesai',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: provider.totalCount == 0 ? 0 : provider.doneCount / provider.totalCount,
                    backgroundColor: AppColors.line,
                    color: AppColors.accent,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: provider.activities.length,
              itemBuilder: (context, index) {
                final activity = provider.activities[index];
                final log = provider.todayLogs[activity.id];
                return ActivityTile(
                  activity: activity,
                  log: log,
                  isLast: index == provider.activities.length - 1,
                  onMarkDone: () => provider.markDone(activity),
                  onMarkSkipped: () async {
                    final reason = await showSkipReasonDialog(context, activity.title);
                    if (reason != null) {
                      await provider.markSkipped(activity, reason);
                    }
                  },
                  onClear: () => provider.clearStatus(activity),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
