import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/ttt_board.dart';
import '../core/ttt_engine.dart';
import '../core/ttt_net.dart';
import 'kit.dart';

class TttPage extends StatefulWidget {
  const TttPage({super.key});

  @override
  State<TttPage> createState() => _TttPageState();
}

class _TttPageState extends State<TttPage> with SingleTickerProviderStateMixin {
  int _mode = 0; // 0 : humain contre IA, 1 : IA contre IA, 2 : reseau
  int _n = 7, _m = 4, _tmo = 3, _hmax = 6, _hmax2 = 2;
  int _humanSide = kX;
  int _base = 0;
  bool _heat = true;

  Board _board = Board(7, 4);
  int _turn = kX;
  int _last = -1;
  int _game = 0; // identifiant de partie : invalide les recherches en cours quand on recommence
  bool _thinking = false;
  int _status = 0;
  SearchResult? _lastSearch;
  int _netMe = 0;
  bool _netActive = false;
  TttClient? _client;
  final List<String> _log = [];
  final ScrollController _logScroll = ScrollController();

  final _name = TextEditingController(text: 'TPRO-Lab');
  final _host = TextEditingController(text: '127.0.0.1');
  final _port = TextEditingController(text: '12345');

  late final AnimationController _clock = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void dispose() {
    _game++;
    _client?.close();
    _clock.dispose();
    _logScroll.dispose();
    _name.dispose();
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  void _say(String s) {
    if (!mounted) return;
    setState(() {
      _log.add(s);
      if (_log.length > 300) _log.removeRange(0, 100);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
    });
  }

  void _startClock() {
    _clock.duration = Duration(seconds: _tmo);
    _clock.forward(from: 0);
  }

  // ------------------------------------------------------------ parties locales

  void _newGame() {
    _client?.close();
    _client = null;
    _netActive = false;
    _game++;
    setState(() {
      _board = Board(_n, _m);
      _turn = kX;
      _last = -1;
      _status = 0;
      _thinking = false;
      _lastSearch = null;
      _log.clear();
    });
    _clock.stop();
    _say('Nouvelle partie : grille $_n x $_n, aligner $_m, TMO = ${_tmo}s');
    if (_mode == 1 || (_mode == 0 && _humanSide != kX)) _aiMove();
  }

  bool _isAi(int player) => _mode == 1 || (_mode == 0 && player != _humanSide);

  void _humanTap(int cell) {
    if (_mode != 0 || _thinking || _status != 0 || _turn != _humanSide || _board.cells[cell] != kEmpty) return;
    _apply(cell, _turn);
    if (_status == 0) _aiMove();
  }

  void _apply(int cell, int player) {
    setState(() {
      _board.place(cell, player);
      _last = cell;
      _turn = 3 - player;
      _status = _board.status();
    });
    final sym = player == kX ? 'X' : 'O';
    _say('$sym at ${cell ~/ _board.n} ${cell % _board.n}');
    if (_status != 0) {
      _clock.stop();
      _say(_status == 3 ? 'Partie nulle (cout = 0)' : (_status == kX ? 'X gagne (cout = 1)' : 'O gagne (cout = -1)'));
    }
  }

  Future<void> _aiMove() async {
    final id = _game;
    final player = _turn;
    final hmax = (_mode == 1 && player == kO) ? _hmax2 : _hmax;
    setState(() => _thinking = true);
    _startClock();
    final sw = Stopwatch()..start();
    final r = await thinkInIsolate(_board.n, _board.m, _board.cells, player, hmax, (_tmo * 900).clamp(100, 60000));
    if (_mode == 1 && sw.elapsedMilliseconds < 350) {
      await Future<void>.delayed(Duration(milliseconds: 350 - sw.elapsedMilliseconds));
    }
    if (!mounted || id != _game) return;
    setState(() {
      _thinking = false;
      _lastSearch = r;
    });
    if (r.move < 0) return;
    _say('   ${player == kX ? 'X' : 'O'} : profondeur ${r.depth}, ${r.nodes} noeuds, ${r.millis} ms, score ${r.score}');
    _apply(r.move, player);
    if (_status == 0 && _isAi(_turn)) _aiMove();
  }

  // ------------------------------------------------------------ mode reseau

  Future<void> _connect({String? name, int? hmax, bool show = true}) async {
    final port = int.tryParse(_port.text.trim()) ?? 12345;
    final c = TttClient(name: name ?? _name.text.trim(), host: _host.text.trim(), port: port, hmax: hmax ?? _hmax, indexBase: _base);
    if (show) {
      _client?.close();
      _client = c;
      _game++;
      setState(() {
        _netActive = true;
        _status = 0;
        _last = -1;
        _lastSearch = null;
      });
      c.onLog = _say;
      c.onStart = (n, m, tmo, me) => setState(() {
            _n = n;
            _m = m;
            _tmo = tmo;
            _netMe = me;
            _board = Board(n, m);
            _turn = kX;
          });
      c.onTurn = (p) {
        if (!mounted) return;
        setState(() {
          _turn = p;
          _thinking = p == _netMe;
        });
        _startClock();
      };
      c.onMove = (cell, p) {
        if (!mounted) return;
        setState(() {
          _board.place(cell, p);
          _last = cell;
          _status = _board.status();
        });
      };
      c.onThought = (r) {
        if (!mounted) return;
        setState(() => _lastSearch = r);
        _say('   profondeur ${r.depth}, ${r.nodes} noeuds, ${r.millis} ms, score ${r.score}');
      };
      c.onGameOver = (v) {
        if (!mounted) return;
        _clock.stop();
        setState(() {
          _thinking = false;
          _netActive = false;
          if (_status == 0) _status = v == 0 ? 3 : (v == 1 ? kX : kO);
        });
        final mine = (v == 1 && _netMe == kX) || (v == -1 && _netMe == kO);
        _say(v == 0 ? 'Resultat : partie nulle' : (mine ? 'Resultat : victoire !' : 'Resultat : defaite'));
      };
    }
    try {
      await c.run();
    } catch (e) {
      if (show) _say('Erreur reseau : $e');
    } finally {
      if (show && mounted) setState(() => _netActive = false);
    }
  }

  /// Demonstration sans le serveur du professeur : serveur local + adversaire automatique.
  Future<void> _localDemo() async {
    final port = int.tryParse(_port.text.trim()) ?? 12345;
    setState(() => _log.clear());
    final ready = Completer<void>();
    unawaited(runTttServer(n: _n, m: _m, tmo: _tmo, port: port, ready: ready, log: (s) => _say('[serveur] $s')).catchError((Object e) {
      _say('[serveur] erreur : $e');
      if (!ready.isCompleted) ready.complete();
      return 0;
    }));
    await ready.future;
    _host.text = '127.0.0.1';
    unawaited(_connect());
    await Future<void>.delayed(const Duration(milliseconds: 300));
    unawaited(_connect(name: 'Bot-HMAX$_hmax2', hmax: _hmax2, show: false));
  }

  // ------------------------------------------------------------ interface

  @override
  Widget build(BuildContext context) {
    final w = Board.defaultWeights(_board.m);
    final est = _board.estimation(w);
    final scale = max(1.0, pow(6, _board.m - 2) * 3.0);
    final bar = _status == kX ? 1.0 : (_status == kO ? 0.0 : 1 / (1 + exp(-est / scale)));
    final heat = _heat && _status == 0 ? moveScores(_board, _turn) : null;
    final locked = _thinking || _netActive;
    final turnName = _turn == kX ? 'X' : 'O';
    final statusText = _status == 3
        ? 'Partie nulle'
        : (_status == kX ? 'X a gagne' : (_status == kO ? 'O a gagne' : (_thinking ? '$turnName reflechit...' : 'Au tour de $turnName')));

    return PageScaffold(
      tag: 'TP 3',
      title: 'Morpion N x N',
      subtitle: 'MinMax + alpha/beta + approfondissement iteratif, client TCP du tournoi',
      accent: C.violet,
      canvas: Panel(
        child: Row(children: [
          // Barre d'evaluation (X en haut)
          SizedBox(
            width: 26,
            child: Column(children: [
              const Text('X', style: TextStyle(color: C.violet, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(children: [
                    Container(color: C.amber),
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 350),
                      heightFactor: bar.clamp(0.02, 0.98),
                      alignment: Alignment.topCenter,
                      child: Container(color: C.violet),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 4),
              const Text('O', style: TextStyle(color: C.amber, fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(builder: (context, box) {
                  final cell = box.maxWidth / _board.n;
                  return GestureDetector(
                    onTapUp: (d) {
                      final c = (d.localPosition.dx / cell).floor(), r = (d.localPosition.dy / cell).floor();
                      if (r >= 0 && c >= 0 && r < _board.n && c < _board.n) _humanTap(r * _board.n + c);
                    },
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _BoardPainter(_board, _last, _status == 0 ? const [] : _board.winningCells(), heat),
                    ),
                  );
                }),
              ),
            ),
          ),
        ]),
      ),
      bottomHeight: 170,
      bottom: Panel(
        title: 'Journal (messages du protocole)',
        accent: C.violet,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: SizedBox(
          height: 110,
          child: ListView.builder(
            controller: _logScroll,
            itemCount: _log.length,
            itemBuilder: (_, i) => Text(_log[i],
                style: kMono.copyWith(
                    fontSize: 12,
                    color: _log[i].startsWith('>') ? C.violet : (_log[i].startsWith('<') ? C.amber : C.muted))),
          ),
        ),
      ),
      side: [
        Panel(
          title: 'Partie',
          accent: C.violet,
          child: Column(children: [
            Row(children: [
              SizedBox(
                width: 54,
                height: 54,
                child: AnimatedBuilder(
                  animation: _clock,
                  builder: (_, __) => CustomPaint(painter: _RingPainter(_clock.isAnimating ? 1 - _clock.value : 0, _tmo * (1 - _clock.value))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(statusText, style: const TextStyle(color: C.text, fontSize: 15, fontWeight: FontWeight.w800)),
                  Text('estimation (point de vue de X) : $est', style: kMono.copyWith(color: C.muted, fontSize: 11)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            StatRow([
              Stat(label: 'profondeur atteinte', value: _lastSearch == null ? '-' : '${_lastSearch!.depth}', color: C.violet),
              Stat(label: 'noeuds explores', value: _lastSearch == null ? '-' : '${_lastSearch!.nodes}'),
            ]),
            const SizedBox(height: 8),
            StatRow([
              Stat(label: 'temps (ms)', value: _lastSearch == null ? '-' : '${_lastSearch!.millis}'),
              Stat(label: 'score du coup', value: _lastSearch == null ? '-' : _scoreText(_lastSearch!.score)),
            ]),
          ]),
        ),
        Panel(
          title: 'Mode',
          accent: C.violet,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Seg(
                options: const ['Moi vs IA', 'IA vs IA', 'Reseau'],
                index: _mode,
                color: C.violet,
                enabled: !locked,
                onChanged: (v) => setState(() => _mode = v)),
            const SizedBox(height: 8),
            if (_mode != 2) ...[
              NumStepper(label: 'Taille N', value: _n, min: 3, max: 15, enabled: !locked, onChanged: (v) => setState(() {
                    _n = v;
                    if (_m > _n) _m = _n;
                  })),
              NumStepper(label: 'Alignement M', value: _m, min: 3, max: min(_n, 6), enabled: !locked, onChanged: (v) => setState(() => _m = v)),
              NumStepper(label: 'Delai TMO (s)', value: _tmo, min: 1, max: 30, enabled: !locked, onChanged: (v) => setState(() => _tmo = v)),
              NumStepper(
                  label: _mode == 1 ? 'HMAX de X' : 'HMAX (profondeur max)',
                  value: _hmax,
                  min: 1,
                  max: 20,
                  enabled: !locked,
                  onChanged: (v) => setState(() => _hmax = v)),
              if (_mode == 1)
                NumStepper(label: 'HMAX de O', value: _hmax2, min: 1, max: 20, enabled: !locked, onChanged: (v) => setState(() => _hmax2 = v)),
              if (_mode == 0) ...[
                const SizedBox(height: 4),
                Seg(
                    options: const ['Je joue X (1er)', 'Je joue O'],
                    index: _humanSide == kX ? 0 : 1,
                    color: C.violet,
                    enabled: !locked,
                    onChanged: (v) => setState(() => _humanSide = v == 0 ? kX : kO)),
              ],
              const SizedBox(height: 6),
              ActionBtn(label: 'Nouvelle partie', icon: Icons.play_arrow_rounded, color: C.violet, filled: true, onPressed: _newGame),
            ] else ...[
              _field('Nom du joueur', _name),
              Row(children: [
                Expanded(flex: 3, child: _field('Adresse du serveur', _host)),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _field('Port', _port)),
              ]),
              NumStepper(label: 'HMAX (profondeur max)', value: _hmax, min: 1, max: 20, enabled: !locked, onChanged: (v) => setState(() => _hmax = v)),
              const SizedBox(height: 4),
              const Text('Indices des cases envoyes au serveur', style: TextStyle(color: C.muted, fontSize: 11)),
              const SizedBox(height: 4),
              Seg(
                  options: const ['a partir de 0', 'a partir de 1'],
                  index: _base,
                  color: C.violet,
                  enabled: !locked,
                  onChanged: (v) => setState(() => _base = v)),
              const SizedBox(height: 6),
              ActionBtn(
                  label: 'Se connecter au serveur',
                  icon: Icons.lan_rounded,
                  color: C.violet,
                  filled: true,
                  onPressed: locked ? null : () => _connect()),
              const Divider(color: C.line, height: 20),
              const Text('Demonstration sans le serveur du professeur', style: TextStyle(color: C.muted, fontSize: 11)),
              NumStepper(label: 'Taille N', value: _n, min: 3, max: 15, enabled: !locked, onChanged: (v) => setState(() {
                    _n = v;
                    if (_m > _n) _m = _n;
                  })),
              NumStepper(label: 'Alignement M', value: _m, min: 3, max: min(_n, 6), enabled: !locked, onChanged: (v) => setState(() => _m = v)),
              NumStepper(label: 'Delai TMO (s)', value: _tmo, min: 1, max: 30, enabled: !locked, onChanged: (v) => setState(() => _tmo = v)),
              NumStepper(label: 'HMAX de l\'adversaire', value: _hmax2, min: 1, max: 20, enabled: !locked, onChanged: (v) => setState(() => _hmax2 = v)),
              ActionBtn(label: 'Serveur local + adversaire', icon: Icons.dns_rounded, color: C.amber, onPressed: locked ? null : _localDemo),
            ],
          ]),
        ),
        Panel(
          title: 'Fonction d\'estimation',
          accent: C.violet,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Seg(
                options: const ['Carte de chaleur', 'Masquee'],
                index: _heat ? 0 : 1,
                color: C.violet,
                onChanged: (v) => setState(() => _heat = v == 0)),
            const SizedBox(height: 10),
            SimpleTableLite(
              header: const ['pions alignes k', 'poids', 'fenetres X', 'fenetres O'],
              rows: [
                for (var k = 1; k < _board.m; k++) ['$k', '${w[k]}', '${_board.open[kX][k]}', '${_board.open[kO][k]}'],
              ],
            ),
            const SizedBox(height: 10),
            const InfoBox([
              'Une fenetre = M cases alignees (4 directions). Si elle contient les deux symboles, elle vaut 0.',
              'E = somme des poids(k) x (fenetres de X a k pions - fenetres de O a k pions).',
              'La carte de chaleur montre l\'interet de chaque case (attaque + defense) : elle sert a trier les coups pour alpha/beta.',
            ], color: C.violet),
          ]),
        ),
      ],
    );
  }

  String _scoreText(int s) => s > kWin - 1000 ? 'gain force' : (s < -kWin + 1000 ? 'perte forcee' : '$s');

  Widget _field(String label, TextEditingController c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextField(
          controller: c,
          style: kMono.copyWith(color: C.text, fontSize: 13),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: C.muted, fontSize: 12),
            isDense: true,
            filled: true,
            fillColor: C.card2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
      );
}

/// Petit tableau sans defilement (hauteur = contenu).
class SimpleTableLite extends StatelessWidget {
  final List<String> header;
  final List<List<String>> rows;
  const SimpleTableLite({super.key, required this.header, required this.rows});

  @override
  Widget build(BuildContext context) {
    Widget line(List<String> cells, bool head) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            for (final c in cells)
              Expanded(
                child: Text(c,
                    textAlign: TextAlign.center,
                    style: head ? const TextStyle(color: C.muted, fontSize: 10.5) : kMono.copyWith(color: C.text, fontSize: 12.5)),
              ),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(10)),
      child: Column(children: [line(header, true), for (final r in rows) line(r, false)]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction; // part du delai restante
  final double seconds;
  _RingPainter(this.fraction, this.seconds);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 4;
    canvas.drawCircle(c, r, Paint()..color = C.card2..style = PaintingStyle.stroke..strokeWidth = 5);
    if (fraction > 0) {
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          -pi / 2,
          2 * pi * fraction,
          false,
          Paint()
            ..color = fraction < 0.25 ? C.red : C.violet
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round);
    }
    drawText(canvas, fraction > 0 ? seconds.toStringAsFixed(1) : '-', c, kMono.copyWith(color: C.text, fontSize: 12, fontWeight: FontWeight.w700),
        anchor: Alignment.center);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.fraction != fraction;
}

class _BoardPainter extends CustomPainter {
  final Board b;
  final int last;
  final List<int> win;
  final List<int>? heat;
  _BoardPainter(this.b, this.last, this.win, this.heat);

  @override
  void paint(Canvas canvas, Size size) {
    final n = b.n;
    final cell = size.width / n;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)), Paint()..color = C.bg);
    Rect rect(int i) => Rect.fromLTWH((i % n) * cell, (i ~/ n) * cell, cell, cell);

    if (heat != null) {
      var hi = 1;
      for (final v in heat!) {
        if (v > hi) hi = v;
      }
      final lhi = log(hi + 1);
      for (var i = 0; i < n * n; i++) {
        final v = heat![i];
        if (v <= 0) continue;
        final t = pow(log(v + 1) / lhi, 3).toDouble();
        canvas.drawRRect(RRect.fromRectAndRadius(rect(i).deflate(cell * 0.08), Radius.circular(cell * 0.14)),
            Paint()..color = fade(C.violet, 0.05 + 0.45 * t));
      }
    }
    if (last >= 0) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect(last).deflate(cell * 0.05), Radius.circular(cell * 0.14)), Paint()..color = fade(C.text, 0.12));
    }
    final grid = Paint()
      ..color = C.line
      ..strokeWidth = 1.2;
    for (var i = 1; i < n; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), grid);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), grid);
    }
    final sw = max(2.5, cell * 0.09);
    for (var i = 0; i < n * n; i++) {
      final v = b.cells[i];
      if (v == kEmpty) continue;
      final c = rect(i).center;
      final r = cell * 0.27;
      if (v == kX) {
        final p = Paint()
          ..color = C.violet
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(c - Offset(r, r), c + Offset(r, r), p);
        canvas.drawLine(c - Offset(r, -r), c + Offset(r, -r), p);
      } else {
        canvas.drawCircle(
            c,
            r,
            Paint()
              ..color = C.amber
              ..style = PaintingStyle.stroke
              ..strokeWidth = sw);
      }
    }
    if (win.isNotEmpty) {
      final a = rect(win.first).center, z = rect(win.last).center;
      canvas.drawLine(a, z, Paint()..color = fade(C.green, 0.3)..strokeWidth = cell * 0.5..strokeCap = StrokeCap.round);
      canvas.drawLine(a, z, Paint()..color = C.green..strokeWidth = sw..strokeCap = StrokeCap.round);
    }
    if (n <= 12) {
      for (var i = 0; i < n; i++) {
        drawText(canvas, '$i', Offset(i * cell + 4, 2), const TextStyle(color: C.muted, fontSize: 9));
        if (i > 0) drawText(canvas, '$i', Offset(3, i * cell + 2), const TextStyle(color: C.muted, fontSize: 9));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
