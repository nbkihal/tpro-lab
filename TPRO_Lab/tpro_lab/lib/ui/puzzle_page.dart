import 'dart:math';

import 'package:flutter/material.dart' hide Step;
import 'package:flutter/services.dart';

import '../core/demo_content.dart';
import '../core/jobs.dart';
import '../core/puzzle.dart';
import '../core/trace.dart';
import 'charts.dart';
import 'explain_panel.dart';
import 'kit.dart';
import 'lab_scaffold.dart';

const int _kNodeLimit = 1500000;
const int _kTimeLimitMs = 20000;
const int _kCompareTimeMs = 10000;
const List<double> _kCompareP = [1, 1.5, 2, 3];

String _pt(double p) => fmtF(p).replaceAll('.', ',');
String _thousands(int v) {
  final s = '$v';
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

/// Resultat d'une recherche lancee dans un isolate.
class _SolveOut {
  /// Mesures : toujours issues de l'execution sans trace.
  final AStarResult res;
  final List<Step> steps;
  final int skipped;
  const _SolveOut(this.res, this.steps, this.skipped);
}

// Fonctions de haut niveau : les fermetures envoyees a l'isolate ne capturent que des valeurs simples.
Job<_SolveOut> _solveJob(int start, int hk, double w, bool heap, bool traced, int nodeLimit, int timeMs) => startJob<_SolveOut>((_) {
      final res = solvePuzzle(start, heuristicKind: hk, weight: w, useHeap: heap, nodeLimit: nodeLimit, timeLimitMs: timeMs);
      if (!traced) return _SolveOut(res, const [], 0);
      final t = Trace(cap: 20000);
      solvePuzzle(start, heuristicKind: hk, weight: w, useHeap: heap, nodeLimit: nodeLimit, timeLimitMs: timeMs, trace: t);
      return _SolveOut(res, t.steps, t.skipped);
    });

Job<List<AStarResult>> _compareJob(List<int> starts, int hk, double w, bool heap, int nodeLimit, int timeMs) => startJob<List<AStarResult>>(
    (_) => [for (final s in starts) solvePuzzle(s, heuristicKind: hk, weight: w, useHeap: heap, nodeLimit: nodeLimit, timeLimitMs: timeMs)]);

/// Une ligne du tableau de comparaison : une variante, mesuree sur une ou plusieurs configurations.
class _CmpRow {
  final bool heap;
  final int hk;
  final double p;
  final List<AStarResult> res;
  const _CmpRow(this.heap, this.hk, this.p, this.res);

  String get label => '${heap ? 'tas' : 'naïve'} · ${kHeuristicShort[hk]} · p=${_pt(p)}';
  Iterable<AStarResult> get ok => res.where((r) => r.status == 'ok');
  double _avg(Iterable<num> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
  double get micros => _avg(res.map((r) => r.micros));
  double get expanded => _avg(res.map((r) => r.expanded));
  double get generated => _avg(res.map((r) => r.generated));
  double get frontier => _avg(res.map((r) => r.maxFrontier));
  double get moves => _avg(ok.map((r) => r.moves));
}

/// TP 4 — Taquin 15 : A*, WA*, tas contre file naive, trois heuristiques.
class PuzzlePage extends StatefulWidget {
  const PuzzlePage({super.key});

  @override
  State<PuzzlePage> createState() => _PuzzlePageState();
}

class _PuzzlePageState extends State<PuzzlePage> {
  static const _accent = C.green;
  final LabHost host = LabHost();
  final Random _rnd = Random();

  /// Configuration de depart (celle que l'on resout). Un deplacement manuel la modifie.
  int state = kGoal;
  String _presetName = '';
  bool useHeap = true;
  int hk = 1;
  double p = 1;
  int scrambleK = 30;

  Job<_SolveOut>? _job;
  String _runLabel = '';
  AStarResult? result;
  String? _note;
  int _tab = 0;

  // Comparaison
  final Set<bool> _cmpQueues = {false, true};
  final Set<int> _cmpH = {0, 1, 2};
  final Set<double> _cmpP = {1, 2};
  bool _cmpBatch = false;
  int _cmpBatchN = 5;
  int _cmpView = 0;
  List<_CmpRow> _rows = [];
  int _cmpConfigs = 1;
  Job<List<AStarResult>>? _cmpJob;
  bool _cmpRunning = false;
  int _cmpDone = 0, _cmpTotal = 0;

  @override
  void initState() {
    super.initState();
    _applyPreset(0);
  }

  @override
  void dispose() {
    _job?.cancel();
    _cmpRunning = false;
    _cmpJob?.cancel();
    host.dispose();
    super.dispose();
  }

  bool get _busy => _job != null;

  // ------------------------------------------------------------ donnees

  void _applyPreset(int i) {
    final pr = kPuzzlePresets[i];
    state = fromTiles(pr.tiles);
    _presetName = '${pr.name} (optimal : ${pr.optimal})';
    _invalidate();
  }

  void _invalidate() {
    result = null;
    _note = null;
    host.player.clear();
  }

  void _setState(int s, String name) {
    if (_busy) return;
    setState(() {
      state = s;
      _presetName = name;
      _invalidate();
    });
  }

  /// Deplace le jeton de la case [pos] s'il touche la case vide.
  void _moveAt(int pos) {
    if (_busy) return;
    final blank = blankOf(state);
    if (!kNeighbors[blank].contains(pos)) return;
    setState(() {
      state = swapBlank(state, blank, pos);
      _presetName = '';
      _invalidate();
    });
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyUpEvent || host.player.hasTrace || _busy) return false;
    final blank = blankOf(state);
    final r = blank ~/ kSide, c = blank % kSide;
    final k = e.logicalKey;
    // La fleche indique le sens de deplacement du jeton vers la case vide.
    int? pos;
    if (k == LogicalKeyboardKey.arrowLeft && c < kSide - 1) pos = blank + 1;
    if (k == LogicalKeyboardKey.arrowRight && c > 0) pos = blank - 1;
    if (k == LogicalKeyboardKey.arrowUp && r < kSide - 1) pos = blank + kSide;
    if (k == LogicalKeyboardKey.arrowDown && r > 0) pos = blank - kSide;
    if (pos == null) {
      return k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown;
    }
    _moveAt(pos);
    return true;
  }

  // ------------------------------------------------------------ recherche

  Future<void> _solve({required bool traced, bool autoplay = true, double? speed}) async {
    if (_busy) return;
    final start = state, hk0 = hk, p0 = p, heap0 = useHeap;
    final job = _solveJob(start, hk0, p0, heap0, traced, _kNodeLimit, _kTimeLimitMs);
    setState(() {
      _invalidate();
      _job = job;
      _runLabel = traced ? 'pas à pas' : 'rapide';
    });
    _SolveOut? out;
    String? error;
    try {
      out = await job.result;
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    setState(() => _job = null);
    if (error != null) {
      setState(() => _note = 'Erreur pendant la recherche : $error');
      return;
    }
    if (out == null) {
      setState(() => _note = 'Recherche arrêtée par l\'utilisateur.');
      return;
    }
    final res = out.res;
    var steps = out.steps;
    if (!traced && res.status == 'ok') {
      final t = Trace();
      appendSolutionSteps(t, res.path, hk0, p0, open: res.maxFrontier, closed: res.expanded, generated: res.generated);
      steps = t.steps;
    }
    setState(() {
      result = res;
      _note = switch (res.status) {
        'ok' => out!.skipped > 0 ? 'Trace plafonnée : ${_thousands(out.skipped)} étapes du milieu ont été sautées (début, fin et solution conservés).' : null,
        'limite' => 'Limite de ${_thousands(_kNodeLimit)} nœuds atteinte sans trouver le but : la mémoire est la limite d\'A* sur le taquin 15. '
            'Essayez une heuristique plus forte (h2, h3) ou p > 1.',
        'delai' => 'Délai de ${_kTimeLimitMs ~/ 1000} s dépassé sans trouver le but. Essayez le tas, une heuristique plus forte ou p > 1.',
        _ => 'Échec : la frontière s\'est vidée sans atteindre le but.',
      };
    });
    host.tick(heap0 ? 'heap' : 'naive');
    if (hk0 == 1) host.tick('h2');
    if (p0 > 1) host.tick('wastar');
    if (speed != null) host.player.setSpeed(speed);
    if (steps.isNotEmpty) host.player.load(steps, autoplay: autoplay);
  }

  void _stop() => _job?.cancel();

  void _scenario(int i) {
    if (_busy) _stop();
    _stopCompare();
    host.bottomOpen.value = true;
    void setup(int preset, int h, bool heap, double w) {
      _tab = 0;
      _applyPreset(preset);
      hk = h;
      useHeap = heap;
      p = w;
    }

    // La recherche precedente (si elle vient d'etre arretee) libere _job au prochain tour.
    Future<void>.delayed(Duration.zero, () {
      if (!mounted) return;
      switch (i) {
        case 0:
          setState(() => setup(0, 1, true, 1));
          _solve(traced: true, autoplay: false, speed: 1);
        case 1:
          setState(() => setup(1, 0, true, 1));
          _solve(traced: false);
        case 2:
          setState(() => setup(2, 1, false, 1));
          _solve(traced: false);
        case 3:
          setState(() => setup(1, 1, true, 2));
          _solve(traced: false);
        default:
          setState(() {
            if (state == kGoal) _applyPreset(1);
            _tab = 1;
            _cmpView = 0;
            _cmpBatch = false;
            _cmpQueues
              ..clear()
              ..addAll([false, true]);
            _cmpH
              ..clear()
              ..addAll([0, 1, 2]);
            _cmpP
              ..clear()
              ..addAll([1, 2]);
          });
          _compare();
      }
    });
  }

  void _requirement(String req) {
    host.bottomOpen.value = true;
    setState(() => _tab = req == 'compare' ? 1 : 0);
    host.spotlight(req);
  }

  // ------------------------------------------------------------ comparaison

  void _stopCompare() {
    _cmpRunning = false;
    _cmpJob?.cancel();
  }

  Future<void> _compare() async {
    if (_cmpRunning) return;
    final variants = <List<Object>>[
      for (final q in [false, true])
        if (_cmpQueues.contains(q))
          for (final h in [0, 1, 2])
            if (_cmpH.contains(h))
              for (final w in _kCompareP)
                if (_cmpP.contains(w)) [q, h, w]
    ];
    if (variants.isEmpty) {
      toast(context, 'Cochez au moins une file, une heuristique et une valeur de p.');
      return;
    }
    final starts = _cmpBatch ? [for (var i = 0; i < _cmpBatchN; i++) scramble(scrambleK, _rnd)] : [state];
    setState(() {
      _rows = [];
      _cmpConfigs = starts.length;
      _cmpRunning = true;
      _cmpDone = 0;
      _cmpTotal = variants.length;
    });
    for (final v in variants) {
      if (!_cmpRunning || !mounted) break;
      final job = _cmpJob = _compareJob(starts, v[1] as int, v[2] as double, v[0] as bool, _kNodeLimit, _kCompareTimeMs);
      List<AStarResult>? res;
      try {
        res = await job.result;
      } catch (_) {
        res = null;
      }
      if (!mounted) return;
      if (res == null) break;
      setState(() {
        _rows = [..._rows, _CmpRow(v[0] as bool, v[1] as int, v[2] as double, res!)];
        _cmpDone++;
      });
    }
    if (!mounted) return;
    final finished = _cmpRunning && _cmpDone == _cmpTotal;
    setState(() {
      _cmpRunning = false;
      _cmpJob = null;
    });
    if (finished) host.tick('compare');
  }

  /// Longueur optimale de chaque configuration : la plus courte trouvee par A* (p = 1, h admissible).
  List<int?> _refs() => [
        for (var i = 0; i < _cmpConfigs; i++)
          () {
            int? best;
            for (final r in _rows) {
              if (r.p == 1 && i < r.res.length && r.res[i].status == 'ok' && (best == null || r.res[i].moves < best)) best = r.res[i].moves;
            }
            return best;
          }()
      ];

  String _statusShort(String s) => switch (s) { 'ok' => 'ok', 'limite' => 'limite nœuds', 'delai' => 'délai', _ => 'échec' };

  List<String> _rowCells(_CmpRow r, List<int?> refs) {
    final single = r.res.length == 1;
    final nOk = r.ok.length;
    String optimal;
    if (single) {
      final x = r.res.first;
      optimal = x.status != 'ok' ? '—' : (refs[0] == null ? '?' : (x.moves == refs[0] ? 'oui' : 'non (+${x.moves - refs[0]!})'));
    } else {
      var c = 0;
      for (var i = 0; i < r.res.length; i++) {
        if (r.res[i].status == 'ok' && refs[i] != null && r.res[i].moves == refs[i]) c++;
      }
      optimal = '$c/${r.res.length}';
    }
    return [
      r.label,
      (r.micros / 1000).toStringAsFixed(r.micros < 10000 ? 2 : 0),
      r.expanded.round().toString(),
      r.generated.round().toString(),
      r.frontier.round().toString(),
      single ? (nOk == 1 ? '${r.res.first.moves}' : _statusShort(r.res.first.status)) : (nOk == 0 ? 'aucune' : '${r.moves.toStringAsFixed(1)} ($nOk/${r.res.length})'),
      optimal,
    ];
  }

  static const _cmpHeaders = ['variante', 'temps (ms)', 'explorés', 'générés', 'frontière max', 'longueur', 'optimal ?'];

  void _exportCsv() {
    final refs = _refs();
    final lines = [
      csvLine(_cmpHeaders),
      for (final r in _rows) csvLine(_rowCells(r, refs)),
    ];
    try {
      toast(context, 'Tableau enregistré : ${saveTextFile('taquin_comparaison.csv', lines.join('\n'))}');
    } catch (e) {
      toast(context, 'Enregistrement impossible : $e', error: true);
    }
  }

  // ------------------------------------------------------------ interface

  PuzzleView? get _view {
    final v = host.player.current?.view;
    return v is PuzzleView ? v : null;
  }

  @override
  Widget build(BuildContext context) {
    return LabScaffold(
      labIndex: 4,
      content: kPuzzleLab,
      host: host,
      pseudo: kAStarPseudo,
      pseudoTitle: p > 1 ? 'WA* (p = ${_pt(p)})' : 'A*',
      onScenario: _scenario,
      onRequirement: _requirement,
      onKey: _onKey,
      counters: _counters,
      extra: _extra,
      bottomHeight: _tab == 1 ? 300 : 236,
      idleText: 'Choisissez une configuration, puis « Pas à pas » : chaque extraction et chaque voisin seront expliqués ici.',
      transportHint: 'Résolvez le puzzle pour rejouer la recherche et la solution',
      canvas: _canvas(),
      bottom: _bottom(),
    );
  }

  Map<String, String> _counters() {
    final v = _view;
    final r = result;
    return {
      'états développés': v != null ? _thousands(v.closed) : (r != null ? _thousands(r.expanded) : '—'),
      'états générés': v != null ? _thousands(v.generated) : (r != null ? _thousands(r.generated) : '—'),
      'frontière': v != null ? _thousands(v.open) : '—',
      if (r != null) 'frontière max': _thousands(r.maxFrontier),
      if (r != null) 'temps (sans trace)': '${(r.micros / 1000).toStringAsFixed(1)} ms',
      if (r != null && r.status == 'ok') 'longueur': '${r.moves}',
    };
  }

  Widget _canvas() {
    return AnimatedBuilder(
      animation: host.player,
      builder: (context, _) {
        final v = _view;
        final shown = v?.state ?? state;
        final h = v?.h ?? heuristic(hk, state);
        final g = v?.g ?? 0;
        final f = v?.f ?? p * h;
        return LayoutBuilder(builder: (context, box) {
          final side = max(120.0, min(box.maxWidth - 40, box.maxHeight - 76));
          return Stack(fit: StackFit.expand, children: [
            Center(child: _Board(state: shown, side: side, onTap: _moveAt)),
            Positioned(
              left: 12,
              top: 10,
              child: IgnorePointer(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('État codé sur un entier 64 bits (4 bits par case)${_presetName.isEmpty ? '' : ' · $_presetName'}',
                      style: kMono.copyWith(color: C.muted, fontSize: 11.5)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: fade(C.bg, 0.8), borderRadius: BorderRadius.circular(10), border: Border.all(color: C.line)),
                    child: Text('g = $g   h = $h   f = g + ${p > 1 ? '${_pt(p)}·' : ''}h = ${_pt(f)}',
                        style: kMono.copyWith(color: _accent, fontSize: 13.5, fontWeight: FontWeight.w800)),
                  ),
                ]),
              ),
            ),
            Positioned(right: 12, top: 8, child: _statusBadge()),
            Positioned(
              left: 12,
              bottom: 8,
              child: IgnorePointer(
                child: Text('clic sur un jeton voisin de la case vide, ou flèches du clavier (hors relecture) · vert : bien placé · ambre : mal placé',
                    style: TextStyle(color: fade(C.muted, 0.75), fontSize: 11)),
              ),
            ),
          ]);
        });
      },
    );
  }

  Widget _statusBadge() {
    String? text;
    var color = _accent;
    final r = result;
    if (_busy) {
      text = 'Recherche $_runLabel en cours…';
      color = C.amber;
    } else if (r != null) {
      switch (r.status) {
        case 'ok':
          text = 'Solution : ${r.moves} déplacements${p == 1 ? ' (optimale)' : ' (≤ ${_pt(p)} × optimum)'}';
        case 'limite':
          text = 'Limite de ${_thousands(_kNodeLimit)} nœuds atteinte';
          color = C.red;
        case 'delai':
          text = 'Délai de ${_kTimeLimitMs ~/ 1000} s dépassé';
          color = C.red;
        default:
          text = 'Échec';
          color = C.red;
      }
    } else if (state == kGoal) {
      text = 'Configuration but';
    }
    if (text == null) return const SizedBox.shrink();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: fade(color, 0.14), borderRadius: BorderRadius.circular(10), border: Border.all(color: fade(color, 0.7))),
      child: Text(text, style: kMono.copyWith(color: color, fontSize: 13.5, fontWeight: FontWeight.w800)),
    );
  }

  Widget _bottom() => BottomTabs(
        tabs: const ['Puzzle et recherche', 'Comparaison'],
        index: _tab,
        accent: _accent,
        onChanged: (i) => setState(() => _tab = i),
        trailing: _tab == 0
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                if (_busy) ...[
                  ChipBtn(label: 'Stop', icon: Icons.stop_rounded, color: C.red, active: true, onTap: _stop),
                  const SizedBox(width: 8),
                ],
                ChipBtn(
                    label: 'Rapide',
                    icon: Icons.bolt_rounded,
                    color: _accent,
                    tip: 'Résoudre (rapide) : recherche sans trace, puis relecture de la solution',
                    onTap: _busy ? null : () => _solve(traced: false)),
                const SizedBox(width: 8),
                ChipBtn(
                    label: 'Pas à pas',
                    icon: Icons.play_arrow_rounded,
                    color: _accent,
                    active: true,
                    tip: 'Résoudre pas à pas : recherche tracée, chaque extraction et chaque voisin sont expliqués',
                    onTap: _busy ? null : () => _solve(traced: true)),
              ])
            : null,
        children: [_searchTab(), _compareTab()],
      );

  Widget _caption(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(color: C.muted, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
      );

  Widget _searchTab() => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 10,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _caption('CONFIGURATION'),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (var i = 0; i < kPuzzlePresets.length; i++)
                  ChipBtn(
                      label: '${kPuzzlePresets[i].name} (≈${kPuzzlePresets[i].optimal})',
                      color: _accent,
                      active: _presetName.startsWith(kPuzzlePresets[i].name),
                      onTap: _busy ? null : () => setState(() => _applyPreset(i))),
                ChipBtn(label: 'But', icon: Icons.flag_outlined, color: _accent, onTap: _busy ? null : () => _setState(kGoal, '')),
                ChipBtn(label: 'Saisir…', tip: 'Saisir une configuration (16 nombres)', icon: Icons.edit_note_rounded, color: _accent, onTap: _busy ? null : _configDialog),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                ChipBtn(
                    label: 'Mélanger ($scrambleK coups)',
                    icon: Icons.shuffle_rounded,
                    color: _accent,
                    tip: 'Mélange par déplacements légaux depuis le but : toujours résoluble',
                    onTap: _busy ? null : () => _setState(scramble(scrambleK, _rnd), 'mélange de $scrambleK coups')),
                SizedBox(width: 150, child: NumStepper(label: 'k', value: scrambleK, min: 5, max: 80, step: 5, onChanged: (v) => setState(() => scrambleK = v))),
              ]),
            ]),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 11,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _caption('FILE DE PRIORITÉ'),
              SpotTarget(
                host: host,
                ids: const ['naive', 'heap'],
                color: _accent,
                radius: 10,
                child: SegBar(
                    options: const ['File naïve · O(n)', 'Tas · O(log n)'],
                    index: useHeap ? 1 : 0,
                    color: _accent,
                    enabled: !_busy,
                    onChanged: (i) => setState(() {
                          useHeap = i == 1;
                          _invalidate();
                        })),
              ),
              const SizedBox(height: 8),
              _caption('HEURISTIQUE (TOUTES ADMISSIBLES, h1 ≤ h2 ≤ h3)'),
              SpotTarget(
                host: host,
                ids: const ['h1', 'h2'],
                color: _accent,
                radius: 10,
                child: SegBar(
                    options: const ['h1 mal placés', 'h2 Manhattan', 'h3 + conflits'],
                    index: hk,
                    color: _accent,
                    enabled: !_busy,
                    onChanged: (i) => setState(() {
                          hk = i;
                          _invalidate();
                        })),
              ),
              const SizedBox(height: 8),
              SpotTarget(
                host: host,
                ids: const ['wastar'],
                color: _accent,
                radius: 10,
                child: Row(children: [
                  SizedBox(
                    width: 96,
                    child: Text('p = ${_pt(p)} → ${p > 1 ? 'WA*' : 'A*'}', style: kMono.copyWith(color: p > 1 ? C.amber : _accent, fontSize: 12.5, fontWeight: FontWeight.w800)),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        activeTrackColor: _accent,
                        inactiveTrackColor: C.line,
                        thumbColor: _accent,
                        overlayColor: fade(_accent, 0.15),
                        tickMarkShape: SliderTickMarkShape.noTickMark,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      ),
                      child: Slider(
                          value: p,
                          min: 1,
                          max: 5,
                          divisions: 8,
                          onChanged: _busy
                              ? null
                              : (v) => setState(() {
                                    p = v;
                                    _invalidate();
                                  })),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(flex: 10, child: _resultBox()),
      ]);

  Widget _resultBox() {
    final r = result;
    Widget kv(String k, String v, {Color color = C.text}) => Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(children: [
            Expanded(child: Text(k, style: const TextStyle(color: C.muted, fontSize: 12))),
            Text(v, style: kMono.copyWith(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _caption('MESURES (EXÉCUTION SANS TRACE)'),
          if (_busy) ...[
            Text('Recherche $_runLabel en cours…', style: const TextStyle(color: C.amber, fontSize: 12.5)),
            const SizedBox(height: 8),
            ClipRRect(
                borderRadius: BorderRadius.circular(3), child: const LinearProgressIndicator(minHeight: 4, color: _accent, backgroundColor: C.line)),
            const SizedBox(height: 8),
          ] else if (r == null && _note == null)
            const Text('Lancez une recherche pour obtenir les mesures.', style: TextStyle(color: C.muted, fontSize: 12.5))
          else if (r != null) ...[
            kv('longueur de la solution', r.status == 'ok' ? '${r.moves}' : '—', color: _accent),
            kv('temps', '${(r.micros / 1000).toStringAsFixed(1)} ms'),
            kv('nœuds explorés', _thousands(r.expanded)),
            kv('nœuds générés', _thousands(r.generated)),
            kv('frontière max', _thousands(r.maxFrontier)),
            kv('qualité', r.status != 'ok' ? '—' : (p == 1 ? 'optimale' : '≤ ${_pt(p)} × optimum'), color: p == 1 ? _accent : C.amber),
          ],
          if (_note != null && !_busy)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_note!, style: TextStyle(color: r != null && r.status == 'ok' ? C.muted : C.red, fontSize: 12, height: 1.35)),
            ),
          const SizedBox(height: 4),
          Text('Limites : ${_thousands(_kNodeLimit)} nœuds · ${_kTimeLimitMs ~/ 1000} s', style: TextStyle(color: fade(C.muted, 0.8), fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _check(String label, bool on, VoidCallback toggle) => ChipBtn(
      label: label, icon: on ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, color: _accent, active: on, onTap: _cmpRunning ? null : toggle);

  void _flip<T>(Set<T> set, T v) => setState(() => set.contains(v) ? set.remove(v) : set.add(v));

  Widget _compareTab() {
    final refs = _refs();
    return SpotTarget(
      host: host,
      ids: const ['compare'],
      color: _accent,
      radius: 12,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 218,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _caption('FILE'),
              Wrap(spacing: 5, runSpacing: 5, children: [
                _check('naïve', _cmpQueues.contains(false), () => _flip(_cmpQueues, false)),
                _check('tas', _cmpQueues.contains(true), () => _flip(_cmpQueues, true)),
              ]),
              const SizedBox(height: 7),
              _caption('HEURISTIQUE'),
              Wrap(spacing: 5, runSpacing: 5, children: [
                for (var h = 0; h < 3; h++) _check(kHeuristicShort[h], _cmpH.contains(h), () => _flip(_cmpH, h)),
              ]),
              const SizedBox(height: 7),
              _caption('PARAMÈTRE p'),
              Wrap(spacing: 5, runSpacing: 5, children: [
                for (final w in _kCompareP) _check(_pt(w), _cmpP.contains(w), () => _flip(_cmpP, w)),
              ]),
              const SizedBox(height: 7),
              Toggle(
                  label: 'sur $_cmpBatchN configurations aléatoires',
                  value: _cmpBatch,
                  color: _accent,
                  onChanged: _cmpRunning ? null : (v) => setState(() => _cmpBatch = v)),
              if (_cmpBatch)
                NumStepper(label: 'N', value: _cmpBatchN, min: 2, max: 20, enabled: !_cmpRunning, onChanged: (v) => setState(() => _cmpBatchN = v)),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              SizedBox(
                width: 210,
                child: SegBar(options: const ['Tableau', 'Graphiques'], index: _cmpView, color: _accent, onChanged: (i) => setState(() => _cmpView = i)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    _cmpRunning
                        ? 'variante ${min(_cmpDone + 1, _cmpTotal)} / $_cmpTotal…'
                        : (_rows.isEmpty ? 'limite par recherche : ${_kCompareTimeMs ~/ 1000} s' : '${_rows.length} variantes · ${_cmpConfigs == 1 ? 'configuration courante' : '$_cmpConfigs configurations'}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _cmpRunning ? C.amber : C.muted, fontSize: 12)),
              ),
              ChipBtn(label: 'Exporter CSV', icon: Icons.save_alt_rounded, color: _accent, onTap: _rows.isEmpty || _cmpRunning ? null : _exportCsv),
              const SizedBox(width: 8),
              _cmpRunning
                  ? ChipBtn(label: 'Stop', icon: Icons.stop_rounded, color: C.red, active: true, onTap: _stopCompare)
                  : ChipBtn(label: 'Comparer', icon: Icons.play_arrow_rounded, color: _accent, active: true, onTap: _compare),
            ]),
            if (_cmpRunning)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(value: _cmpTotal == 0 ? 0 : _cmpDone / _cmpTotal, minHeight: 4, color: _accent, backgroundColor: C.line)),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _cmpView == 0
                  ? SimpleTable(headers: _cmpHeaders, rows: [for (final r in _rows) _rowCells(r, refs)], flex: const [8, 5, 5, 5, 6, 6, 5], accent: _accent)
                  : Row(children: [
                      Expanded(
                        child: LogBarChart(
                            title: 'Temps (µs, échelle log)',
                            labels: [for (final r in _rows) r.label],
                            values: [for (final r in _rows) max(1.0, r.micros)],
                            colors: [for (final r in _rows) r.heap ? _accent : C.amber]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LogBarChart(
                            title: 'Nœuds explorés (échelle log)',
                            labels: [for (final r in _rows) r.label],
                            values: [for (final r in _rows) max(1.0, r.expanded)],
                            colors: [for (final r in _rows) r.heap ? _accent : C.amber]),
                      ),
                    ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _configDialog() async {
    final ctl = TextEditingController(text: toTiles(state).join(' '));
    String? error;
    await showDarkDialog<void>(
      context,
      title: 'Saisir une configuration',
      width: 500,
      child: StatefulBuilder(
        builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('16 entiers de 0 à 15, ligne par ligne (0 = case vide), séparés par des espaces ou des virgules.',
              style: TextStyle(color: C.muted, fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 10),
          DarkField(controller: ctl, maxLines: 4, mono: true, hint: '1 2 3 4\n5 6 7 8\n9 10 11 12\n13 14 15 0'),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: C.red, fontSize: 12.5, height: 1.4))),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            ChipBtn(label: 'Fermer', onTap: () => Navigator.pop(ctx)),
            const SizedBox(width: 8),
            ChipBtn(
                label: 'Charger',
                icon: Icons.check_rounded,
                color: _accent,
                active: true,
                onTap: () {
                  final tiles = parseTiles(ctl.text);
                  if (tiles == null) {
                    setS(() => error = 'Saisie invalide : il faut exactement 16 entiers, chacun des nombres 0 à 15 une seule fois.');
                    return;
                  }
                  if (!isSolvable(tiles)) {
                    var inv = 0;
                    for (var i = 0; i < kCells; i++) {
                      for (var j = i + 1; j < kCells; j++) {
                        if (tiles[i] != 0 && tiles[j] != 0 && tiles[i] > tiles[j]) inv++;
                      }
                    }
                    final row = kSide - tiles.indexOf(0) ~/ kSide;
                    setS(() => error = 'Configuration insoluble. Chaque déplacement conserve la parité de '
                        '(nombre d\'inversions + ligne de la case vide comptée depuis le bas) ; pour le but cette somme est impaire. '
                        'Ici : $inv inversions + ligne $row = ${inv + row}, somme paire. '
                        'La moitié des 16! configurations est ainsi inatteignable.');
                    return;
                  }
                  Navigator.pop(ctx);
                  _setState(fromTiles(tiles), 'configuration saisie');
                }),
          ]),
        ]),
      ),
    );
    ctl.dispose();
  }

  // ------------------------------------------------------------ zone propre au TP (panneau)

  Widget _extra(BuildContext context, Step? step) {
    final v = step?.view;
    if (v is! PuzzleView) {
      return const PanelSection(
        title: 'f = g + p·h',
        accent: _accent,
        child: InfoBox([
          'g : nombre de déplacements déjà joués ; h : estimation du reste (jamais surestimée si h est admissible).',
          'p = 1 : A*, solution optimale. p > 1 : WA*, moins de nœuds, solution au plus p fois plus longue.',
          'Le tas et la file naïve extraient les mêmes nœuds : seul le coût de chaque extraction change.',
        ], color: _accent),
      );
    }
    if (v.solutionIndex >= 0) {
      return PanelSection(
        title: 'Relecture de la solution',
        accent: _accent,
        child: Row(children: [
          _MiniBoard(state: v.state, size: 84, color: _accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Déplacement ${v.solutionIndex} : g = ${v.g}, h = ${v.h}, f = ${_pt(v.f)}.\nh diminue jusqu\'à 0 quand le but est atteint.',
                style: const TextStyle(color: C.text, fontSize: 12.5, height: 1.45)),
          ),
        ]),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      PanelSection(
        title: 'Nœud extrait et voisins',
        accent: _accent,
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          _nodeCard(v.state, 'extrait', _accent, v.g, v.h, v.f),
          for (final nb in v.neighbors)
            _nodeCard(nb.state, nb.verdict, nb.verdict == 'ignoré' ? C.muted : (nb.verdict == 'amélioré' ? C.amber : C.cyan), nb.g, nb.h, nb.f),
        ]),
      ),
      const SizedBox(height: 14),
      PanelSection(
        title: useHeap ? 'File de priorité : tas binaire' : 'File de priorité : file naïve',
        accent: _accent,
        child: _queueView(v),
      ),
    ]);
  }

  Widget _nodeCard(int s, String label, Color color, int g, int h, double f) => Container(
        width: 72,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(9), border: Border.all(color: fade(color, 0.6))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _MiniBoard(state: s, size: 60, color: color),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
          Text('g$g h$h', style: kMono.copyWith(color: C.muted, fontSize: 10)),
          Text('f=${_pt(f)}', style: kMono.copyWith(color: C.text, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _queueView(PuzzleView v) {
    final head = v.queueHead;
    final path = v.queuePath;
    final op = v.queueOp;
    final String caption;
    if (useHeap) {
      caption = switch (op) {
        'insertion' => 'Insertion : ajout en fin de tableau puis remontée (sift-up) le long du chemin surligné — O(log n), ${path.length - 1} échange(s).',
        'retrait' => 'Retrait : la racine sort, le dernier élément la remplace puis redescend (sift-down) le long du chemin surligné — O(log n), ${path.length - 1} échange(s).',
        _ => 'Tableau du tas : fils de i en 2i+1 et 2i+2, père en (i−1)/2. La racine est toujours le minimum.',
      };
    } else {
      caption = switch (op) {
        'insertion' => 'Insertion : ajout en fin de file — O(1).',
        'retrait' => 'Retrait : toute la file a été balayée pour trouver le minimum — O(n), ici ${v.open + 1} comparaisons. La case surlignée est celle du minimum retiré.',
        _ => 'File non triée : insertion O(1), retrait du minimum O(n).',
      };
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(caption, style: const TextStyle(color: C.text, fontSize: 12.3, height: 1.4)),
      const SizedBox(height: 8),
      if (head.isEmpty)
        Text('file vide', style: kMono.copyWith(color: C.muted, fontSize: 12))
      else ...[
        if (useHeap) SizedBox(height: 150, width: double.infinity, child: CustomPaint(painter: _HeapPainter(head, path, _accent))),
        if (useHeap) const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (var i = 0; i < head.length; i++)
              Container(
                margin: const EdgeInsets.only(right: 3),
                constraints: const BoxConstraints(minWidth: 26),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: path.contains(i) ? fade(_accent, 0.2) : C.card2,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: path.contains(i) ? fade(_accent, 0.85) : Colors.transparent),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$i', style: kMono.copyWith(color: fade(C.muted, 0.7), fontSize: 9)),
                  Text(_pt(head[i]), style: kMono.copyWith(color: path.contains(i) ? _accent : C.text, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            if (v.open > head.length)
              Padding(padding: const EdgeInsets.only(left: 4), child: Text('… ${_thousands(v.open)} éléments', style: kMono.copyWith(color: C.muted, fontSize: 11))),
          ]),
        ),
      ],
    ]);
  }
}

// ---------------------------------------------------------------------- plateau

/// Plateau 4 x 4 : chaque jeton glisse vers sa nouvelle case.
class _Board extends StatelessWidget {
  final int state;
  final double side;
  final void Function(int pos)? onTap;
  const _Board({required this.state, required this.side, this.onTap});

  @override
  Widget build(BuildContext context) {
    final gap = side * 0.018;
    final cell = (side - gap * (kSide + 1)) / kSide;
    final tiles = toTiles(state);
    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(side * 0.045), border: Border.all(color: C.line)),
      child: Stack(children: [
        for (var pos = 0; pos < kCells; pos++)
          if (tiles[pos] != 0)
            AnimatedPositioned(
              key: ValueKey('tile-${tiles[pos]}'),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              left: gap + (pos % kSide) * (cell + gap),
              top: gap + (pos ~/ kSide) * (cell + gap),
              width: cell,
              height: cell,
              child: _Tile(value: tiles[pos], placed: tiles[pos] == pos + 1, size: cell, onTap: onTap == null ? null : () => onTap!(pos)),
            ),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  final int value;
  final bool placed;
  final double size;
  final VoidCallback? onTap;
  const _Tile({required this.value, required this.placed, required this.size, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = placed ? C.green : C.amber;
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(C.card2, color, 0.26)!, Color.lerp(C.card2, color, 0.10)!]),
            borderRadius: BorderRadius.circular(size * 0.16),
            border: Border.all(color: fade(color, placed ? 0.75 : 0.55), width: max(1.2, size * 0.022)),
            boxShadow: [BoxShadow(color: fade(color, 0.12), blurRadius: size * 0.16)],
          ),
          child: Text('$value',
              textScaler: TextScaler.noScaling, style: kMono.copyWith(color: placed ? C.green : C.text, fontSize: size * 0.4, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

/// Petit plateau statique (panneau d'explication).
class _MiniBoard extends StatelessWidget {
  final int state;
  final double size;
  final Color color;
  const _MiniBoard({required this.state, required this.size, required this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _MiniPainter(state, color));
}

class _MiniPainter extends CustomPainter {
  final int state;
  final Color color;
  _MiniPainter(this.state, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / kSide;
    for (var i = 0; i < kCells; i++) {
      final t = tileAt(state, i);
      final r = Rect.fromLTWH((i % kSide) * cell + 0.8, (i ~/ kSide) * cell + 0.8, cell - 1.6, cell - 1.6);
      final rr = RRect.fromRectAndRadius(r, Radius.circular(cell * 0.18));
      if (t == 0) {
        canvas.drawRRect(rr, Paint()..color = C.bg);
        continue;
      }
      canvas.drawRRect(rr, Paint()..color = t == i + 1 ? fade(C.green, 0.22) : fade(C.amber, 0.14));
      drawText(canvas, '$t', r.center, kMono.copyWith(color: t == i + 1 ? C.green : C.text, fontSize: cell * 0.5, fontWeight: FontWeight.w700),
          anchor: Alignment.center);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniPainter old) => old.state != state || old.color != color;
}

/// Les 15 premieres cases du tas dessinees en arbre binaire ; le chemin de la derniere
/// operation (remontee ou descente) est surligne.
class _HeapPainter extends CustomPainter {
  final List<double> head;
  final List<int> path;
  final Color accent;
  _HeapPainter(this.head, this.path, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    const levels = 4;
    final rowH = size.height / levels;
    final r = min(13.0, rowH * 0.36);
    Offset at(int i) {
      var l = 0;
      while ((1 << (l + 1)) - 1 <= i) {
        l++;
      }
      final k = i - ((1 << l) - 1);
      return Offset((k + 0.5) / (1 << l) * size.width, l * rowH + rowH / 2);
    }

    final n = min(head.length, 15);
    for (var i = 1; i < n; i++) {
      final pr = (i - 1) >> 1;
      final hot = path.contains(i) && path.contains(pr);
      canvas.drawLine(
          at(pr),
          at(i),
          Paint()
            ..color = hot ? accent : C.line
            ..strokeWidth = hot ? 2.6 : 1.3);
    }
    for (var i = 0; i < n; i++) {
      final c = at(i);
      final hot = path.contains(i);
      canvas.drawCircle(c, r, Paint()..color = hot ? Color.lerp(C.card2, accent, 0.35)! : C.card2);
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..color = hot ? accent : C.line
            ..style = PaintingStyle.stroke
            ..strokeWidth = hot ? 2 : 1.2);
      drawText(canvas, _pt(head[i]), c, kMono.copyWith(color: hot ? C.text : fade(C.text, 0.85), fontSize: r * 0.82, fontWeight: FontWeight.w700),
          anchor: Alignment.center);
    }
  }

  @override
  bool shouldRepaint(covariant _HeapPainter old) => old.head != head || old.path != path;
}
