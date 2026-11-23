/// TP4 (TD5 ex.5) - Taquin 4 x 4 (15-puzzle) : A* et WA*.
/// Un etat est code sur un entier 64 bits : 4 bits par case, la case i occupe les bits 4i..4i+3.
library;

import 'dart:collection';
import 'dart:isolate';
import 'dart:math';

const int kSide = 4, kCells = 16;

/// Configuration but : 1 2 3 ... 15 puis la case vide (0).
final int kGoal = fromTiles([for (var i = 0; i < kCells; i++) (i + 1) % kCells]);

int fromTiles(List<int> tiles) {
  var s = 0;
  for (var i = 0; i < kCells; i++) {
    s |= tiles[i] << (4 * i);
  }
  return s;
}

List<int> toTiles(int s) => [for (var i = 0; i < kCells; i++) (s >>> (4 * i)) & 15];

int tileAt(int s, int i) => (s >>> (4 * i)) & 15;

int blankOf(int s) {
  for (var i = 0; i < kCells; i++) {
    if ((s >>> (4 * i)) & 15 == 0) return i;
  }
  return -1;
}

/// Echange la case vide (en [blank]) avec la case [pos].
int swapBlank(int s, int blank, int pos) {
  final t = (s >>> (4 * pos)) & 15;
  return (s & ~(15 << (4 * pos))) | (t << (4 * blank));
}

/// Positions voisines de la case i (haut, bas, gauche, droite).
final List<List<int>> kNeighbors = [
  for (var i = 0; i < kCells; i++)
    [
      if (i >= kSide) i - kSide,
      if (i < kCells - kSide) i + kSide,
      if (i % kSide > 0) i - 1,
      if (i % kSide < kSide - 1) i + 1,
    ],
];

/// Melange par [moves] deplacements aleatoires depuis le but (toujours resoluble).
int scramble(int moves, Random rnd) {
  var s = kGoal, blank = kCells - 1, prev = -1;
  for (var k = 0; k < moves; k++) {
    final opts = kNeighbors[blank].where((p) => p != prev).toList();
    final p = opts[rnd.nextInt(opts.length)];
    s = swapBlank(s, blank, p);
    prev = blank;
    blank = p;
  }
  return s;
}

// ---------------------------------------------------------------- heuristiques

/// h1 : nombre de jetons mal places (la case vide ne compte pas).
int hMisplaced(int s) {
  var h = 0;
  for (var i = 0; i < kCells; i++) {
    final t = (s >>> (4 * i)) & 15;
    if (t != 0 && t != i + 1) h++;
  }
  return h;
}

/// h2 : somme des distances de Manhattan de chaque jeton a sa place finale.
int hManhattan(int s) {
  var h = 0;
  for (var i = 0; i < kCells; i++) {
    final t = (s >>> (4 * i)) & 15;
    if (t == 0) continue;
    final g = t - 1;
    h += (i ~/ kSide - g ~/ kSide).abs() + (i % kSide - g % kSide).abs();
  }
  return h;
}

/// h3 : Manhattan + conflits lineaires. Deux jetons deja dans leur ligne (ou colonne)
/// finale mais inverses obligent l'un des deux a sortir puis revenir : +2 deplacements
/// par jeton a sortir. Reste admissible et domine h2.
int hLinearConflict(int s) {
  var h = hManhattan(s);
  final line = <int>[];
  for (var r = 0; r < kSide; r++) {
    line.clear();
    for (var c = 0; c < kSide; c++) {
      final t = (s >>> (4 * (r * kSide + c))) & 15;
      if (t != 0 && (t - 1) ~/ kSide == r) line.add((t - 1) % kSide);
    }
    h += 2 * (line.length - _lis(line));
  }
  for (var c = 0; c < kSide; c++) {
    line.clear();
    for (var r = 0; r < kSide; r++) {
      final t = (s >>> (4 * (r * kSide + c))) & 15;
      if (t != 0 && (t - 1) % kSide == c) line.add((t - 1) ~/ kSide);
    }
    h += 2 * (line.length - _lis(line));
  }
  return h;
}

/// Longueur de la plus longue sous-suite croissante (au plus 4 elements).
int _lis(List<int> a) {
  var best = 0;
  final l = List<int>.filled(a.length, 1);
  for (var i = 0; i < a.length; i++) {
    for (var j = 0; j < i; j++) {
      if (a[j] < a[i] && l[j] + 1 > l[i]) l[i] = l[j] + 1;
    }
    if (l[i] > best) best = l[i];
  }
  return best;
}

const List<String> kHeuristicNames = ['Mal places', 'Manhattan', 'Manhattan + conflits'];

int heuristic(int kind, int s) => switch (kind) {
      0 => hMisplaced(s),
      1 => hManhattan(s),
      _ => hLinearConflict(s),
    };

// ---------------------------------------------------------------- files de priorite

class Node {
  final int state, g, h;
  final double f;
  final Node? parent;
  Node(this.state, this.g, this.h, this.f, this.parent);

