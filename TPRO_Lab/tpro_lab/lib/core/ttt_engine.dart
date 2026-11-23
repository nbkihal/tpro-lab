/// MinMax avec elagage alpha/beta + approfondissement iteratif ("iterative deepening")
/// borne par une profondeur maximale HMAX et par un delai (TMO).
library;

import 'dart:isolate';
import 'dart:typed_data';

import 'ttt_board.dart';

const int kWin = 1000000000;

class SearchResult {
  final int move; // case choisie (ligne * n + colonne), -1 si aucun coup
  final int score; // du point de vue du joueur qui cherche
  final int depth; // derniere profondeur terminee
  final int nodes;
  final int millis;
  const SearchResult(this.move, this.score, this.depth, this.nodes, this.millis);
}

class _Timeout {
  const _Timeout();
}

class Engine {
  static const int _ttBits = 18;
  static const int _ttMask = (1 << _ttBits) - 1;
  final Int64List _ttKey = Int64List(1 << _ttBits);
  final Int64List _ttVal = Int64List(1 << _ttBits);
  final Int8List _ttDepth = Int8List(1 << _ttBits);
  final Int8List _ttFlag = Int8List(1 << _ttBits); // 0 vide, 1 exact, 2 borne inf, 3 borne sup
  final Int16List _ttMove = Int16List(1 << _ttBits);

  late Board _b;
  late List<int> _w;
  final Stopwatch _clock = Stopwatch();
  int _budgetMs = 0;
  int nodes = 0;

  /// Nombre maximal de coups examines par noeud (les plus prometteurs selon l'estimation).
  int rootWidth = 24, innerWidth = 12;

  SearchResult think(Board board, int player, {required int hmax, required int timeMs}) {
    _b = board;
    _w = Board.defaultWeights(board.m);
    _budgetMs = timeMs;
    nodes = 0;
    _clock
      ..reset()
      ..start();

    var moves = _orderedMoves(player, -1, rootWidth);
    if (moves.isEmpty) return const SearchResult(-1, 0, 0, 0, 0);
    var best = moves.first, bestScore = 0, done = 0;
    if (moves.length > 1) {
      try {
        for (var depth = 1; depth <= hmax; depth++) {
          var alpha = -kWin * 2;
          const beta = kWin * 2;
          var dBest = moves.first;
          for (final mv in moves) {
            _b.place(mv, player);
            final int v;
            try {
              v = -_search(3 - player, depth - 1, -beta, -alpha, 1);
            } finally {
              _b.remove(mv, player);
            }
            if (v > alpha) {
              alpha = v;
              dBest = mv;
            }
          }
          best = dBest;
          bestScore = alpha;
          done = depth;
          // Le meilleur coup passe en tete pour la profondeur suivante.
          moves = [best, ...moves.where((x) => x != best)];
          if (alpha.abs() > kWin - 1000) break; // gain ou perte forces : inutile d'aller plus loin
        }
      } on _Timeout {
        // delai ecoule : on garde le meilleur coup de la derniere profondeur terminee
      }
    }
    _clock.stop();
    return SearchResult(best, bestScore, done, nodes, _clock.elapsedMilliseconds);
  }

