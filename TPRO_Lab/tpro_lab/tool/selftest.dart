// Verification des 4 noyaux algorithmiques :  dart run tool/selftest.dart
import 'dart:async';
import 'dart:math';

import 'package:tpro_lab/core/graph.dart';
import 'package:tpro_lab/core/puzzle.dart';
import 'package:tpro_lab/core/tsp.dart';
import 'package:tpro_lab/core/ttt_board.dart';
import 'package:tpro_lab/core/ttt_engine.dart';
import 'package:tpro_lab/core/ttt_net.dart';

var _fails = 0;
void check(String name, bool ok) {
  print('${ok ? "OK  " : "FAIL"}  $name');
  if (!ok) _fails++;
}

Graph graphOf(int n, List<List<int>> e) {
  final g = Graph();
  for (var i = 0; i < n; i++) {
    g.addVertex();
  }
  for (final x in e) {
    g.addEdge(x[0], x[1]);
  }
  return g;
}

/// Reference lente : plus court cycle par DFS exhaustif.
int slowGirth(Graph g) {
  var best = 1 << 30;
  final onPath = List<bool>.filled(g.n, false);
  void dfs(int start, int u, int len) {
    if (len >= best) return;
    for (final v in g.adj[u]) {
      if (v == start && len >= 3) {
        if (len < best) best = len;
      } else if (!onPath[v] && v > start) {
        onPath[v] = true;
        dfs(start, v, len + 1);
        onPath[v] = false;
      }
    }
  }

  for (var s = 0; s < g.n; s++) {
    onPath[s] = true;
    dfs(s, s, 1);
    onPath[s] = false;
  }
  return best == 1 << 30 ? 0 : best;
}

bool validCycle(Graph g, List<int> c) {
  if (c.isEmpty) return true;
  if (c.toSet().length != c.length || c.length < 3) return false;
  for (var i = 0; i < c.length; i++) {
    if (!g.hasEdge(c[i], c[(i + 1) % c.length])) return false;
  }
  return true;
}

