import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpro_lab/core/tsp.dart';
import 'package:tpro_lab/ui/explain_panel.dart';
import 'package:tpro_lab/ui/lab_scaffold.dart';
import 'package:tpro_lab/ui/transport.dart';
import 'package:tpro_lab/ui/tsp_page.dart';

import 'helpers.dart';

/// Attend (en temps reel : les calculs tournent dans un isolate) que [done] soit vrai.
Future<void> waitFor(WidgetTester tester, bool Function() done) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 400 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  });
  await settle(tester, 300);
}

void main() {
  testWidgets('TP 2 : la page tient dans la fenetre minimale', (tester) async {
    await pumpPage(tester, const TspPage(), size: const Size(1204, 760));
    expect(find.text('Voyageur de commerce'), findsOneWidget);
    expect(find.byType(TransportBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await shot(tester, 'tp2_min');
  });

  testWidgets('TP 2 : Held-Karp pas a pas, enumeration, les deux methodes, banc d\'essai', (tester) async {
    await pumpPage(tester, const TspPage());
    final host = tester.widget<LabScaffold>(find.byType(LabScaffold)).host;
    await shot(tester, 'tp2_idle');

    // Scenario 2 : n = 4, Held-Karp pas a pas, en pause sur la premiere etape.
    LabBus.scenario.value = [2, 1];
    await tester.pump();
    await waitFor(tester, () => host.player.hasTrace);
    expect(host.player.hasTrace, isTrue);
    expect(host.player.playing, isFalse);
    expect(host.player.current!.view, isA<HkView>());
    expect(find.textContaining('coût 80'), findsWidgets);

    // Un pas en avant, un pas en arriere.
    host.player.next();
    await tester.pump();
    expect(host.player.index, 1);
    host.player.prev();
    await tester.pump();
    expect(host.player.index, 0);

    // Milieu de la trace : la table C(S, j) se remplit, la recurrence est chiffree.
    host.player.seek(host.player.steps.indexWhere((s) => s.line == 6 && (s.view as HkView).filled >= 6));
    await settle(tester);
    expect(find.textContaining('SOUS-ENSEMBLES DE 3 VILLES'), findsOneWidget);
    expect(host.checks.value.contains('loops'), isTrue);
    await shot(tester, 'tp2_hk_step');

    host.player.last();
    await settle(tester);
    expect(find.text('Coût optimal : 80'), findsOneWidget);
    expect(host.checks.value.contains('hk'), isTrue);
    await shot(tester, 'tp2_hk_done');

    // Scenario 1 : n = 6, enumeration des 120 cycles.
    LabBus.scenario.value = [2, 0];
    await tester.pump();
    await waitFor(tester, () => host.player.hasTrace && host.player.current!.view is EnumView);
    host.player.pause();
    expect(host.player.steps.where((s) => s.line == 3).length, 120);
    host.player.seek(60);
    await settle(tester);
    await shot(tester, 'tp2_enum_step');
    host.player.last();
    await settle(tester);
    expect(host.checks.value.containsAll(['n6', 'enum']), isTrue);

    // Les deux methodes sur la meme instance : meme cout.
    await tester.tap(find.text('Lancer les deux'));
    await tester.pump();
    await waitFor(tester, () => find.textContaining('Même coût optimal').evaluate().isNotEmpty);
    expect(find.textContaining('Même coût optimal'), findsOneWidget);
    await shot(tester, 'tp2_both');

    // Onglet du banc d'essai (sans le lancer : il dure plusieurs secondes).
    await tester.tap(find.text('Banc d\'essai'));
    await settle(tester);
    expect(find.text('Lancer le banc d\'essai'), findsOneWidget);
    expect(find.text('Exporter CSV'), findsOneWidget);
    await shot(tester, 'tp2_bench');

    host.tab.value = 1;
    await settle(tester);
    expect(find.text('Charger'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
