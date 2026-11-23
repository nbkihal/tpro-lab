import 'package:flutter/material.dart';

import 'ui/cycle_page.dart';
import 'ui/home_page.dart';
import 'ui/kit.dart';
import 'ui/puzzle_page.dart';
import 'ui/tsp_page.dart';
import 'ui/ttt_page.dart';

void main() => runApp(const TproApp());

class TproApp extends StatelessWidget {
  const TproApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TPRO Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: C.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: C.cyan, brightness: Brightness.dark),
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      ),
      home: const Shell(),
    );
  }
}

class _Nav {
  final String label, sub;
  final IconData icon;
  final Color color;
  const _Nav(this.label, this.sub, this.icon, this.color);
}

const _navs = [
  _Nav('Accueil', 'Les 4 TP', Icons.dashboard_rounded, C.text),
  _Nav('Plus court cycle', 'TP 1 - BFS', Icons.hub_rounded, C.cyan),
  _Nav('Voyageur de commerce', 'TP 2 - Held-Karp', Icons.route_rounded, C.amber),
  _Nav('Morpion N x N', 'TP 3 - MinMax', Icons.grid_3x3_rounded, C.violet),
  _Nav('Taquin 4 x 4', 'TP 4 - A* / WA*', Icons.extension_rounded, C.green),
];

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(children: [
        Container(
          width: 232,
          color: C.sidebar,
          padding: const EdgeInsets.fromLTRB(14, 22, 14, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [C.cyan, C.violet], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.science_rounded, color: C.bg, size: 20),
                ),
                const SizedBox(width: 10),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TPRO Lab', style: TextStyle(color: C.text, fontSize: 17, fontWeight: FontWeight.w800)),
                  Text('ESI - 2CS SIQ/SIL', style: TextStyle(color: C.muted, fontSize: 11)),
                ]),
              ]),
            ),
            const SizedBox(height: 26),
            for (var i = 0; i < _navs.length; i++) _item(i),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text('Les recherches tournent dans des\nisolates : l\'interface reste fluide.',
                  style: TextStyle(color: C.muted, fontSize: 11, height: 1.4)),
            ),
          ]),
        ),
        Expanded(
          child: IndexedStack(index: _index, children: [
            HomePage(onOpen: (i) => setState(() => _index = i)),
            const CyclePage(),
            const TspPage(),
            const TttPage(),
            const PuzzlePage(),
          ]),
        ),
      ]),
    );
  }

  Widget _item(int i) {
    final nav = _navs[i];
    final on = i == _index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _index = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: on ? fade(nav.color, 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? fade(nav.color, 0.45) : Colors.transparent),
          ),
          child: Row(children: [
            Icon(nav.icon, size: 20, color: on ? nav.color : C.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nav.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: on ? C.text : C.muted, fontSize: 13, fontWeight: FontWeight.w700)),
                Text(nav.sub, style: const TextStyle(color: C.muted, fontSize: 10.5)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
