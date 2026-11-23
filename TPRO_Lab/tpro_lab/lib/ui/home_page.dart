import 'dart:math';

import 'package:flutter/material.dart';

import '../core/demo_content.dart';
import 'explain_panel.dart';
import 'kit.dart';

/// Accueil : choisir un TP. Quatre cartes animees + l'ordre conseille de la demonstration.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = kLabs.fold<int>(0, (s, l) => s + l.minutes);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('TPRO Lab', style: TextStyle(color: C.text, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          SizedBox(width: 14),
          Padding(
            padding: EdgeInsets.only(bottom: 5),
            child: Text('Les quatre TP notés · ESI Alger · 2CS', style: TextStyle(color: C.muted, fontSize: 14)),
          ),
          Spacer(),
          Padding(
            padding: EdgeInsets.only(bottom: 5),
            child: Text('Choisissez un TP — la démonstration s\'explique étape par étape', style: TextStyle(color: C.muted, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: Column(children: [
            Expanded(child: Row(children: [Expanded(child: _card(0)), const SizedBox(width: 16), Expanded(child: _card(1))])),
            const SizedBox(height: 16),
            Expanded(child: Row(children: [Expanded(child: _card(2)), const SizedBox(width: 16), Expanded(child: _card(3))])),
          ]),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
          child: Row(children: [
            const Icon(Icons.timer_outlined, size: 16, color: C.muted),
            const SizedBox(width: 8),
            const Text('Ordre conseillé', style: TextStyle(color: C.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            for (var k = 0; k < kDemoOrder.length; k++) ...[
              if (k > 0) const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward_rounded, size: 14, color: C.muted)),
              _OrderChip(lab: kDemoOrder[k]),
            ],
            const Spacer(),
            Text('≈ $total min au total', style: kMono.copyWith(color: C.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  Widget _card(int lab) => _LabCard(lab: lab, anim: _anim);
}

class _OrderChip extends StatelessWidget {
  /// Indice dans [kLabs] (0..3).
  final int lab;
  const _OrderChip({required this.lab});

  @override
  Widget build(BuildContext context) {
    final c = kLabs[lab];
    final color = kAccents[lab + 1];
    return Tooltip(
      message: 'Ouvrir ${c.tag} avec son premier scénario chargé',
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => LabBus.open(lab + 1, scenarioIndex: 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: fade(color, 0.12), borderRadius: BorderRadius.circular(9), border: Border.all(color: fade(color, 0.5))),
          child: Text('${c.tag} · ${c.minutes} min', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _LabCard extends StatefulWidget {
  final int lab;
  final Animation<double> anim;
  const _LabCard({required this.lab, required this.anim});

  @override
  State<_LabCard> createState() => _LabCardState();
}

class _LabCardState extends State<_LabCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = kLabs[widget.lab];
    final color = kAccents[widget.lab + 1];
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => LabBus.open(widget.lab + 1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: C.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _hover ? fade(color, 0.8) : C.line, width: _hover ? 1.5 : 1),
            boxShadow: [BoxShadow(color: fade(color, _hover ? 0.22 : 0.0), blurRadius: 28, spreadRadius: -6)],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              flex: 11,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 8, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: fade(color, 0.16), borderRadius: BorderRadius.circular(7)),
                      child: Text(c.tag, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ),
                    const SizedBox(width: 10),
                    Flexible(child: Text(c.source, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 12.5))),
                  ]),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(c.title, style: const TextStyle(color: C.text, fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(c.algos, overflow: TextOverflow.fade, style: kMono.copyWith(color: fade(C.text, 0.8), fontSize: 12.5, height: 1.45)),
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _hover ? color : fade(color, 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: fade(color, 0.7)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.play_arrow_rounded, size: 17, color: _hover ? C.bg : color),
                      const SizedBox(width: 6),
                      Text('Lancer la démonstration', style: TextStyle(color: _hover ? C.bg : color, fontSize: 13, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ]),
              ),
            ),
            Expanded(
              flex: 9,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: widget.anim,
                  builder: (_, __) => CustomPaint(painter: _PreviewPainter(widget.lab, widget.anim.value, color)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Apercus animes des quatre TP.
class _PreviewPainter extends CustomPainter {
  final int lab;
  final double t; // 0..1, boucle
  final Color color;
  _PreviewPainter(this.lab, this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height) * 0.86;
    final o = Offset((size.width - s) / 2, (size.height - s) / 2);
    canvas.save();
    canvas.translate(o.dx, o.dy);
    switch (lab) {
      case 0:
        _cycle(canvas, s);
      case 1:
        _tsp(canvas, s);
      case 2:
        _ttt(canvas, s);
      default:
        _puzzle(canvas, s);
    }
    canvas.restore();
  }

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _node(Canvas canvas, Offset p, double r, Color c, {double glow = 0}) {
    if (glow > 0) canvas.drawCircle(p, r * (1.6 + glow), Paint()..color = fade(c, 0.18 * glow));
    canvas.drawCircle(p, r, Paint()..color = C.card2);
    canvas.drawCircle(p, r, _stroke(c, max(1.5, r * 0.22)));
  }

  // Un cycle qui pulse dans un graphe.
  void _cycle(Canvas canvas, double s) {
    final pts = [
      for (final p in const [[0.12, 0.5], [0.34, 0.2], [0.34, 0.8], [0.58, 0.5], [0.84, 0.24], [0.84, 0.76], [0.6, 0.1]]) Offset(p[0] * s, p[1] * s)
    ];
    const edges = [[0, 1], [0, 2], [1, 3], [2, 3], [3, 4], [3, 5], [4, 5], [1, 6], [6, 4]];
    const cyc = [3, 4, 5];
    final pulse = 0.5 + 0.5 * sin(t * 2 * pi * 4);
    for (final e in edges) {
      canvas.drawLine(pts[e[0]], pts[e[1]], _stroke(C.line, s * 0.012));
    }
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(pts[cyc[i]], pts[cyc[(i + 1) % 3]], _stroke(fade(color, 0.55 + 0.45 * pulse), s * (0.02 + 0.012 * pulse)));
    }
    // Front du BFS : une onde qui part du sommet 0.
    final wave = (t * 2) % 1;
    for (var i = 0; i < pts.length; i++) {
      final d = (pts[i] - pts[0]).distance / s;
      final hit = (1 - ((wave * 1.2 - d).abs() * 6)).clamp(0.0, 1.0);
      _node(canvas, pts[i], s * 0.045, cyc.contains(i) ? color : Color.lerp(C.muted, color, hit)!, glow: cyc.contains(i) ? pulse : hit);
    }
  }

  // Une tournee tracee entre des villes.
  void _tsp(Canvas canvas, double s) {
    final pts = [
      for (final p in const [[0.5, 0.1], [0.86, 0.3], [0.8, 0.74], [0.46, 0.9], [0.14, 0.66], [0.2, 0.26]]) Offset(p[0] * s, p[1] * s)
    ];
    for (var i = 0; i < pts.length; i++) {
      for (var j = i + 1; j < pts.length; j++) {
        canvas.drawLine(pts[i], pts[j], _stroke(fade(C.line, 0.6), s * 0.006));
      }
    }
    final n = pts.length;
    final prog = (t * 2) % 1 * n;
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    var dot = pts[0];
    for (var k = 0; k < n; k++) {
      final a = pts[k], b = pts[(k + 1) % n];
      final f = (prog - k).clamp(0.0, 1.0);
      if (f <= 0) break;
      dot = Offset.lerp(a, b, f)!;
      path.lineTo(dot.dx, dot.dy);
    }
    canvas.drawPath(path, _stroke(color, s * 0.022));
    for (var i = 0; i < n; i++) {
      _node(canvas, pts[i], s * 0.045, i == 0 ? C.text : color, glow: i == 0 ? 0.6 : 0);
    }
    canvas.drawCircle(dot, s * 0.03, Paint()..color = C.text);
    canvas.drawCircle(dot, s * 0.06, Paint()..color = fade(color, 0.3));
  }

  // Une grille X / O qui se remplit.
  void _ttt(Canvas canvas, double s) {
    const n = 4;
    final cell = s / n;
    for (var i = 1; i < n; i++) {
      canvas.drawLine(Offset(i * cell, s * 0.04), Offset(i * cell, s * 0.96), _stroke(C.line, s * 0.012));
      canvas.drawLine(Offset(s * 0.04, i * cell), Offset(s * 0.96, i * cell), _stroke(C.line, s * 0.012));
    }
    const moves = [5, 6, 10, 1, 0, 9, 15, 2, 3]; // X, O, X, O... X aligne 0-5-10-15
    final prog = (t * 2) % 1 * (moves.length + 3);
    for (var k = 0; k < moves.length; k++) {
      final f = (prog - k).clamp(0.0, 1.0);
      if (f <= 0) break;
      final c = Offset((moves[k] % n + 0.5) * cell, (moves[k] ~/ n + 0.5) * cell);
      final r = cell * 0.27;
      if (k.isEven) {
        final p = _stroke(color, s * 0.028);
        canvas.drawLine(c + Offset(-r, -r), c + Offset(-r + 2 * r * min(1, f * 2), -r + 2 * r * min(1, f * 2)), p);
        if (f > 0.5) canvas.drawLine(c + Offset(r, -r), c + Offset(r - 2 * r * (f - 0.5) * 2, -r + 2 * r * (f - 0.5) * 2), p);
      } else {
        canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2, 2 * pi * f, false, _stroke(C.text, s * 0.026));
      }
    }
    final w = (prog - moves.length + 2).clamp(0.0, 1.0);
    if (w > 0) {
      final a = Offset(0.5 * cell, 0.5 * cell), b = Offset(3.5 * cell, 3.5 * cell);
      canvas.drawLine(a, Offset.lerp(a, b, w)!, _stroke(fade(C.green, 0.9), s * 0.035));
    }
  }

  // Des jetons qui glissent.
  void _puzzle(Canvas canvas, double s) {
    const n = 3;
    final cell = s / n;
    // Cycle de 4 deplacements de la case vide autour d'un carre : le plateau revient a l'identique.
    const cyclePos = [8, 7, 4, 5];
    final phase = (t * 12) % 12; // 12 deplacements ramenent les trois jetons a leur place
    final k = phase.floor() % 12;
    final f = Curves.easeInOut.transform(phase - phase.floor());
    final tiles = <int, int>{}; // position -> jeton
    final board = [1, 2, 3, 4, 5, 6, 7, 8, 0];
    for (var i = 0; i < k; i++) {
      final from = cyclePos[(i + 1) % 4], to = cyclePos[i % 4];
      board[to] = board[from];
      board[from] = 0;
    }
    for (var i = 0; i < 9; i++) {
      tiles[i] = board[i];
    }
    final movingFrom = cyclePos[(k + 1) % 4], movingTo = cyclePos[k % 4];
    for (var i = 0; i < 9; i++) {
      final v = tiles[i]!;
      if (v == 0) continue;
      var c = Offset((i % n + 0.5) * cell, (i ~/ n + 0.5) * cell);
      if (i == movingFrom) c = Offset.lerp(c, Offset((movingTo % n + 0.5) * cell, (movingTo ~/ n + 0.5) * cell), f)!;
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: cell * 0.86, height: cell * 0.86), Radius.circular(cell * 0.16));
      final hot = i == movingFrom;
      canvas.drawRRect(r, Paint()..color = hot ? fade(color, 0.3) : C.card2);
      canvas.drawRRect(r, _stroke(hot ? color : C.line, s * 0.012));
      drawText(canvas, '$v', c, kMono.copyWith(color: hot ? color : C.text, fontSize: cell * 0.36, fontWeight: FontWeight.w800), anchor: Alignment.center);
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) => old.t != t;
}
