import 'dart:math';

import 'package:flutter/material.dart' hide Step;
import 'package:flutter/services.dart';

import '../core/demo_content.dart';
import '../core/graph.dart';
import '../core/trace.dart';
import 'explain_panel.dart';
import 'kit.dart';
import 'lab_scaffold.dart';

const List<Color> _levelColors = [C.cyan, Color(0xFF60A5FA), C.violet, Color(0xFFF472B6), C.amber, Color(0xFFA3E635), Color(0xFFFB923C)];

/// TP 1 — Plus petit cycle d'un graphe non oriente : un BFS depuis chaque sommet.
class CyclePage extends StatefulWidget {
  const CyclePage({super.key});

  @override
  State<CyclePage> createState() => _CyclePageState();
}

class _CyclePageState extends State<CyclePage> with SingleTickerProviderStateMixin {
  static const _accent = C.cyan;
  final LabHost host = LabHost();
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  final Random _rnd = Random();

  Graph g = Graph();
  List<Offset> pos = []; // positions normalisees (0..1)
  bool earlyCut = false;
  CycleResult? result;
  int _tab = 0;
  int rndN = 10, rndDensity = 25;
  String _presetName = '';

  // Geste en cours sur la scene
  int _drag = -1;
  Offset _dragStart = Offset.zero, _pointer = Offset.zero;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    host.player.onStep = _onStep;
    _applyPreset(0);
  }

  @override
  void dispose() {
    _pulse.dispose();
    host.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ donnees

  void _applyPreset(int i) {
    final p = kGraphPresets[i];
    g = Graph.fromEdges(p.pos.length, p.edges);
    pos = [for (final q in p.pos) Offset(q[0], q[1])];
    _presetName = p.name;
    _invalidate();
  }

  void _loadPreset(int i) => setState(() => _applyPreset(i));

  void _invalidate() {
    result = null;
    host.player.clear();
  }

  List<Offset> _circle(int n) => [for (var i = 0; i < n; i++) Offset(0.5 + 0.4 * cos(-pi / 2 + 2 * pi * i / n), 0.5 + 0.4 * sin(-pi / 2 + 2 * pi * i / n))];

  void _random() {
    final maxM = rndN * (rndN - 1) ~/ 2;
    setState(() {
      g = Graph.random(rndN, max(1, (maxM * rndDensity / 100).round()), _rnd);
      pos = _circle(rndN);
      _presetName = 'Aléatoire';
      _invalidate();
    });
  }

  /// Action destructrice en un clic, avec « Annuler ».
  void _mutate(String message, VoidCallback change) {
    final oldG = g.copy(), oldPos = List<Offset>.from(pos), oldName = _presetName;
    setState(() {
      change();
      _invalidate();
    });
    toast(context, message, onUndo: () => setState(() {
          g = oldG;
          pos = oldPos;
          _presetName = oldName;
          _invalidate();
        }));
  }

  // ------------------------------------------------------------ execution

  void _run({bool autoplay = true, double? speed}) {
    if (g.n == 0) {
      toast(context, 'Le graphe est vide : ajoutez des sommets en cliquant sur la scène, ou chargez un exemple.');
      return;
    }
    // Le temps affiche vient d'une execution sans trace ; la trace sert a l'animation.
    final r = shortestCycle(g, earlyCut: earlyCut);
    final t = Trace();
    shortestCycle(g, trace: t, earlyCut: earlyCut);
    setState(() => result = r);
    host.tick('repr');
    if (speed != null) host.player.setSpeed(speed);
    host.player.load(t.steps, autoplay: autoplay);
  }

  void _onStep(Step s) {
    final v = s.view;
    if (v is! CycleView) return;
    if (v.source >= 1) host.tick('bfs_each');
    if (s.kind == StepKind.done) {
      host.tick('bfs_each');
      host.tick('complexity');
      host.tick(v.bestCycle.isEmpty ? 'nocycle' : 'result');
    }
  }

  void _scenario(int i) {
    setState(() => _tab = 0);
    switch (i) {
      case 0:
        _loadPreset(0);
        setState(() => earlyCut = false);
        _run(autoplay: false, speed: 1);
      case 1:
        _loadPreset(2);
        _run(speed: 16);
      case 2:
        _loadPreset(3);
        _run(speed: 8);
      default:
        setState(() {
          g = Graph();
          pos = [];
          _presetName = '';
          _invalidate();
        });
        toast(context, 'Scène vide : cliquez pour poser les sommets, glissez d\'un sommet à l\'autre pour les relier, puis « Lancer ».');
    }
  }

  void _requirement(String req) {
    host.bottomOpen.value = true;
    setState(() => _tab = req == 'repr' ? 0 : 1);
    if (req == 'bfs_each' || req == 'result') {
      if (!host.player.hasTrace) _run();
      host.tab.value = 0;
    }
    host.spotlight(req);
  }

  // ------------------------------------------------------------ scene : gestes

  static const double _pad = 46;
  Offset _toPx(Offset p) => Offset(_pad + p.dx * (_size.width - 2 * _pad), _pad + p.dy * (_size.height - 2 * _pad));
  Offset _toNorm(Offset px) =>
      Offset(((px.dx - _pad) / (_size.width - 2 * _pad)).clamp(0.0, 1.0), ((px.dy - _pad) / (_size.height - 2 * _pad)).clamp(0.0, 1.0));
  double get _radius => (min(_size.width, _size.height) * 0.036).clamp(13.0, 22.0);

  int _vertexAt(Offset px, {int except = -1, double slack = 6}) {
    for (var i = g.n - 1; i >= 0; i--) {
      if (i != except && (_toPx(pos[i]) - px).distance <= _radius + slack) return i;
    }
    return -1;
  }

  List<int>? _edgeAt(Offset px) {
    for (final e in g.edges()) {
      final a = _toPx(pos[e[0]]), b = _toPx(pos[e[1]]);
      final ab = b - a;
      final t = (((px - a).dx * ab.dx + (px - a).dy * ab.dy) / (ab.distanceSquared + 1e-9)).clamp(0.0, 1.0);
      if ((a + ab * t - px).distance < 8) return e;
    }
    return null;
  }

  void _tapUp(TapUpDetails d) {
    final p = d.localPosition;
    if (_vertexAt(p) >= 0 || _edgeAt(p) != null) return;
    if (g.n >= 60) {
      toast(context, 'Limite de 60 sommets atteinte : au-delà, la scène devient illisible.');
      return;
    }
    setState(() {
      g.addVertex();
      pos.add(_toNorm(p));
      _presetName = '';
      _invalidate();
    });
  }

  void _secondary(TapUpDetails d) {
    final p = d.localPosition;
    final v = _vertexAt(p);
    if (v >= 0) {
      _mutate('Sommet $v supprimé (les sommets suivants sont renumérotés).', () {
        g.removeVertex(v);
        pos.removeAt(v);
        _presetName = '';
      });
      return;
    }
    final e = _edgeAt(p);
    if (e != null) {
      _mutate('Arête ${e[0]}–${e[1]} supprimée.', () {
        g.removeEdge(e[0], e[1]);
        _presetName = '';
      });
    }
  }

  void _panStart(DragStartDetails d) {
    final v = _vertexAt(d.localPosition);
    if (v < 0) return;
    setState(() {
      _drag = v;
      _dragStart = pos[v];
      _pointer = d.localPosition;
    });
  }

  void _panUpdate(DragUpdateDetails d) {
    if (_drag < 0) return;
    setState(() {
      _pointer = d.localPosition;
      pos[_drag] = _toNorm(_pointer);
    });
  }

  void _panEnd(DragEndDetails d) {
    if (_drag < 0) return;
    final v = _drag;
    final target = _vertexAt(_pointer, except: v, slack: 2);
    setState(() {
      _drag = -1;
      if (target >= 0) {
        // Lache sur un autre sommet : le sommet reprend sa place et l'arete est creee.
        pos[v] = _dragStart;
        if (g.addEdge(v, target)) {
          _presetName = '';
          _invalidate();
        }
      }
    });
  }

  // ------------------------------------------------------------ interface

  @override
  Widget build(BuildContext context) {
    return LabScaffold(
      labIndex: 1,
      content: kCycleLab,
      host: host,
      pseudo: kCyclePseudo,
      pseudoTitle: 'BFS depuis chaque sommet',
      onScenario: _scenario,
      onRequirement: _requirement,
      counters: _counters,
      extra: _extra,
      idleText: 'Dessinez ou chargez un graphe, puis « Lancer » : chaque étape du BFS sera expliquée ici.',
      canvas: _canvas(),
      bottom: _bottom(),
    );
  }

  Map<String, String> _counters() {
    final v = host.player.current?.view;
    final bound = g.n * (g.n + 2 * g.m);
    return {
      'sommets défilés': v is CycleView ? '${v.visits}' : '—',
      'arêtes examinées': v is CycleView ? '${v.edgeChecks}' : '—',
      'borne V·(V+2E)': '$bound',
      'BFS': v is CycleView && v.source >= 0 ? '${v.source + 1} / ${g.n}' : (v is CycleView && host.player.atEnd ? '${g.n} / ${g.n}' : '—'),
      if (result != null) 'temps (sans trace)': '${result!.micros} µs',
    };
  }

  Widget _extra(BuildContext context, Step? step) => const PanelSection(
        title: 'Pourquoi un BFS depuis chaque sommet',
        accent: _accent,
        child: InfoBox([
          'Un seul BFS peut annoncer un cycle qui ne passe pas par sa source et le surestimer.',
          'Le BFS lancé sur un sommet du plus petit cycle trouve exactement sa longueur : le minimum sur toutes les sources est donc exact.',
        ], color: _accent),
      );

  Widget _canvas() {
    return LayoutBuilder(builder: (context, box) {
      _size = box.biggest;
      return AnimatedBuilder(
        animation: Listenable.merge([_pulse, host.player]),
        builder: (context, _) {
          final step = host.player.current;
          final view = step?.view is CycleView ? step!.view as CycleView : null;
          return Stack(fit: StackFit.expand, children: [
            MouseRegion(
              cursor: SystemMouseCursors.precise,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: _tapUp,
                onSecondaryTapUp: _secondary,
                onPanStart: _panStart,
                onPanUpdate: _panUpdate,
                onPanEnd: _panEnd,
                child: CustomPaint(
                  painter: _GraphPainter(
                    g: g,
                    pts: [for (final p in pos) _toPx(p)],
                    radius: _radius,
                    view: view,
                    done: step?.kind == StepKind.done,
                    idleCycle: view == null ? (result?.cycle ?? const []) : const [],
                    phase: _pulse.value,
                    dragFrom: _drag >= 0 ? _toPx(_dragStart) : null,
                    dragTo: _drag >= 0 && _vertexAt(_pointer, except: _drag, slack: 2) >= 0 ? _pointer : null,
                  ),
                ),
              ),
            ),
            if (g.n == 0)
              const IgnorePointer(child: EmptyState(icon: Icons.hub_outlined, text: 'Ajoutez des sommets en cliquant, ou chargez un exemple', color: _accent)),
            Positioned(
              left: 12,
              top: 10,
              child: IgnorePointer(
                child: Text('Listes d\'adjacence · V = ${g.n} · E = ${g.m}${_presetName.isEmpty ? '' : ' · $_presetName'}',
                    style: kMono.copyWith(color: C.muted, fontSize: 11.5)),
              ),
            ),
            Positioned(right: 12, top: 8, child: _resultBadge(view, step)),
            Positioned(
              left: 12,
              bottom: 8,
              child: IgnorePointer(
                child: Text('clic : sommet · glisser : déplacer · glisser vers un sommet : arête · clic droit : supprimer',
                    style: TextStyle(color: fade(C.muted, 0.75), fontSize: 11)),
              ),
            ),
          ]);
        },
      );
    });
  }

  Widget _resultBadge(CycleView? view, Step? step) {
    String? text;
    var color = C.green;
    if (view != null) {
      if (step!.kind == StepKind.done) {
        text = view.bestCycle.isEmpty ? 'Aucun cycle (le graphe est une forêt)' : 'Plus petit cycle : ${view.best}';
        if (view.bestCycle.isEmpty) color = C.amber;
      } else {
        text = 'best = ${view.best == 0 ? '∞' : view.best}';
        color = _accent;
      }
    } else if (result != null) {
      text = result!.cycle.isEmpty ? 'Aucun cycle (le graphe est une forêt)' : 'Plus petit cycle : ${result!.length}';
      if (result!.cycle.isEmpty) color = C.amber;
    }
    if (text == null) return const SizedBox.shrink();
    return SpotTarget(
      host: host,
      ids: const ['result'],
      color: _accent,
      radius: 10,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: fade(color, 0.14), borderRadius: BorderRadius.circular(10), border: Border.all(color: fade(color, 0.7))),
        child: Text(text, style: kMono.copyWith(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _bottom() => BottomTabs(
        tabs: const ['Graphe', 'Résultat et complexité'],
        index: _tab,
        accent: _accent,
        onChanged: (i) => setState(() => _tab = i),
        trailing: SpotTarget(
          host: host,
          ids: const ['bfs_each'],
          color: _accent,
          radius: 10,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Toggle(
                label: 'Coupe 2·dist[u]+1 ≥ best',
                value: earlyCut,
                color: _accent,
                onChanged: (v) => setState(() {
                      earlyCut = v;
                      _invalidate();
                    })),
            const SizedBox(width: 12),
            SizedBox(
              width: 230,
              child: ActionBtn(label: 'Lancer la démonstration', icon: Icons.play_arrow_rounded, color: _accent, filled: true, onPressed: _run),
            ),
          ]),
        ),
        children: [_graphTab(), _resultTab()],
      );

  Widget _graphTab() => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('EXEMPLES', style: TextStyle(color: C.muted, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (var i = 0; i < kGraphPresets.length; i++)
                  ChipBtn(label: kGraphPresets[i].name, color: _accent, active: _presetName == kGraphPresets[i].name, onTap: () => _loadPreset(i)),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                ChipBtn(label: 'Aléatoire', icon: Icons.casino_outlined, color: _accent, onTap: _random),
                SizedBox(width: 150, child: NumStepper(label: 'n', value: rndN, min: 3, max: 30, onChanged: (v) => setState(() => rndN = v))),
                SizedBox(
                    width: 190,
                    child: NumStepper(label: 'densité', value: rndDensity, min: 5, max: 100, step: 5, format: (v) => '$v %', onChanged: (v) => setState(() => rndDensity = v))),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                ChipBtn(label: 'Liste d\'arêtes…', icon: Icons.edit_note_rounded, color: _accent, onTap: _edgeListDialog),
                ChipBtn(
                    label: 'Exporter',
                    icon: Icons.save_alt_rounded,
                    color: _accent,
                    onTap: () {
                      try {
                        toast(context, 'Liste d\'arêtes enregistrée : ${saveTextFile('graphe_tp1.txt', g.toEdgeList())}');
                      } catch (e) {
                        toast(context, 'Enregistrement impossible : $e', error: true);
                      }
                    }),
                ChipBtn(
                    label: 'Tout effacer',
                    icon: Icons.delete_outline_rounded,
                    color: C.red,
                    onTap: g.n == 0
                        ? null
                        : () => _mutate('Graphe effacé.', () {
                              g = Graph();
                              pos = [];
                              _presetName = '';
                            })),
              ]),
            ]),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 4,
          child: SpotTarget(
            host: host,
            ids: const ['repr'],
            color: _accent,
            radius: 12,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('REPRÉSENTATION : LISTES D\'ADJACENCE', style: TextStyle(color: C.muted, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                const SizedBox(height: 6),
                Expanded(
                  child: g.n == 0
                      ? const Text('graphe vide', style: TextStyle(color: C.muted, fontSize: 12))
                      : ListView.builder(
                          itemCount: g.n,
                          itemBuilder: (_, u) => Text('adj[$u] → ${g.adj[u].isEmpty ? '∅' : g.adj[u].join(', ')}',
                              style: kMono.copyWith(color: C.text, fontSize: 12, height: 1.45)),
                        ),
                ),
              ]),
            ),
          ),
        ),
      ]);

  Widget _resultTab() {
    final r = result;
    final bound = g.n * (g.n + 2 * g.m);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        flex: 5,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StatRow([
            Stat(label: 'longueur du plus petit cycle', value: r == null ? '—' : (r.cycle.isEmpty ? 'aucun' : '${r.length}'), color: C.green),
            Stat(label: 'sommets défilés', value: r == null ? '—' : '${r.visits}'),
            Stat(label: 'arêtes examinées', value: r == null ? '—' : '${r.edgeChecks}'),
            Stat(label: 'temps (sans trace)', value: r == null ? '—' : '${r.micros} µs'),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(12)),
              child: SingleChildScrollView(
                child: Text(
                    r == null
                        ? 'Lancez l\'algorithme pour obtenir le cycle.'
                        : r.cycle.isEmpty
                            ? 'Aucun cycle : aucune arête hors arbre n\'a été rencontrée (le graphe est une forêt).'
                            : 'Cycle retourné : ${r.cycle.join(' → ')} → ${r.cycle.first}',
                    style: kMono.copyWith(color: C.text, fontSize: 13, height: 1.4)),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(width: 14),
      Expanded(
        flex: 4,
        child: SpotTarget(
          host: host,
          ids: const ['complexity'],
          color: _accent,
          radius: 12,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(12)),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('COMPLEXITÉ : O(V·(V+E))', style: kMono.copyWith(color: _accent, fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                InfoBox([
                  'Un BFS : O(V + E). On en lance V → O(V·(V+E)) ; O(V·E) si connexe, O(V³) si dense.',
                  'Ici V = ${g.n}, E = ${g.m} : borne V·(V+2E) = $bound opérations.'
                      '${r == null ? '' : ' Mesuré : ${r.visits} sommets défilés + ${r.edgeChecks} arêtes examinées = ${r.visits + r.edgeChecks}.'}',
                  'Mémoire : O(V + E).',
                ], color: _accent),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }

  Future<void> _edgeListDialog() async {
    final ctl = TextEditingController(text: g.toEdgeList());
    String? error;
    await showDarkDialog<void>(
      context,
      title: 'Liste d\'arêtes',
      width: 460,
      child: StatefulBuilder(
        builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Une arête par ligne : « u v ». Un entier seul déclare un sommet isolé. Les sommets sont numérotés à partir de 0.',
              style: TextStyle(color: C.muted, fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 10),
          SizedBox(height: 240, child: DarkField(controller: ctl, maxLines: 14, mono: true, hint: '0 1\n1 2\n2 0')),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: C.red, fontSize: 12.5))),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            ChipBtn(
                label: 'Copier',
                icon: Icons.copy_rounded,
                color: _accent,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: ctl.text));
                  setS(() => error = null);
                }),
            const SizedBox(width: 8),
            ChipBtn(label: 'Fermer', onTap: () => Navigator.pop(ctx)),
            const SizedBox(width: 8),
            ChipBtn(
                label: 'Charger ce graphe',
                icon: Icons.check_rounded,
                color: _accent,
                active: true,
                onTap: () {
                  final ng = Graph.parseEdgeList(ctl.text);
                  if (ng == null || ng.n > 60) {
                    setS(() => error = ng == null
                        ? 'Texte invalide : chaque ligne doit contenir un ou deux entiers positifs.'
                        : 'Trop de sommets (${ng.n}) : la limite est de 60.');
                    return;
                  }
                  Navigator.pop(ctx);
                  _mutate('Graphe chargé depuis la liste d\'arêtes (${ng.n} sommets, ${ng.m} arêtes).', () {
                    g = ng;
                    pos = _circle(ng.n);
                    _presetName = '';
                  });
                }),
          ]),
        ]),
      ),
    );
    ctl.dispose();
  }
}

