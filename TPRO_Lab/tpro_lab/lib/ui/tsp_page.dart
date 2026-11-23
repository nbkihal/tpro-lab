import 'dart:math';

import 'package:flutter/material.dart' hide Step;
import 'package:flutter/services.dart';

import '../core/demo_content.dart';
import '../core/jobs.dart';
import '../core/trace.dart';
import '../core/tsp.dart';
import 'charts.dart';
import 'explain_panel.dart';
import 'kit.dart';
import 'lab_scaffold.dart';

const List<String> _methodNames = ['Énumération (DFS)', 'Énumération (BFS)', 'Held-Karp'];

/// Limites de l'interface (au-dela, un message explique pourquoi).
const int _enumTraceMax = 11, _hkTraceMax = 12, _enumMax = 12, _bfsMax = 11, _hkMax = 20;

typedef _RunOut = (List<TspResult?>, TspResult?, Trace?);

TspResult _solve(List<List<int>> d, int method, Trace? t) => switch (method) {
      0 => tspBruteForce(d, trace: t),
      1 => tspBruteForceBfs(d, trace: t),
      _ => tspHeldKarp(d, trace: t),
    };

/// Calcul dans un isolate annulable : executions sans trace (pour les temps affiches),
/// puis, si [traceMethod] >= 0, une execution tracee pour l'animation.
Job<_RunOut> _startRun(List<List<int>> d, List<int> methods, int traceMethod) {
  final copy = [for (final r in d) List<int>.from(r)];
  final ms = List<int>.from(methods);
  return startJob<_RunOut>((_) {
    final res = List<TspResult?>.filled(3, null);
    for (final m in ms) {
      res[m] = _solve(copy, m, null);
    }
    TspResult? tr;
    Trace? t;
    if (traceMethod >= 0) {
      t = Trace();
      tr = _solve(copy, traceMethod, t);
    }
    return (res, tr, t);
  });
}

Job<BenchRow> _startBench(int n, int instances, bool brute) => startJob<BenchRow>((_) => benchTspN(n, instances: instances, brute: brute));

String _fmtMicros(int? us) {
  if (us == null) return '—';
  if (us < 1000) return '$us µs';
  if (us < 1000000) return '${(us / 1000).toStringAsFixed(us < 10000 ? 2 : 1).replaceAll('.', ',')} ms';
  return '${(us / 1e6).toStringAsFixed(2).replaceAll('.', ',')} s';
}

String _fmtDuration(double seconds) {
  if (seconds < 1) return 'moins d\'une seconde';
  if (seconds < 90) return '${seconds.round()} s';
  if (seconds < 5400) return '${(seconds / 60).round()} min';
  if (seconds < 172800) return '${(seconds / 3600).round()} h';
  if (seconds < 86400 * 730) return '${(seconds / 86400).round()} jours';
  final years = seconds / (86400 * 365);
  return years < 1e6 ? '${years.round()} ans' : '${years.toStringAsExponential(1)} ans';
}

String _fmtBig(double v) => v < 1e15 ? v.round().toString() : v.toStringAsExponential(2);

String _tourText(List<int> t) => t.isEmpty ? '—' : '${t.join(' → ')} → 0';

/// TP 2 — Voyageur de commerce : enumeration exacte contre Bellman-Held-Karp.
class TspPage extends StatefulWidget {
  const TspPage({super.key});

  @override
  State<TspPage> createState() => _TspPageState();
}

class _TspPageState extends State<TspPage> with SingleTickerProviderStateMixin {
  static const _accent = C.amber;
  final LabHost host = LabHost();
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  final Random _rnd = Random();

  // Instance
  int n = 6;
  List<List<int>> d = [for (final r in kTspDefault6) List<int>.from(r)];
  List<Offset> pos = [];
  bool points = false; // true : distances euclidiennes des points ; false : matrice explicite
  bool asym = false;
  int method = 0;

  // Resultats
  final List<TspResult?> res = [null, null, null];
  TspResult? _traced; // execution tracee (porte les cases de la table de Held-Karp)
  int _tracedMethod = -1;
  bool busy = false;
  Job<_RunOut>? _job;
  int _gen = 0;

  // Banc d'essai
  final List<BenchRow> rows = [];
  bool benchRunning = false;
  int benchN = 0;
  Job<BenchRow>? _benchJob;

