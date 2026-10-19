import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_time.dart';
import '../widgets/activity_tile.dart';
import '../widgets/skip_reason_dialog.dart';

/// Tab "Hari Ini" — timeline jadwal harian, progres, dan status tiap kegiatan.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final provider = context.watch<ScheduleProvider>();
    final activities = provider.activities;
    final allSet = activities.isNotEmpty && activities.every((a) => provider.todayLogs.containsKey(a.id));

    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _HeaderDelegate(
            colors: c,
            todayLabel: DateFormat('EEEE, d MMMM', 'id_ID').format(AppTime.now()),
            streak: provider.perfectStreak,
            doneCount: provider.doneCount,
            totalCount: provider.totalCount,
            donePct: provider.totalCount == 0 ? 0 : provider.onTimeCount / provider.totalCount,
            latePct: provider.totalCount == 0 ? 0 : provider.lateCount / provider.totalCount,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (activities.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(
                    provider.templates.isEmpty
                        ? 'Belum ada template. Buat satu di Pengaturan → Kelola Template.'
                        : 'Template hari ini belum berisi kegiatan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.inkMuted),
                  ),
                ),
              for (var i = 0; i < activities.length; i++)
                ActivityTile(
                  activity: activities[i],
                  log: provider.todayLogs[activities[i].id],
                  isRunning: provider.isRunning(activities[i]),
                  isLocked: provider.isLocked(activities[i]),
                  isUpcoming: provider.isUpcoming(activities[i]),
                  isLast: i == activities.length - 1,
                  toleranceMinutes: provider.toleranceMinutes,
                  onCheck: () => provider.toggle(activities[i]),
                  onCancel: () async {
                    final reason = await showSkipReasonDialog(
                      context,
                      '${activities[i].startTime} · ${activities[i].title}',
                    );
                    if (reason != null) {
                      await provider.markCancelled(activities[i], reason);
                    }
                  },
                ),
              if (allSet)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: c.lineSoft, width: 1.5),
                  ),
                  child: Text(
                    'Selesai. Besok mulai ${activities.first.startTime}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.inkMuted2),
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }
}

