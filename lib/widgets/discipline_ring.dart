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
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(pct: pct),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(pct * 100).round()}%',
                style: const TextStyle(fontFamily: AppFonts.title, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1.4, color: AppColors.ink, height: 1),
              ),
              const SizedBox(height: 2),
              const Text(
                'DISIPLIN',
                style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppColors.yellowInk2),
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
  _RingPainter({required this.pct});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    final trackPaint = Paint()
      ..color = const Color(0xFFF3E6C8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = AppColors.yellow
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
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.pct != pct;
}
