// Tests des noyaux algorithmiques (version courte ; la version complete est tool/selftest.dart).
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tpro_lab/core/demo_content.dart';
import 'package:tpro_lab/core/graph.dart';
import 'package:tpro_lab/core/puzzle.dart';
import 'package:tpro_lab/core/trace.dart';
import 'package:tpro_lab/core/tsp.dart';
import 'package:tpro_lab/core/ttt_board.dart';
import 'package:tpro_lab/core/ttt_engine.dart';
import 'package:tpro_lab/core/ttt_net.dart';

Graph _preset(String name) {
  final p = kGraphPresets.firstWhere((g) => g.name == name);
  return Graph.fromEdges(p.pos.length, p.edges);
}

bool _linesOk(Trace t, List<String> pseudo) => t.steps.isNotEmpty && t.steps.every((s) => s.line >= 1 && s.line <= pseudo.length);

void main() {
  group('TP 1 — plus petit cycle', () {
    test('exemples', () {
      expect(shortestCycle(_preset('Carré')).length, 4);
      expect(shortestCycle(_preset('Petersen')).length, 5);
      expect(shortestCycle(_preset('Arbre')).cycle, isEmpty);
      expect(shortestCycle(_preset('2 composantes')).length, 3);
      expect(shortestCycle(Graph()).cycle, isEmpty);
    });
    test('trace = execution normale, lignes valides', () {
      final g = _preset('Grille 4×4');
      final t = Trace();
      expect(shortestCycle(g, trace: t).length, shortestCycle(g).length);
      expect(_linesOk(t, kCyclePseudo), isTrue);
      expect(t.steps.last.kind, StepKind.done);
    });
  });

  group('TP 2 — voyageur de commerce', () {
    test('les trois methodes donnent le meme cout', () {
      final rnd = Random(3);
      for (var k = 0; k < 40; k++) {
        final d = randomMatrix(3 + rnd.nextInt(6), rnd, symmetric: k.isEven);
        final a = tspBruteForce(d), b = tspHeldKarp(d), c = tspBruteForceBfs(d);
        expect(b.cost, a.cost);
        expect(c.cost, a.cost);
        expect(tourCost(d, b.tour), b.cost);
        expect(b.tour.toSet().length, d.length);
      }
    });
    test('traces', () {
      final t1 = Trace(), t2 = Trace(), t3 = Trace();
      expect(tspBruteForce(kTspDefault6, trace: t1).cost, tspHeldKarp(kTspDefault6, trace: t3).cost);
      tspBruteForceBfs(kTspDemo4, trace: t2);
      expect(_linesOk(t1, kEnumPseudo) && _linesOk(t2, kEnumPseudo) && _linesOk(t3, kHkPseudo), isTrue);
    });
  });

  group('TP 3 — morpion', () {
    test('estimation et tactique', () {
      expect(Board(7, 4).estimation(Board.defaultWeights(4)), 0);
      final b = Board(3, 3);
      for (final mv in [[0, kX], [3, kO], [1, kX], [4, kO]]) {
        b.place(mv[0], mv[1]);
      }
      expect(Engine().think(b, kX, hmax: 6, timeMs: 2000).move, 2);
    });
    test('le delai est respecte et un coup legal est toujours renvoye', () {
      final sw = Stopwatch()..start();
      final r = Engine().think(Board(11, 5)..place(60, kX), kO, hmax: 30, timeMs: 300);
      expect(sw.elapsedMilliseconds, lessThan(450));
      expect(r.move, isNot(60));
      expect(r.move, greaterThanOrEqualTo(0));
      expect(r.timedOut, isTrue);
    });
    test('trace : meme coup, lignes valides', () {
      final demo = Board.fromCells(3, 3, kTttDemoCells);
      const opt = EngineOptions(useTT: false, tactics: false);
      final t = Trace();
      final trees = <SearchTree>[];
      final a = Engine().think(demo, kX, hmax: 4, timeMs: 5000, options: opt);
      final b = Engine().think(demo, kX, hmax: 4, timeMs: 5000, options: opt, trace: t, trees: trees);
      expect(b.move, a.move);
      expect(_linesOk(t, kTttPseudo), isTrue);
      expect(trees, isNotEmpty);
    });
    test('analyse tolerante du protocole', () {
      expect(parseMove('x  AT 2,3')!.j, 3);
      expect(parseParams(' 7  4 5 X')!.tmo, 5);
      expect(parseGameOver('gameover cost = -1'), -1);
      expect(parseMove('bonjour'), isNull);
    });
  });

  group('TP 4 — taquin', () {
    test('heuristiques', () {
      final rnd = Random(5);
      for (var h = 0; h < 3; h++) {
        expect(heuristic(h, kGoal), 0);
      }
      for (var k = 0; k < 200; k++) {
        final s = scramble(1 + rnd.nextInt(60), rnd);
        expect(hMisplaced(s) <= hManhattan(s) && hManhattan(s) <= hLinearConflict(s), isTrue);
      }
    });
    test('A*, files et WA*', () {
      final s = fromTiles(kPuzzlePresets[1].tiles);
      final a = solvePuzzle(s, heuristicKind: 2);
      final n = solvePuzzle(s, heuristicKind: 2, useHeap: false);
      final w = solvePuzzle(s, heuristicKind: 1, weight: 2);
      expect(a.moves, kPuzzlePresets[1].optimal);
      expect(n.moves, a.moves);
      expect(n.expanded, a.expanded);
      expect(w.moves, inInclusiveRange(a.moves, 2 * a.moves));
      final t = Trace();
      expect(solvePuzzle(s, heuristicKind: 2, trace: t).moves, a.moves);
      expect(_linesOk(t, kAStarPseudo), isTrue);
    });
    test('parite', () {
      final bad = toTiles(kGoal);
      bad[0] = 2;
      bad[1] = 1;
      expect(isSolvable(bad), isFalse);
      expect(isSolvable(toTiles(kGoal)), isTrue);
    });
  });
}
