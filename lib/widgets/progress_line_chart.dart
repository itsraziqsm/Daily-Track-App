import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../theme/app_theme.dart';
import '../utils/number_format.dart';

class ChartPoint {
  final DateTime date;
  final double value;
  const ChartPoint(this.date, this.value);
}

/// Grafik garis satu seri untuk riwayat target angka, dengan garis target.
///
/// Satu seri, jadi tanpa kotak legenda — judul bagian di atasnya sudah
/// menamainya. Hanya titik terakhir yang diberi label; ketuk atau geser untuk
/// melihat nilai tiap titik. Tabel catatan di bawah grafik menjadi tampilan
/// datanya.
class ProgressLineChart extends StatefulWidget {
  final List<ChartPoint> points;
  final double target;
  final String? unit;
  final double height;

  const ProgressLineChart({super.key, required this.points, required this.target, this.unit, this.height = 190});

  @override
  State<ProgressLineChart> createState() => _ProgressLineChartState();
}

class _ProgressLineChartState extends State<ProgressLineChart> {
  int? _selected;

  void _select(Offset local, Size size) {
    final layout = _ChartLayout(widget.points, widget.target, size);
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < widget.points.length; i++) {
      final d = (layout.x(widget.points[i].date) - local.dx).abs();
      if (d < bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
    setState(() => _selected = best);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, widget.height);
        return GestureDetector(
          // Seluruh area grafik menjadi sasaran sentuh; titik terdekat secara
          // horizontal yang dipilih, jadi tidak perlu tepat mengenai titiknya.
          onTapDown: (d) => _select(d.localPosition, size),
          onHorizontalDragUpdate: (d) => _select(d.localPosition, size),
          onHorizontalDragEnd: (_) => setState(() => _selected = null),
          child: CustomPaint(
            size: size,
            painter: _ChartPainter(
              points: widget.points,
              target: widget.target,
              unit: widget.unit,
              selected: _selected,
              colors: c,
              textScaler: MediaQuery.textScalerOf(context),
            ),
          ),
        );
      },
    );
  }
}

/// Pemetaan data ke piksel, dipakai bersama oleh painter dan deteksi sentuh.
class _ChartLayout {
  static const left = 40.0;
  static const right = 16.0;
  static const top = 14.0;
  static const bottom = 24.0;

  final DateTime first;
  final DateTime last;
  final double min;
  final double max;

  /// Jarak antar garis bantu: 1, 2, atau 5 kali pangkat sepuluh, supaya
  /// labelnya angka bulat seperti 72, 74, 76.
  final double step;
  final Size size;

  factory _ChartLayout(List<ChartPoint> points, double target, Size size) {
    final values = [...points.map((p) => p.value), target];
    var lo = values.reduce(math.min), hi = values.reduce(math.max);
    if (hi == lo) {
      lo -= 1;
      hi += 1;
    }
    final step = _niceStep((hi - lo) / 4);
    final dates = points.map((p) => p.date).toList()..sort();
    var end = dates.last;
    if (!end.isAfter(dates.first)) end = dates.first.add(const Duration(days: 1));
    return _ChartLayout._(dates.first, end, (lo / step).floor() * step, (hi / step).ceil() * step, step, size);
  }

  _ChartLayout._(this.first, this.last, this.min, this.max, this.step, this.size);

  static double _niceStep(double raw) {
    final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final n = raw / magnitude;
    return (n <= 1 ? 1 : n <= 2 ? 2 : n <= 5 ? 5 : 10) * magnitude;
  }

  double get plotWidth => size.width - left - right;
  double get plotHeight => size.height - top - bottom;

  double x(DateTime d) {
    final span = last.difference(first).inMinutes;
    return left + plotWidth * (d.difference(first).inMinutes / span);
  }

  double y(double v) => top + plotHeight * (1 - (v - min) / (max - min));
}

class _ChartPainter extends CustomPainter {
  final List<ChartPoint> points;
  final double target;
  final String? unit;
  final int? selected;
  final AppColors colors;
  final TextScaler textScaler;

  _ChartPainter({
    required this.points,
    required this.target,
    required this.unit,
    required this.selected,
    required this.colors,
    required this.textScaler,
  });

  TextPainter _text(String s, double size, Color color, {FontWeight weight = FontWeight.w600}) => TextPainter(
        text: TextSpan(text: s, style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: size, fontWeight: weight, color: color)),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();

  String _label(double v) => unit == null ? formatNumber(v) : '${formatNumber(v)} $unit';

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final c = colors;
    final l = _ChartLayout(points, target, size);

