import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/tsp.dart';
import 'charts.dart';
import 'kit.dart';

class _BenchRow {
  final int n;
  final double? bruteMs;
  final double hkMs;
  final bool? same;
  const _BenchRow(this.n, this.bruteMs, this.hkMs, this.same);
}

const int kBruteMax = 11; // au-dela, (n-1)! permutations deviennent trop longues

class TspPage extends StatefulWidget {
  const TspPage({super.key});

  @override
  State<TspPage> createState() => _TspPageState();
}

class _TspPageState extends State<TspPage> with SingleTickerProviderStateMixin {
  final Random _rnd = Random();
  final List<Offset> _cities = []; // coordonnees normalisees
  List<List<int>>? _custom; // matrice saisie a la main (sinon distances euclidiennes)
  late final AnimationController _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  TspResult? _brute, _hk;
  List<int> _tour = const [];
  Color _tourColor = C.amber;
  bool _busy = false;
  int _n = 8, _benchMax = 14;
  int? _drag;
  Size _size = Size.zero;
  final List<_BenchRow> _bench = [];

  @override
  void initState() {
    super.initState();
    _random();
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  void _invalidate() {
    _brute = null;
    _hk = null;
    _tour = const [];
  }

  void _random() => setState(() {
        _invalidate();
        _custom = null;
        _cities
          ..clear()
          ..addAll([for (var i = 0; i < _n; i++) Offset(0.06 + _rnd.nextDouble() * 0.88, 0.08 + _rnd.nextDouble() * 0.84)]);
      });

  List<List<int>> _matrix() {
    if (_custom != null) return _custom!;
    final n = _cities.length;
    return [
      for (var i = 0; i < n; i++) [for (var j = 0; j < n; j++) i == j ? 0 : ((_cities[i] - _cities[j]).distance * 100).round()],
    ];
  }

  Future<void> _solve(bool heldKarp) async {
    final d = _matrix();
    if (d.length < 3) return toast(context, 'Il faut au moins 3 villes.');
    if (!heldKarp && d.length > kBruteMax + 1) {
      return toast(context, 'Enumeration limitee a ${kBruteMax + 1} villes ((n-1)! permutations).');
    }
    setState(() => _busy = true);
    final r = await tspInIsolate(d, heldKarp: heldKarp);
    if (!mounted) return;
    setState(() {
      _busy = false;
      heldKarp ? _hk = r : _brute = r;
      _tour = r.tour;
      _tourColor = heldKarp ? C.amber : C.cyan;
    });
    _draw.forward(from: 0);
  }

  Future<void> _benchmark() async {
    setState(() {
      _busy = true;
      _bench.clear();
    });
    for (var n = 4; n <= _benchMax; n++) {
      final d = randomMatrix(n, Random(n));
      final hk = await tspInIsolate(d, heldKarp: true);
      TspResult? bf;
      if (n <= kBruteMax) bf = await tspInIsolate(d, heldKarp: false);
      if (!mounted) return;
      setState(() => _bench.add(_BenchRow(n, bf == null ? null : bf.micros / 1000, hk.micros / 1000, bf == null ? null : bf.cost == hk.cost)));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _export() async {
    if (_bench.isEmpty) return toast(context, 'Lancez d\'abord le benchmark.');
    final sb = StringBuffer('n;enumeration_ms;held_karp_ms;meme_cout\n');
    for (final r in _bench) {
      sb.writeln('${r.n};${r.bruteMs?.toStringAsFixed(3) ?? ''};${r.hkMs.toStringAsFixed(3)};${r.same ?? ''}');
    }
    final f = File('tsp_benchmark.csv');
    await f.writeAsString(sb.toString());
    if (mounted) toast(context, 'Exporte : ${f.absolute.path}');
  }

  Future<void> _editMatrix() async {
    final ctl = TextEditingController(text: _matrix().map((r) => r.join(' ')).join('\n'));
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.card,
        title: const Text('Matrice des distances', style: TextStyle(color: C.text, fontSize: 18)),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Une ligne par ville, valeurs entieres separees par des espaces (matrice carree).',
                style: TextStyle(color: C.muted, fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: ctl,
              maxLines: 12,
              style: kMono.copyWith(color: C.text, fontSize: 13),
              decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: C.card2),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('Appliquer')),
        ],
      ),
    );
    if (text == null || !mounted) return;
    try {
      final rows = [
        for (final l in text.split('\n'))
          if (l.trim().isNotEmpty) l.trim().split(RegExp(r'[\s,;]+')).map(int.parse).toList(),
      ];
      final n = rows.length;
      if (n < 3 || n > 20 || rows.any((r) => r.length != n)) throw const FormatException();
      setState(() {
        _invalidate();
        _custom = rows;
        _cities
          ..clear()
          ..addAll([for (var i = 0; i < n; i++) Offset(0.5 + 0.38 * cos(2 * pi * i / n - pi / 2), 0.5 + 0.38 * sin(2 * pi * i / n - pi / 2))]);
      });
    } catch (_) {
      toast(context, 'Matrice invalide : il faut une matrice carree d\'entiers, de 3 a 20 villes.');
    }
  }

  Offset _px(Offset p) => Offset(28 + p.dx * (_size.width - 56), 28 + p.dy * (_size.height - 56));
  Offset _norm(Offset p) => Offset(
      ((p.dx - 28) / max(1, _size.width - 56)).clamp(0.0, 1.0), ((p.dy - 28) / max(1, _size.height - 56)).clamp(0.0, 1.0));
  int? _hit(Offset at) {
    for (var i = 0; i < _cities.length; i++) {
      if ((_px(_cities[i]) - at).distance <= 18) return i;
    }
    return null;
  }

  String _ms(TspResult? r) => r == null ? '-' : (r.micros / 1000).toStringAsFixed(r.micros < 10000 ? 2 : 0);

  @override
  Widget build(BuildContext context) {
    final d = _matrix();
    return PageScaffold(
      tag: 'TP 2',
      title: 'Voyageur de commerce',
      subtitle: 'Enumeration exacte O(n!) contre Bellman-Held-Karp O(n² 2ⁿ)',
      accent: C.amber,
      canvas: Panel(
        padding: EdgeInsets.zero,
        child: LayoutBuilder(builder: (context, box) {
          _size = box.biggest;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (e) {
              if (_custom != null || _busy || _hit(e.localPosition) != null || _cities.length >= 20) return;
              setState(() {
                _invalidate();
                _cities.add(_norm(e.localPosition));
              });
            },
            onSecondaryTapUp: (e) {
              final v = _hit(e.localPosition);
              if (v == null || _custom != null || _busy) return;
              setState(() {
                _invalidate();
                _cities.removeAt(v);
              });
            },
            onPanStart: (e) => _drag = _busy ? null : _hit(e.localPosition),
            onPanUpdate: (e) {
              if (_drag == null) return;
              setState(() {
                if (_custom == null) _invalidate();
                _cities[_drag!] = _norm(e.localPosition);
              });
            },
            onPanEnd: (_) => _drag = null,
            child: AnimatedBuilder(
              animation: _draw,
              builder: (_, __) => CustomPaint(
                size: Size.infinite,
                painter: _TspPainter([for (final c in _cities) _px(c)], _tour, d, _draw.value, _tourColor),
              ),
            ),
          );
        }),
      ),
      bottomHeight: 230,
      bottom: Row(children: [
        Expanded(
          flex: 5,
          child: Panel(
            padding: const EdgeInsets.all(12),
            child: LogLineChart(
              xLabel: 'n villes',
              yLabel: 'temps (ms), echelle log',
              series: [
                Series('Enumeration n!', C.cyan, [
                  for (final r in _bench)
                    if (r.bruteMs != null) Offset(r.n.toDouble(), max(r.bruteMs!, 0.001)),
                ]),
                Series('Held-Karp', C.amber, [for (final r in _bench) Offset(r.n.toDouble(), max(r.hkMs, 0.001))]),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 4,
          child: Panel(
            padding: const EdgeInsets.all(8),
            child: SimpleTable(
              headers: const ['n', 'n! (ms)', 'Held-Karp (ms)', 'meme cout'],
              flex: const [1, 3, 3, 2],
              rows: [
                for (final r in _bench)
                  ['${r.n}', r.bruteMs?.toStringAsFixed(2) ?? 'trop long', r.hkMs.toStringAsFixed(2), r.same == null ? '-' : (r.same! ? 'oui' : 'NON')],
              ],
            ),
          ),
        ),
      ]),
      side: [
        Panel(
          title: 'Villes',
          accent: C.amber,
          child: Column(children: [
            NumStepper(label: 'Nombre de villes', value: _n, min: 3, max: 18, onChanged: (v) => setState(() => _n = v)),
            Row(children: [
              Expanded(child: ActionBtn(label: 'Aleatoire', icon: Icons.casino_rounded, color: C.amber, onPressed: _busy ? null : _random)),
              const SizedBox(width: 8),
              Expanded(child: ActionBtn(label: 'Matrice...', icon: Icons.grid_on_rounded, color: C.amber, onPressed: _busy ? null : _editMatrix)),
            ]),
            const SizedBox(height: 6),
            InfoBox([
              _custom != null
                  ? 'Matrice saisie a la main (${d.length} villes) : les positions sont seulement indicatives.'
                  : 'Clic : ajouter une ville. Glisser : la deplacer. Clic droit : la supprimer. Distance = distance euclidienne x 100.',
              'La tournee part de la ville 0 et y revient.',
            ], color: C.amber),
          ]),
        ),
        Panel(
          title: 'Resolution',
          accent: C.amber,
          child: Column(children: [
            ActionBtn(
                label: 'Enumeration exacte  (n!)', icon: Icons.all_inclusive_rounded, color: C.cyan, onPressed: _busy ? null : () => _solve(false)),
            ActionBtn(
                label: 'Bellman-Held-Karp', icon: Icons.memory_rounded, color: C.amber, filled: true, onPressed: _busy ? null : () => _solve(true)),
            const SizedBox(height: 6),
            StatRow([
              Stat(label: 'cout enumeration', value: _brute == null ? '-' : '${_brute!.cost}', color: C.cyan),
              Stat(label: 'cout Held-Karp', value: _hk == null ? '-' : '${_hk!.cost}', color: C.amber),
            ]),
            const SizedBox(height: 8),
            StatRow([
              Stat(label: 'temps n! (ms)', value: _ms(_brute)),
              Stat(label: 'temps HK (ms)', value: _ms(_hk)),
            ]),
            const SizedBox(height: 8),
            StatRow([
              Stat(label: 'cycles evalues', value: _brute == null ? '-' : '${_brute!.ops}'),
              Stat(label: 'transitions C(S,j)', value: _hk == null ? '-' : '${_hk!.ops}'),
            ]),
            if (_tour.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Tournee : ${_tour.join(' - ')} - 0', style: kMono.copyWith(color: C.text, fontSize: 12.5)),
              ),
            ],
          ]),
        ),
        Panel(
          title: 'Benchmark',
          accent: C.amber,
          child: Column(children: [
            NumStepper(label: 'Jusqu\'a n =', value: _benchMax, min: 8, max: 18, onChanged: (v) => setState(() => _benchMax = v)),
            ActionBtn(label: 'Comparer les deux methodes', icon: Icons.speed_rounded, color: C.amber, onPressed: _busy ? null : _benchmark),
            ActionBtn(label: 'Exporter en CSV', icon: Icons.download_rounded, color: C.muted, onPressed: _busy ? null : _export),
            if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator(color: C.amber, backgroundColor: C.card2)),
          ]),
        ),
        const Panel(
          title: 'Methode et complexite',
          accent: C.amber,
          child: InfoBox([
            'Enumeration : toutes les permutations des villes 1..n-1, soit (n-1)! cycles.',
            'Held-Karp : C(S, j) = cout minimal pour partir de 0, visiter S et finir en j.',
            'C(S, j) = min sur i de C(S - {j}, i) + d(i, j) ; S est un masque de bits.',
            '2ⁿ sous-ensembles x n arrivees x n predecesseurs : O(n² 2ⁿ).',
          ], color: C.amber),
        ),
      ],
    );
  }
}

