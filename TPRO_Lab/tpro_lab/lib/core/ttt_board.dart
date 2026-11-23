/// TP3 (TD4 ex.6) - Morpion N x N, il faut aligner M symboles.
/// Le plateau maintient de facon incrementale, pour chaque "fenetre" de M cases
/// alignees (4 directions), le nombre de X et de O qu'elle contient. La fonction
/// d'estimation s'en deduit en O(1).
library;

import 'dart:math';
import 'dart:typed_data';

const int kEmpty = 0, kX = 1, kO = 2;

class Board {
  final int n, m;
  final Uint8List cells;
  int count = 0;

  late final List<Int32List> _cellWins; // fenetres contenant chaque case
  late final List<Int32List> winCells; // cases de chaque fenetre
  late final Int32List _wx, _wo; // nb de X / de O par fenetre
  late final List<Int32List> _near; // cases a distance <= 2 de chaque case
  late final Int32List near; // nb de pions a distance <= 2 de chaque case

  /// open[p][k] = nombre de fenetres contenant exactement k pions de p et aucun pion adverse.
  late final List<Int32List> open;
  late final List<Int64List> _zob;
  int hash = 0;

  Board(this.n, this.m) : cells = Uint8List(n * n) {
    final wins = <List<int>>[];
    const dirs = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1],
    ];
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        for (final d in dirs) {
          final er = r + d[0] * (m - 1), ec = c + d[1] * (m - 1);
          if (er < 0 || er >= n || ec < 0 || ec >= n) continue;
          wins.add([for (var k = 0; k < m; k++) (r + d[0] * k) * n + (c + d[1] * k)]);
        }
      }
    }
    winCells = [for (final w in wins) Int32List.fromList(w)];
    final per = List.generate(n * n, (_) => <int>[]);
    for (var w = 0; w < wins.length; w++) {
      for (final c in wins[w]) {
        per[c].add(w);
      }
    }
    _cellWins = [for (final l in per) Int32List.fromList(l)];
    _wx = Int32List(wins.length);
    _wo = Int32List(wins.length);
    open = [Int32List(m + 1), Int32List(m + 1), Int32List(m + 1)];
    near = Int32List(n * n);
    _near = List.generate(n * n, (cell) {
      final r = cell ~/ n, c = cell % n;
      final l = <int>[];
      for (var dr = -2; dr <= 2; dr++) {
        for (var dc = -2; dc <= 2; dc++) {
          final rr = r + dr, cc = c + dc;
          if ((dr != 0 || dc != 0) && rr >= 0 && rr < n && cc >= 0 && cc < n) l.add(rr * n + cc);
        }
      }
      return Int32List.fromList(l);
    });
    final rnd = Random(12345);
    int r64() => (rnd.nextInt(1 << 31) << 32) ^ (rnd.nextInt(1 << 31) << 1) ^ rnd.nextInt(2);
    _zob = [
      Int64List(n * n),
      Int64List.fromList([for (var i = 0; i < n * n; i++) r64()]),
      Int64List.fromList([for (var i = 0; i < n * n; i++) r64()]),
    ];
  }

  factory Board.fromCells(int n, int m, List<int> src) {
    final b = Board(n, m);
    for (var i = 0; i < src.length; i++) {
      if (src[i] != kEmpty) b.place(i, src[i]);
    }
    return b;
  }

  bool get full => count == n * n;

  int numWindows() => winCells.length;
  int windowsOf(int cell) => _cellWins[cell].length;
  Int32List windowIdsOf(int cell) => _cellWins[cell];
  int xIn(int w) => _wx[w];
  int oIn(int w) => _wo[w];

  void place(int cell, int p) {
    cells[cell] = p;
    count++;
    hash ^= _zob[p][cell];
    final mine = p == kX ? _wx : _wo;
    final theirs = p == kX ? _wo : _wx;
    final om = open[p], ot = open[3 - p];
    for (final w in _cellWins[cell]) {
      final a = mine[w], b = theirs[w];
      if (b == 0) {
        om[a]--;
        om[a + 1]++;
      } else if (a == 0) {
        ot[b]--; // la fenetre adverse vient d'etre bloquee
      }
      mine[w] = a + 1;
    }
    for (final c in _near[cell]) {
      near[c]++;
    }
  }

  void remove(int cell, int p) {
    cells[cell] = kEmpty;
    count--;
    hash ^= _zob[p][cell];
    final mine = p == kX ? _wx : _wo;
    final theirs = p == kX ? _wo : _wx;
    final om = open[p], ot = open[3 - p];
    for (final w in _cellWins[cell]) {
      final a = mine[w] - 1, b = theirs[w];
      mine[w] = a;
      if (b == 0) {
        om[a + 1]--;
        om[a]++;
      } else if (a == 0) {
        ot[b]++;
      }
    }
    for (final c in _near[cell]) {
      near[c]--;
    }
  }

  /// Le joueur p a-t-il aligne M symboles ?
  bool wins(int p) => open[p][m] > 0;

  /// 0 : partie en cours ; 1 : X gagne ; 2 : O gagne ; 3 : nulle.
  int status() {
    if (wins(kX)) return kX;
    if (wins(kO)) return kO;
    return full ? 3 : 0;
  }

  /// Cases de l'alignement gagnant (vide s'il n'y en a pas).
  List<int> winningCells() {
    for (var w = 0; w < winCells.length; w++) {
      if (_wx[w] == m || _wo[w] == m) return winCells[w].toList();
    }
    return const [];
  }

  /// Fonction d'estimation, du point de vue de X : somme, sur les fenetres encore
  /// "ouvertes" (un seul camp present), d'un poids qui croit geometriquement avec le
  /// nombre de pions alignes. Une fenetre contenant les deux symboles vaut 0.
  int estimation(List<int> weights) {
    var s = 0;
    final ox = open[kX], oo = open[kO];
    for (var k = 1; k < m; k++) {
      s += weights[k] * (ox[k] - oo[k]);
    }
    return s;
  }

  static List<int> defaultWeights(int m) => [for (var k = 0; k <= m; k++) k == 0 ? 0 : pow(6, k - 1).toInt()];
}
