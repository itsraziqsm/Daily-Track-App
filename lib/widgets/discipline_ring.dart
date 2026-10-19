import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Ring chart progres disiplin mingguan, sesuai desain "Daily Track".
class DisciplineRing extends StatelessWidget {
  final double pct; // 0..1
  final double size;

  const DisciplineRing({super.key, required this.pct, this.size = 118});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(pct: pct, track: c.track, fill: c.yellow),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(pct * 100).round()}%',
                style: TextStyle(fontFamily: AppFonts.title, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1.4, color: c.ink, height: 1),
              ),
              const SizedBox(height: 2),
              Text(
                'DISIPLIN',
                style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: c.yellowInk2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  final Color track;
  final Color fill;
  _RingPainter({required this.pct, required this.track, required this.fill});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final sweep = 2 * math.pi * pct.clamp(0, 1);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.pct != pct || oldDelegate.track != track || oldDelegate.fill != fill;
}
