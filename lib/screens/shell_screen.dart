import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';
import 'calendar_tab.dart';
import 'home_tab.dart';
import 'notification_feed_screen.dart';
import 'settings_tab.dart';
import 'stats_tab.dart';

/// Shell utama aplikasi: app bar + 4 tab bawah, mengikuti struktur navigasi desain.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _tab = 0;

  static const _tabs = [
    (icon: LucideIcons.listTodo, label: 'Hari Ini'),
    (icon: LucideIcons.calendarDays, label: 'Kalender'),
    (icon: LucideIcons.chartColumn, label: 'Statistik'),
    (icon: LucideIcons.settings, label: 'Pengaturan'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        toolbarHeight: 48,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationFeedScreen()),
              ),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 38,
                height: 38,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(LucideIcons.bell, size: 21, color: AppColors.ink),
                    Positioned(
                      top: 7,
                      right: 7,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [HomeTab(), CalendarTab(), StatsTab(), SettingsTab()],
      ),
      bottomNavigationBar: Container(
        height: 84,
        padding: const EdgeInsets.only(top: 11),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      Icon(
                        _tabs[i].icon,
                        size: 23,
                        color: _tab == i ? AppColors.orange : const Color(0xFF9C927F),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _tabs[i].label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _tab == i ? AppColors.ink : AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
