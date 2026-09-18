import 'package:flutter/material.dart';
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
    (icon: Icons.today_rounded, label: 'Hari Ini'),
    (icon: Icons.calendar_month_rounded, label: 'Kalender'),
    (icon: Icons.bar_chart_rounded, label: 'Statistik'),
    (icon: Icons.settings_rounded, label: 'Pengaturan'),
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
        title: const Text('Daily Track'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationFeedScreen()),
              ),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.line, width: 1.5),
                ),
                child: Stack(
                  children: [
                    const Center(child: Icon(Icons.notifications_none_rounded, size: 21, color: AppColors.ink)),
                    Positioned(
                      top: 6,
                      right: 6,
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