/// Header yang menempel di atas daftar. Saat digulung, tanggal dan chip hari
/// beruntun melipat hingga tersisa progresnya saja; latarnya masif dan
/// berbayang supaya kegiatan yang tergulung lewat di belakangnya.
class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final AppColors colors;
  final String todayLabel;
  final int streak;
  final int doneCount;
  final int totalCount;
  final double donePct;
  final double latePct;

  _HeaderDelegate({
    required this.colors,
    required this.todayLabel,
    required this.streak,
    required this.doneCount,
    required this.totalCount,
    required this.donePct,
    required this.latePct,
  });

  // Tinggi tiap bagian ditulis eksplisit supaya maxExtent dan minExtent persis
  // sama dengan tinggi isinya di kedua ujung animasi.
  static const _padTop = 8.0;
  static const _padBottom = 14.0;
  static const _titleBlock = 56.0; // baris tanggal + judul + chip streak
  static const _gap = 18.0;
  static const _cardPadMax = 16.0;
  static const _cardPadMin = 10.0;
  static const _cardBorder = 3.0; // 1,5 atas + 1,5 bawah
  static const _cardFixed = 36.0; // baris hitungan + jarak + bar
  static const _cardTail = 24.0; // jarak + legenda, ikut melipat

  static const _cardMax = _cardPadMax * 2 + _cardBorder + _cardFixed + _cardTail;
  static const _cardMin = _cardPadMin * 2 + _cardBorder + _cardFixed;

  @override
  double get maxExtent => _padTop + _titleBlock + _gap + _cardMax + _padBottom;

  @override
  double get minExtent => _padTop + _cardMin + _padBottom;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final c = colors;
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final expanded = 1 - t;

    // Harus mengisi persis tinggi yang diberikan sliver. Kalau isinya menghitung
    // tingginya sendiri, selisih pembulatan sekecil apa pun membuat paintExtent
    // dan layoutExtent tidak sama, dan Flutter menolak geometrinya.
    return SizedBox.expand(
      child: ClipRect(
        child: Container(
          decoration: BoxDecoration(
            color: c.bg,
            boxShadow: t > 0.02
                ? [
                    BoxShadow(
                      color: c.shadow.withValues(alpha: (c.isDark ? 0.35 : 0.07) * t),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(22, _padTop, 22, _padBottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: expanded,
                  child: Opacity(
                    opacity: expanded,
                    child: SizedBox(height: _titleBlock, child: _titleRow(c)),
                  ),
                ),
              ),
              SizedBox(height: _gap * expanded),
              _progressCard(c, t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleRow(AppColors c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 15,
                child: Text(
                  todayLabel[0].toUpperCase() + todayLabel.substring(1),
                  style: TextStyle(
                    fontFamily: AppFonts.subtitle,
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: c.inkMuted,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                height: 36,
                child: Text(
                  'Hari Ini',
                  style: TextStyle(fontFamily: AppFonts.title, fontSize: 27, height: 1.2, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: c.ink),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(9, 7, 11, 7),
          decoration: BoxDecoration(
            color: c.yellowChipBg,
            border: Border.all(color: c.yellowChipBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: c.yellow),
                child: Text(
                  '$streak',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.onYellow),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'hari\nberuntun',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.yellowInk2, height: 1.1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _progressCard(AppColors c, double t) {
    final expanded = 1 - t;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 18,
        vertical: _cardPadMax - (_cardPadMax - _cardPadMin) * t,
      ),
      decoration: BoxDecoration(
        color: c.yellowBg,
        border: Border.all(color: c.yellowBorder, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Opacity(
                  opacity: expanded,
                  child: Text(
                    'PROGRES HARI INI',
                    style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 12, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: c.yellowInk3),
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: doneCount.toDouble()),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Text(
                    '${value.round()}/$totalCount selesai',
                    style: TextStyle(fontSize: 12, height: 1.2, fontWeight: FontWeight.w700, color: c.ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          _ProgressBar(donePct: donePct, latePct: latePct),
          ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: expanded,
              child: Opacity(
                opacity: expanded,
                child: SizedBox(
                  height: _cardTail,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 14,
                        child: Row(
                          children: [
                            _Legend(color: c.yellow, label: 'Selesai'),
                            const SizedBox(width: 14),
                            _Legend(color: c.orange, label: 'Terlambat'),
                            const SizedBox(width: 14),
                            _Legend(color: c.cancelledDot, label: 'Dibatalkan'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HeaderDelegate oldDelegate) =>
      oldDelegate.colors != colors ||
      oldDelegate.todayLabel != todayLabel ||
      oldDelegate.streak != streak ||
      oldDelegate.doneCount != doneCount ||
      oldDelegate.totalCount != totalCount ||
      oldDelegate.donePct != donePct ||
      oldDelegate.latePct != latePct;
}

/// Bar progres tiga lapis: jalur dasar, porsi terlambat, lalu porsi selesai
/// tepat waktu di atasnya. Tiap lapis melebar sendiri saat angkanya berubah.
class _ProgressBar extends StatelessWidget {
  final double donePct;
  final double latePct;

  const _ProgressBar({required this.donePct, required this.latePct});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 9,
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: c.track)),
            _ProgressSegment(fraction: donePct + latePct, color: c.orange),
            _ProgressSegment(fraction: donePct, color: c.yellow),
          ],
        ),
      ),
    );
  }
}

class _ProgressSegment extends StatelessWidget {
  final double fraction;
  final Color color;

  const _ProgressSegment({required this.fraction, required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: fraction.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 450),
        // Sedikit melewati target lalu mengendap, seperti transisi di desain.
        curve: const Cubic(0.3, 1.2, 0.4, 1),
        builder: (context, value, _) => Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10.5, height: 1.2, fontWeight: FontWeight.w600, color: c.yellowInk3)),
      ],
    );
  }
}
