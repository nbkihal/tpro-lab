import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/graph.dart';
import 'kit.dart';

const _levelColors = [Color(0xFFFFFFFF), C.cyan, Color(0xFF60A5FA), C.violet, Color(0xFFF472B6), C.amber, C.green];

class CyclePage extends StatefulWidget {
  const CyclePage({super.key});

  @override
  State<CyclePage> createState() => _CyclePageState();
}

class _CyclePageState extends State<CyclePage> with SingleTickerProviderStateMixin {
  final Graph _g = Graph();
  final List<Offset> _pos = []; // coordonnees normalisees dans [0, 1]
  final Random _rnd = Random();
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  CycleResult? _res;
  List<BfsEvent> _trace = const [];
  int _ev = 0;
  Timer? _timer;
  int _speed = 1;
  int _n = 9, _m = 12;
  int? _dragFrom;
  Offset? _dragAt;
  Size _size = Size.zero;

  bool get _animating => _timer != null;

  @override
  void initState() {
    super.initState();
    _random();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    _res = null;
    _trace = const [];
    _ev = 0;
  }

  void _random() {
    _reset();
    final g = Graph.random(_n, _m, _rnd);
    _g.clear();
    _pos.clear();
    for (var i = 0; i < _n; i++) {
      _g.addVertex();
      final a = 2 * pi * i / _n - pi / 2;
      final r = 0.34 + _rnd.nextDouble() * 0.1;
      _pos.add(Offset(0.5 + r * cos(a), 0.5 + r * sin(a)));
    }
    for (final e in g.edges()) {
      _g.addEdge(e[0], e[1]);
    }
    setState(() {});
  }

  void _clear() => setState(() {
        _reset();
        _g.clear();
        _pos.clear();
      });

  void _run({required bool animate}) {
    _reset();
    final r = shortestCycle(_g, trace: true);
    _res = r;
    if (animate && r.trace.isNotEmpty) {
      _trace = r.trace;
      final perTick = [1, 2, 6][_speed];
      _timer = Timer.periodic(const Duration(milliseconds: 70), (t) {
        setState(() {
          _ev = min(_ev + perTick, _trace.length);
          if (_ev >= _trace.length) {
            t.cancel();
            _timer = null;
          }
        });
      });
    }
    setState(() {});
  }

  Offset _px(Offset p) => Offset(30 + p.dx * (_size.width - 60), 30 + p.dy * (_size.height - 60));
  Offset _norm(Offset p) => Offset(
      ((p.dx - 30) / max(1, _size.width - 60)).clamp(0.0, 1.0), ((p.dy - 30) / max(1, _size.height - 60)).clamp(0.0, 1.0));

  int? _hit(Offset at) {
    for (var i = 0; i < _pos.length; i++) {
      if ((_px(_pos[i]) - at).distance <= 20) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final r = _res;
    final done = r != null && !_animating;
    // Etat de l'animation : source courante et niveau de chaque sommet deja atteint.
    int? source;
    final levels = <int, int>{};
    if (_animating && _ev > 0) {
      source = _trace[_ev - 1].source;
      for (var i = _ev - 1; i >= 0 && _trace[i].source == source; i--) {
        levels[_trace[i].node] = _trace[i].dist;
      }
    }

    return PageScaffold(
      tag: 'TP 1',
      title: 'Plus court cycle',
      subtitle: 'Graphe non oriente - un BFS depuis chaque sommet',
      accent: C.cyan,
      canvas: Panel(
        padding: EdgeInsets.zero,
        child: LayoutBuilder(builder: (context, box) {
          _size = box.biggest;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              if (_hit(d.localPosition) != null || _g.n >= 40) return;
              setState(() {
                _reset();
                _g.addVertex();
                _pos.add(_norm(d.localPosition));
              });
            },
            onSecondaryTapUp: (d) {
              final v = _hit(d.localPosition);
              if (v == null) return;
              setState(() {
                _reset();
                _g.removeVertex(v);
                _pos.removeAt(v);
              });
            },
            onPanStart: (d) => setState(() {
              _dragFrom = _hit(d.localPosition);
              _dragAt = d.localPosition;
            }),
            onPanUpdate: (d) => setState(() => _dragAt = d.localPosition),
            onPanEnd: (_) => setState(() {
              final to = _dragAt == null ? null : _hit(_dragAt!);
              if (_dragFrom != null && to != null && to != _dragFrom) {
                _reset();
                if (_g.hasEdge(_dragFrom!, to)) {
                  _g.removeEdge(_dragFrom!, to);
                } else {
                  _g.addEdge(_dragFrom!, to);
                }
              }
              _dragFrom = null;
              _dragAt = null;
            }),
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => CustomPaint(
                size: Size.infinite,
                painter: _GraphPainter(
                  g: _g,
                  pts: [for (final p in _pos) _px(p)],
                  cycle: done ? r.cycle : const [],
                  source: source,
                  levels: levels,
                  pulse: _pulse.value,
                  dragFrom: _dragFrom,
                  dragAt: _dragAt,
                ),
              ),
            ),
          );
        }),
      ),
      side: [
        Panel(
          title: 'Graphe',
          accent: C.cyan,
          child: Column(children: [
            NumStepper(label: 'Sommets', value: _n, min: 3, max: 30, onChanged: (v) => setState(() => _n = v)),
            NumStepper(label: 'Aretes', value: _m, min: 0, max: 80, onChanged: (v) => setState(() => _m = v)),
            Row(children: [
              Expanded(child: ActionBtn(label: 'Aleatoire', icon: Icons.casino_rounded, onPressed: _random)),
              const SizedBox(width: 8),
              Expanded(child: ActionBtn(label: 'Effacer', icon: Icons.delete_outline_rounded, color: C.red, onPressed: _clear)),
            ]),
            const SizedBox(height: 6),
            const InfoBox([
              'Clic dans le vide : ajouter un sommet.',
              'Glisser d\'un sommet a un autre : ajouter / retirer une arete.',
              'Clic droit sur un sommet : le supprimer.',
            ]),
          ]),
        ),
        Panel(
          title: 'Execution',
          accent: C.cyan,
          child: Column(children: [
            Seg(options: const ['Lent', 'Normal', 'Rapide'], index: _speed, onChanged: (v) => setState(() => _speed = v)),
            const SizedBox(height: 6),
            ActionBtn(
                label: 'Animer les BFS',
                icon: Icons.play_arrow_rounded,
                filled: true,
                onPressed: _g.n == 0 ? null : () => _run(animate: true)),
            ActionBtn(label: 'Resultat direct', icon: Icons.bolt_rounded, onPressed: _g.n == 0 ? null : () => _run(animate: false)),
          ]),
        ),
        Panel(
          title: 'Resultat',
          accent: C.cyan,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StatRow([
              Stat(label: 'longueur du cycle', value: !done ? '-' : (r.cycle.isEmpty ? 'aucun' : '${r.length}'), color: C.cyan),
              Stat(label: 'sommets defiles', value: r == null ? '-' : '${r.visits}'),
            ]),
            const SizedBox(height: 8),
            StatRow([
              Stat(label: 'n sommets / m aretes', value: '${_g.n} / ${_g.m}'),
              Stat(label: 'temps (µs)', value: r == null ? '-' : '${r.micros}'),
            ]),
            const SizedBox(height: 10),
            Text(
              _animating
                  ? 'BFS depuis le sommet $source ...'
                  : (!done
                      ? 'Lancez l\'algorithme.'
                      : (r.cycle.isEmpty ? 'Le graphe est acyclique (une foret).' : 'Cycle : ${r.cycle.join(' - ')} - ${r.cycle.first}')),
              style: kMono.copyWith(color: C.text, fontSize: 12.5),
            ),
          ]),
        ),
        const Panel(
          title: 'Methode et complexite',
          accent: C.cyan,
          child: InfoBox([
            'Representation : listes d\'adjacence.',
            'Depuis chaque sommet s, un BFS calcule dist[] et pere[].',
            'Une arete (u, v) vers un sommet deja vu, v different de pere[u], ferme un cycle de longueur au plus dist[u] + dist[v] + 1.',
            'On garde le minimum : il est atteint quand s appartient au plus court cycle.',
            'Complexite : n BFS en O(n + m), soit O(n (n + m)).',
          ]),
        ),
      ],
    );
  }
}

