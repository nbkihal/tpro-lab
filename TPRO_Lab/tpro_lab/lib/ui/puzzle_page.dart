import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/puzzle.dart';
import 'charts.dart';
import 'kit.dart';

class _Cfg {
  final String name;
  final int heuristic;
  final double weight;
  final bool heap;
  const _Cfg(this.name, this.heuristic, this.weight, this.heap);
}

const _configs = [
  _Cfg('A* h1 tas', 0, 1, true),
  _Cfg('A* h2 tas', 1, 1, true),
  _Cfg('A* h3 tas', 2, 1, true),
  _Cfg('A* h2 naive', 1, 1, false),
  _Cfg('WA* 1.5 h2', 1, 1.5, true),
  _Cfg('WA* 2 h2', 1, 2, true),
  _Cfg('WA* 3 h2', 1, 3, true),
  _Cfg('WA* 5 h2', 1, 5, true),
];

class PuzzlePage extends StatefulWidget {
  const PuzzlePage({super.key});

  @override
  State<PuzzlePage> createState() => _PuzzlePageState();
}

class _PuzzlePageState extends State<PuzzlePage> {
  final Random _rnd = Random();
  int _state = kGoal;
  int _scramble = 30, _weight10 = 10, _heur = 1, _queue = 0;
  bool _busy = false;
  AStarResult? _res;
  String _resName = '';
  Timer? _replay;
  int _step = 0;
  final List<(_Cfg, AStarResult)> _rows = [];

  @override
  void dispose() {
    _replay?.cancel();
    super.dispose();
  }

  void _stopReplay() {
    _replay?.cancel();
    _replay = null;
  }

  void _shuffle() => setState(() {
        _stopReplay();
        _res = null;
        _rows.clear();
        _state = scramble(_scramble, _rnd);
      });

  void _resetGoal() => setState(() {
        _stopReplay();
        _res = null;
        _rows.clear();
        _state = kGoal;
      });

  void _tap(int pos) {
    if (_busy || _replay != null) return;
    final blank = blankOf(_state);
    if (!kNeighbors[blank].contains(pos)) return;
    setState(() {
      _state = swapBlank(_state, blank, pos);
      _res = null;
      _rows.clear();
    });
  }