class _GraphPainter extends CustomPainter {
  final Graph g;
  final List<Offset> pts;
  final double radius;
  final CycleView? view;
  final bool done;
  final List<int> idleCycle;
  final double phase;
  final Offset? dragFrom, dragTo;
  _GraphPainter({
    required this.g,
    required this.pts,
    required this.radius,
    required this.view,
    required this.done,
    required this.idleCycle,
    required this.phase,
    this.dragFrom,
    this.dragTo,
  });

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  void _cycle(Canvas canvas, List<int> c, Paint p) {
    for (var i = 0; i < c.length; i++) {
      canvas.drawLine(pts[c[i]], pts[c[(i + 1) % c.length]], p);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final v = view;
    final unit = radius / 16;
    final pulse = 0.5 + 0.5 * sin(phase * 2 * pi);
    // Aretes
    for (final e in g.edges()) {
      final a = e[0], b = e[1];
      var p = _stroke(C.line, 2 * unit);
      if (v != null && v.dist[a] >= 0 && v.dist[b] >= 0) {
        final tree = v.parent[a] == b || v.parent[b] == a;
        p = tree ? _stroke(fade(C.cyan, 0.75), 3 * unit) : _stroke(fade(C.muted, 0.45), 2 * unit);
      }
      canvas.drawLine(pts[a], pts[b], p);
    }
    // Meilleur cycle connu (epais) ; il pulse a la fin.
    final best = v != null ? v.bestCycle : idleCycle;
    if (best.isNotEmpty) {
      final finalState = v == null || done;
      if (finalState) _cycle(canvas, best, _stroke(fade(C.green, 0.18 + 0.2 * pulse), (11 + 5 * pulse) * unit));
      _cycle(canvas, best, _stroke(C.green, (finalState ? 5 : 4.2) * unit));
    }
    // Cycle ferme a cette etape : il clignote.
    if (v != null && v.closing.isNotEmpty) {
      _cycle(canvas, v.closing, _stroke(fade(C.amber, 0.35 + 0.4 * pulse), 8 * unit));
    }
    // Arete en cours d'examen : pointilles animes.
    if (v != null && v.u >= 0 && v.v >= 0) {
      final closes = v.closing.isNotEmpty;
      drawDashed(canvas, pts[v.u], pts[v.v], _stroke(closes ? C.amber : C.text, 3.4 * unit), dash: 9 * unit, gap: 7 * unit, phase: phase * 4);
    }
    if (dragFrom != null && dragTo != null) {
      drawDashed(canvas, dragFrom!, dragTo!, _stroke(C.cyan, 2.5 * unit), phase: phase * 4);
    }
    // Sommets
    for (var i = 0; i < g.n; i++) {
      final c = pts[i];
      var col = C.muted;
      var fill = C.card2;
      if (v != null && v.dist[i] >= 0) {
        col = _levelColors[v.dist[i] % _levelColors.length];
        fill = Color.lerp(C.card2, col, 0.28)!;
      }
      final inBest = best.contains(i);
      if (v != null && i == v.source) {
        canvas.drawCircle(c, radius * (1.9 + 0.5 * pulse), Paint()..color = fade(C.cyan, 0.12 + 0.1 * pulse));
        canvas.drawCircle(c, radius * 1.45, _stroke(fade(C.cyan, 0.5), 1.5 * unit));
      }
      canvas.drawCircle(c, radius * 1.35, Paint()..color = fade(col, 0.1)); // halo doux
      canvas.drawCircle(c, radius, Paint()..color = fill);
      canvas.drawCircle(c, radius, _stroke(inBest && (v == null || done) ? C.green : col, 2.4 * unit));
      if (v != null && i == v.u) canvas.drawCircle(c, radius * 1.22, _stroke(C.text, 2.2 * unit));
      if (v != null && i == v.v) canvas.drawCircle(c, radius * 1.22, _stroke(fade(C.text, 0.6), 1.6 * unit));
      drawText(canvas, '$i', c, kMono.copyWith(color: C.text, fontSize: radius * 0.82, fontWeight: FontWeight.w800), anchor: Alignment.center);
      if (v != null && v.dist[i] >= 0) {
        drawPill(canvas, i == v.source ? 'source' : 'd=${v.dist[i]}', c + Offset(0, radius + 11 * unit), color: col, size: max(9.5, 10 * unit));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) => true;
}
