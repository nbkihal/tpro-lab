/// Protocole reseau du TP (sockets TCP, messages texte termines par '\n') :
///   client -> serveur : "<nom>"
///   serveur -> client : "N M TMO X|O"
///   client -> serveur : "i j"
///   serveur -> client : "X at i j" / "O at i j"
///   serveur -> clients : "gameover cost = val"   (1 : X gagne, 0 : nulle, -1 : O gagne)
///
/// Les fichiers C du professeur n'etant pas disponibles, deux details sont reglables :
/// la base des indices (0 ou 1) et l'espacement des messages (analyse tolerante).
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'ttt_board.dart';
import 'ttt_engine.dart';

// ---------------------------------------------------------------- analyse tolerante

class GameParams {
  final int n, m, tmo, symbol;
  const GameParams(this.n, this.m, this.tmo, this.symbol);
}

class MoveMsg {
  final int player, i, j;
  const MoveMsg(this.player, this.i, this.j);
}

/// "7 4 5 X" (espaces ou virgules quelconques, casse indifferente). null si invalide.
GameParams? parseParams(String line) {
  final t = line.trim().split(RegExp(r'[\s,;]+')).where((s) => s.isNotEmpty).toList();
  if (t.length < 4) return null;
  final n = int.tryParse(t[0]), m = int.tryParse(t[1]), tmo = int.tryParse(t[2]);
  final s = t[3].toUpperCase();
  if (n == null || m == null || tmo == null || n < 1 || m < 1 || m > n || !(s.startsWith('X') || s.startsWith('O'))) return null;
  return GameParams(n, m, tmo, s.startsWith('X') ? kX : kO);
}

final RegExp _moveRe = RegExp(r'([xo])\s*at\s*\(?\s*(-?\d+)\s*[\s,;]\s*(-?\d+)', caseSensitive: false);

/// "X at 2 3", "x AT 2,3", "O  at  (2 , 3)"... null si la ligne n'est pas un coup.
MoveMsg? parseMove(String line) {
  final mt = _moveRe.firstMatch(line);
  if (mt == null) return null;
  return MoveMsg(mt.group(1)!.toUpperCase() == 'X' ? kX : kO, int.parse(mt.group(2)!), int.parse(mt.group(3)!));
}

/// "gameover cost = 1", "GAMEOVER cost=-1"... Retourne le cout, ou null si ce n'est pas une fin de partie.
int? parseGameOver(String line) {
  if (!line.toLowerCase().replaceAll(' ', '').contains('gameover')) return null;
  final v = RegExp(r'-?\d+').allMatches(line).map((e) => int.parse(e.group(0)!)).toList();
  return v.isEmpty ? 0 : v.last.clamp(-1, 1);
}

/// Coup envoye par un client : "2 3" ou "2,3". null si invalide.
List<int>? parseCoords(String line) {
  final t = line.trim().split(RegExp(r'[\s,;]+')).where((s) => s.isNotEmpty).toList();
  if (t.length < 2) return null;
  final i = int.tryParse(t[0]), j = int.tryParse(t[1]);
  return i == null || j == null ? null : [i, j];
}

// ---------------------------------------------------------------- lecture ligne par ligne

/// Lecture ligne par ligne d'une socket, avec delai optionnel.
class LineReader {
  final Queue<String> _lines = Queue<String>();
  Completer<void>? _wake;
  bool closed = false;

  LineReader(Socket socket) {
    socket.cast<List<int>>().transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter()).listen(
      (l) {
        _lines.add(l);
        _signal();
      },
      onError: (_) {
        closed = true;
        _signal();
      },
      onDone: () {
        closed = true;
        _signal();
      },
      cancelOnError: true,
    );
  }

  void _signal() {
    final w = _wake;
    _wake = null;
    if (w != null && !w.isCompleted) w.complete();
  }

  /// Une ligne deja recue verifie-t-elle [test] ? (sert a voir un "gameover" arrive pendant la reflexion)
  bool anyPending(bool Function(String) test) => _lines.any(test);

  /// Ligne suivante ; null si la connexion est fermee ou si le delai est depasse.
  Future<String?> next({Duration? timeout}) async {
    final sw = Stopwatch()..start();
    while (_lines.isEmpty) {
      if (closed) return null;
      final c = _wake = Completer<void>();
      if (timeout == null) {
        await c.future;
      } else {
        final left = timeout - sw.elapsed;
        if (left <= Duration.zero) return null;
        await c.future.timeout(left, onTimeout: () {});
        if (_lines.isEmpty && sw.elapsed >= timeout) return null;
      }
    }
    return _lines.removeFirst();
  }
}

