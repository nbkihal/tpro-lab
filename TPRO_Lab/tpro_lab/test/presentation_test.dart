// Chaque page a la taille minimale de la fenetre (1280 x 760 moins le rail) avec les polices
// du mode presentation (x 1,25) : aucun debordement, sur tous les onglets.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpro_lab/ui/cycle_page.dart';
import 'package:tpro_lab/ui/lab_scaffold.dart';
import 'package:tpro_lab/ui/puzzle_page.dart';
import 'package:tpro_lab/ui/tsp_page.dart';
import 'package:tpro_lab/ui/ttt_page.dart';

import 'helpers.dart';

void main() {
  final pages = <String, Widget>{
    'tp1': const CyclePage(),
    'tp2': const TspPage(),
    'tp3': const TttPage(),
    'tp4': const PuzzlePage(),
  };
  for (final e in pages.entries) {
    testWidgets('${e.key} : taille minimale + mode presentation', (tester) async {
      await pumpPage(tester, MediaQuery(data: const MediaQueryData(textScaler: TextScaler.linear(1.25)), child: e.value),
          size: const Size(1204, 760));
      final host = tester.widget<LabScaffold>(find.byType(LabScaffold)).host;
      for (final tab in [1, 2, 0]) {
        host.tab.value = tab;
        await settle(tester, 300);
      }
      host.bottomOpen.value = false;
      await settle(tester, 400);
      host.bottomOpen.value = true;
      await settle(tester, 400);
      await shot(tester, '${e.key}_presentation_min');
      // Demonter la page proprement (timers, isolates, sockets).
      await tester.pumpWidget(const SizedBox());
      await settle(tester, 200);
    });
  }
}
