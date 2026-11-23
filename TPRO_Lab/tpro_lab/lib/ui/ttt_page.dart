import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart' hide Step;
import 'package:flutter/services.dart';

import '../core/demo_content.dart';
import '../core/trace.dart';
import '../core/ttt_board.dart';
import '../core/ttt_engine.dart';
import '../core/ttt_net.dart';
import 'explain_panel.dart';
import 'kit.dart';
import 'lab_scaffold.dart';
import 'ttt_widgets.dart';

/// Bilan d'une recherche, garde pour l'affichage et la comparaison.
class SearchInfo {
  final SearchResult r;
  final int player, budgetMs, hmax, n;
  final String label;
  const SearchInfo(this.r, this.player, this.budgetMs, this.hmax, this.n, this.label);
}

class _LogLine {
  final DateTime t;
  final String dir, text;
  const _LogLine(this.t, this.dir, this.text);

  String get stamp {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.${t.millisecond.toString().padLeft(3, '0')}';
  }
}

class _Snapshot {
  final int n, m, turn, lastMove;
  final List<int> cells;
  final String? result;
  const _Snapshot(this.n, this.m, this.turn, this.lastMove, this.cells, this.result);
}

String _secs(int ms) => '${(ms / 1000).toStringAsFixed(1).replaceAll('.', ',')} s';

/// TP 3 — Morpion N x N : estimation, alpha-beta, approfondissement iteratif, alarme, client TCP.
class TttPage extends StatefulWidget {
  const TttPage({super.key});

  @override
  State<TttPage> createState() => TttPageState();
}

class TttPageState extends State<TttPage> with SingleTickerProviderStateMixin {
  static const _accent = C.violet;
  final LabHost host = LabHost();
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  final Stopwatch _clock = Stopwatch()..start();

  // Reglages
  int n = 7, m = 4, tmo = 3, hmax = 5, hmax2 = 1, fraction = 85;
  bool ordering = true, nearOnly = true, useTT = true, tactics = true;
  bool heat = false, showTree = true;

  /// 0 : moi contre l'IA ; 1 : IA contre IA ; 2 : reseau ; 3 : demonstration locale.
  int mode = 0;
  bool humanIsX = true;

  // Partie
  Board board = Board(7, 4);
  int turn = kX, lastMove = -1;
  final Map<int, int> _placedAt = {};
  String? resultText;
  int _gen = 0;
  bool running = false; // IA contre IA en cours
  Timer? _nextTimer;

  // Recherche
  bool thinking = false, explaining = false;
  int _thinkPlayer = kX, _thinkBudget = 0, _thinkStart = 0;
  SearchInfo? lastSearch, prevSearch;
  List<SearchTree> trees = const [];

  // Reseau
  final TextEditingController nameCtl = TextEditingController(text: 'TPRO-Lab');
  final TextEditingController hostCtl = TextEditingController(text: '127.0.0.1');
  final TextEditingController portCtl = TextEditingController(text: '12345');
  final ScrollController _logScroll = ScrollController();
  int indexBase = 0;
  TttClient? _client, _opponent;
  ServerControl? _server;
  bool netActive = false;
  int netMe = kX;
  final List<_LogLine> _log = [];
  int _tab = 0;

  EngineOptions get _opts => EngineOptions(ordering: ordering, nearOnly: nearOnly, useTT: useTT, tactics: tactics);
  int get _human => humanIsX ? kX : kO;
  int get _budget => TttClient.budgetFor(tmo, fraction / 100);
  String _sym(int p) => p == kX ? 'X' : 'O';

  @override
  void dispose() {
    _gen++;
    _nextTimer?.cancel();
    _client?.close();
    _opponent?.close();
    _server?.stop();
    _anim.dispose();
    nameCtl.dispose();
    hostCtl.dispose();
    portCtl.dispose();
    _logScroll.dispose();
    host.dispose();
    super.dispose();
  }

  void _set(VoidCallback f) {
    if (mounted) setState(f);
  }

  // ------------------------------------------------------------ partie locale

  void _clearTrace() {
    trees = const [];
    host.player.clear();
  }

  /// Remplace la position (nouvelle partie ou position d'un scenario).
  void _resetBoard({List<int>? cells, int? toMove}) {
    _gen++;
    _nextTimer?.cancel();
    running = false;
    thinking = false;
    explaining = false;
    board = cells == null ? Board(n, m) : Board.fromCells(n, m, cells);
    turn = toMove ?? kX;
    lastMove = -1;
    _placedAt.clear();
    resultText = null;
    _clearTrace();
  }

  _Snapshot _snapshot() => _Snapshot(n, m, turn, lastMove, List<int>.from(board.cells), resultText);

  void _restore(_Snapshot s) => _set(() {
        n = s.n;
        m = s.m;
        _resetBoard(cells: s.cells, toMove: s.turn);
        lastMove = s.lastMove;
        resultText = s.result;
      });