  int _tab = 0;
  int _drag = -1;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    host.player.onStep = _onStep;
    pos = _circle(n);
  }

  @override
  void dispose() {
    _job?.cancel();
    _benchJob?.cancel();
    _anim.dispose();
    host.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ instance

  List<Offset> _circle(int k) => [for (var i = 0; i < k; i++) Offset(0.5 + 0.4 * cos(-pi / 2 + 2 * pi * i / k), 0.5 + 0.4 * sin(-pi / 2 + 2 * pi * i / k))];

  List<List<int>> _euclid() => euclideanMatrix([
        for (final p in pos) [p.dx * 100, p.dy * 100]
      ]);

  void _invalidate() {
    _gen++;
    _job?.cancel();
    busy = false;
    res.fillRange(0, 3, null);
    _traced = null;
    _tracedMethod = -1;
    host.player.clear();
  }

  void _setInstance(List<List<int>> m, {List<Offset>? at, bool pointsMode = false, bool? asymmetric}) {
    n = m.length;
    d = [for (final r in m) List<int>.from(r)];
    pos = at ?? _circle(n);
    points = pointsMode;
    asym = asymmetric ?? _isAsym(d);
    _invalidate();
  }

  bool _isAsym(List<List<int>> m) {
    for (var i = 0; i < m.length; i++) {
      for (var j = 0; j < i; j++) {
        if (m[i][j] != m[j][i]) return true;
      }
    }
    return false;
  }

  void _setN(int k) => setState(() {
        if (points) {
          final p = List<Offset>.from(pos);
          while (p.length > k) {
            p.removeLast();
          }
          while (p.length < k) {
            p.add(Offset(0.08 + 0.84 * _rnd.nextDouble(), 0.08 + 0.84 * _rnd.nextDouble()));
          }
          pos = p;
          n = k;
          d = _euclid();
          _invalidate();
        } else {
          // On conserve les distances deja saisies ; les nouvelles villes recoivent des distances aleatoires.
          final m = List.generate(k, (i) => List<int>.filled(k, 0));
          for (var i = 0; i < k; i++) {
            for (var j = 0; j < k; j++) {
              if (i == j) continue;
              if (i < n && j < n) {
                m[i][j] = d[i][j];
              } else if (asym || i < j) {
                m[i][j] = 5 + _rnd.nextInt(40);
              }
            }
          }
          if (!asym) {
            for (var i = 0; i < k; i++) {
              for (var j = 0; j < i; j++) {
                if (i >= n || j >= n) m[i][j] = m[j][i];
              }
            }
          }
          _setInstance(m, asymmetric: asym);
        }
      });

  void _random() => setState(() {
        if (points) {
          pos = [for (var i = 0; i < n; i++) Offset(0.06 + 0.88 * _rnd.nextDouble(), 0.08 + 0.84 * _rnd.nextDouble())];
          d = _euclid();
          _invalidate();
        } else {
          _setInstance(randomMatrix(n, _rnd, maxDist: 60, symmetric: !asym), asymmetric: asym);
        }
      });

  void _setMode(bool pointsMode) => setState(() {
        if (pointsMode == points) return;
        points = pointsMode;
        if (points) {
          asym = false;
          d = _euclid();
        }
        _invalidate();
      });

  void _setAsym(bool v) => setState(() {
        asym = v;
        if (v) {
          points = false; // des points du plan donnent toujours des distances symetriques
        } else {
          for (var i = 0; i < n; i++) {
            for (var j = 0; j < i; j++) {
              d[i][j] = d[j][i];
            }
          }
        }
        _invalidate();
      });

  void _setMethod(int m) => setState(() {
        if (m == method) return;
        method = m;
        // La trace chargee appartient a l'autre pseudo-code : on la retire (les resultats restent).
        host.player.clear();
        _traced = null;
        _tracedMethod = -1;
      });

  Future<void> _editMatrix() async {
    final m = await showDarkDialog<List<List<int>>>(
      context,
      title: 'Matrice des distances d(i, j)',
      width: min(980.0, 150.0 + n * 52.0).clamp(420.0, 980.0),
      child: _MatrixEditor(d: d, symmetric: !asym),
    );
    if (m == null || !mounted) return;
    setState(() => _setInstance(m, at: points ? null : pos, asymmetric: asym));
    toast(context, 'Matrice $n × $n enregistrée (${asym ? 'asymétrique' : 'symétrique'}).');
  }

  // ------------------------------------------------------------ execution

  bool _traceable(int m) => m < 2 ? n <= _enumTraceMax : n <= _hkTraceMax;

  /// Verifie les limites ; explique en clair pourquoi une methode est refusee.
  bool _allowed(int m) {
    if (m == 2) {
      if (n > _hkMax) {
        toast(context, 'Held-Karp est limité à n = $_hkMax : la table demanderait ${(heldKarpBytes(n) / 1e6).round()} Mo.', error: true);
        return false;
      }
      return true;
    }
    final lim = m == 1 ? _bfsMax : _enumMax;
    if (n > lim) {
      toast(
          context,
          'Au-delà de n = $lim, l\'énumération${m == 1 ? ' BFS (file de (n−1)! chemins)' : ''} évaluerait (n−1)! = ${_fmtBig(factorial(n - 1))} cycles : '
          'environ ${_fmtDuration(estimateBruteSeconds(n))}. Utilisez Held-Karp.',
          error: true);
      return false;
    }
    return true;
  }

  Future<void> _run({List<int>? methods, bool autoplay = true, double? speed}) async {
    final ms = methods ?? [method];
    for (final m in ms) {
      if (!_allowed(m)) return;
    }
    final tm = ms.contains(method) && _traceable(method) ? method : -1;
    _job?.cancel();
    final gen = ++_gen;
    host.player.clear();
    setState(() => busy = true);
    final job = _job = _startRun(d, ms, tm);
    _RunOut? out;
    Object? error;
    try {
      out = await job.result;
    } catch (e) {
      error = e;
    }
    if (!mounted || gen != _gen) return;
    setState(() {
      busy = false;
      if (out != null) {
        for (final m in ms) {
          res[m] = out.$1[m];
        }
        _traced = out.$2;
        _tracedMethod = tm;
      }
    });
    if (error != null) {
      toast(context, 'Le calcul a échoué : $error', error: true);
      return;
    }
    if (out == null) return; // annule
    if (n == 6) host.tick('n6');
    for (final m in ms) {
      host.tick(m < 2 ? 'enum' : 'hk');
    }
    if (out.$3 != null) {
      if (speed != null) host.player.setSpeed(speed);
      host.player.load(out.$3!.steps, autoplay: autoplay);
      if (out.$3!.truncated) {
        toast(context, 'Trace longue : ${out.$3!.total} étapes, dont ${out.$3!.skipped} sautées au milieu. Le début, la fin et le résultat sont conservés.');
      }
    } else if (ms.contains(method)) {
      final lim = method < 2 ? _enumTraceMax : _hkTraceMax;
      var msg = 'Exécution pas à pas limitée à n ≤ $lim pour ${_methodNames[method]} : seul le résultat final est affiché.';
      if (method == 2 && n > 18) msg += ' Table de Held-Karp : ${(heldKarpBytes(n) / 1e6).round()} Mo.';
      toast(context, msg);
    }
  }

  void _runBoth() {
    final e = method < 2 ? method : 0;
    if (n > (e == 1 ? _bfsMax : _enumMax)) {
      toast(context,
          'n = $n : l\'énumération prendrait environ ${_fmtDuration(estimateBruteSeconds(n))} ((n−1)! = ${_fmtBig(factorial(n - 1))} cycles). Seul Held-Karp est lancé.');
      _run(methods: [2]);
      return;
    }
    _run(methods: [e, 2]);
  }

  void _stop() {
    _gen++;
    _job?.cancel();
    setState(() => busy = false);
    toast(context, 'Calcul arrêté.');
  }

  void _onStep(Step s) {
    if (s.view is HkView && s.line >= 5) host.tick('loops');
  }

  Future<void> _bench() async {
    if (benchRunning) return;
    setState(() {
      rows.clear();
      benchRunning = true;
    });
    var complete = true;
    for (var k = 4; k <= _hkMax; k++) {
      if (!mounted) return;
      setState(() => benchN = k);
      final job = _benchJob = _startBench(k, k <= 17 ? 3 : 1, k <= _enumMax);
      BenchRow? r;
      try {
        r = await job.result;
      } catch (_) {
        r = null;
      }
      if (!mounted) return;
      if (r == null) {
        complete = false;
        break;
      }
      setState(() => rows.add(r!));
    }
    if (!mounted) return;
    setState(() => benchRunning = false);
    if (complete) {
      host.tick('bench');
      toast(context, 'Banc d\'essai terminé : n = 4 à $_hkMax. Les deux méthodes donnent le même coût sur chaque ligne comparée.');
    }
  }

  void _stopBench() => _benchJob?.cancel();

  void _exportCsv() {
    final lines = [
      csvLine(['n', '(n-1)!', 'n^2 * 2^n', 'enumeration (us)', 'Held-Karp (us)', 'rapport', 'meme cout']),
      for (final r in rows)
        csvLine([
          r.n,
          _fmtBig(factorial(r.n - 1)),
          _fmtBig(r.n * r.n * pow(2.0, r.n).toDouble()),
          r.bruteMicros ?? '',
          r.hkMicros ?? '',
          r.bruteMicros != null && r.hkMicros != null ? (r.bruteMicros! / max(1, r.hkMicros!)).toStringAsFixed(2) : '',
          r.sameCost == null ? '' : (r.sameCost! ? 'oui' : 'NON'),
        ]),
    ];
    try {
      toast(context, 'Tableau enregistré : ${saveTextFile('tsp_banc_essai.csv', lines.join('\r\n'))}');
    } catch (e) {
      toast(context, 'Enregistrement impossible : $e', error: true);
    }
  }

  void _scenario(int i) {
    host.bottomOpen.value = true;
    switch (i) {
      case 0:
        setState(() {
          _tab = 0;
          method = 0;
          _setInstance(kTspDefault6, asymmetric: false);
        });
        _run(speed: 8);
      case 1:
        setState(() {
          _tab = 0;
          method = 2;
          _setInstance(kTspDemo4, asymmetric: false);
        });
        _run(autoplay: false, speed: 1);
      case 2:
        setState(() => _tab = 1);
        _bench();
      default:
        setState(() {
          _tab = 0;
          method = 2;
          asym = false;
          _setInstance(randomMatrix(18, _rnd, maxDist: 60), asymmetric: false);
        });
        _run();
    }
  }

  void _requirement(String req) {
    host.bottomOpen.value = true;
    if (req == 'bench') {
      setState(() => _tab = 1);
    } else {
      setState(() => _tab = 0);
      if (req == 'loops') {
        _setMethod(2);
        host.tab.value = 0;
        if (!host.player.hasTrace && n <= _hkTraceMax && !busy) _run(autoplay: false);
      }
    }
    host.spotlight(req);
  }

  // ------------------------------------------------------------ scene

  static const double _pad = 52;
  Offset _toPx(Offset p) => Offset(_pad + p.dx * (_size.width - 2 * _pad), _pad + p.dy * (_size.height - 2 * _pad));
  Offset _toNorm(Offset px) =>
      Offset(((px.dx - _pad) / (_size.width - 2 * _pad)).clamp(0.0, 1.0), ((px.dy - _pad) / (_size.height - 2 * _pad)).clamp(0.0, 1.0));
  double get _radius => (min(_size.width, _size.height) * 0.038).clamp(12.0, 22.0) * (n > 12 ? 0.8 : 1.0);

  void _panStart(DragStartDetails e) {
    for (var i = n - 1; i >= 0; i--) {
      if ((_toPx(pos[i]) - e.localPosition).distance <= _radius + 6) {
        _drag = i;
        return;
      }
    }
  }

  void _panUpdate(DragUpdateDetails e) {
    if (_drag < 0) return;
    setState(() {
      pos[_drag] = _toNorm(e.localPosition);
      if (points) {
        d = _euclid();
        _invalidate();
      }
    });
  }

  // ------------------------------------------------------------ interface

  @override
  Widget build(BuildContext context) {
    final hk = method == 2;
    return LabScaffold(
      labIndex: 2,
      content: kTspLab,
      host: host,
      pseudo: hk ? kHkPseudo : kEnumPseudo,
      pseudoTitle: hk ? 'Bellman-Held-Karp' : (method == 1 ? 'énumération par BFS (file de chemins)' : 'énumération par DFS (permutations)'),
      onScenario: _scenario,
      onRequirement: _requirement,
      counters: _counters,
      extra: _extra,
      bottomHeight: 262,
      idleText: 'Choisissez une méthode puis « Lancer » : chaque cycle testé ou chaque case C(S, j) remplie sera expliqué ici.',
      canvas: _canvas(),
      bottom: _bottom(),
    );
  }

  Map<String, String> _counters() {
    final v = host.player.current?.view;
    final r = res[method];
    final m = n - 1;
    return {
      if (method < 2) ...{
        'cycles évalués': v is EnumView ? '${v.count}' : (r != null ? '${r.ops}' : '—'),
        '(n−1)!': _fmtBig(factorial(n - 1)),
        'meilleur coût': v is EnumView ? (v.best < 0 ? '∞' : '${v.best}') : (r != null ? '${r.cost}' : '—'),
        if (method == 1) 'chemins en file': v is EnumView ? '${v.queueSize}' : (r != null ? 'max ${r.extra}' : '—'),
      } else ...{
        'cases C(S, j)': v is HkView ? '${v.filled} / ${m * (1 << max(0, m - 1))}' : (r != null ? '${r.extra}' : '—'),
        'transitions': v is HkView ? '${v.ops}' : (r != null ? '${r.ops}' : '—'),
        'n²·2ⁿ': _fmtBig(n * n * pow(2.0, n).toDouble()),
        'mémoire table': '${(heldKarpBytes(n) / 1024).ceil()} Ko',
      },
      if (r != null) 'temps (sans trace)': _fmtMicros(r.micros),
    };
  }

  Widget _extra(BuildContext context, Step? step) {
    final v = step?.view;
    if (method < 2) {
      final r = res[method];
      final count = v is EnumView ? v.count : (r?.ops ?? 0);
      final total = factorial(n - 1);
      return PanelSection(
        title: 'Énumération',
        accent: _accent,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: total <= 0 ? 0 : (count / total).clamp(0.0, 1.0), minHeight: 6, backgroundColor: C.card2, color: _accent),
          ),
          const SizedBox(height: 8),
          Text('$count cycles évalués sur (n−1)! = ${_fmtBig(total)}',
              style: kMono.copyWith(color: C.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              v is EnumView
                  ? (v.best < 0 ? 'Aucune tournée complète pour l\'instant.' : 'Meilleure tournée : ${_tourText(v.bestTour)} — coût ${v.best}')
                  : (r != null ? 'Tournée optimale : ${_tourText(r.tour)} — coût ${r.cost}' : 'La ville 0 est fixée : il reste (n−1)! ordres à tester.'),
              style: const TextStyle(color: C.muted, fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 8),
          InfoBox([
            method == 1
                ? 'Style BFS : une file de chemins partiels ; chaque chemin défilé est prolongé par chaque ville non visitée. Mémoire : jusqu\'à (n−1)! chemins.'
                : 'Style DFS : on permute les villes 1..n−1 sur place. Même résultat que le BFS, mémoire O(n).',
          ], color: _accent),
        ]),
      );
    }
    final cells = _tracedMethod == 2 ? (_traced?.cells ?? const <HkCell>[]) : const <HkCell>[];
    final filled = v is HkView ? min(v.filled, cells.length) : 0;
    final from = max(0, filled - 40);
    final children = <Widget>[];
    var lastSize = -1;
    for (var k = from; k < filled; k++) {
      final c = cells[k];
      final sz = c.size;
      if (sz != lastSize) {
        lastSize = sz;
        children.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 3),
          child: Text('SOUS-ENSEMBLES DE $sz VILLES', style: const TextStyle(color: C.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
        ));
      }
      final hot = k == filled - 1;
      children.add(Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: hot ? fade(_accent, 0.16) : C.card2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: hot ? fade(_accent, 0.8) : Colors.transparent),
        ),
        child: Row(children: [
          Expanded(
            child: Text('C(${setName(c.set)}, ${c.j})',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: kMono.copyWith(color: hot ? _accent : C.text, fontSize: 12)),
          ),
          Text('= ${c.value}', style: kMono.copyWith(color: hot ? _accent : C.text, fontSize: 12, fontWeight: FontWeight.w700)),
          SizedBox(
            width: 74,
            child: Text('vient de ${c.from}', textAlign: TextAlign.right, style: kMono.copyWith(color: C.muted, fontSize: 10.5)),
          ),
        ]),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      PanelSection(
        title: 'Table C(S, j) — $filled case${filled > 1 ? 's' : ''} remplie${filled > 1 ? 's' : ''}',
        accent: _accent,
        child: filled == 0
            ? const Text('La table se remplit par taille croissante de S. Lancez Held-Karp pas à pas pour la voir se construire.',
                style: TextStyle(color: C.muted, fontSize: 12.5, height: 1.4))
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                if (from > 0) Text('… $from cases plus anciennes', style: const TextStyle(color: C.muted, fontSize: 11)),
                ...children,
              ]),
      ),
      const SizedBox(height: 14),
      const PanelSection(
        title: 'Pourquoi c\'est plus rapide',
        accent: _accent,
        child: InfoBox([
          'Un chemin est résumé par (ensemble de villes visitées, dernière ville). L\'ordre à l\'intérieur de l\'ensemble n\'a plus d\'importance : '
              'tous les chemins qui visitent le même S et finissent en j partagent une seule case C(S, j). On passe de n! chemins à n·2ⁿ cases.',
        ], color: _accent),
      ),
    ]);
  }

  Widget _canvas() {
    return LayoutBuilder(builder: (context, box) {
      _size = box.biggest;
      return AnimatedBuilder(
        animation: Listenable.merge([_anim, host.player]),
        builder: (context, _) {
          final step = host.player.current;
          final view = step?.view;
          final r = res[method] ?? res[2] ?? res[0] ?? res[1];
          // Tournee finale : celle de l'etape de fin, ou du dernier resultat quand aucune trace n'est chargee.
          var finalTour = const <int>[];
          var finalCost = 0;
          if (view is EnumView && step!.kind == StepKind.done) {
            finalTour = view.bestTour;
            finalCost = view.best;
          } else if (view is HkView && view.tour.isNotEmpty) {
            finalTour = view.tour;
            finalCost = view.cost;
          } else if (view == null && r != null && !busy) {
            finalTour = r.tour;
            finalCost = r.cost;
          }
          return Stack(fit: StackFit.expand, children: [
            MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _panStart,
                onPanUpdate: _panUpdate,
                onPanEnd: (_) => _drag = -1,
                child: CustomPaint(
                  painter: _TspPainter(
                    d: d,
                    pts: [for (final p in pos) _toPx(p)],
                    radius: _radius,
                    view: view,
                    finalTour: finalTour,
                    phase: _anim.value,
                    asym: asym,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 10,
              child: IgnorePointer(
                child: Text(
                    'n = $n · ${points ? 'points du plan (distances euclidiennes arrondies)' : 'matrice explicite ${asym ? 'asymétrique' : 'symétrique'}'} · départ : ville 0',
                    style: kMono.copyWith(color: C.muted, fontSize: 11.5)),
              ),
            ),
            Positioned(right: 12, top: 8, child: _badge(view, step, finalTour, finalCost)),
            Positioned(
              left: 12,
              bottom: 8,
              child: IgnorePointer(
                child: Text(
                    points
                        ? 'glisser une ville : la déplacer (les distances sont recalculées)'
                        : 'glisser une ville : réorganiser l\'affichage (les distances de la matrice ne changent pas)',
                    style: TextStyle(color: fade(C.muted, 0.75), fontSize: 11)),
              ),
            ),
            if (busy)
              Positioned(
                left: 0,
                right: 0,
                bottom: 30,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(10), border: Border.all(color: fade(_accent, 0.6))),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _accent)),
                      SizedBox(width: 10),
                      Text('Calcul en cours dans un isolate…', style: TextStyle(color: C.text, fontSize: 12.5)),
                    ]),
                  ),
                ),
              ),
          ]);
        },
      );
    });
  }

  Widget _badge(Object? view, Step? step, List<int> finalTour, int finalCost) {
    String? text;
    var color = _accent;
    if (finalTour.isNotEmpty) {
      text = 'Coût optimal : $finalCost';
      color = C.green;
    } else if (view is EnumView) {
      text = 'best = ${view.best < 0 ? '∞' : view.best}';
    } else if (view is HkView && view.set != 0) {
      text = view.j >= 0 ? 'C(${setName(view.set)}, ${view.j})' : 'S = ${setName(view.set)}';
    }
    if (text == null) return const SizedBox.shrink();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: fade(color, 0.14), borderRadius: BorderRadius.circular(10), border: Border.all(color: fade(color, 0.7))),
      child: Text(text, style: kMono.copyWith(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
    );
  }

  Widget _bottom() => BottomTabs(
        tabs: const ['Instance', 'Banc d\'essai'],
        index: _tab,
        accent: _accent,
        onChanged: (i) => setState(() => _tab = i),
        trailing: _tab == 0
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                if (busy) ...[ChipBtn(label: 'Arrêter', icon: Icons.stop_rounded, color: C.red, active: true, onTap: _stop), const SizedBox(width: 8)],
                ChipBtn(
                    label: 'Lancer les deux',
                    icon: Icons.compare_arrows_rounded,
                    color: _accent,
                    tip: 'Énumération puis Held-Karp sur la même instance : coûts, tournées et temps côte à côte',
                    onTap: busy ? null : _runBoth),
                const SizedBox(width: 8),
                SizedBox(
                  width: 150,
                  child: ActionBtn(label: 'Lancer', icon: Icons.play_arrow_rounded, color: _accent, filled: true, onPressed: busy ? null : () => _run()),
                ),
              ])
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (benchRunning) ...[
                  Text('n = $benchN…', style: kMono.copyWith(color: _accent, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 10),
                  ChipBtn(label: 'Arrêter', icon: Icons.stop_rounded, color: C.red, active: true, onTap: _stopBench),
                  const SizedBox(width: 8),
                ],
                ChipBtn(label: 'Exporter CSV', icon: Icons.save_alt_rounded, color: _accent, onTap: rows.isEmpty ? null : _exportCsv),
                const SizedBox(width: 8),
                SizedBox(
                  width: 210,
                  child: ActionBtn(
                      label: 'Lancer le banc d\'essai', icon: Icons.speed_rounded, color: _accent, filled: true, onPressed: benchRunning ? null : _bench),
                ),
              ]),
        children: [_instanceTab(), _benchTab()],
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(t, style: const TextStyle(color: C.muted, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
      );

  Widget _instanceTab() => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          flex: 10,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('MÉTHODE'),
              SpotTarget(
                host: host,
                ids: const ['enum', 'hk', 'loops'],
                color: _accent,
                radius: 10,
                child: SegBar(options: _methodNames, index: method, color: _accent, onChanged: _setMethod),
              ),
              const SizedBox(height: 8),
              Row(children: [
                SpotTarget(
                  host: host,
                  ids: const ['n6'],
                  color: _accent,
                  radius: 10,
                  child: SizedBox(width: 140, child: NumStepper(label: 'n', value: n, min: 2, max: _hkMax, onChanged: _setN)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SegBar(options: const ['Matrice', 'Points'], index: points ? 1 : 0, color: _accent, onChanged: (i) => _setMode(i == 1)),
                ),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                ChipBtn(
                    label: 'Matrice…',
                    icon: Icons.grid_on_rounded,
                    color: _accent,
                    tip: 'Saisir les distances case par case (Tab passe à la case suivante)',
                    onTap: _editMatrix),
                ChipBtn(label: 'Aléatoire', icon: Icons.casino_outlined, color: _accent, tip: 'Nouvelle instance aléatoire de même taille', onTap: _random),
                ChipBtn(
                    label: 'n = 6',
                    icon: Icons.restart_alt_rounded,
                    color: _accent,
                    tip: 'Recharger l\'instance par défaut à 6 villes',
                    onTap: () => setState(() => _setInstance(kTspDefault6, asymmetric: false))),
                Toggle(label: 'asymétrique', value: asym, color: _accent, onChanged: _setAsym),
              ]),
            ]),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(flex: 11, child: _results()),
      ]);

  Widget _results() {
    final a = res[0] ?? res[1], b = res[2];
    final same = a != null && b != null ? a.cost == b.cost : null;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('RÉSULTATS (TEMPS MESURÉS SANS TRACE)'),
        for (var m = 0; m < 3; m++)
          if (res[m] != null || m == method) _resultRow(m),
        const Spacer(),
        if (same != null)
          Row(children: [
            Icon(same ? Icons.check_circle_rounded : Icons.error_rounded, size: 16, color: same ? C.green : C.red),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  same
                      ? 'Même coût optimal (${b!.cost}) — ${a!.micros >= b.micros ? 'Held-Karp ${(a.micros / max(1, b.micros)).toStringAsFixed(1).replaceAll('.', ',')}× plus rapide' : 'n est petit : l\'énumération est encore aussi rapide, l\'écart se creuse avec n'}'
                      : 'Coûts différents : ${a!.cost} et ${b!.cost}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: same ? C.green : C.red, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ])
        else
          const Text('« Lancer les deux » compare l\'énumération et Held-Karp sur cette instance.',
              maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: C.muted, fontSize: 12)),
      ]),
    );
  }

  Widget _resultRow(int m) {
    final r = res[m];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Container(width: 3, height: 30, decoration: BoxDecoration(color: m == 2 ? _accent : C.red, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(_methodNames[m],
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              Text(r == null ? '—' : 'coût ${r.cost}', style: kMono.copyWith(color: r == null ? C.muted : C.green, fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(width: 12),
              Text(_fmtMicros(r?.micros), style: kMono.copyWith(color: C.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
            Text(
                r == null
                    ? 'pas encore exécutée sur cette instance'
                    : '${_tourText(r.tour)}   ·   ${m < 2 ? '${r.ops} cycles' : '${r.ops} transitions'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kMono.copyWith(color: C.muted, fontSize: 11.5)),
          ]),
        ),
      ]),
    );
  }

  Widget _benchTab() => SpotTarget(
        host: host,
        ids: const ['bench'],
        color: _accent,
        radius: 12,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            flex: 13,
            child: SimpleTable(
              accent: _accent,
              headers: const ['n', '(n−1)!', 'n²·2ⁿ', 'énumération', 'Held-Karp', 'rapport', 'même coût'],
              flex: const [2, 6, 5, 6, 6, 5, 5],
              rows: [
                for (final r in rows)
                  [
                    '${r.n}',
                    _fmtBig(factorial(r.n - 1)),
                    _fmtBig(r.n * r.n * pow(2.0, r.n).toDouble()),
                    _fmtMicros(r.bruteMicros),
                    _fmtMicros(r.hkMicros),
                    r.bruteMicros != null && r.hkMicros != null ? '×${(r.bruteMicros! / max(1, r.hkMicros!)).toStringAsFixed(r.bruteMicros! > 10 * r.hkMicros! ? 0 : 2)}' : '—',
                    r.sameCost == null ? '—' : (r.sameCost! ? '✔' : '✘'),
                  ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 9,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
              decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(12)),
              child: LogLineChart(
                xLabel: 'n',
                yLabel: 'ms (log)',
                series: [
                  Series('Énumération', C.red, [
                    for (final r in rows)
                      if (r.bruteMicros != null) Offset(r.n.toDouble(), max(r.bruteMicros!, 1) / 1000)
                  ]),
                  Series('Held-Karp', _accent, [
                    for (final r in rows)
                      if (r.hkMicros != null) Offset(r.n.toDouble(), max(r.hkMicros!, 1) / 1000)
                  ]),
                ],
              ),
            ),
          ),
        ]),
      );
}