// ---------------------------------------------------------------- client

typedef Thinker = Future<SearchResult> Function(Board board, int player, int hmax, int timeMs);

Future<SearchResult> isolateThinker(Board b, int player, int hmax, int timeMs) =>
    thinkInIsolate(b.n, b.m, b.cells, player, hmax, timeMs);

/// Client du tournoi. Les lignes du journal sont prefixees par '> ' (envoye),
/// '< ' (recu) ou '# ' (information).
class TttClient {
  final String host, name;
  final int port, hmax;

  /// 0 si le serveur numerote lignes et colonnes a partir de 0, 1 sinon.
  final int indexBase;

  /// Part du delai TMO reellement utilisee pour reflechir (marge de securite reseau).
  final double timeFraction;
  final Thinker thinker;

  void Function(String line)? onLog;
  void Function(int n, int m, int tmo, int me)? onStart;
  void Function(int cell, int player)? onMove;

  /// Appele quand un joueur commence a reflechir, avec son budget en millisecondes (0 pour l'adversaire).
  void Function(int player, int budgetMs)? onTurn;
  void Function(SearchResult r)? onThought;
  void Function(int cost)? onGameOver;

  Board? board;
  int me = kX;
  Socket? _socket;

  TttClient({
    required this.name,
    this.host = '127.0.0.1',
    this.port = 12345,
    this.hmax = 6,
    this.indexBase = 0,
    this.timeFraction = 0.8,
    this.thinker = isolateThinker,
  });

  void close() => _socket?.destroy();

  /// Budget de reflexion : une fraction de TMO, moins une marge fixe pour le reseau.
  static int budgetFor(int tmoSeconds, double fraction) {
    final b = (tmoSeconds * 1000 * fraction).round() - 150;
    return b < 100 ? 100 : b;
  }

  /// Joue une partie complete. Leve une [SocketException] si le serveur est injoignable.
  Future<void> run() async {
    final socket = _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
    socket.setOption(SocketOption.tcpNoDelay, true);
    final reader = LineReader(socket);
    void send(String s) {
      try {
        socket.write('$s\n');
        onLog?.call('> $s');
      } catch (_) {
        onLog?.call('# envoi impossible : connexion fermée');
      }
    }

    try {
      send(name);
      GameParams? gp;
      while (gp == null) {
        final params = await reader.next();
        if (params == null) {
          onLog?.call('# connexion fermée avant le début de la partie');
          return;
        }
        onLog?.call('< $params');
        final over = parseGameOver(params);
        if (over != null) {
          onGameOver?.call(over);
          return;
        }
        gp = parseParams(params);
        if (gp == null) onLog?.call('# ligne ignorée (paramètres attendus : "N M TMO X|O")');
      }
      final n = gp.n, m = gp.m, tmo = gp.tmo;
      me = gp.symbol;
      final b = board = Board(n, m);
      onStart?.call(n, m, tmo, me);
      final budget = budgetFor(tmo, timeFraction);

      Future<void> play() async {
        onTurn?.call(me, budget);
        final r = await thinker(b, me, hmax, budget);
        if (r.move < 0) return;
        // Une fin de partie est peut-etre arrivee pendant la reflexion : on n'envoie rien.
        if (reader.closed || reader.anyPending((l) => parseGameOver(l) != null)) {
          onLog?.call('# fin de partie reçue pendant la réflexion : coup non envoyé');
          return;
        }
        b.place(r.move, me);
        onThought?.call(r);
        onMove?.call(r.move, me);
        send('${r.move ~/ n + indexBase} ${r.move % n + indexBase}');
        onTurn?.call(3 - me, 0);
      }

      if (me == kX) await play();
      while (true) {
        final line = await reader.next();
        if (line == null) {
          onLog?.call('# connexion fermée par le serveur');
          break;
        }
        onLog?.call('< $line');
        final over = parseGameOver(line);
        if (over != null) {
          onGameOver?.call(over);
          break;
        }
        final mv = parseMove(line);
        if (mv == null) {
          if (line.trim().isNotEmpty) onLog?.call('# ligne ignorée (format inconnu)');
          continue;
        }
        final i = mv.i - indexBase, j = mv.j - indexBase;
        if (i < 0 || j < 0 || i >= n || j >= n || b.cells[i * n + j] != kEmpty) {
          onLog?.call('# coup reçu invalide : vérifiez le réglage « indices à partir de »');
          continue;
        }
        if (mv.player == me) continue; // echo de mon propre coup
        b.place(i * n + j, mv.player);
        onMove?.call(i * n + j, mv.player);
        if (b.status() == 0) await play();
      }
    } finally {
      socket.destroy();
    }
  }
}