class _GraphPainter extends CustomPainter {
  final Graph g;
  final List<Offset> pts;
  final List<int> cycle;
  final int? source;
  final Map<int, int> levels;
  final double pulse;
  final int? dragFrom;
  final Offset? dragAt;
  _GraphPainter({
    required this.g,
    required this.pts,
    required this.cycle,
    required this.source,
    required this.levels,
    required this.pulse,
    required this.dragFrom,
    required this.dragAt,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.isEmpty) {
      drawText(canvas, 'Cliquez pour ajouter des sommets', size.center(Offset.zero), const TextStyle(color: C.muted, fontSize: 14),
          anchor: Alignment.center);
      return;
    }
    final edge = Paint()
      ..color = C.line
      ..strokeWidth = 2;
    for (final e in g.edges()) {
      final both = levels.containsKey(e[0]) && levels.containsKey(e[1]);
      canvas.drawLine(pts[e[0]], pts[e[1]], both ? (Paint()..color = fade(C.cyan, 0.45)..strokeWidth = 2.5) : edge);
    }
    if (cycle.isNotEmpty) {
      final glow = 0.5 + 0.5 * sin(pulse * 2 * pi);
      for (var i = 0; i < cycle.length; i++) {
        final a = pts[cycle[i]], b = pts[cycle[(i + 1) % cycle.length]];
        canvas.drawLine(a, b, Paint()..color = fade(C.cyan, 0.15 + 0.2 * glow)..strokeWidth = 12 + 6 * glow..strokeCap = StrokeCap.round);
        canvas.drawLine(a, b, Paint()..color = C.cyan..strokeWidth = 4..strokeCap = StrokeCap.round);
      }
    }
    if (dragFrom != null && dragAt != null) {
      canvas.drawLine(pts[dragFrom!], dragAt!, Paint()..color = fade(C.cyan, 0.7)..strokeWidth = 2);
    }
    for (var i = 0; i < pts.length; i++) {
      final inCycle = cycle.contains(i);
      final lvl = levels[i];
      final fill = lvl != null ? _levelColors[lvl % _levelColors.length] : (inCycle ? C.cyan : C.card2);
      if (i == source) canvas.drawCircle(pts[i], 24, Paint()..color = fade(Colors.white, 0.18));
      canvas.drawCircle(pts[i], 16, Paint()..color = fill);
      canvas.drawCircle(
          pts[i],
          16,
          Paint()
            ..color = inCycle || lvl != null ? Colors.transparent : C.muted
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      drawText(canvas, '$i', pts[i],
          TextStyle(color: lvl != null || inCycle ? C.bg : C.text, fontSize: 13, fontWeight: FontWeight.w800),
          anchor: Alignment.center);
      if (lvl != null) {
        drawText(canvas, 'd=$lvl', pts[i] + const Offset(0, 20), const TextStyle(color: C.muted, fontSize: 10), anchor: Alignment.topCenter);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) => true;
}