  /// Nouvelle partie en un clic, avec « Annuler ».
  void newGame({bool withToast = true, VoidCallback? change}) {
    if (netActive) _disconnect();
    final old = _snapshot();
    final hadMoves = board.count > 0;
    _set(() {
      change?.call();
      if (m > min(n, 6)) m = min(n, 6);
      _resetBoard();
    });
    if (withToast && hadMoves) toast(context, 'Nouvelle partie.', onUndo: () => _restore(old));
    _afterMove();
  }

  void _place(int cell, int p) {
    board.place(cell, p);
    lastMove = cell;
    _placedAt[cell] = _clock.elapsedMilliseconds;
    _clearTrace();
  }

  void _checkEnd() {
    final st = board.status();
    if (st == 0) return;
    running = false;
    resultText = st == 3 ? 'Partie nulle' : '${_sym(st)} gagne : $m symboles alignés';
    if (st != 3) host.tick('align');
  }

  /// Apres un coup : fin de partie, ou au tour de l'IA.
  void _afterMove() {
    if (!mounted) return;
    _set(_checkEnd);
    if (board.status() != 0 || netActive) return;
    if (mode == 1 && running) {
      if (hmax != hmax2 && board.count >= 4) host.tick('hmax');
      _nextTimer?.cancel();
      _nextTimer = Timer(const Duration(milliseconds: 350), _aiMove);
    } else if (mode == 0 && turn != _human) {
      _aiMove();
    }
  }

  void _startThinking(int p, int budget) {
    thinking = true;
    _thinkPlayer = p;
    _thinkBudget = budget;
    _thinkStart = _clock.elapsedMilliseconds;
  }

  void _record(SearchResult r, int p, int budget, int h, {String? label}) {
    prevSearch = lastSearch;
    lastSearch = SearchInfo(r, p, budget, h, n, label ?? (ordering ? 'avec tri' : 'sans tri'));
    host.tick('estim');
    if (r.iters.where((i) => i.completed).length >= 2) host.tick('iter');
    if (r.timedOut) host.tick('alarm');
  }

  Future<void> _aiMove() async {
    if (!mounted || thinking || explaining || netActive || board.status() != 0) return;
    final gen = _gen, p = turn;
    final h = mode == 1 ? (p == kX ? hmax : hmax2) : hmax;
    final budget = _budget;
    _set(() => _startThinking(p, budget));
    SearchResult r;
    try {
      r = await thinkInIsolate(n, m, board.cells, p, h, budget, options: _opts);
    } catch (e) {
      if (mounted && gen == _gen) {
        _set(() => thinking = false);
        toast(context, 'La recherche a échoué : $e', error: true);
      }
      return;
    }
    if (!mounted || gen != _gen) return;
    _set(() {
      thinking = false;
      if (r.move < 0) return;
      _record(r, p, budget, h);
      _place(r.move, p);
      turn = 3 - p;
    });
    _afterMove();
  }

  void _tapCell(Offset local, Size size) {
    if (mode != 0 || netActive || thinking || explaining || board.status() != 0 || turn != _human) return;
    final cell = boardCellAt(size, n, local);
    if (cell < 0 || board.cells[cell] != kEmpty) return;
    setState(() {
      _place(cell, turn);
      turn = 3 - turn;
    });
    _afterMove();
  }

  void toggleAiVsAi() {
    if (netActive) return;
    if (running) {
      _nextTimer?.cancel();
      setState(() => running = false);
      return;
    }
    setState(() {
      mode = 1;
      if (board.status() != 0) _resetBoard();
      running = true;
    });
    _aiMove();
  }

  // ------------------------------------------------------------ mode pas a pas

  /// Recherche tracee du prochain coup : charge la trace et l'arbre, sans jouer le coup.
  Future<void> explain() async {
    if (thinking || explaining || netActive) return;
    if (board.status() != 0) {
      toast(context, 'La partie est terminée : lancez une nouvelle partie pour expliquer un coup.');
      return;
    }
    final gen = _gen, p = turn;
    final h = mode == 1 ? (p == kX ? hmax : hmax2) : hmax;
    _nextTimer?.cancel();
    _set(() {
      running = false;
      explaining = true;
    });
    try {
      final (r, t, trs) = await thinkTracedInIsolate(n, m, board.cells, p, h, 120000, options: _opts, treePly: 2);
      if (!mounted || gen != _gen) return;
      _set(() {
        explaining = false;
        _record(r, p, 0, h);
        trees = trs;
        showTree = true;
      });
      host.tab.value = 0;
      host.player.load(t.steps);
    } catch (e) {
      if (mounted && gen == _gen) {
        _set(() => explaining = false);
        toast(context, 'La recherche tracée a échoué : $e', error: true);
      }
    }
  }

  /// Recherche sans jouer le coup, pour comparer des reglages sur la meme position.
  Future<void> _analyze(String label, EngineOptions opt) async {
    final gen = _gen, p = turn;
    _set(() => _startThinking(p, 20000));
    final r = await thinkInIsolate(n, m, board.cells, p, hmax, 20000, options: opt);
    if (!mounted || gen != _gen) return;
    _set(() {
      thinking = false;
      _record(r, p, 20000, hmax, label: label);
    });
  }

