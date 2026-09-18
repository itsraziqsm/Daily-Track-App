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
  final _pageController = PageController();
  int _tab = 0;

  static const _tabIcons = [
    (icon: LucideIcons.listTodo, tooltip: 'Hari Ini'),
    (icon: LucideIcons.calendarDays, tooltip: 'Kalender'),
    (icon: LucideIcons.chartColumn, tooltip: 'Statistik'),
    (icon: LucideIcons.settings, tooltip: 'Pengaturan'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleProvider>().load();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToTab(int index) {
    setState(() => _tab = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
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
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _tab = index),
        children: const [
          _KeepAlive(child: HomeTab()),
          _KeepAlive(child: CalendarTab()),
          _KeepAlive(child: StatsTab()),
          _KeepAlive(child: SettingsTab()),
        ],
      ),
      bottomNavigationBar: Container(
        height: 64,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              for (var i = 0; i < _tabIcons.length; i++)
                Expanded(
                  child: Tooltip(
                    message: _tabIcons[i].tooltip,
                    child: GestureDetector(
                      onTap: () => _goToTab(i),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          scale: _tab == i ? 1.08 : 1,
                          child: Icon(
                            _tabIcons[i].icon,
                            size: 24,
                            color: _tab == i ? AppColors.orange : const Color(0xFF9C927F),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Menjaga state tiap halaman (posisi gulir, bulan terpilih) saat digeser
/// keluar-masuk viewport PageView.
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
