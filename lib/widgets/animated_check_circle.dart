import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lingkaran centang beranimasi: cincin menyapu melingkar, lingkaran terisi
/// dengan sedikit melambung, lalu centang digambar goresan demi goresan.
///
/// Irama dan proporsinya diambil dari aset animasi Checkmark_Icon.mp4
/// (sapuan ±59% durasi, isi ±12%, centang ±29%, dengan isi dan centang sedikit
/// bertumpuk). Digambar sebagai vektor, bukan diputar sebagai video, supaya
/// latarnya transparan, tajam di ukuran kecil, dan mengikuti warna palet.
class AnimatedCheckCircle extends StatefulWidget {
  /// Status tujuan. Berubah ke true memainkan urutan maju, ke false memutarnya
  /// mundur lebih cepat.
  final bool checked;

  /// Warna cincin sapuan dan isian.
  final Color accent;

  /// Warna cincin saat belum ditandai.
  final Color idleBorder;

  /// Isi lingkaran sebelum tercentang, supaya tetap terbaca di kartu berwarna.
  final Color background;
  final Color checkColor;
  final double size;

  const AnimatedCheckCircle({
    super.key,
    required this.checked,
    required this.accent,
    required this.idleBorder,
    required this.background,
    required this.checkColor,
    this.size = 34,
  });

  @override
  State<AnimatedCheckCircle> createState() => _AnimatedCheckCircleState();
}

class _AnimatedCheckCircleState extends State<AnimatedCheckCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 680),
    reverseDuration: const Duration(milliseconds: 240),
    // Mulai di posisi akhir bila sudah tercentang, supaya membuka aplikasi atau
    // menggulung daftar tidak memutar ulang animasinya.
    value: widget.checked ? 1 : 0,
  );

  @override
  void didUpdateWidget(AnimatedCheckCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.checked != oldWidget.checked) {
      widget.checked ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _CheckPainter(
          progress: _controller.value,
          accent: widget.accent,
          idleBorder: widget.idleBorder,
          background: widget.background,
          checkColor: widget.checkColor,
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color accent;
  final Color idleBorder;
  final Color background;
  final Color checkColor;

  _CheckPainter({
    required this.progress,
    required this.accent,
    required this.idleBorder,
    required this.background,
    required this.checkColor,
  });

  // Batas fase, sebagai pecahan dari total durasi.
  static const _sweepEnd = 0.59;
  static const _fillStart = 0.59;
  static const _fillEnd = 0.71;
  static const _checkStart = 0.66;

  double _phase(double from, double to) =>
      ((progress - from) / (to - from)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final ringWidth = size.width * 0.06;
    final radius = (size.width - ringWidth) / 2;

    canvas.drawCircle(center, radius, Paint()..color = background);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..color = idleBorder,
    );

    final sweep = Curves.easeInOutCubic.transform(_phase(0, _sweepEnd));
    if (sweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth
          ..strokeCap = StrokeCap.round
          ..color = accent,
      );
    }

    final fill = Curves.easeOutBack.transform(_phase(_fillStart, _fillEnd)).clamp(0.0, 1.0);
    if (fill > 0) {
      canvas.drawCircle(center, radius * fill, Paint()..color = accent);
    }

    final checkProgress = Curves.easeOutCubic.transform(_phase(_checkStart, 1));
    if (checkProgress > 0) {
      final path = Path()
        ..moveTo(size.width * 0.28, size.height * 0.52)
        ..lineTo(size.width * 0.43, size.height * 0.67)
        ..lineTo(size.width * 0.73, size.height * 0.35);
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * checkProgress),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.085
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = checkColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent ||
      oldDelegate.idleBorder != idleBorder ||
      oldDelegate.background != background ||
      oldDelegate.checkColor != checkColor;
}
