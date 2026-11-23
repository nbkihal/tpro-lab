import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpro_lab/core/ttt_board.dart';
import 'package:tpro_lab/ui/ttt_page.dart';

import 'helpers.dart';

/// Attend (en temps reel) qu'une condition devienne vraie.
Future<bool> waitFor(WidgetTester tester, bool Function() test, {int seconds = 20}) async {
  for (var i = 0; i < seconds * 10; i++) {
    if (test()) return true;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  return test();
}

void main() {
  TttPageState stateOf(WidgetTester tester) => tester.state<TttPageState>(find.byType(TttPage));

  testWidgets('TP 3 : la page tient dans la fenetre minimale', (tester) async {
    await pumpPage(tester, const TttPage(), size: const Size(1204, 760));
    expect(tester.takeException(), isNull);
    expect(find.text('Morpion N×N'), findsOneWidget);
    await shot(tester, 'tp3_min');
  });

  testWidgets('TP 3 : moi contre l\'IA, carte de chaleur', (tester) async {
    await pumpPage(tester, const TttPage());
    expect(tester.takeException(), isNull);
    final s = stateOf(tester);
    await shot(tester, 'tp3_idle');
    s.hmax = 3;
    // Un clic au centre de la grille pose mon X ; l'IA repond.
    await tester.tapAt(tester.getCenter(find.byKey(const Key('ttt-board'))));
    await tester.pump();
    expect(s.board.count, 1);
    expect(s.board.cells[24], kX);
    expect(await waitFor(tester, () => s.board.count == 2 && !s.thinking), isTrue);
    expect(s.lastSearch, isNotNull);
    expect(s.host.checks.value.contains('estim'), isTrue);
    // Deuxieme coup, puis carte de chaleur.
    final box = tester.getRect(find.byKey(const Key('ttt-board')));
    await tester.tapAt(box.center + Offset(-box.shortestSide * 0.27, box.shortestSide * 0.27)); // case eloignee, forcement libre
    await tester.pump();
    expect(await waitFor(tester, () => s.board.count == 4 && !s.thinking), isTrue);
    await tester.tap(find.text('Carte de chaleur'));
    await settle(tester);
    expect(s.heat, isTrue);
    await shot(tester, 'tp3_heat');
    // Onglet Resultats : tableau des iterations.
    await tester.tap(find.text('Résultats'));
    await settle(tester);
    expect(find.text('APPROFONDISSEMENT ITÉRATIF'), findsOneWidget);
    await shot(tester, 'tp3_results');
    expect(tester.takeException(), isNull);
  });

  testWidgets('TP 3 : scenario pas a pas, arbre de recherche, pas avant / arriere', (tester) async {
    await pumpPage(tester, const TttPage());
    final s = stateOf(tester);
    await tester.runAsync(() => s.loadScenario(0));
    await settle(tester);
    expect(s.host.player.hasTrace, isTrue);
    expect(s.trees, isNotEmpty);
    expect(find.byKey(const Key('ttt-tree')), findsNothing); // premiere etape : pas encore d'iteration
    s.host.player.seek(s.host.player.steps.length ~/ 2);
    await settle(tester);
    expect(find.byKey(const Key('ttt-tree')), findsOneWidget);
    await shot(tester, 'tp3_step_tree');
    final at = s.host.player.index;
    s.host.player.next();
    await tester.pump();
    expect(s.host.player.index, at + 1);
    s.host.player.prev();
    await tester.pump();
    expect(s.host.player.index, at);
    s.host.player.last();
    await settle(tester);
    await shot(tester, 'tp3_step_end');
    expect(s.board.count, 4); // la recherche tracee ne joue pas le coup
    expect(tester.takeException(), isNull);
  });

  testWidgets('TP 3 : scenarios alarme (TMO = 1 s, HMAX = 20) et tri des coups', (tester) async {
    await pumpPage(tester, const TttPage());
    final s = stateOf(tester);
    await tester.runAsync(() => s.loadScenario(2));
    expect(await waitFor(tester, () => s.host.checks.value.contains('alarm'), seconds: 10), isTrue);
    expect(s.lastSearch!.r.timedOut, isTrue);
    expect(s.lastSearch!.r.millis, lessThan(1000)); // jamais plus que TMO
    expect(s.board.count, 3); // l'IA a bien joue un coup legal
    await settle(tester);
    await shot(tester, 'tp3_alarm');
    await tester.runAsync(() => s.loadScenario(3));
    await settle(tester);
    expect(s.prevSearch!.label, 'avec tri');
    expect(s.lastSearch!.label, 'sans tri');
    expect(s.lastSearch!.r.nodes, greaterThan(s.prevSearch!.r.nodes));
    await shot(tester, 'tp3_ordering');
    expect(tester.takeException(), isNull);
  });

  testWidgets('TP 3 : IA contre IA jusqu\'a la fin de la partie', (tester) async {
    await pumpPage(tester, const TttPage());
    final s = stateOf(tester);
    s.newGame(change: () {
      s.n = 3;
      s.m = 3;
      s.hmax = 4;
      s.hmax2 = 2;
    });
    await tester.pump();
    s.toggleAiVsAi();
    expect(await waitFor(tester, () => s.board.status() != 0, seconds: 40), isTrue);
    await settle(tester);
    expect(s.resultText, isNotNull);
    expect(s.host.checks.value.contains('hmax'), isTrue);
    await shot(tester, 'tp3_ai_vs_ai');
    expect(tester.takeException(), isNull);
  });

  testWidgets('TP 3 : demonstration locale (serveur integre + deux clients) jusqu\'au gameover', (tester) async {
    await pumpPage(tester, const TttPage());
    final s = stateOf(tester);
    s.newGame(change: () {
      s.n = 3;
      s.m = 3;
      s.tmo = 2;
      s.hmax = 4;
      s.hmax2 = 2;
    });
    s.portCtl.text = '24571';
    await tester.pump();
    // Le serveur, les sockets et les isolates ont besoin du temps reel.
    await tester.runAsync(() async {
      final done = s.startLocal();
      for (var i = 0; i < 300 && !s.host.checks.value.contains('net'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await done.timeout(const Duration(seconds: 10), onTimeout: () {});
    });
    await settle(tester);
    expect(s.host.checks.value.contains('net'), isTrue);
    expect(s.resultText, contains('gameover cost ='));
    expect(s.netActive, isFalse);
    expect(s.board.status(), isNot(0));
    await shot(tester, 'tp3_local_demo');

    // Serveur injoignable : message d'erreur, pas de plantage.
    s.portCtl.text = '24999';
    await tester.runAsync(() => s.connect());
    await settle(tester);
    expect(s.netActive, isFalse);
    expect(s.debugLog.any((l) => l.contains('connexion impossible')), isTrue);
    // Le message d'erreur (toast) a besoin du theme de l'application (SnackBar flottant) :
    // avec le theme reduit des tests, son affichage leve une assertion que l'on ecarte ici.
    tester.takeException();
    await settle(tester, 7000); // laisse le message disparaitre
    tester.takeException();
  });
}