  /// Valeur de la position pour le joueur [p] qui doit jouer (forme "negamax" du MinMax).
  int _search(int p, int depth, int alpha, int beta, int ply) {
    nodes++;
    if ((nodes & 1023) == 0 && _clock.elapsedMilliseconds >= _budgetMs) throw const _Timeout();
    final b = _b;
    if (b.wins(3 - p)) return -(kWin - ply); // l'adversaire vient d'aligner M symboles
    if (b.full) return 0;
    if (b.open[p][b.m - 1] > 0) return kWin - ply - 1; // p complete un alignement au prochain coup
    if (depth <= 0) {
      final e = b.estimation(_w);
      return p == kX ? e : -e;
    }

    // Table de transposition
    final key = b.hash ^ (p == kX ? 0x5bd1e995 : 0);
    final slot = key & _ttMask;
    var ttMove = -1;
    if (_ttFlag[slot] != 0 && _ttKey[slot] == key) {
      ttMove = _ttMove[slot];
      if (_ttDepth[slot] >= depth) {
        var v = _ttVal[slot];
        if (v > kWin - 1000) v -= ply;
        if (v < -kWin + 1000) v += ply;
        final f = _ttFlag[slot];
        if (f == 1) return v;
        if (f == 2 && v >= beta) return v;
        if (f == 3 && v <= alpha) return v;
      }
    }

    final alpha0 = alpha;
    var best = -kWin * 2, bestMove = -1;
    for (final mv in _orderedMoves(p, ttMove, innerWidth)) {
      b.place(mv, p);
      final int v;
      try {
        v = -_search(3 - p, depth - 1, -beta, -alpha, ply + 1);
      } finally {
        b.remove(mv, p);
      }
      if (v > best) {
        best = v;
        bestMove = mv;
      }
      if (best > alpha) alpha = best;
      if (alpha >= beta) break; // coupe alpha/beta
    }

    var store = best;
    if (store > kWin - 1000) store += ply;
    if (store < -kWin + 1000) store -= ply;
    _ttKey[slot] = key;
    _ttVal[slot] = store;
    _ttDepth[slot] = depth;
    _ttFlag[slot] = best <= alpha0 ? 3 : (best >= beta ? 2 : 1);
    _ttMove[slot] = bestMove;
    return best;
  }

  /// Coups candidats (cases vides proches d'un pion), tries par interet decroissant.
  List<int> _orderedMoves(int p, int ttMove, int width) {
    final b = _b;
    if (b.count == 0) return [(b.n ~/ 2) * b.n + b.n ~/ 2];
    final cand = <int>[];
    final sc = <int>[];
    final nn = b.n * b.n;
    for (var c = 0; c < nn; c++) {
      if (b.cells[c] != kEmpty || b.near[c] == 0) continue;
      cand.add(c);
      sc.add(c == ttMove ? 1 << 60 : moveScore(b, c, p));
    }
    final idx = List<int>.generate(cand.length, (i) => i)..sort((x, y) => sc[y].compareTo(sc[x]));
    final len = idx.length < width ? idx.length : width;
    return [for (var i = 0; i < len; i++) cand[idx[i]]];
  }
}

/// Interet statique de jouer en [cell] pour le joueur [p] : attaque (prolonger ses
/// propres fenetres) + defense (bloquer celles de l'adversaire).
int moveScore(Board b, int cell, int p) {
  var s = 0;
  final m = b.m;
  for (final w in b.windowIdsOf(cell)) {
    final mine = p == kX ? b.xIn(w) : b.oIn(w);
    final theirs = p == kX ? b.oIn(w) : b.xIn(w);
    if (theirs == 0) {
      s += mine == m - 1 ? 100000000 : 2 * _pow8[mine];
    }
    if (mine == 0 && theirs > 0) {
      s += theirs == m - 1 ? 10000000 : _pow8[theirs];
    }
  }
  return s;
}

const List<int> _pow8 = [1, 8, 64, 512, 4096, 32768, 262144, 2097152, 16777216, 134217728];

/// Estimation de chaque case vide pour le joueur p (-1 pour une case occupee) : carte de chaleur.
List<int> moveScores(Board b, int p) => [
      for (var c = 0; c < b.n * b.n; c++) b.cells[c] != kEmpty ? -1 : moveScore(b, c, p),
    ];

/// Lance la recherche dans un isolate pour ne pas bloquer l'interface.
Future<SearchResult> thinkInIsolate(int n, int m, List<int> cells, int player, int hmax, int timeMs) {
  final copy = List<int>.from(cells);
  return Isolate.run(() => Engine().think(Board.fromCells(n, m, copy), player, hmax: hmax, timeMs: timeMs));
}