// ---------------------------------------------------------------------------- editeur de matrice

class _MatrixEditor extends StatefulWidget {
  final List<List<int>> d;
  final bool symmetric;
  const _MatrixEditor({required this.d, required this.symmetric});

  @override
  State<_MatrixEditor> createState() => _MatrixEditorState();
}

class _MatrixEditorState extends State<_MatrixEditor> {
  late final int n = widget.d.length;
  late final List<List<TextEditingController>> _c = [
    for (var i = 0; i < n; i++) [for (var j = 0; j < n; j++) TextEditingController(text: '${widget.d[i][j]}')]
  ];
  String? _error;

  @override
  void dispose() {
    for (final row in _c) {
      for (final c in row) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _apply() {
    final m = List.generate(n, (_) => List<int>.filled(n, 0));
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        if (i == j) continue;
        final v = int.tryParse(_c[i][j].text.trim());
        if (v == null || v < 0 || v > 99999) {
          setState(() => _error = 'd($i, $j) doit être un entier entre 0 et 99999.');
          return;
        }
        m[i][j] = v;
      }
    }
    Navigator.pop(context, m);
  }

  Widget _head(String t) => SizedBox(
        width: 48,
        height: 26,
        child: Center(child: Text(t, style: kMono.copyWith(color: C.amber, fontSize: 12, fontWeight: FontWeight.w700))),
      );

