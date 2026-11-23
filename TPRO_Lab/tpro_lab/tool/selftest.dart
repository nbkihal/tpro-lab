// Verification des 4 noyaux algorithmiques :  dart run tool/selftest.dart
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:tpro_lab/core/demo_content.dart';
import 'package:tpro_lab/core/graph.dart';
import 'package:tpro_lab/core/jobs.dart';
import 'package:tpro_lab/core/puzzle.dart';
import 'package:tpro_lab/core/trace.dart';
import 'package:tpro_lab/core/tsp.dart';
import 'package:tpro_lab/core/ttt_board.dart';
import 'package:tpro_lab/core/ttt_engine.dart';
import 'package:tpro_lab/core/ttt_net.dart';

var _fails = 0;
void check(String name, bool ok) {
  print('${ok ? "OK  " : "FAIL"}  $name');
  if (!ok) _fails++;
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

bool linesOk(Trace t, List<String> pseudo) => t.steps.isNotEmpty && t.steps.every((s) => s.line >= 1 && s.line <= pseudo.length);

/// Reference : longueur optimale du taquin par BFS (melanges peu profonds uniquement).
int bfsPuzzle(int start) {
  final dist = HashMap<int, int>()..[start] = 0;
  final q = Queue<int>()..add(start);
  while (q.isNotEmpty) {
    final s = q.removeFirst();
    if (s == kGoal) return dist[s]!;
    final bl = blankOf(s);
    for (final p in kNeighbors[bl]) {
      final ns = swapBlank(s, bl, p);
      if (!dist.containsKey(ns)) {
        dist[ns] = dist[s]! + 1;
        q.add(ns);
      }
    }
  }
  return -1;
}

Future<void> main() async {
  final rnd = Random(7);
  Graph preset(String name) {
    final p = kGraphPresets.firstWhere((g) => g.name == name);
    return Graph.fromEdges(p.pos.length, p.edges);
  }

  // ---- TP1 : plus court cycle
  check('cycle : triangle = 3', shortestCycle(Graph.fromEdges(3, [[0, 1], [1, 2], [2, 0]])).length == 3);
  check('cycle : carre = 4', shortestCycle(preset('Carré')).length == 4);
  check('cycle : Petersen = 5', shortestCycle(preset('Petersen')).length == 5);
  check('cycle : arbre = aucun', shortestCycle(preset('Arbre')).cycle.isEmpty);
  check('cycle : deux composantes = le plus petit des deux cycles (3)', shortestCycle(preset('2 composantes')).length == 3);
  check('cycle : exemples C8 = 8, K5 = 3, grille = 4, "Triangle" = 3',
      shortestCycle(preset('Cycle C₈')).length == 8 &&
          shortestCycle(preset('Complet K₅')).length == 3 &&
          shortestCycle(preset('Grille 4×4')).length == 4 &&
          shortestCycle(preset('Triangle')).length == 3);
  check('cycle : graphe vide et graphe a un sommet', shortestCycle(Graph()).cycle.isEmpty && shortestCycle(Graph()..addVertex()).cycle.isEmpty);
  var okAll = true, okTrace = true;
  for (var t = 0; t < 300; t++) {
    final n = 3 + rnd.nextInt(9);
    final g = Graph.random(n, rnd.nextInt(n * 2), rnd);
    final r = shortestCycle(g);
    final cut = shortestCycle(g, earlyCut: true);
    final tr = Trace();
    final traced = shortestCycle(g, trace: tr);
    final ref = slowGirth(g);
    if (r.length != ref || !validCycle(g, r.cycle) || cut.length != ref || !validCycle(g, cut.cycle)) okAll = false;
    if (traced.length != r.length || !linesOk(tr, kCyclePseudo) || tr.steps.last.kind != StepKind.done) okTrace = false;
  }
  check('cycle : 300 graphes aleatoires = reference exhaustive (avec et sans coupe), cycle reel de la longueur annoncee', okAll);
  check('cycle : execution tracee = execution normale, lignes de pseudo-code valides', okTrace);
  final parsed = Graph.parseEdgeList('0 1\n1,2\n2-0\n\n3');
  check('cycle : lecture d\'une liste d\'aretes en texte', parsed != null && parsed.n == 4 && parsed.m == 3 && Graph.parseEdgeList('a b') == null);
  final capped = Trace(cap: 50);
  shortestCycle(preset('Grille 4×4'), trace: capped);
  check('trace : plafond respecte, fin conservee (${capped.total} etapes, ${capped.skipped} sautees)',
      capped.truncated && capped.steps.length == 51 && capped.steps.last.kind == StepKind.done);

  // ---- TP2 : voyageur de commerce
  check('tsp : exemple 4 villes = 80 (enumeration DFS, BFS et Held-Karp)',
      tspBruteForce(kTspDemo4).cost == 80 && tspBruteForceBfs(kTspDemo4).cost == 80 && tspHeldKarp(kTspDemo4).cost == 80);
  okAll = true;
  okTrace = true;
  for (var t = 0; t < 200; t++) {
    final n = 3 + rnd.nextInt(7);
    final d = randomMatrix(n, rnd, symmetric: t.isEven);
    final a = tspBruteForce(d), b = tspHeldKarp(d), c = tspBruteForceBfs(d);
    for (final r in [a, b, c]) {
      if (r.cost != a.cost || tourCost(d, r.tour) != r.cost || r.tour.toSet().length != n || r.tour.first != 0) okAll = false;
    }
    if (a.ops != factorial(n - 1).round()) okAll = false;
    if (t < 40) {
      final t1 = Trace(), t2 = Trace(), t3 = Trace();
      if (tspBruteForce(d, trace: t1).cost != a.cost || !linesOk(t1, kEnumPseudo)) okTrace = false;
      if (tspBruteForceBfs(d, trace: t2).cost != a.cost || !linesOk(t2, kEnumPseudo)) okTrace = false;
      final hk = tspHeldKarp(d, trace: t3);
      if (hk.cost != a.cost || !linesOk(t3, kHkPseudo) || hk.cells.length != hk.extra) okTrace = false;
    }
  }
  check('tsp : 200 matrices aleatoires (n = 3..9, symetriques ou non), les 3 methodes donnent le meme cout, tournees valides', okAll);
  check('tsp : executions tracees = executions normales, lignes de pseudo-code valides', okTrace);
  check('tsp : n = 2 et n = 3', tspHeldKarp([[0, 5], [7, 0]]).cost == 12 && tspBruteForce([[0, 5], [7, 0]]).cost == 12 && tspHeldKarp(randomMatrix(3, rnd)).tour.length == 3);
  final d15 = randomMatrix(15, rnd);
  final hk = tspHeldKarp(d15);
  check('tsp : Held-Karp n=15 en ${hk.micros ~/ 1000} ms (< 1 s), tournee valide', tourCost(d15, hk.tour) == hk.cost && hk.micros < 1000000);
  final row = benchTspN(8);
  check('tsp : banc d\'essai n=8, couts identiques', row.sameCost == true && row.bruteMicros != null && row.hkMicros != null);

  // ---- TP3 : morpion
  var dirs = true;
  for (final line in [[0, 1, 2, 3], [0, 5, 10, 15], [0, 6, 12, 18], [3, 7, 11, 15]]) {
    final b = Board(5, 4);
    for (final c in line) {
      b.place(c, kO);
    }
    if (!b.wins(kO) || b.wins(kX) || b.winningCells().toSet().difference(line.toSet()).isNotEmpty) dirs = false;
  }
  check('morpion : alignement detecte dans les 4 directions de ligne', dirs);
  final w4 = Board.defaultWeights(4);
  var anti = Board(7, 4).estimation(w4) == 0;
  for (var t = 0; t < 50; t++) {
    final a = Board(7, 4), b = Board(7, 4);
    for (var k = 0; k < 12; k++) {
      int c;
      do {
        c = rnd.nextInt(49);
      } while (a.cells[c] != kEmpty);
      a.place(c, k.isEven ? kX : kO);
      b.place(c, k.isEven ? kO : kX);
    }
    if (a.estimation(w4) != -b.estimation(w4)) anti = false;
    final sum = estimationTable(a).fold<int>(0, (s, r) => s + r.contribution);
    if (sum != a.estimation(w4)) anti = false;
  }
  check('morpion : estimation nulle sur grille vide, antisymetrique, egale a la somme du tableau', anti);
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
  const noTactics = EngineOptions(tactics: false, useTT: false);
  check('morpion 3x3 : idem sans detection tactique ni table de transposition',
      Engine().think(b3, kX, hmax: 6, timeMs: 2000, options: noTactics).move == 2 &&
          Engine().think(b3b, kO, hmax: 6, timeMs: 2000, options: noTactics).move == 2);
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
  final e20 = b7.estimation(w4);
  final free = b7.cells.indexOf(kEmpty);
  b7.place(free, kX);
  b7.remove(free, kX);
  final same = Board.fromCells(7, 4, b7.cells);
  check('morpion : place/remove incrementaux coherents', b7.hash == h20 && b7.estimation(w4) == e20 && same.estimation(w4) == e20);
  // partie complete 3x3 entre deux moteurs parfaits : nulle (pour chaque jeu d'options)
  var draws = true;
  for (final opt in const [EngineOptions(), EngineOptions(ordering: false, nearOnly: false, useTT: false, tactics: false)]) {
    final g = Board(3, 3);
    var p = kX;
    while (g.status() == 0) {
      g.place(Engine().think(g, p, hmax: 9, timeMs: 3000, options: opt).move, p);
      p = 3 - p;
    }
    if (g.status() != 3) draws = false;
  }
  check('morpion 3x3 : IA parfaite contre IA parfaite = nulle (avec et sans accelerations)', draws);
  // trace : meme coup, lignes valides, arbre enregistre
  final demo = Board.fromCells(3, 3, kTttDemoCells);
  const demoOpt = EngineOptions(useTT: false, tactics: false);
  final plain = Engine().think(demo, kX, hmax: 4, timeMs: 5000, options: demoOpt);
  final ttr = Trace();
  final trees = <SearchTree>[];
  final tracedR = Engine().think(demo, kX, hmax: 4, timeMs: 5000, options: demoOpt, trace: ttr, trees: trees);
  check(
      'morpion : recherche tracee = recherche normale (coup ${tracedR.move}, ${ttr.total} etapes, ${trees.length} arbres, ${tracedR.cuts} coupes)',
      tracedR.move == plain.move &&
          tracedR.score == plain.score &&
          tracedR.nodes == plain.nodes &&
          linesOk(ttr, kTttPseudo) &&
          trees.length == tracedR.depth &&
          trees.last.nodes.isNotEmpty &&
          trees.last.nodes.first.valueAt >= 0 &&
          demo.count == 4);
  // respect du delai
  final sw = Stopwatch()..start();
  final rt = Engine().think(Board(11, 5)..place(60, kX), kO, hmax: 30, timeMs: 400);
  sw.stop();
  check('morpion 11x11 : delai de 400 ms respecte (${sw.elapsedMilliseconds} ms, profondeur ${rt.depth}, ${rt.nodes} noeuds, interrompu : ${rt.timedOut})',
      sw.elapsedMilliseconds < 520 && rt.move >= 0 && rt.timedOut && rt.iters.isNotEmpty && !rt.iters.last.completed);
  final r0 = Engine().think(Board(15, 5)..place(112, kX), kO, hmax: 30, timeMs: 0);
  check('morpion : echeance immediate -> un coup legal est quand meme renvoye', r0.move >= 0 && r0.move != 112);
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

  // analyse tolerante des messages
  final pm = [parseMove('X at 2 3'), parseMove('x  AT 2,3'), parseMove('  O at (2 , 3)\r'), parseMove('Xat 2;3')];
  final pp = parseParams('  7   4 5 x ');
  check(
      'reseau : analyse tolerante (espacement, casse, virgule)',
      pm.every((m) => m != null && m.i == 2 && m.j == 3) &&
          pm[0]!.player == kX &&
          pm[2]!.player == kO &&
          parseMove('hello') == null &&
          pp != null &&
          pp.n == 7 &&
          pp.m == 4 &&
          pp.tmo == 5 &&
          pp.symbol == kX &&
          parseParams('7 4') == null &&
          parseGameOver('gameover cost = -1') == -1 &&
          parseGameOver('GAMEOVER cost=1') == 1 &&
          parseGameOver('game over cost = 0') == 0 &&
          parseGameOver('X at 1 2') == null &&
          parseCoords('2,3')![1] == 3);

  // reseau : serveur + 2 clients (indices a partir de 1 pour verifier le reglage)
  for (final base in [0, 1]) {
    final ready = Completer<void>();
    final serverLog = <String>[];
    final srv = runTttServer(n: 5, m: 4, tmo: 2, port: 23456 + base, indexBase: base, ready: ready, log: serverLog.add);
    await ready.future;
    final results = <int>[];
    Future<void> cl(String name, int hmax) async {
      final c = TttClient(name: name, port: 23456 + base, hmax: hmax, indexBase: base);
      c.onGameOver = (v) => results.add(v);
      await c.run();
    }

    await Future.wait([cl('A', 4), Future.delayed(const Duration(milliseconds: 200), () => cl('B', 2))]);
    final cost = await srv;
    check('reseau : partie complete serveur + 2 clients, indices a partir de $base (gameover cost = $cost)',
        results.length == 2 && results.every((v) => v == cost) && serverLog.last == 'gameover cost = $cost' && !serverLog.any((l) => l.contains('illégal')));
  }
  var refused = false;
  try {
    await TttClient(name: 'x', port: 23999).run();
  } on SocketException {
    refused = true;
  }
  check('reseau : serveur injoignable -> erreur signalee proprement', refused);

  // ---- TP4 : taquin
  check('taquin : h du but = 0 pour les 3 heuristiques', hMisplaced(kGoal) == 0 && hManhattan(kGoal) == 0 && hLinearConflict(kGoal) == 0);
  final swapped = toTiles(kGoal);
  swapped[0] = 2;
  swapped[1] = 1;
  check('taquin : configurations insolubles rejetees',
      isSolvable(toTiles(kGoal)) && !isSolvable(swapped) && [for (var t = 0; t < 50; t++) isSolvable(toTiles(scramble(30 + t, rnd)))].every((x) => x) && parseTiles('1 2 3') == null);
  okAll = true;
  for (var t = 0; t < 500; t++) {
    final s = scramble(1 + rnd.nextInt(80), rnd);
    if (hMisplaced(s) > hManhattan(s) || hManhattan(s) > hLinearConflict(s)) okAll = false;
  }
  check('taquin : h1 <= h2 <= h3 sur 500 etats aleatoires', okAll);
  okAll = true;
  for (var t = 0; t < 10; t++) {
    final s = scramble(6 + t, rnd);
    final ref = bfsPuzzle(s);
    for (var h = 0; h < 3; h++) {
      if (solvePuzzle(s, heuristicKind: h).moves != ref || solvePuzzle(s, heuristicKind: h, useHeap: false).moves != ref) okAll = false;
    }
  }
  check('taquin : longueur A* = reference BFS sur 10 melanges peu profonds (3 heuristiques, 2 files)', okAll);
  okAll = true;
  okTrace = true;
  var lens = '';
  for (var t = 0; t < 12; t++) {
    final s = scramble(18 + 2 * t, rnd);
    final a = solvePuzzle(s, heuristicKind: 1);
    final b = solvePuzzle(s, heuristicKind: 2);
    final c = solvePuzzle(s, heuristicKind: 0, nodeLimit: 400000);
    final n = solvePuzzle(s, heuristicKind: 2, useHeap: false);
    lens += '${a.moves} ';
    if (a.status != 'ok' || b.moves != a.moves || n.moves != a.moves || n.expanded != b.expanded) okAll = false;
    if (c.status == 'ok' && c.moves != a.moves) okAll = false;
    for (final p in [1.5, 2.0, 3.0]) {
      final w = solvePuzzle(s, heuristicKind: 1, weight: p);
      if (w.status != 'ok' || w.moves < a.moves || w.moves > p * a.moves) okAll = false;
    }
    if (b.expanded > a.expanded) okAll = false; // h3 domine h2
    if (hLinearConflict(s) > a.moves) okAll = false; // admissibilite
    // chemin valide
    for (var i = 1; i < a.path.length; i++) {
      final bl = blankOf(a.path[i - 1]);
      if (!kNeighbors[bl].any((pp) => swapBlank(a.path[i - 1], bl, pp) == a.path[i])) okAll = false;
    }
    if (t < 4) {
      for (final heap in [true, false]) {
        final tr = Trace();
        final x = solvePuzzle(s, heuristicKind: 2, useHeap: heap, trace: tr);
        if (x.moves != b.moves || x.expanded != b.expanded || !linesOk(tr, kAStarPseudo) || tr.steps.last.kind != StepKind.done) okTrace = false;
      }
    }
  }
  check('taquin : 12 melanges, optimalite, tas = file naive, WA* <= p x optimal (longueurs $lens)', okAll);
  check('taquin : executions tracees = executions normales, lignes de pseudo-code valides', okTrace);
  check('taquin : puzzle deja resolu', solvePuzzle(kGoal).moves == 0);
  var presetsOk = true;
  var presetLens = '';
  for (final p in kPuzzlePresets) {
    final r = solvePuzzle(fromTiles(p.tiles), heuristicKind: 2);
    presetLens += '${p.name}=${r.moves} ';
    if (!isSolvable(p.tiles) || r.status != 'ok') presetsOk = false;
  }
  check('taquin : exemples fournis resolubles ($presetLens)', presetsOk);

  // ---- calculs annulables
  final job = startJob<int>((progress) {
    progress(1);
    var x = 0;
    for (var i = 0; i < 1000; i++) {
      x += i;
    }
    return x;
  });
  final jr = await job.result;
  final endless = startJob<int>((_) {
    while (true) {}
  });
  await Future<void>.delayed(const Duration(milliseconds: 100));
  endless.cancel();
  check('calculs : resultat d\'un isolate et annulation', jr == 499500 && await endless.result == null);

  print(_fails == 0 ? '\nTous les tests passent.' : '\n$_fails test(s) en echec.');
  exit(_fails == 0 ? 0 : 1);
}