    // Garis bantu: tipis, solid, satu langkah dari permukaan.
    final grid = Paint()
      ..color = c.line
      ..strokeWidth = 1;
    for (var v = l.min; v <= l.max + l.step / 2; v += l.step) {
      final y = l.y(v);
      canvas.drawLine(Offset(_ChartLayout.left, y), Offset(size.width - _ChartLayout.right, y), grid);
      final t = _text(formatNumber(double.parse(v.toStringAsFixed(6))), 10, c.inkMuted2);
      t.paint(canvas, Offset(_ChartLayout.left - 8 - t.width, y - t.height / 2));
    }

    // Garis target dengan labelnya, dalam tinta teks.
    final ty = l.y(target);
    canvas.drawLine(
      Offset(_ChartLayout.left, ty),
      Offset(size.width - _ChartLayout.right, ty),
      Paint()
        ..color = c.yellow
        ..strokeWidth = 1.5,
    );
    final targetText = _text('Target ${_label(target)}', 10, c.inkMuted, weight: FontWeight.w700);
    final aboveTarget = ty - targetText.height - 3 > _ChartLayout.top;
    targetText.paint(canvas, Offset(_ChartLayout.left + 4, aboveTarget ? ty - targetText.height - 3 : ty + 3));

    // Label sumbu waktu: hanya tanggal pertama dan terakhir.
    final fmt = DateFormat('d MMM', 'id_ID');
    final firstLabel = _text(fmt.format(points.first.date), 10, c.inkMuted2);
    firstLabel.paint(canvas, Offset(_ChartLayout.left, size.height - firstLabel.height));
    if (points.length > 1) {
      final lastLabel = _text(fmt.format(points.last.date), 10, c.inkMuted2);
      lastLabel.paint(canvas, Offset(size.width - _ChartLayout.right - lastLabel.width, size.height - lastLabel.height));
    }

    final offsets = [for (final p in points) Offset(l.x(p.date), l.y(p.value))];

    // Area tipis di bawah garis, lalu garisnya.
    if (offsets.length > 1) {
      final line = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final o in offsets.skip(1)) {
        line.lineTo(o.dx, o.dy);
      }
      final baseline = l.y(l.min);
      final area = Path.from(line)
        ..lineTo(offsets.last.dx, baseline)
        ..lineTo(offsets.first.dx, baseline)
        ..close();
      canvas.drawPath(area, Paint()..color = c.orange.withValues(alpha: 0.1));
      canvas.drawPath(
        line,
        Paint()
          ..color = c.orange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    // Titik: r 4 dengan cincin 2px warna permukaan.
    for (final o in offsets) {
      canvas.drawCircle(o, 6, Paint()..color = c.card);
      canvas.drawCircle(o, 4, Paint()..color = c.orange);
    }

    // Label selektif: hanya nilai terakhir, kecuali sedang memilih titik.
    if (selected == null) {
      final last = offsets.last;
      final t = _text(_label(points.last.value), 11, c.ink, weight: FontWeight.w700);
      final dx = (last.dx - t.width / 2).clamp(0.0, size.width - t.width);
      final dy = last.dy - t.height - 8 < 0 ? last.dy + 8 : last.dy - t.height - 8;
      t.paint(canvas, Offset(dx, dy));
      return;
    }

    // Crosshair dan tooltip untuk titik terpilih.
    final p = points[selected!];
    final o = offsets[selected!];
    canvas.drawLine(
      Offset(o.dx, _ChartLayout.top),
      Offset(o.dx, size.height - _ChartLayout.bottom),
      Paint()
        ..color = c.inkMuted2
        ..strokeWidth = 1,
    );
    canvas.drawCircle(o, 7, Paint()..color = c.card);
    canvas.drawCircle(o, 5, Paint()..color = c.orange);

    final value = _text(_label(p.value), 12, c.ink, weight: FontWeight.w800);
    final date = _text(DateFormat('d MMM yyyy', 'id_ID').format(p.date), 10, c.inkMuted);
    final w = math.max(value.width, date.width) + 16;
    final h = value.height + date.height + 12;
    var bx = o.dx - w / 2;
    bx = bx.clamp(0.0, size.width - w);
    final by = o.dy - h - 12 < 0 ? o.dy + 12 : o.dy - h - 12;
    final box = RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, w, h), const Radius.circular(9));
    canvas.drawRRect(box, Paint()..color = c.card);
    canvas.drawRRect(
      box,
      Paint()
        ..color = c.lineSoft
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    value.paint(canvas, Offset(bx + 8, by + 6));
    date.paint(canvas, Offset(bx + 8, by + 6 + value.height));
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.points != points || old.target != target || old.selected != selected || old.colors != colors || old.unit != unit;
}