class _TspPainter extends CustomPainter {
  final List<Offset> pts;
  final List<int> tour;
  final List<List<int>> d;
  final double progress;
  final Color color;
  _TspPainter(this.pts, this.tour, this.d, this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.isEmpty) {
      drawText(canvas, 'Cliquez pour ajouter des villes', size.center(Offset.zero), const TextStyle(color: C.muted, fontSize: 14),
          anchor: Alignment.center);
      return;
    }
    if (pts.length <= 9) {
      final faint = Paint()
        ..color = fade(C.line, 0.6)
        ..strokeWidth = 1;
      for (var i = 0; i < pts.length; i++) {
        for (var j = i + 1; j < pts.length; j++) {
          canvas.drawLine(pts[i], pts[j], faint);
        }
      }
    }
    if (tour.length == pts.length && tour.isNotEmpty) {
      final total = tour.length.toDouble();
      for (var k = 0; k < tour.length; k++) {
        final f = (progress * total - k).clamp(0.0, 1.0);
        if (f <= 0) break;
        final a = pts[tour[k]], b = pts[tour[(k + 1) % tour.length]];
        final end = Offset.lerp(a, b, f)!;
        canvas.drawLine(a, end, Paint()..color = fade(color, 0.2)..strokeWidth = 10..strokeCap = StrokeCap.round);
        canvas.drawLine(a, end, Paint()..color = color..strokeWidth = 3.5..strokeCap = StrokeCap.round);
        if (f >= 1 && tour.length <= 12) {
          drawText(canvas, '${d[tour[k]][tour[(k + 1) % tour.length]]}', Offset.lerp(a, b, 0.5)! + const Offset(0, -9),
              kMono.copyWith(color: C.text, fontSize: 11), anchor: Alignment.center);
        }
      }
    }
    for (var i = 0; i < pts.length; i++) {
      canvas.drawCircle(pts[i], 15, Paint()..color = i == 0 ? C.amber : C.card2);
      canvas.drawCircle(pts[i], 15, Paint()..color = i == 0 ? C.amber : C.muted..style = PaintingStyle.stroke..strokeWidth = 1.5);
      drawText(canvas, '$i', pts[i], TextStyle(color: i == 0 ? C.bg : C.text, fontSize: 12, fontWeight: FontWeight.w800),
          anchor: Alignment.center);
    }
  }

  @override
  bool shouldRepaint(covariant _TspPainter old) => true;
}