  Future<void> _solve() async {
    _stopReplay();
    final start = _state;
    final w = _weight10 / 10;
    setState(() => _busy = true);
    final r = await solvePuzzleInIsolate(start, heuristicKind: _heur, weight: w, useHeap: _queue == 0);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _res = r;
      _resName = '${w == 1 ? 'A*' : 'WA* p=$w'} - ${kHeuristicNames[_heur]} - ${_queue == 0 ? 'tas' : 'file naive'}';
    });
    if (r.status == 'ok') {
      _play();
    } else {
      toast(context, 'Recherche interrompue (${r.status}) : essayez WA* avec p plus grand ou une meilleure heuristique.');
    }
  }

  void _play() {
    final r = _res;
    if (r == null || r.path.isEmpty) return;
    _stopReplay();
    setState(() {
      _step = 0;
      _state = r.path.first;
    });
    _replay = Timer.periodic(const Duration(milliseconds: 190), (t) {
      setState(() {
        _step++;
        if (_step >= r.path.length) {
          t.cancel();
          _replay = null;
        } else {
          _state = r.path[_step];
        }
      });
    });
  }

  Future<void> _compare() async {
    _stopReplay();
    final start = _state;
    setState(() {
      _busy = true;
      _rows.clear();
    });
    for (final c in _configs) {
      final r = await solvePuzzleInIsolate(start, heuristicKind: c.heuristic, weight: c.weight, useHeap: c.heap);
      if (!mounted) return;
      setState(() => _rows.add((c, r)));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _export() async {
    if (_rows.isEmpty) return toast(context, 'Lancez d\'abord la comparaison.');
    final sb = StringBuffer('configuration;coups;noeuds_developpes;noeuds_generes;frontiere_max;temps_ms;statut\n');
    for (final (c, r) in _rows) {
      sb.writeln('${c.name};${r.moves};${r.expanded};${r.generated};${r.maxFrontier};${(r.micros / 1000).toStringAsFixed(2)};${r.status}');
    }
    final f = File('taquin_comparaison.csv');
    await f.writeAsString(sb.toString());
    if (mounted) toast(context, 'Exporte : ${f.absolute.path}');
  }

  @override
  Widget build(BuildContext context) {
    final r = _res;
    final tiles = toTiles(_state);
    return PageScaffold(
      tag: 'TP 4',
      title: 'Taquin 4 x 4',
      subtitle: 'A* et WA* : f(x) = g(x) + p · h(x)',
      accent: C.green,
      canvas: Panel(
        child: Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(builder: (context, box) {
              final cell = box.maxWidth / kSide;
              return Stack(children: [
                Container(decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(18))),
                for (var pos = 0; pos < kCells; pos++)
                  if (tiles[pos] != 0)
                    AnimatedPositioned(
                      key: ValueKey(tiles[pos]),
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      left: (pos % kSide) * cell,
                      top: (pos ~/ kSide) * cell,
                      width: cell,
                      height: cell,
                      child: Padding(
                        padding: EdgeInsets.all(cell * 0.045),
                        child: GestureDetector(
                          onTap: () => _tap(pos),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(cell * 0.16),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: tiles[pos] == pos + 1 ? [C.green, const Color(0xFF10B981)] : [C.card2, const Color(0xFF2D3348)],
                              ),
                              border: Border.all(color: tiles[pos] == pos + 1 ? Colors.transparent : C.line),
                            ),
                            child: Text('${tiles[pos]}',
                                style: TextStyle(
                                    color: tiles[pos] == pos + 1 ? C.bg : C.text, fontSize: cell * 0.36, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                    ),
              ]);
            }),
          ),
        ),
      ),
      bottomHeight: 250,
      bottom: Row(children: [
        Expanded(
          flex: 6,
          child: Panel(
            padding: const EdgeInsets.all(8),
            child: SimpleTable(
              accent: C.green,
              headers: const ['Configuration', 'coups', 'noeuds', 'frontiere max', 'temps (ms)', 'statut'],
              flex: const [4, 2, 3, 3, 3, 2],
              rows: [
                for (final (c, x) in _rows)
                  [
                    c.name,
                    x.moves < 0 ? '-' : '${x.moves}',
                    '${x.expanded}',
                    '${x.maxFrontier}',
                    (x.micros / 1000).toStringAsFixed(1),
                    x.status,
                  ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 4,
          child: Panel(
            padding: const EdgeInsets.all(12),
            child: LogBarChart(
              title: 'Noeuds developpes (echelle log)',
              labels: [for (final (c, _) in _rows) c.name],
              values: [for (final (_, x) in _rows) x.expanded.toDouble()],
              colors: [for (final (c, _) in _rows) c.weight > 1 ? C.amber : (c.heap ? C.green : C.red)],
            ),
          ),
        ),
      ]),
      side: [
        Panel(
          title: 'Configuration initiale',
          accent: C.green,
          child: Column(children: [
            NumStepper(
                label: 'Melange (deplacements)', value: _scramble, min: 5, max: 80, step: 5, onChanged: (v) => setState(() => _scramble = v)),
            Row(children: [
              Expanded(child: ActionBtn(label: 'Melanger', icon: Icons.shuffle_rounded, color: C.green, onPressed: _busy ? null : _shuffle)),
              const SizedBox(width: 8),
              Expanded(child: ActionBtn(label: 'But', icon: Icons.restart_alt_rounded, color: C.muted, onPressed: _busy ? null : _resetGoal)),
            ]),
            const SizedBox(height: 6),
            InfoBox([
              'Cliquez sur un jeton voisin de la case vide pour le deplacer.',
              'h1 = ${hMisplaced(_state)}   h2 = ${hManhattan(_state)}   h3 = ${hLinearConflict(_state)}',
            ], color: C.green),
          ]),
        ),
        Panel(
          title: 'Algorithme',
          accent: C.green,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            NumStepper(
              label: 'Poids p  (1 = A*, > 1 = WA*)',
              value: _weight10,
              min: 10,
              max: 60,
              step: 5,
              format: (v) => (v / 10).toStringAsFixed(1),
              onChanged: (v) => setState(() => _weight10 = v),
            ),
            const SizedBox(height: 6),
            const Text('Heuristique h', style: TextStyle(color: C.muted, fontSize: 11)),
            const SizedBox(height: 4),
            Seg(options: const ['Mal places', 'Manhattan', '+ conflits'], index: _heur, color: C.green, onChanged: (v) => setState(() => _heur = v)),
            const SizedBox(height: 8),
            const Text('File de priorite', style: TextStyle(color: C.muted, fontSize: 11)),
            const SizedBox(height: 4),
            Seg(options: const ['Tas O(log n)', 'Naive O(n)'], index: _queue, color: C.green, onChanged: (v) => setState(() => _queue = v)),
            const SizedBox(height: 8),
            ActionBtn(label: 'Resoudre', icon: Icons.play_arrow_rounded, color: C.green, filled: true, onPressed: _busy ? null : _solve),
            Row(children: [
              Expanded(
                  child: ActionBtn(
                      label: 'Rejouer', icon: Icons.replay_rounded, color: C.green, onPressed: _busy || r == null || r.path.isEmpty ? null : _play)),
              const SizedBox(width: 8),
              Expanded(child: ActionBtn(label: 'Comparer', icon: Icons.bar_chart_rounded, color: C.amber, onPressed: _busy ? null : _compare)),
            ]),
            ActionBtn(label: 'Exporter en CSV', icon: Icons.download_rounded, color: C.muted, onPressed: _busy ? null : _export),
            if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator(color: C.green, backgroundColor: C.card2)),
          ]),
        ),
        Panel(
          title: 'Resultat',
          accent: C.green,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StatRow([
              Stat(label: 'longueur (coups)', value: r == null || r.moves < 0 ? '-' : '${r.moves}', color: C.green),
              Stat(label: 'temps (ms)', value: r == null ? '-' : (r.micros / 1000).toStringAsFixed(1)),
            ]),
            const SizedBox(height: 8),
            StatRow([
              Stat(label: 'noeuds developpes', value: r == null ? '-' : '${r.expanded}'),
              Stat(label: 'frontiere max', value: r == null ? '-' : '${r.maxFrontier}'),
            ]),
            if (r != null) ...[
              const SizedBox(height: 8),
              Text(_resName, style: const TextStyle(color: C.muted, fontSize: 12)),
              if (_replay != null) Text('Lecture : coup $_step / ${r.moves}', style: kMono.copyWith(color: C.green, fontSize: 12)),
            ],
          ]),
        ),
        const Panel(
          title: 'Ce que montre la comparaison',
          accent: C.green,
          child: InfoBox([
            'h3 domine h2 qui domine h1 : moins de noeuds developpes, meme longueur optimale.',
            'Tas contre file naive : memes noeuds, mais retrait en O(log n) au lieu de O(n).',
            'WA* (p > 1) : beaucoup moins de noeuds, solution au plus p fois plus longue que l\'optimum.',
          ], color: C.green),
        ),
      ],
    );
  }
}