  Widget _cell(int i, int j) {
    if (i == j) {
      return SizedBox(
        width: 48,
        height: 36,
        child: Center(child: Text('0', style: kMono.copyWith(color: C.muted, fontSize: 13))),
      );
    }
    OutlineInputBorder border(Color c) => OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: c));
    return Padding(
      padding: const EdgeInsets.all(2),
      child: SizedBox(
        width: 44,
        height: 32,
        child: Focus(
          skipTraversal: true,
          canRequestFocus: false,
          onFocusChange: (has) {
            if (has) _c[i][j].selection = TextSelection(baseOffset: 0, extentOffset: _c[i][j].text.length);
          },
          child: TextField(
            controller: _c[i][j],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
            textInputAction: TextInputAction.next,
            cursorColor: C.amber,
            style: kMono.copyWith(color: C.text, fontSize: 13, fontWeight: FontWeight.w700),
            onChanged: (t) {
              // Matrice symetrique : d(j, i) suit d(i, j).
              if (widget.symmetric && _c[j][i].text != t) _c[j][i].text = t;
            },
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: i < j || !widget.symmetric ? C.card2 : C.bg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              enabledBorder: border(C.line),
              focusedBorder: border(C.amber),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
          widget.symmetric
              ? 'Ligne i, colonne j : distance de la ville i à la ville j. Matrice symétrique : modifier d(i, j) recopie la valeur dans d(j, i). Tab passe à la case suivante.'
              : 'Ligne i, colonne j : distance de la ville i vers la ville j (matrice asymétrique : chaque case est indépendante). Tab passe à la case suivante.',
          style: const TextStyle(color: C.muted, fontSize: 12.5, height: 1.4)),
      const SizedBox(height: 10),
      Flexible(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 430),
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [_head('i \\ j'), for (var j = 0; j < n; j++) _head('$j')]),
                  for (var i = 0; i < n; i++)
                    Row(mainAxisSize: MainAxisSize.min, children: [_head('$i'), for (var j = 0; j < n; j++) _cell(i, j)]),
                ]),
              ),
            ),
          ),
        ),
      ),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: C.red, fontSize: 12.5))),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        ChipBtn(label: 'Annuler', onTap: () => Navigator.pop(context)),
        const SizedBox(width: 8),
        ChipBtn(label: 'Enregistrer la matrice', icon: Icons.check_rounded, color: C.amber, active: true, onTap: _apply),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------------------- dessin de la scene