  // ------------------------------------------------------------ reseau

  void _addLog(String line) {
    if (!mounted) return;
    final dir = line.isNotEmpty && '<>#'.contains(line[0]) ? line[0] : '#';
    final text = line.length > 2 && '<>#'.contains(line[0]) ? line.substring(2) : line;
    setState(() {
      _log.add(_LogLine(DateTime.now(), dir, text));
      if (_log.length > 600) _log.removeRange(0, 100);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
    });
  }

  int? _port() {
    final p = int.tryParse(portCtl.text.trim());
    if (p == null || p < 1 || p > 65535) {
      toast(context, 'Port invalide : entrez un entier entre 1 et 65535.', error: true);
      return null;
    }
    return p;
  }

  TttClient _makeClient(String name, String hostName, int port, int h) {
    final opt = _opts;
    return TttClient(
      name: name,
      host: hostName,
      port: port,
      hmax: h,
      indexBase: indexBase,
      timeFraction: fraction / 100,
      thinker: (b, p, hm, t) => thinkInIsolate(b.n, b.m, b.cells, p, hm, t, options: opt),
    );
  }

  /// Lance mon client (celui qui est affiche) ; retourne quand la partie est finie.
  Future<void> _runMyClient(String hostName, int port) async {
    final c = _client = _makeClient(nameCtl.text.trim().isEmpty ? 'TPRO-Lab' : nameCtl.text.trim(), hostName, port, hmax);
    final gen = _gen;
    bool live() => mounted && gen == _gen;
    c.onLog = (l) {
      if (live()) _addLog(l);
    };
    c.onStart = (nn, mm, t, me) {
      if (!live()) return;
      setState(() {
        n = nn;
        m = mm;
        tmo = t;
        netMe = me;
        board = Board(nn, mm);
        turn = kX;
        lastMove = -1;
        _placedAt.clear();
        resultText = null;
        _clearTrace();
      });
      _addLog('# partie : N=$nn, M=$mm, TMO=$t s — je joue ${_sym(me)}');
    };
    c.onMove = (cell, p) {
      if (!live() || cell < 0 || cell >= board.cells.length || board.cells[cell] != kEmpty) return;
      setState(() {
        _place(cell, p);
        turn = 3 - p;
      });
    };
    c.onTurn = (p, budget) {
      if (!live()) return;
      setState(() {
        if (budget > 0) {
          _startThinking(p, budget);
        } else {
          thinking = false;
        }
      });
    };
    c.onThought = (r) {
      if (!live()) return;
      setState(() => _record(r, netMe, _budget, hmax));
      _addLog('# profondeur ${r.depth}, ${r.nodes} nœuds, ${r.millis} ms${r.timedOut ? ', interrompu par l\'alarme' : ''}');
    };
    c.onGameOver = (v) {
      if (!live()) return;
      final mine = v == 0 ? 'partie nulle' : ((v == 1) == (netMe == kX) ? 'j\'ai gagné' : 'j\'ai perdu');
      setState(() {
        thinking = false;
        resultText = 'gameover cost = $v → ${v == 0 ? 'nulle' : (v == 1 ? 'X gagne' : 'O gagne')} ($mine)';
        if (board.status() == kX || board.status() == kO) host.tick('align');
      });
      host.tick('net');
    };
    try {
      await c.run();
    } on SocketException catch (e) {
      if (live()) {
        _addLog('# connexion impossible : ${e.message}');
        toast(context, 'Serveur injoignable ($hostName:$port). Vérifiez l\'adresse, le port et que le serveur est lancé.', error: true);
      }
    } catch (e) {
      if (live()) _addLog('# erreur : $e');
    }
  }

  void _beginNet(int newMode) {
    _gen++;
    _nextTimer?.cancel();
    running = false;
    thinking = false;
    explaining = false;
    mode = newMode;
    netActive = true;
    _tab = 1;
    resultText = null;
    _clearTrace();
  }

  void _endNet(int gen) {
    if (!mounted || gen != _gen) return;
    setState(() {
      netActive = false;
      thinking = false;
    });
  }

  /// Mode reseau : se connecte au serveur du professeur (ou a tout serveur du protocole).
  Future<void> connect() async {
    if (netActive) return;
    final port = _port();
    if (port == null) return;
    final h = hostCtl.text.trim().isEmpty ? '127.0.0.1' : hostCtl.text.trim();
    setState(() => _beginNet(2));
    final gen = _gen;
    _addLog('# connexion à $h:$port (indices à partir de $indexBase, HMAX = $hmax)');
    await _runMyClient(h, port);
    _endNet(gen);
  }

