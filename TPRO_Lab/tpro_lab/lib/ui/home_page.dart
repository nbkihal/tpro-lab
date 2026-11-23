import 'dart:math';

import 'package:flutter/material.dart';

import 'kit.dart';

class _Tp {
  final String tag, title, desc, complexity;
  final Color color;
  const _Tp(this.tag, this.title, this.desc, this.complexity, this.color);
}

const _tps = [
  _Tp('TP 1 - TD2', 'Plus court cycle', 'Un parcours en largeur depuis chaque sommet d\'un graphe non oriente.', 'O(n (n + m))', C.cyan),
  _Tp('TP 2 - TD3', 'Voyageur de commerce', 'Enumeration exacte contre programmation dynamique de Bellman-Held-Karp.',
      'O(n!)  vs  O(n² 2ⁿ)', C.amber),
  _Tp('TP 3 - TD4', 'Morpion N x N', 'MinMax, elagage alpha/beta, approfondissement iteratif et client TCP du tournoi.',
      'alpha/beta + TMO', C.violet),
  _Tp('TP 4 - TD5', 'Taquin 4 x 4', 'A* et WA*, tas binaire contre file naive, trois heuristiques comparees.', 'f = g + p·h', C.green),
];

class HomePage extends StatefulWidget {
  final ValueChanged<int> onOpen;
  const HomePage({super.key, required this.onOpen});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Techniques de programmation', style: TextStyle(color: C.muted, fontSize: 13, letterSpacing: 1)),
        const SizedBox(height: 4),
        const Text('Quatre travaux pratiques, une seule application',
            style: TextStyle(color: C.text, fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Choisissez un module : chaque algorithme est execute, mesure et visualise.',
            style: TextStyle(color: C.muted, fontSize: 14)),
        const SizedBox(height: 22),
        Expanded(
          child: Column(children: [
            Expanded(child: Row(children: [_card(0), const SizedBox(width: 16), _card(1)])),
            const SizedBox(height: 16),
            Expanded(child: Row(children: [_card(2), const SizedBox(width: 16), _card(3)])),
          ]),
        ),
      ]),
    );
  }

  Widget _card(int i) => Expanded(child: _TpCard(tp: _tps[i], index: i, anim: _anim, onTap: () => widget.onOpen(i + 1)));
}

class _TpCard extends StatefulWidget {
  final _Tp tp;
  final int index;
  final Animation<double> anim;
  final VoidCallback onTap;
  const _TpCard({required this.tp, required this.index, required this.anim, required this.onTap});

  @override
  State<_TpCard> createState() => _TpCardState();
}