class _TspPainter extends CustomPainter {
  final List<List<int>> d;
  final List<Offset> pts;
  final double radius;
  final Object? view;
  final List<int> finalTour;
  final double phase;
  final bool asym;
  _TspPainter({required this.d, required this.pts, required this.radius, required this.view, required this.finalTour, required this.phase, required this.asym});

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _tour(Canvas canvas, List<int> t, Paint p, {bool close = true}) {
    if (t.length < 2) return;
    final path = Path()..moveTo(pts[t[0]].dx, pts[t[0]].dy);
    for (var i = 1; i < t.length; i++) {
      path.lineTo(pts[t[i]].dx, pts[t[i]].dy);
    }
    if (close) path.close();
    canvas.drawPath(path, p);
  }

  void _arrow(Canvas canvas, Offset a, Offset b, Color c, double w) {
    final len = (b - a).distance;
    if (len < 1) return;
    final dir = (b - a) / len;
    final tip = b - dir * (radius + 3);
    canvas.drawLine(a + dir * radius, tip, _stroke(c, w));
    final nrm = Offset(-dir.dy, dir.dx);
    final back = tip - dir * (w * 3.2);
    canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo((back + nrm * w * 1.8).dx, (back + nrm * w * 1.8).dy)
          ..lineTo((back - nrm * w * 1.8).dx, (back - nrm * w * 1.8).dy)
          ..close(),
        Paint()..color = c);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = pts.length;
    final unit = radius / 16;
    final pulse = 0.5 + 0.5 * sin(phase * 2 * pi * 2);
    final v = view;
    // Graphe complet en fond.
    final base = _stroke(fade(C.line, n <= 8 ? 0.85 : (n <= 12 ? 0.5 : 0.28)), 1.3 * unit);
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        canvas.drawLine(pts[i], pts[j], base);
      }
    }

    var inSet = 0, vj = -1, vi = -1;
    if (finalTour.isNotEmpty) {
      // Tournee optimale : trait epais, halo qui pulse, point mobile.
      _tour(canvas, finalTour, _stroke(fade(C.green, 0.14 + 0.16 * pulse), (11 + 4 * pulse) * unit));
      _tour(canvas, finalTour, _stroke(C.green, 4.6 * unit));
    } else if (v is EnumView) {
      if (v.bestTour.isNotEmpty) {
        _tour(canvas, v.bestTour, _stroke(fade(C.amber, 0.22), 10 * unit));
        _tour(canvas, v.bestTour, _stroke(C.amber, 4.4 * unit));
      }
      if (v.partial) {
        for (var i = 0; i + 1 < v.tour.length; i++) {
          drawDashed(canvas, pts[v.tour[i]], pts[v.tour[i + 1]], _stroke(C.text, 2.6 * unit), dash: 9 * unit, gap: 7 * unit, phase: phase * 6);
        }
      } else {
        _tour(canvas, v.tour, _stroke(fade(C.text, 0.92), 1.8 * unit));
      }
    } else if (v is HkView) {
      inSet = v.set;
      vj = v.j;
      vi = v.i;
      // Villes de S reliees a la ville 0 par un voile : "l'ensemble deja visite".
      final members = setCities(v.set);
      for (final c in members) {
        if (c != 0 && c != vj) canvas.drawLine(pts[0], pts[c], _stroke(fade(C.amber, 0.16), 5 * unit));
      }
      if (vi >= 0 && vj >= 0) {
        canvas.drawLine(pts[vi], pts[vj], _stroke(fade(C.amber, 0.22 + 0.2 * pulse), 9 * unit));
        _arrow(canvas, pts[vi], pts[vj], C.amber, 3.4 * unit);
      } else if (vj >= 0 && members.length == 2) {
        _arrow(canvas, pts[0], pts[vj], C.amber, 3.4 * unit);
      }
    }

    // Distances sur des pastilles (petites instances).
    if (n <= 7) {
      for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
          final t = (i + j).isEven ? 0.38 : 0.62; // decale pour limiter les superpositions au centre
          final hot = (i == vi && j == vj) || (i == vj && j == vi);
          drawPill(canvas, asym && d[i][j] != d[j][i] ? '${d[i][j]}/${d[j][i]}' : '${d[i][j]}', Offset.lerp(pts[i], pts[j], t)!,
              color: hot ? C.amber : fade(C.text, 0.8), size: max(9.5, 10.5 * unit));
        }
      }
    }

    // Villes
    for (var i = 0; i < n; i++) {
      final c = pts[i];
      final member = inSet & (1 << i) != 0;
      final onFinal = finalTour.isNotEmpty;
      var col = i == 0 ? C.text : (onFinal ? C.green : C.amber);
      if (v is HkView && finalTour.isEmpty && !member) col = C.muted;
      final r = i == 0 ? radius * 1.18 : radius;
      canvas.drawCircle(c, r * 1.4, Paint()..color = fade(col, 0.1)); // halo doux
      canvas.drawCircle(c, r, Paint()..color = member && finalTour.isEmpty ? Color.lerp(C.card2, C.amber, 0.35)! : C.card2);
      canvas.drawCircle(c, r, _stroke(col, 2.4 * unit));
      if (i == 0) canvas.drawCircle(c, r * 1.32, _stroke(fade(C.text, 0.55), 1.4 * unit)); // la ville de depart a un double anneau
      if (i == vj) canvas.drawCircle(c, r * (1.35 + 0.12 * pulse), _stroke(C.text, 2.2 * unit));
      if (i == vi) canvas.drawCircle(c, r * 1.3, _stroke(fade(C.amber, 0.9), 2 * unit));
      drawText(canvas, '$i', c, kMono.copyWith(color: C.text, fontSize: r * 0.82, fontWeight: FontWeight.w800), anchor: Alignment.center);
      final tag = i == 0 ? 'départ' : (i == vj ? 'j' : (i == vi ? 'i' : null));
      if (tag != null) drawPill(canvas, tag, c + Offset(0, r + 11 * unit), color: i == 0 ? C.text : C.amber, size: max(9.5, 10 * unit));
    }

    // Point mobile sur la tournee finale.
    if (finalTour.length >= 2) {
      final m = finalTour.length;
      final x = phase * m;
      final k = x.floor() % m;
      final p = Offset.lerp(pts[finalTour[k]], pts[finalTour[(k + 1) % m]], x - x.floor())!;
      canvas.drawCircle(p, radius * 0.75, Paint()..color = fade(C.green, 0.3));
      canvas.drawCircle(p, radius * 0.36, Paint()..color = C.text);
    }
  }

  @override
  bool shouldRepaint(covariant _TspPainter old) => true;
}
