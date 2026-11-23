import 'package:flutter/material.dart' hide Step;
import 'package:flutter_test/flutter_test.dart';
import 'package:tpro_lab/core/puzzle.dart';
import 'package:tpro_lab/core/trace.dart';
import 'package:tpro_lab/ui/lab_scaffold.dart';
import 'package:tpro_lab/ui/puzzle_page.dart';

import 'helpers.dart';

/// Attend (en temps reel) qu'une condition devienne vraie : les recherches tournent dans des isolates.
Future<void> waitFor(WidgetTester tester, bool Function() test, {int seconds = 40}) async {
  await tester.runAsync(() async {
    final sw = Stopwatch()..start();
    while (!test() && sw.elapsed.inSeconds < seconds) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  });
  await settle(tester, 400);
}

void main() {
  testWidgets('TP 4 : plateau, deplacement manuel, recherche pas a pas, comparaison', (tester) async {
    await pumpPage(tester, const PuzzlePage());
    expect(find.text('Taquin 15'), findsOneWidget);
    final scaffold = tester.widget<LabScaffold>(find.byType(LabScaffold));
    final host = scaffold.host;
    await shot(tester, 'tp4_idle');

    // Exemple « Facile » : la case vide est en 13, le jeton 14 est a sa droite.
    final before = tester.getCenter(find.byKey(const ValueKey('tile-14')));
    await tester.tap(find.byKey(const ValueKey('tile-14')));
    await settle(tester, 400);
    final after = tester.getCenter(find.byKey(const ValueKey('tile-14')));
    expect(after.dx, lessThan(before.dx - 20));

    // Scenario 1 : puzzle facile, pas a pas, h2, tas.
    scaffold.onScenario(0);
    await tester.pump(const Duration(milliseconds: 50));
    await waitFor(tester, () => host.player.hasTrace);
    expect(host.player.hasTrace, isTrue);
    expect(host.player.playing, isFalse);
    expect(host.checks.value.containsAll(['heap', 'h2']), isTrue);
    host.player.next();
    host.player.next();
    await settle(tester, 300);
    expect(host.player.index, 2);
    host.player.prev();
    await tester.pump();
    expect(host.player.index, 1);
    // Avance jusqu'a une etape avec des voisins pour voir le tas.
    while (!host.player.atEnd && !((host.player.current!.view as PuzzleView).neighbors.length >= 2)) {
      host.player.next();
    }
    await settle(tester, 400);
    await shot(tester, 'tp4_step');
    host.player.last();
    await settle(tester, 400);
    expect(host.player.current!.kind, StepKind.done);
    expect((host.player.current!.view as PuzzleView).state, kGoal);
    expect(find.textContaining('Solution : 10 déplacements'), findsOneWidget);
    await shot(tester, 'tp4_done');

    // Scenario 4 : WA* (p = 2), resolution rapide.
    scaffold.onScenario(3);
    await tester.pump(const Duration(milliseconds: 50));
    await waitFor(tester, () => host.checks.value.contains('wastar'));
    expect(host.checks.value.contains('wastar'), isTrue);
    host.player.pause();
    await settle(tester, 300);
    await shot(tester, 'tp4_wastar');

    // Comparaison sur l'exemple facile, selection reduite pour rester rapide.
    scaffold.onScenario(0);
    await tester.pump(const Duration(milliseconds: 50));
    await waitFor(tester, () => host.player.hasTrace);
    await tester.tap(find.text('Comparaison'));
    await settle(tester, 500);
    await tester.tap(find.text('Comparer'));
    await tester.pump(const Duration(milliseconds: 50));
    await waitFor(tester, () => host.checks.value.contains('compare'), seconds: 90);
    expect(host.checks.value.contains('compare'), isTrue);
    expect(find.textContaining('tas · h2 · p=1'), findsWidgets);
    await shot(tester, 'tp4_compare');
    await tester.tap(find.text('Graphiques'));
    await settle(tester, 300);
    await shot(tester, 'tp4_charts');
  });

  testWidgets('TP 4 : fenetre minimale et grandes polices sans debordement', (tester) async {
    await pumpPage(tester, const MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(1.25)), child: PuzzlePage()), size: const Size(1204, 760));
    expect(find.text('Taquin 15'), findsOneWidget);
    final host = tester.widget<LabScaffold>(find.byType(LabScaffold)).host;
    await shot(tester, 'tp4_min');
    await tester.tap(find.text('Comparaison'));
    await settle(tester, 500);
    await shot(tester, 'tp4_min_compare');
    host.tab.value = 1;
    await settle(tester, 300);
    host.tab.value = 2;
    await settle(tester, 300);
  });
}
