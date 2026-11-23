/// Protocole reseau du TP (sockets TCP, messages texte termines par '\n') :
///   client -> serveur : "<nom>"
///   serveur -> client : "N M TMO X|O"
///   client -> serveur : "i j"
///   serveur -> client : "X at i j" / "O at i j"
///   serveur -> clients : "gameover cost = val"   (1 : X gagne, 0 : nulle, -1 : O gagne)
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'ttt_board.dart';
import 'ttt_engine.dart';

/// Lecture ligne par ligne d'une socket, avec delai optionnel.
class LineReader {
  final Queue<String> _lines = Queue<String>();
  Completer<void>? _wake;
  bool closed = false;

  LineReader(Socket socket) {
    socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen(
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

typedef Thinker = Future<SearchResult> Function(Board board, int player, int hmax, int timeMs);

Future<SearchResult> isolateThinker(Board b, int player, int hmax, int timeMs) =>
    thinkInIsolate(b.n, b.m, b.cells, player, hmax, timeMs);

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
  void Function(int player)? onTurn;
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

  Future<void> run() async {
    final socket = _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
    socket.setOption(SocketOption.tcpNoDelay, true);
    final reader = LineReader(socket);
    void send(String s) {
      socket.write('$s\n');
      onLog?.call('> $s');
    }

    try {
      send(name);
      final params = await reader.next();
      if (params == null) {
        onLog?.call('connexion fermee avant le debut de la partie');
        return;
      }
      onLog?.call('< $params');
      final t = params.trim().split(RegExp(r'\s+'));
      final n = int.parse(t[0]), m = int.parse(t[1]), tmo = int.parse(t[2]);
      me = t[3].toUpperCase().startsWith('X') ? kX : kO;
      final b = board = Board(n, m);
      onStart?.call(n, m, tmo, me);
      var budget = (tmo * 1000 * timeFraction).round() - 150;
      if (budget < 100) budget = 100;

      Future<void> play() async {
        onTurn?.call(me);
        final r = await thinker(b, me, hmax, budget);
        if (r.move < 0) return;
        b.place(r.move, me);
        onThought?.call(r);
        onMove?.call(r.move, me);
        send('${r.move ~/ n + indexBase} ${r.move % n + indexBase}');
        onTurn?.call(3 - me);
      }

      if (me == kX) await play();
      while (true) {
        final line = await reader.next();
        if (line == null) {
          onLog?.call('connexion fermee par le serveur');
          break;
        }
        onLog?.call('< $line');
        final low = line.toLowerCase();
        if (low.contains('gameover')) {
          final v = RegExp(r'-?\d+').allMatches(line).map((e) => int.parse(e.group(0)!)).toList();
          onGameOver?.call(v.isEmpty ? 0 : v.last);
          break;
        }
        final mt = RegExp(r'([XOxo])\s+at\s+(-?\d+)\s+(-?\d+)').firstMatch(line);
        if (mt == null) continue;
        final p = mt.group(1)!.toUpperCase() == 'X' ? kX : kO;
        final i = int.parse(mt.group(2)!) - indexBase, j = int.parse(mt.group(3)!) - indexBase;
        if (i < 0 || j < 0 || i >= n || j >= n || b.cells[i * n + j] != kEmpty) {
          onLog?.call('coup recu invalide : verifiez l\'option "indices a partir de"');
          continue;
        }
        b.place(i * n + j, p);
        onMove?.call(i * n + j, p);
        if (p != me && b.status() == 0) await play();
      }
    } finally {
      socket.destroy();
    }
  }
}

/// Serveur de test reproduisant le protocole du TP (pour s'entrainer sans le serveur du professeur).
/// Retourne le cout final : 1 (X gagne), 0 (nulle), -1 (O gagne).
Future<int> runTttServer({
  required int n,
  required int m,
  required int tmo,
  int port = 12345,
  void Function(String)? log,
  void Function(Board board)? onBoard,
  Completer<void>? ready,
}) async {
  final server = await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
  log?.call('serveur en ecoute sur le port $port (N=$n, M=$m, TMO=${tmo}s)');
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
      readers.add(r);
      names.add(name.trim());
      log?.call('joueur ${sockets.length == 1 ? "X" : "O"} connecte : ${name.trim()}');
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
        log?.call('$sym (${names[turn]}) : delai depasse ou connexion perdue');
        cost = turn == 0 ? -1 : 1;
        break;
      }
      final t = line.trim().split(RegExp(r'\s+'));
      final i = t.length >= 2 ? int.tryParse(t[0]) : null;
      final j = t.length >= 2 ? int.tryParse(t[1]) : null;
      if (i == null || j == null || i < 0 || j < 0 || i >= n || j >= n || board.cells[i * n + j] != kEmpty) {
        log?.call('$sym (${names[turn]}) : coup illegal "$line"');
        cost = turn == 0 ? -1 : 1;
        break;
      }
      board.place(i * n + j, p);
      log?.call('$sym at $i $j');
      onBoard?.call(board);
      final st = board.status();
      if (st != 0) {
        cost = st == kX ? 1 : (st == kO ? -1 : 0);
        break;
      }
      sockets[1 - turn].write('$sym at $i $j\n');
      turn = 1 - turn;
    }
    for (final s in sockets) {
      s.write('gameover cost = $cost\n');
    }
    log?.call('gameover cost = $cost');
    for (final s in sockets) {
      await s.flush();
      await s.close();
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