class _TpCardState extends State<_TpCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tp = widget.tp;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [fade(tp.color, _hover ? 0.22 : 0.10), C.card],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: fade(tp.color, _hover ? 0.8 : 0.25), width: 1.2),
          ),
          child: Row(children: [
            Expanded(
              flex: 5,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tp.tag, style: TextStyle(color: tp.color, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 8),
                Text(tp.title, style: const TextStyle(color: C.text, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Flexible(
                  child: Text(tp.desc,
                      overflow: TextOverflow.fade, style: const TextStyle(color: C.muted, fontSize: 13, height: 1.4)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: fade(C.bg, 0.6), borderRadius: BorderRadius.circular(8)),
                  child: Text(tp.complexity, style: kMono.copyWith(color: tp.color, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: AnimatedBuilder(
                animation: widget.anim,
                builder: (_, __) => CustomPaint(painter: _MiniPainter(widget.index, widget.anim.value, tp.color), size: Size.infinite),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Mini-illustrations animees des quatre algorithmes.
class _MiniPainter extends CustomPainter {
  final int kind;
  final double t;
  final Color color;
  _MiniPainter(this.kind, this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height);
    final o = Offset((size.width - s) / 2, (size.height - s) / 2);
    Offset p(double x, double y) => o + Offset(x * s, y * s);
    final line = Paint()
      ..color = fade(color, 0.35)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final hot = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (kind == 0) {
      // BFS : une onde part d'un sommet, niveau par niveau
      const pts = [Offset(.5, .5), Offset(.25, .28), Offset(.75, .3), Offset(.3, .78), Offset(.72, .76), Offset(.08, .55), Offset(.93, .55)];
      const es = [[0, 1], [0, 2], [0, 3], [0, 4], [1, 5], [3, 5], [2, 6], [4, 6], [1, 2]];
      const level = [0, 1, 1, 1, 1, 2, 2];
      for (final e in es) {
        canvas.drawLine(p(pts[e[0]].dx, pts[e[0]].dy), p(pts[e[1]].dx, pts[e[1]].dy), line);
      }
      final wave = (t * 4) % 4;
      for (var i = 0; i < pts.length; i++) {
        final on = wave >= level[i] + 0.3;
        canvas.drawCircle(p(pts[i].dx, pts[i].dy), s * 0.05, Paint()..color = on ? color : C.card2);
        canvas.drawCircle(p(pts[i].dx, pts[i].dy), s * 0.05, line);
      }
    } else if (kind == 1) {
      // Tournee qui se dessine
      const pts = [Offset(.15, .3), Offset(.45, .12), Offset(.85, .25), Offset(.9, .7), Offset(.55, .88), Offset(.2, .75)];
      final prog = (t * 2) % 1.4;
      final total = pts.length.toDouble();
      for (var i = 0; i < pts.length; i++) {
        final a = pts[i], b = pts[(i + 1) % pts.length];
        final f = (prog * total / 1.0 - i).clamp(0.0, 1.0);
        canvas.drawLine(p(a.dx, a.dy), p(b.dx, b.dy), line);
        if (f > 0) canvas.drawLine(p(a.dx, a.dy), p(a.dx + (b.dx - a.dx) * f, a.dy + (b.dy - a.dy) * f), hot);
      }
      for (final q in pts) {
        canvas.drawCircle(p(q.dx, q.dy), s * 0.045, Paint()..color = color);
      }
    } else if (kind == 2) {
      // Plateau qui se remplit
      const n = 5;
      final cell = s * 0.8 / n;
      final org = p(.1, .1);
      for (var i = 0; i <= n; i++) {
        canvas.drawLine(org + Offset(i * cell, 0), org + Offset(i * cell, n * cell), line);
        canvas.drawLine(org + Offset(0, i * cell), org + Offset(n * cell, i * cell), line);
      }
      const moves = [12, 7, 13, 11, 8, 17, 6, 18, 14, 16, 4];
      final shown = ((t * 3) % 1.2 * moves.length).floor().clamp(0, moves.length);
      for (var k = 0; k < shown; k++) {
        final c = org + Offset((moves[k] % n + .5) * cell, (moves[k] ~/ n + .5) * cell);
        if (k.isEven) {
          canvas.drawLine(c - Offset(cell * .25, cell * .25), c + Offset(cell * .25, cell * .25), hot);
          canvas.drawLine(c - Offset(cell * .25, -cell * .25), c + Offset(cell * .25, -cell * .25), hot);
        } else {
          canvas.drawCircle(c, cell * .27, Paint()..color = C.amber..style = PaintingStyle.stroke..strokeWidth = 3);
        }
      }
    } else {
      // Taquin : une tuile glisse
      const n = 4;
      final cell = s * 0.8 / n;
      final org = p(.1, .1);
      final phase = (t * 6) % 2;
      final slide = phase < 1 ? Curves.easeInOut.transform(phase) : 1 - Curves.easeInOut.transform(phase - 1);
      for (var i = 0; i < 15; i++) {
        var c = org + Offset((i % n) * cell, (i ~/ n) * cell);
        if (i == 14) c += Offset(cell * slide, 0);
        final r = RRect.fromRectAndRadius(Rect.fromLTWH(c.dx + 2, c.dy + 2, cell - 4, cell - 4), Radius.circular(cell * .18));
        canvas.drawRRect(r, Paint()..color = i == 14 ? color : fade(color, 0.22));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MiniPainter old) => old.t != t;
}