Future<void> main() async {
  final rnd = Random(7);

  // ---- TP1 : plus court cycle
  check('cycle : triangle = 3', shortestCycle(graphOf(3, [[0, 1], [1, 2], [2, 0]])).length == 3);
  check('cycle : carre = 4', shortestCycle(graphOf(4, [[0, 1], [1, 2], [2, 3], [3, 0]])).length == 4);
  check('cycle : arbre = aucun', shortestCycle(graphOf(5, [[0, 1], [1, 2], [1, 3], [3, 4]])).cycle.isEmpty);
  check('cycle : carre + diagonale = 3', shortestCycle(graphOf(4, [[0, 1], [1, 2], [2, 3], [3, 0], [0, 2]])).length == 3);
  var okAll = true;
  for (var t = 0; t < 300; t++) {
    final n = 3 + rnd.nextInt(9);
    final g = Graph.random(n, rnd.nextInt(n * 2), rnd);
    final r = shortestCycle(g, trace: true);
    if (r.length != slowGirth(g) || !validCycle(g, r.cycle)) okAll = false;
  }
  check('cycle : 300 graphes aleatoires = reference exhaustive', okAll);

  // ---- TP2 : voyageur de commerce
  final d4 = [
    [0, 10, 15, 20],
    [10, 0, 35, 25],
    [15, 35, 0, 30],
    [20, 25, 30, 0],
  ];
  check('tsp : exemple 4 villes = 80 (enumeration)', tspBruteForce(d4).cost == 80);
  check('tsp : exemple 4 villes = 80 (Held-Karp)', tspHeldKarp(d4).cost == 80);
  okAll = true;
  for (var t = 0; t < 60; t++) {
    final n = 2 + rnd.nextInt(8);
    final d = randomMatrix(n, rnd);
    final a = tspBruteForce(d), b = tspHeldKarp(d);
    if (a.cost != b.cost || tourCost(d, b.tour) != b.cost || b.tour.toSet().length != n || b.tour.first != 0) okAll = false;
  }
  check('tsp : 60 matrices aleatoires, Held-Karp = enumeration', okAll);
  final d15 = randomMatrix(15, rnd);
  final hk = tspHeldKarp(d15);
  check('tsp : Held-Karp n=15 en ${hk.micros ~/ 1000} ms, tournee valide', tourCost(d15, hk.tour) == hk.cost);

  // ---- TP3 : morpion
  final b3 = Board(3, 3);
  for (final mv in [[0, kX], [3, kO], [1, kX], [4, kO]]) {
    b3.place(mv[0], mv[1]);
  }
  final r3 = Engine().think(b3, kX, hmax: 6, timeMs: 2000);
  check('morpion 3x3 : X trouve le coup gagnant (case 2)', r3.move == 2);
  final b3b = Board(3, 3);
  for (final mv in [[0, kX], [4, kO], [1, kX]]) {
    b3b.place(mv[0], mv[1]);
  }
  check('morpion 3x3 : O bloque la menace (case 2)', Engine().think(b3b, kO, hmax: 6, timeMs: 2000).move == 2);
  // place / remove restaurent exactement l'etat
  final b7 = Board(7, 4);
  final seq = <int>[];
  for (var k = 0; k < 20; k++) {
    int c;
    do {
      c = rnd.nextInt(49);
    } while (b7.cells[c] != kEmpty);
    b7.place(c, k.isEven ? kX : kO);
    seq.add(c);
  }
  final h20 = b7.hash;
  final e20 = b7.estimation(Board.defaultWeights(4));
  b7.place(seq.first == 0 ? 1 : 0, kX);
  b7.remove(seq.first == 0 ? 1 : 0, kX);
  final same = Board.fromCells(7, 4, b7.cells);
  check('morpion : place/remove incrementaux coherents',
      b7.hash == h20 && b7.estimation(Board.defaultWeights(4)) == e20 && same.estimation(Board.defaultWeights(4)) == e20);
  // partie complete 3x3 entre deux moteurs parfaits : nulle
  final g = Board(3, 3);
  var p = kX;
  while (g.status() == 0) {
    g.place(Engine().think(g, p, hmax: 9, timeMs: 3000).move, p);
    p = 3 - p;
  }
  check('morpion 3x3 : IA parfaite contre IA parfaite = nulle', g.status() == 3);
  // respect du delai
  final sw = Stopwatch()..start();
  final rt = Engine().think(Board(11, 5)..place(60, kX), kO, hmax: 30, timeMs: 400);
  sw.stop();
  check('morpion 11x11 : delai de 400 ms respecte (${sw.elapsedMilliseconds} ms, profondeur ${rt.depth}, ${rt.nodes} noeuds)',
      sw.elapsedMilliseconds < 520 && rt.move >= 0);
  // profondeur 5 contre profondeur 1 : le plus profond ne perd pas
  var strongPts = 0;
  for (var game = 0; game < 4; game++) {
    final gb = Board(7, 4);
    final strong = game.isEven ? kX : kO;
    var pl = kX;
    while (gb.status() == 0) {
      final r = Engine().think(gb, pl, hmax: pl == strong ? 5 : 1, timeMs: 600);
      gb.place(r.move, pl);
      pl = 3 - pl;
    }
    final st = gb.status();
    strongPts += st == strong ? 2 : (st == 3 ? 1 : 0);
  }
  check('morpion 7x7 M=4 : HMAX=5 contre HMAX=1 sur 4 parties -> $strongPts/8 points', strongPts >= 6);

  // reseau : serveur + 2 clients
  final ready = Completer<void>();
  final srv = runTttServer(n: 5, m: 4, tmo: 2, port: 23456, ready: ready);
  await ready.future;
  final results = <int>[];
  Future<void> cl(String name, int hmax) async {
    final c = TttClient(name: name, port: 23456, hmax: hmax);
    c.onGameOver = (v) => results.add(v);
    await c.run();
  }

  await Future.wait([cl('A', 4), Future.delayed(const Duration(milliseconds: 200), () => cl('B', 2))]);
  final cost = await srv;
  check('reseau : partie complete serveur + 2 clients (cout $cost)', results.length == 2 && results.every((v) => v == cost));

  // ---- TP4 : taquin
  check('taquin : h du but = 0', hMisplaced(kGoal) == 0 && hManhattan(kGoal) == 0 && hLinearConflict(kGoal) == 0);
  okAll = true;
  var lens = '';
  for (var t = 0; t < 12; t++) {
    final s = scramble(18 + 2 * t, rnd);
    final a = solvePuzzle(s, heuristicKind: 1);
    final b = solvePuzzle(s, heuristicKind: 2);
    final c = solvePuzzle(s, heuristicKind: 0, nodeLimit: 400000);
    final n = solvePuzzle(s, heuristicKind: 2, useHeap: false);
    final w = solvePuzzle(s, heuristicKind: 1, weight: 2.5);
    lens += '${a.moves} ';
    if (a.status != 'ok' || b.moves != a.moves || n.moves != a.moves) okAll = false;
    if (c.status == 'ok' && c.moves != a.moves) okAll = false;
    if (w.status != 'ok' || w.moves < a.moves || w.moves > 2.5 * a.moves) okAll = false;
    if (b.expanded > a.expanded) okAll = false; // h3 domine h2
    if (hLinearConflict(s) < hManhattan(s) || hManhattan(s) < hMisplaced(s) || hLinearConflict(s) > a.moves) okAll = false;
    // chemin valide
    for (var i = 1; i < a.path.length; i++) {
      final bl = blankOf(a.path[i - 1]);
      if (!kNeighbors[bl].any((pp) => swapBlank(a.path[i - 1], bl, pp) == a.path[i])) okAll = false;
    }
  }
  check('taquin : 12 melanges, optimalite et coherence des variantes (longueurs $lens)', okAll);

  print(_fails == 0 ? '\nTous les tests passent.' : '\n$_fails test(s) en echec.');
}
