import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpro_lab/main.dart';
import 'package:tpro_lab/ui/cycle_page.dart';
import 'package:tpro_lab/ui/explain_panel.dart';
import 'package:tpro_lab/ui/home_page.dart';
import 'package:tpro_lab/ui/lab_scaffold.dart';
import 'package:tpro_lab/ui/transport.dart';

import 'helpers.dart';

void main() {
  testWidgets('accueil : quatre cartes et l\'ordre conseille', (tester) async {
    await pumpPage(tester, const HomePage());
    expect(find.text('Lancer la démonstration'), findsNWidgets(4));
    expect(find.text('Plus petit cycle'), findsOneWidget);
    expect(find.text('Taquin 15'), findsOneWidget);
    await shot(tester, 'home');
  });

  testWidgets('TP 1 : execution, pas avant, pas arriere, scenarios, enonce', (tester) async {
    await pumpPage(tester, const CyclePage());
    expect(find.text('Plus petit cycle'), findsOneWidget);
    expect(find.byType(TransportBar), findsOneWidget);
    await shot(tester, 'tp1_idle');

    // Lancer : une trace est chargee et se rejoue.
    await tester.tap(find.text('Lancer la démonstration'));
    await settle(tester, 1500);
    expect(find.textContaining('étape'), findsWidgets);
    await shot(tester, 'tp1_running');

    // Pause, un pas en avant, un pas en arriere.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    final host = tester.widget<LabScaffold>(find.byType(LabScaffold)).host;
    final at = host.player.index;
    host.player.next();
    await tester.pump();
    expect(host.player.index, at + 1);
    host.player.prev();
    await tester.pump();
    expect(host.player.index, at);

    // Fin : le resultat est affiche et les exigences sont cochees.
    host.player.last();
    await settle(tester);
    expect(find.text('Plus petit cycle : 3'), findsOneWidget);
    expect(host.checks.value.containsAll(['repr', 'bfs_each', 'result', 'complexity']), isTrue);
    await shot(tester, 'tp1_done');

    // Onglet Demo : script, scenarios, questions.
    host.tab.value = 1;
    await settle(tester);
    expect(find.text('Charger'), findsWidgets);
    await shot(tester, 'tp1_demo');

    // Onglet Enonce : texte officiel.
    host.tab.value = 2;
    await settle(tester);
    expect(find.textContaining('shortest cycle in an undirected graph', findRichText: true), findsWidgets);
    await shot(tester, 'tp1_statement');
  });

  testWidgets('application complete : navigation sans perte d\'etat', (tester) async {
    await loadRealFonts();
    tester.view.physicalSize = const Size(1440, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TproApp());
    await settle(tester);
    expect(find.text('TPRO Lab'), findsOneWidget);
    LabBus.open(1, scenarioIndex: 1); // Petersen, lecture rapide
    await settle(tester, 400);
    LabBus.active.value = 0;
    await settle(tester, 200);
    LabBus.active.value = 1;
    await settle(tester, 200);
    expect(find.textContaining('Petersen'), findsWidgets);
    LabBus.active.value = 0;
    await settle(tester, 100);
  });

  // Taille minimale de la fenetre (1280 x 760 moins le rail) et mode presentation (polices x 1,25).
  testWidgets('TP 1 et accueil : taille minimale et mode presentation sans debordement', (tester) async {
    await pumpPage(tester, const MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(1.25)), child: CyclePage()),
        size: const Size(1204, 760));
    await tester.tap(find.text('Lancer la démonstration'));
    await settle(tester, 800);
    final host = tester.widget<LabScaffold>(find.byType(LabScaffold)).host;
    host.player.last();
    await settle(tester);
    await shot(tester, 'tp1_min_presentation');
    host.tab.value = 1;
    await settle(tester);
    host.tab.value = 2;
    await settle(tester);
    await pumpPage(tester, const MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(1.25)), child: HomePage()),
        size: const Size(1204, 760));
    await shot(tester, 'home_min_presentation');
  });
}