  /// Demonstration locale : serveur integre + adversaire automatique + mon client.
  Future<void> startLocal() async {
    if (netActive) return;
    final port = _port();
    if (port == null) return;
    setState(() => _beginNet(3));
    final gen = _gen;
    final ctl = _server = ServerControl();
    final ready = Completer<void>();
    final srv = runTttServer(
      n: n,
      m: m,
      tmo: tmo,
      port: port,
      indexBase: indexBase,
      ready: ready,
      control: ctl,
      log: (s) {
        if (mounted && gen == _gen) _addLog('# serveur : $s');
      },
    );
    unawaited(srv.then<void>((_) {}, onError: (Object e) {
      if (!ready.isCompleted) {
        ready.completeError(e);
      } else if (mounted && gen == _gen) {
        _addLog('# serveur arrêté : $e');
      }
    }));
    try {
      await ready.future;
    } catch (e) {
      if (!mounted) return;
      if (gen == _gen) {
        _addLog('# impossible d\'ouvrir le port $port : ${e is SocketException ? e.message : e}');
        toast(context, 'Le port $port est déjà utilisé : fermez l\'autre serveur ou changez de port.', error: true);
      }
      _endNet(gen);
      return;
    }
    // Mon client se connecte en premier (il joue X), l'adversaire automatique ensuite.
    final mine = _runMyClient('127.0.0.1', port);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted && gen == _gen) {
      final opp = _opponent = _makeClient('Adversaire (HMAX $hmax2)', '127.0.0.1', port, hmax2);
      unawaited(opp.run().catchError((Object _) {}));
    }
    await mine;
    ctl.stop();
    _endNet(gen);
  }

  void _disconnect() {
    if (!netActive) return;
    _gen++;
    _client?.close();
    _opponent?.close();
    _server?.stop();
    _set(() {
      netActive = false;
      thinking = false;
    });
    _addLog('# déconnecté');
  }

  // ------------------------------------------------------------ scenarios, enonce

  Future<void> loadScenario(int i) async {
    if (netActive) _disconnect();
    switch (i) {
      case 0:
        setState(() {
          mode = 0;
          humanIsX = true;
          n = 3;
          m = 3;
          hmax = 4;
          tactics = false;
          useTT = false;
          ordering = true;
          nearOnly = true;
          _tab = 0;
          _resetBoard(cells: kTttDemoCells, toMove: kX);
        });
        await explain();
      case 1:
        setState(() {
          n = 7;
          m = 4;
          tmo = 3;
          hmax = 5;
          hmax2 = 1;
          ordering = nearOnly = useTT = tactics = true;
          mode = 1;
          _tab = 0;
          _resetBoard();
        });
        toggleAiVsAi();
      case 2:
        setState(() {
          n = 9;
          m = 5;
          tmo = 1;
          hmax = 20;
          ordering = nearOnly = useTT = tactics = true;
          mode = 0;
          humanIsX = false;
          _tab = 2;
          final cells = List<int>.filled(81, kEmpty);
          cells[40] = kX;
          cells[31] = kO;
          _resetBoard(cells: cells, toMove: kX);
        });
        _afterMove();
      case 3:
        setState(() {
          n = 7;
          m = 4;
          tmo = 3;
          hmax = 4;
          nearOnly = useTT = tactics = true;
          ordering = false;
          mode = 0;
          humanIsX = true;
          _tab = 2;
          final cells = List<int>.filled(49, kEmpty);
          cells[24] = kX;
          cells[25] = kX;
          cells[17] = kO;
          cells[23] = kO;
          cells[31] = kX;
          cells[32] = kO;
          _resetBoard(cells: cells, toMove: kX);
          lastSearch = null;
          prevSearch = null;
        });
        await _analyze('avec tri', const EngineOptions());
        await _analyze('sans tri', const EngineOptions(ordering: false));
      default:
        setState(() => _tab = 1);
        await startLocal();
    }
  }

  void _requirement(String req) {
    host.bottomOpen.value = true;
    switch (req) {
      case 'estim' || 'alarm':
        host.tab.value = 0;
      case 'net':
        setState(() => _tab = 1);
      case 'iter':
        setState(() => _tab = 2);
      case 'hmax':
        setState(() => _tab = 0);
    }
    host.spotlight(req);
  }

  // ------------------------------------------------------------ interface

  @override
  Widget build(BuildContext context) {
    return LabScaffold(
      labIndex: 3,
      content: kTttLab,
      host: host,
      pseudo: kTttPseudo,
      pseudoTitle: 'alpha-bêta + approfondissement itératif',
      onScenario: loadScenario,
      onRequirement: _requirement,
      counters: _counters,
      extra: _extra,
      idleText: 'Jouez un coup, ou « Expliquer le prochain coup » : la recherche alpha-bêta sera détaillée ici, étape par étape.',
      transportHint: '« Expliquer le prochain coup » pour rejouer la recherche pas à pas',
      canvas: _canvas(),
      bottom: _bottom(),
    );
  }

  Map<String, String> _counters() {
    final v = host.player.current?.view;
    final s = lastSearch;
    return {
      'nœuds explorés': v is TttView ? '${v.nodes}' : (s == null ? '—' : '${s.r.nodes}'),
      'coupes α/β': v is TttView ? '${v.cuts}' : (s == null ? '—' : '${s.r.cuts}'),
      'profondeur': v is TttView ? '${v.depth}' : (s == null ? '—' : '${s.r.depth}'),
      if (s != null) 'temps': s.budgetMs > 0 ? '${_secs(s.r.millis)} / ${_secs(tmo * 1000)}' : _secs(s.r.millis),
      'coups joués': '${board.count}',
    };
  }

  /// Position avec les coups hypothetiques de l'etape courante (pour l'estimation).
  Board _shownBoard(TttView? v) {
    if (v == null || v.path.isEmpty) return board;
    final b = Board.fromCells(n, m, board.cells);
    var p = v.rootPlayer;
    for (final c in v.path) {
      if (c >= 0 && c < b.cells.length && b.cells[c] == kEmpty) b.place(c, p);
      p = 3 - p;
    }
    return b;
  }

  String _sentence(SearchInfo s) {
    final r = s.r;
    final t = _secs(r.millis);
    if (r.iters.isEmpty) return 'Un seul coup utile dans cette position : il est joué sans recherche.';
    if (r.timedOut) {
      return r.depth == 0
          ? 'L\'alarme a sonné avant la fin de la profondeur 1 ($t) : on joue le coup légal retenu au départ.'
          : 'Profondeur ${r.depth} atteinte en $t ; la profondeur ${r.depth + 1} a été interrompue par l\'alarme, on joue le coup de la profondeur ${r.depth}.';
    }
    if (r.depth >= s.hmax) return 'Profondeur ${r.depth} (HMAX) atteinte en $t, sans interruption : on joue le coup de cette profondeur.';
    return 'Recherche arrêtée à la profondeur ${r.depth} en $t : l\'issue est forcée (gain ou perte), inutile d\'aller plus loin.';
  }

  String _move(int cell, int nn) => cell < 0 ? '—' : '(${cell ~/ nn + indexBaseShown}, ${cell % nn + indexBaseShown})';
  int get indexBaseShown => netActive ? indexBase : 0;

  Widget _iterTable(SearchInfo s) => MiniTable(
        headers: const ['prof.', 'meilleur coup', 'score', 'nœuds', 'temps', 'terminée'],
        highlight: s.r.iters.lastIndexWhere((i) => i.completed),
        rows: [
          for (final it in s.r.iters)
            [
              '${it.depth}',
              _move(it.move, s.n),
              it.completed ? fmtScore(s.player == kX ? it.score : -it.score) : '—',
              '${it.nodes}',
              '${it.millis} ms',
              it.completed ? 'oui' : 'alarme',
            ],
        ],
      );

  Widget _extra(BuildContext context, Step? step) {
    final view = step?.view is TttView ? step!.view as TttView : null;
    final shown = _shownBoard(view);
    final rows = estimationTable(shown);
    final e = shown.estimation(Board.defaultWeights(m));
    final s = lastSearch;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (s != null) ...[
        PanelSection(
          title: 'Dernière recherche · ${_sym(s.player)} · HMAX ${s.hmax}',
          accent: _accent,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_sentence(s), style: const TextStyle(color: C.text, fontSize: 13, height: 1.4)),
            if (s.r.iters.isNotEmpty) ...[const SizedBox(height: 8), _iterTable(s)],
          ]),
        ),
        const SizedBox(height: 14),
      ],
      SpotTarget(
        host: host,
        ids: const ['estim'],
        color: _accent,
        radius: 10,
        child: PanelSection(
          title: 'Fonction d\'estimation${view != null && view.path.isNotEmpty ? ' · position explorée' : ''}',
          accent: _accent,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Fenêtres de $m cases alignées (4 directions). Une fenêtre contenant les deux symboles vaut 0.',
                style: const TextStyle(color: C.muted, fontSize: 11.5, height: 1.35)),
            const SizedBox(height: 6),
            MiniTable(
              headers: const ['k', 'poids', 'fen. X', 'fen. O', 'contribution'],
              rows: [
                for (final r in rows) ['${r.k}', '${r.weight}', '${r.xWindows}', '${r.oWindows}', '${r.contribution}'],
              ],
            ),
            const SizedBox(height: 6),
            Text('E = Σ poids(k) × (fenêtres X − fenêtres O) = $e',
                style: kMono.copyWith(color: e > 0 ? kXColor : (e < 0 ? kOColor : C.text), fontSize: 12.5, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      SpotTarget(
        host: host,
        ids: const ['alarm'],
        color: _accent,
        radius: 10,
        child: PanelSection(
          title: 'Alarme : équivalence avec le C',
          accent: _accent,
          child: MiniTable(headers: const [
            'programme C',
            'ce client (Dart)'
          ], rows: [
            const ['alarm(TMO)', 'échéance (chronomètre)'],
            const ['SIGALRM', 'exception d\'interruption'],
            const ['le handler', 'meilleur coup de la dernière'],
            const ['', 'profondeur terminée'],
            ['marge', '$fraction % de TMO = ${_secs(_budget)}'],
          ]),
        ),
      ),
    ]);
  }

  // ------------------------------------------------------------ scene

  Widget _canvas() {
    return AnimatedBuilder(
      animation: Listenable.merge([_anim, host.player]),
      builder: (context, _) {
        final step = host.player.current;
        final view = step?.view is TttView ? step!.view as TttView : null;
        final tree = view != null && view.tree >= 0 && view.tree < trees.length ? trees[view.tree] : null;
        final now = _clock.elapsedMilliseconds;
        final progress = <int, double>{};
        _placedAt.forEach((c, t) {
          final f = (now - t) / 260;
          if (f < 1) progress[c] = f.clamp(0.0, 1.0);
        });
        final shown = _shownBoard(view);
        final e = shown.estimation(Board.defaultWeights(m));
        final st = shown.status();
        final scale = Board.defaultWeights(m)[m - 1] * 3.0;
        final share = st == kX ? 1.0 : (st == kO ? 0.0 : 0.5 + 0.5 * e.sign * min(1.0, log(1 + e.abs()) / log(1 + scale)));
        final player = turn;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 30, 12, 26),
          child: Stack(clipBehavior: Clip.none, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: EvalBar(share: share, label: st == kX ? 'gain X' : (st == kO ? 'gain O' : (e > 0 ? '+$e' : '$e'))),
              ),
              Expanded(
                flex: 5,
                child: LayoutBuilder(builder: (context, box) {
                  return MouseRegion(
                    cursor: mode == 0 && !thinking && turn == _human && board.status() == 0 ? SystemMouseCursors.click : SystemMouseCursors.basic,
                    child: GestureDetector(
                      key: const Key('ttt-board'),
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) => _tapCell(d.localPosition, box.biggest),
                      child: CustomPaint(
                        size: box.biggest,
                        painter: BoardPainter(
                          n: n,
                          cells: board.cells,
                          lastMove: lastMove,
                          winCells: board.winningCells(),
                          heat: heat && board.status() == 0 && view == null ? moveScores(board, player) : null,
                          ghost: view?.path ?? const [],
                          ghostFirst: view?.rootPlayer ?? kX,
                          bestMove: view?.bestMove ?? -1,
                          progress: progress,
                          phase: _anim.value,
                          labelBase: indexBaseShown,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              if (tree != null && showTree) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 6,
                  child: SearchTreeView(
                    key: const Key('ttt-tree'),
                    tree: tree,
                    seq: step!.seq,
                    current: view!.node,
                    boardN: n,
                    onClose: () => setState(() => showTree = false),
                  ),
                ),
              ],
            ]),
            Positioned(
              left: 0,
              top: -22,
              child: IgnorePointer(
                child: Text(
                    'N = $n · M = $m · TMO = $tmo s · ${const ['Moi contre l\'IA', 'IA contre IA', 'Réseau', 'Démonstration locale'][mode]}'
                    '${board.status() == 0 ? ' · trait à ${_sym(turn)}' : ''}',
                    style: kMono.copyWith(color: C.muted, fontSize: 11.5)),
              ),
            ),
            Positioned(right: 0, top: -24, child: _badge()),
            if (thinking || explaining)
              Positioned(
                right: tree != null && showTree ? null : 4,
                left: tree != null && showTree ? 48 : null,
                top: 18,
                child: SpotTarget(host: host, ids: const ['alarm'], color: _accent, radius: 30, child: _ring(now)),
              ),
            Positioned(
              left: 0,
              bottom: -24,
              child: Row(children: [
                ChipBtn(
                    label: 'Carte de chaleur',
                    icon: Icons.local_fire_department_outlined,
                    color: C.amber,
                    active: heat,
                    tip: 'Teinte chaque case vide selon son score de tri des coups',
                    onTap: () => setState(() => heat = !heat)),
                if (tree != null && !showTree) ...[
                  const SizedBox(width: 6),
                  ChipBtn(label: 'Arbre de recherche', icon: Icons.account_tree_outlined, color: _accent, onTap: () => setState(() => showTree = true)),
                ],
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _ring(int now) {
    if (explaining) {
      return const CountdownRing(remaining: 1, label: '…', caption: 'recherche tracée');
    }
    final left = max(0, _thinkBudget - (now - _thinkStart));
    return CountdownRing(
      remaining: _thinkBudget <= 0 ? 0 : left / _thinkBudget,
      label: _secs(left),
      caption: '${_sym(_thinkPlayer)} réfléchit',
    );
  }

  Widget _badge() {
    final t = resultText;
    if (t == null) return const SizedBox.shrink();
    final draw = t.contains('nulle');
    final color = draw ? C.amber : C.green;
    return SpotTarget(
      host: host,
      ids: const ['align'],
      color: _accent,
      radius: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: fade(color, 0.14), borderRadius: BorderRadius.circular(10), border: Border.all(color: fade(color, 0.7))),
        child: Text(t, style: kMono.copyWith(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
      ),
    );
  }

  // ------------------------------------------------------------ zone basse

  Widget _bottom() => BottomTabs(
        tabs: const ['Partie', 'Réseau', 'Résultats'],
        index: _tab,
        accent: _accent,
        onChanged: (i) => setState(() => _tab = i),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          ChipBtn(label: 'Nouvelle partie', icon: Icons.refresh_rounded, color: _accent, onTap: () => newGame()),
          const SizedBox(width: 8),
          ChipBtn(
              label: 'Expliquer le prochain coup (pas à pas)',
              icon: Icons.account_tree_outlined,
              color: _accent,
              active: true,
              tip: 'Recherche tracée : pseudo-code, α/β et arbre, sans jouer le coup',
              onTap: thinking || explaining || netActive ? null : explain),
        ]),
        children: [_gameTab(), _netTab(), _resultTab()],
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(color: C.muted, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
      );

  Widget _gameTab() {
    final lock = netActive;
    Widget stepper(String label, int value, int lo, int hi, ValueChanged<int> on, {String Function(int)? fmt, int step = 1, double w = 176}) =>
        SizedBox(width: w, child: NumStepper(label: label, value: value, min: lo, max: hi, step: step, format: fmt, enabled: !lock, onChanged: on));
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        flex: 7,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SegBar(
              options: const ['Moi contre l\'IA', 'IA contre IA', 'Réseau', 'Démo locale'],
              index: mode,
              color: _accent,
              onChanged: (i) {
                if (i == mode) return;
                if (netActive) _disconnect();
                _nextTimer?.cancel();
                setState(() {
                  running = false;
                  mode = i;
                  if (i >= 2) _tab = 1;
                });
              },
            ),
            const SizedBox(height: 8),
            if (mode == 0)
              Row(children: [
                const Text('Je joue', style: TextStyle(color: C.text, fontSize: 13)),
                const SizedBox(width: 10),
                SizedBox(
                  width: 210,
                  child: SegBar(
                      options: const ['X (je commence)', 'O'],
                      index: humanIsX ? 0 : 1,
                      color: _accent,
                      onChanged: (i) {
                        setState(() => humanIsX = i == 0);
                        _afterMove();
                      }),
                ),
              ])
            else if (mode == 1)
              Row(children: [
                ChipBtn(
                    label: running ? 'Pause' : (board.status() != 0 ? 'Rejouer' : 'Démarrer'),
                    icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: _accent,
                    active: true,
                    onTap: toggleAiVsAi),
                const SizedBox(width: 10),
                Expanded(child: Text('X : HMAX $hmax   ·   O : HMAX $hmax2', style: kMono.copyWith(color: C.muted, fontSize: 12))),
              ])
            else
              const Text('Les réglages de connexion sont dans l\'onglet « Réseau ».', style: TextStyle(color: C.muted, fontSize: 12.5)),
            const SizedBox(height: 4),
            SpotTarget(
              host: host,
              ids: const ['hmax'],
              color: _accent,
              radius: 10,
              child: Wrap(spacing: 14, children: [
                stepper('N', n, 3, 15, (v) => newGame(change: () => n = v)),
                stepper('M', m, 3, min(n, 6), (v) => newGame(change: () => m = v)),
                stepper('TMO', tmo, 1, 30, (v) => setState(() => tmo = v), fmt: (v) => '$v s'),
                stepper('HMAX', hmax, 1, 30, (v) => setState(() => hmax = v)),
                stepper('HMAX adversaire', hmax2, 1, 30, (v) => setState(() => hmax2 = v), w: 230),
                stepper('Part de TMO utilisée', fraction, 50, 95, (v) => setState(() => fraction = v), fmt: (v) => '$v %', step: 5, w: 250),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        flex: 3,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 6),
          decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(12)),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('ACCÉLÉRATIONS DE LA RECHERCHE'),
              Toggle(label: 'Tri des coups', value: ordering, color: _accent, onChanged: lock ? null : (v) => setState(() => ordering = v)),
              Toggle(label: 'Cases proches seulement', value: nearOnly, color: _accent, onChanged: lock ? null : (v) => setState(() => nearOnly = v)),
              Toggle(label: 'Table de transposition', value: useTT, color: _accent, onChanged: lock ? null : (v) => setState(() => useTT = v)),
              Toggle(label: 'Gain immédiat / blocage forcé', value: tactics, color: _accent, onChanged: lock ? null : (v) => setState(() => tactics = v)),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _netTab() {
    final lock = netActive;
    return SpotTarget(
      host: host,
      ids: const ['net'],
      color: _accent,
      radius: 12,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DarkField(controller: nameCtl, hint: 'Nom du joueur', enabled: !lock),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(flex: 3, child: DarkField(controller: hostCtl, hint: 'Adresse du serveur', mono: true, enabled: !lock)),
                const SizedBox(width: 6),
                Expanded(flex: 2, child: DarkField(controller: portCtl, hint: 'Port', mono: true, enabled: !lock)),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Expanded(child: Text('Indices à partir de', style: TextStyle(color: C.text, fontSize: 12.5))),
                SizedBox(
                    width: 110,
                    child: SegBar(options: const ['0', '1'], index: indexBase, color: _accent, enabled: !lock, onChanged: (i) => setState(() => indexBase = i))),
              ]),
              const SizedBox(height: 6),
              if (!lock) ...[
                Row(children: [
                  Expanded(child: ChipBtn(label: 'Se connecter', icon: Icons.link_rounded, color: _accent, active: true, onTap: connect)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ChipBtn(
                        label: 'Démo locale',
                        icon: Icons.dns_outlined,
                        color: _accent,
                        tip: 'Serveur intégré (N=$n, M=$m, TMO=$tmo s) + adversaire automatique HMAX $hmax2',
                        onTap: startLocal),
                  ),
                ]),
              ] else
                ChipBtn(
                    label: mode == 3 ? 'Arrêter la démonstration locale' : 'Déconnecter',
                    icon: Icons.link_off_rounded,
                    color: C.red,
                    active: true,
                    onTap: _disconnect),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 4, 2),
                child: Row(children: [
                  const Expanded(
                    child: Text('JOURNAL DU PROTOCOLE   > envoyé   < reçu   # info',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: C.muted, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  ),
                  IconBtn(
                      icon: Icons.copy_rounded,
                      tip: 'Copier le journal',
                      size: 26,
                      onTap: _log.isEmpty
                          ? null
                          : () {
                              Clipboard.setData(ClipboardData(text: _log.map((l) => '${l.stamp} ${l.dir} ${l.text}').join('\n')));
                              toast(context, 'Journal copié dans le presse-papiers.');
                            }),
                  const SizedBox(width: 4),
                  IconBtn(icon: Icons.delete_outline_rounded, tip: 'Effacer le journal', size: 26, onTap: _log.isEmpty ? null : () => setState(_log.clear)),
                ]),
              ),
              Expanded(
                child: _log.isEmpty
                    ? const Center(
                        child: Text('Aucun message : connectez-vous ou lancez la démonstration locale.', style: TextStyle(color: C.muted, fontSize: 12)))
                    : ListView.builder(
                        controller: _logScroll,
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                        itemCount: _log.length,
                        itemBuilder: (_, i) {
                          final l = _log[i];
                          final col = l.dir == '>' ? kXColor : (l.dir == '<' ? C.green : C.muted);
                          return Text.rich(
                            TextSpan(children: [
                              TextSpan(text: '${l.stamp}  ', style: TextStyle(color: fade(C.muted, 0.7))),
                              TextSpan(text: '${l.dir} ', style: TextStyle(color: col, fontWeight: FontWeight.w800)),
                              TextSpan(text: l.text, style: TextStyle(color: l.dir == '#' ? C.muted : C.text)),
                            ]),
                            style: kMono.copyWith(fontSize: 11.5, height: 1.4),
                          );
                        }),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _resultTab() {
    final s = lastSearch, p = prevSearch;
    if (s == null) {
      return const EmptyState(icon: Icons.insights_outlined, text: 'Aucune recherche pour le moment : jouez un coup ou lancez une partie IA contre IA.', color: _accent);
    }
    final comparable = p != null && p.n == s.n;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        flex: 5,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StatRow([
              Stat(label: 'profondeur atteinte', value: '${s.r.depth}', color: _accent),
              Stat(label: 'nœuds explorés', value: '${s.r.nodes}'),
              Stat(label: 'coupes α/β', value: '${s.r.cuts}'),
              Stat(label: s.budgetMs > 0 ? 'temps / TMO' : 'temps', value: s.budgetMs > 0 ? '${_secs(s.r.millis)} / $tmo s' : _secs(s.r.millis)),
              Stat(label: 'score (vu de X)', value: fmtScore(s.player == kX ? s.r.score : -s.r.score)),
            ]),
            const SizedBox(height: 8),
            Text('${_sym(s.player)} joue ${_move(s.r.move, s.n)} — ${_sentence(s)}', style: const TextStyle(color: C.text, fontSize: 12.8, height: 1.4)),
            if (comparable) ...[
              const SizedBox(height: 8),
              MiniTable(headers: const [
                'comparaison',
                'profondeur',
                'nœuds',
                'coupes',
                'temps'
              ], rows: [
                ['précédente (${p.label})', '${p.r.depth}', '${p.r.nodes}', '${p.r.cuts}', '${p.r.millis} ms'],
                ['dernière (${s.label})', '${s.r.depth}', '${s.r.nodes}', '${s.r.cuts}', '${s.r.millis} ms'],
              ]),
            ],
          ]),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        flex: 4,
        child: SpotTarget(
          host: host,
          ids: const ['iter'],
          color: _accent,
          radius: 10,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('APPROFONDISSEMENT ITÉRATIF'),
              if (s.r.iters.isEmpty) const Text('Coup unique : aucune itération.', style: TextStyle(color: C.muted, fontSize: 12)) else _iterTable(s),
            ]),
          ),
        ),
      ),
    ]);
  }
}