  /// Priorite : f croissant ; a egalite, le noeud le plus proche du but (h minimal).
  bool before(Node o) => f < o.f || (f == o.f && h < o.h);
}

abstract class PriorityQueue {
  int get length;
  void insert(Node n);
  Node removeMin();
}

/// File naive : insertion O(1), retrait du minimum O(n).
class NaiveQueue implements PriorityQueue {
  final List<Node> _a = [];
  @override
  int get length => _a.length;
  @override
  void insert(Node n) => _a.add(n);
  @override
  Node removeMin() {
    var bi = 0;
    for (var i = 1; i < _a.length; i++) {
      if (_a[i].before(_a[bi])) bi = i;
    }
    final best = _a[bi];
    _a[bi] = _a.last;
    _a.removeLast();
    return best;
  }
}

/// Tas binaire : insertion et retrait en O(log n).
class HeapQueue implements PriorityQueue {
  final List<Node> _a = [];
  @override
  int get length => _a.length;

  @override
  void insert(Node n) {
    _a.add(n);
    var i = _a.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (!_a[i].before(_a[p])) break;
      final t = _a[i];
      _a[i] = _a[p];
      _a[p] = t;
      i = p;
    }
  }

  @override
  Node removeMin() {
    final top = _a.first;
    final last = _a.removeLast();
    if (_a.isNotEmpty) {
      _a[0] = last;
      var i = 0;
      final n = _a.length;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var s = i;
        if (l < n && _a[l].before(_a[s])) s = l;
        if (r < n && _a[r].before(_a[s])) s = r;
        if (s == i) break;
        final t = _a[i];
        _a[i] = _a[s];
        _a[s] = t;
        i = s;
      }
    }
    return top;
  }
}

// ---------------------------------------------------------------- A* / WA*

class AStarResult {
  /// 'ok', 'limite' (trop de noeuds) ou 'delai'.
  final String status;

  /// Suite des etats du depart au but (vide en cas d'echec).
  final List<int> path;
  final int expanded, generated, maxFrontier, micros;
  const AStarResult(this.status, this.path, this.expanded, this.generated, this.maxFrontier, this.micros);

  int get moves => path.isEmpty ? -1 : path.length - 1;
}

/// A* avec f(x) = g(x) + weight * h(x). weight = 1 : A* ; weight > 1 : WA*.
AStarResult solvePuzzle(
  int start, {
  int heuristicKind = 1,
  double weight = 1.0,
  bool useHeap = true,
  int nodeLimit = 1500000,
  int timeLimitMs = 20000,
}) {
  final sw = Stopwatch()..start();
  final PriorityQueue open = useHeap ? HeapQueue() : NaiveQueue();
  final bestG = HashMap<int, int>();
  final h0 = heuristic(heuristicKind, start);
  open.insert(Node(start, 0, h0, weight * h0, null));
  bestG[start] = 0;
  var expanded = 0, generated = 1, maxFrontier = 1;

  while (open.length > 0) {
    final cur = open.removeMin();
    if (cur.g > bestG[cur.state]!) continue; // entree perimee : un meilleur chemin a ete trouve depuis
    if (cur.state == kGoal) {
      final path = <int>[];
      for (Node? x = cur; x != null; x = x.parent) {
        path.add(x.state);
      }
      sw.stop();
      return AStarResult('ok', path.reversed.toList(), expanded, generated, maxFrontier, sw.elapsedMicroseconds);
    }
    expanded++;
    if (expanded > nodeLimit) {
      return AStarResult('limite', const [], expanded, generated, maxFrontier, sw.elapsedMicroseconds);
    }
    if ((expanded & 255) == 0 && sw.elapsedMilliseconds > timeLimitMs) {
      return AStarResult('delai', const [], expanded, generated, maxFrontier, sw.elapsedMicroseconds);
    }
    final blank = blankOf(cur.state);
    final g = cur.g + 1;
    for (final pos in kNeighbors[blank]) {
      final ns = swapBlank(cur.state, blank, pos);
      final old = bestG[ns];
      if (old != null && old <= g) continue; // programmation dynamique : on garde le meilleur chemin
      bestG[ns] = g;
      final h = heuristic(heuristicKind, ns);
      open.insert(Node(ns, g, h, g + weight * h, cur));
      generated++;
    }
    if (open.length > maxFrontier) maxFrontier = open.length;
  }
  return AStarResult('echec', const [], expanded, generated, maxFrontier, sw.elapsedMicroseconds);
}

/// Execute la recherche dans un isolate (l'interface reste fluide).
Future<AStarResult> solvePuzzleInIsolate(
  int start, {
  required int heuristicKind,
  required double weight,
  required bool useHeap,
  int nodeLimit = 1500000,
  int timeLimitMs = 20000,
}) {
  return Isolate.run(() => solvePuzzle(start,
      heuristicKind: heuristicKind, weight: weight, useHeap: useHeap, nodeLimit: nodeLimit, timeLimitMs: timeLimitMs));
}