// ---------------------------------------------------------------- serveur de test

/// Permet d'arreter le serveur de test depuis l'exterieur.
class ServerControl {
  ServerSocket? _server;
  final List<Socket> _sockets = [];
  bool stopped = false;

  void stop() {
    stopped = true;
    _server?.close();
    for (final s in _sockets) {
      s.destroy();
    }
  }
}

/// Serveur de test reproduisant le protocole du TP (pour s'entrainer sans le serveur du professeur).
/// Retourne le cout final : 1 (X gagne), 0 (nulle), -1 (O gagne).
/// Leve une [SocketException] si le port est deja utilise.
Future<int> runTttServer({
  required int n,
  required int m,
  required int tmo,
  int port = 12345,
  int indexBase = 0,
  void Function(String)? log,
  void Function(Board board)? onBoard,
  Completer<void>? ready,
  ServerControl? control,
}) async {
  final server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
  control?._server = server;
  log?.call('serveur en écoute sur le port $port (N=$n, M=$m, TMO=${tmo}s)');
  ready?.complete();
  final sockets = <Socket>[];
  final readers = <LineReader>[];
  final names = <String>[];
  final incoming = StreamIterator<Socket>(server);
  try {
    while (sockets.length < 2 && await incoming.moveNext()) {
      final s = incoming.current;
      s.setOption(SocketOption.tcpNoDelay, true);
      final r = LineReader(s);
      final name = await r.next(timeout: const Duration(seconds: 60));
      if (name == null) {
        s.destroy();
        continue;
      }
      sockets.add(s);
      control?._sockets.add(s);
      readers.add(r);
      names.add(name.trim());
      log?.call('joueur ${sockets.length == 1 ? "X" : "O"} connecté : ${name.trim()}');
    }
    if (sockets.length < 2) return 0;
    sockets[0].write('$n $m $tmo X\n');
    sockets[1].write('$n $m $tmo O\n');
    final board = Board(n, m);
    onBoard?.call(board);
    var turn = 0; // 0 : X, 1 : O
    int cost;
    while (true) {
      final p = turn == 0 ? kX : kO;
      final sym = turn == 0 ? 'X' : 'O';
      final line = await readers[turn].next(timeout: Duration(seconds: tmo));
      if (line == null) {
        log?.call('$sym (${names[turn]}) : délai dépassé ou connexion perdue');
        cost = turn == 0 ? -1 : 1;
        break;
      }
      final t = parseCoords(line);
      final i = t == null ? -1 : t[0] - indexBase, j = t == null ? -1 : t[1] - indexBase;
      if (i < 0 || j < 0 || i >= n || j >= n || board.cells[i * n + j] != kEmpty) {
        log?.call('$sym (${names[turn]}) : coup illégal "$line"');
        cost = turn == 0 ? -1 : 1;
        break;
      }
      board.place(i * n + j, p);
      log?.call('$sym at ${i + indexBase} ${j + indexBase}');
      onBoard?.call(board);
      final st = board.status();
      if (st != 0) {
        cost = st == kX ? 1 : (st == kO ? -1 : 0);
        break;
      }
      sockets[1 - turn].write('$sym at ${i + indexBase} ${j + indexBase}\n');
      turn = 1 - turn;
    }
    for (final s in sockets) {
      try {
        s.write('gameover cost = $cost\n');
      } catch (_) {}
    }
    log?.call('gameover cost = $cost');
    for (final s in sockets) {
      try {
        await s.flush();
        await s.close();
      } catch (_) {}
    }
    return cost;
  } finally {
    await incoming.cancel();
    await server.close();
    for (final s in sockets) {
      s.destroy();
    }
  }
}

String boardToText(Board b) {
  final sb = StringBuffer();
  for (var r = 0; r < b.n; r++) {
    for (var c = 0; c < b.n; c++) {
      final v = b.cells[r * b.n + c];
      sb.write(v == kX ? ' X' : (v == kO ? ' O' : ' .'));
    }
    sb.writeln();
  }
  return sb.toString();
}
