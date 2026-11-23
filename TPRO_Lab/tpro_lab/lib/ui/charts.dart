import 'dart:math';

import 'package:flutter/material.dart';

import 'kit.dart';

class Series {
  final String name;
  final Color color;
  final List<Offset> points; // (x, y), y > 0
  const Series(this.name, this.color, this.points);
}

/// Courbes en echelle logarithmique sur l'axe vertical.
class LogLineChart extends StatelessWidget {
  final List<Series> series;
  final String xLabel, yLabel;
  const LogLineChart({super.key, required this.series, this.xLabel = '', this.yLabel = ''});

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _LinePainter(series, xLabel, yLabel), size: Size.infinite);
}

class _LinePainter extends CustomPainter {
  final List<Series> series;
  final String xLabel, yLabel;
  _LinePainter(this.series, this.xLabel, this.yLabel);

  @override
  void paint(Canvas canvas, Size size) {
    const style = TextStyle(color: C.muted, fontSize: 10);
    final pts = [for (final s in series) ...s.points];
    final area = Rect.fromLTRB(46, 22, size.width - 12, size.height - 24);
    final grid = Paint()
      ..color = C.line
      ..strokeWidth = 1;
    canvas.drawLine(area.bottomLeft, area.bottomRight, grid);
    canvas.drawLine(area.bottomLeft, area.topLeft, grid);
    var lx = 8.0;
    for (final s in series) {
      canvas.drawCircle(Offset(area.left + lx, 10), 4, Paint()..color = s.color);
      drawText(canvas, s.name, Offset(area.left + lx + 8, 10), style.copyWith(color: C.text), anchor: Alignment.centerLeft);
      lx += 22 + s.name.length * 6.0;
    }
    if (pts.isEmpty) {
      drawText(canvas, 'Lancez les mesures', area.center, style, anchor: Alignment.center);
      return;
    }
    final minX = pts.map((p) => p.dx).reduce(min), maxX = pts.map((p) => p.dx).reduce(max);
    final lo = (log(max(pts.map((p) => p.dy).reduce(min), 1e-4)) / ln10).floorToDouble();
    final hi = max((log(max(pts.map((p) => p.dy).reduce(max), 1e-4)) / ln10).ceilToDouble(), lo + 1);
    double px(double x) => area.left + (maxX == minX ? 0.5 : (x - minX) / (maxX - minX)) * area.width;
    double py(double y) => area.bottom - ((log(max(y, 1e-4)) / ln10 - lo) / (hi - lo)).clamp(0.0, 1.0) * area.height;
    for (var e = lo; e <= hi; e++) {
      final y = area.bottom - (e - lo) / (hi - lo) * area.height;
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), Paint()..color = fade(C.line, 0.5));
      drawText(canvas, '1e${e.toInt()}', Offset(area.left - 6, y), style, anchor: Alignment.centerRight);
    }
    for (var x = minX; x <= maxX; x++) {
      drawText(canvas, '${x.toInt()}', Offset(px(x), area.bottom + 4), style, anchor: Alignment.topCenter);
    }
    drawText(canvas, xLabel, Offset(area.right, area.bottom + 4), style, anchor: Alignment.topRight);
    drawText(canvas, yLabel, Offset(area.right, 10), style, anchor: Alignment.centerRight);
    for (final s in series) {
      if (s.points.isEmpty) continue;
      final path = Path();
      for (var i = 0; i < s.points.length; i++) {
        final o = Offset(px(s.points[i].dx), py(s.points[i].dy));
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = s.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeJoin = StrokeJoin.round);
      for (final p in s.points) {
        canvas.drawCircle(Offset(px(p.dx), py(p.dy)), 3.5, Paint()..color = s.color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => true;
}

/// Barres horizontales en echelle logarithmique.
class LogBarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final List<Color> colors;
  final String title;
  const LogBarChart({super.key, required this.labels, required this.values, required this.colors, this.title = ''});

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _BarPainter(labels, values, colors, title), size: Size.infinite);
}

class _BarPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final List<Color> colors;
  final String title;
  _BarPainter(this.labels, this.values, this.colors, this.title);

  @override
  void paint(Canvas canvas, Size size) {
    const style = TextStyle(color: C.muted, fontSize: 10);
    drawText(canvas, title, const Offset(0, 0), style.copyWith(fontWeight: FontWeight.w700));
    if (values.isEmpty) {
      drawText(canvas, 'Lancez la comparaison', size.center(Offset.zero), style, anchor: Alignment.center);
      return;
    }
    final hi = log(max(values.reduce(max), 10)) / ln10;
    final rowH = min(22.0, (size.height - 18) / values.length);
    const left = 92.0;
    for (var i = 0; i < values.length; i++) {
      final y = 18 + i * rowH;
      final w = (log(max(values[i], 1)) / ln10 / hi).clamp(0.02, 1.0) * (size.width - left - 56);
      drawText(canvas, labels[i], Offset(left - 6, y + rowH / 2), style.copyWith(color: C.text),
          anchor: Alignment.centerRight, maxWidth: left - 6);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(left, y + 3, w, rowH - 6), const Radius.circular(4)), Paint()..color = colors[i]);
      drawText(canvas, values[i].toStringAsFixed(0), Offset(left + w + 6, y + rowH / 2), style, anchor: Alignment.centerLeft);
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => true;
}
