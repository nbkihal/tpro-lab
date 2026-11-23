import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/cycle_page.dart';
import 'ui/explain_panel.dart';
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
        colorScheme: ColorScheme.fromSeed(seedColor: C.cyan, brightness: Brightness.dark, surface: C.card),
        splashFactory: InkSparkle.splashFactory,
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.line)),
          textStyle: const TextStyle(color: C.text, fontSize: 12),
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStatePropertyAll(fade(C.muted, 0.35)),
          thickness: const WidgetStatePropertyAll(6),
          radius: const Radius.circular(3),
        ),
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      ),
      // L'interface est concue pour au moins 1280 x 760 points. Sur un ecran plus petit
      // (portable 1920 x 1080 a 150 %, video-projecteur), elle est dessinee a cette taille
      // puis reduite pour tenir dans la fenetre : rien n'est coupe.
      builder: (context, child) => LayoutBuilder(builder: (context, box) {
        const minW = 1280.0, minH = 760.0;
        final sw = box.maxWidth / minW, sh = box.maxHeight / minH;
        final s = sw < sh ? sw : sh;
        if (s >= 1 || !s.isFinite || s <= 0) return child!;
        final w = box.maxWidth / s, h = box.maxHeight / s;
        return FittedBox(
          child: SizedBox(
            width: w,
            height: h,
            child: MediaQuery(data: MediaQuery.of(context).copyWith(size: Size(w, h)), child: child!),
          ),
        );
      }),
      home: const Shell(),
    );
  }
}

class _Nav {
  final String label, tip;
  final IconData icon;
  const _Nav(this.label, this.tip, this.icon);
}

const _navs = [
  _Nav('Accueil', 'Accueil — choisir un TP (Ctrl+0)', Icons.dashboard_rounded),
  _Nav('TP 1', 'TP 1 — Plus petit cycle (Ctrl+1)', Icons.hub_rounded),
  _Nav('TP 2', 'TP 2 — Voyageur de commerce (Ctrl+2)', Icons.route_rounded),
  _Nav('TP 3', 'TP 3 — Morpion N×N (Ctrl+3)', Icons.grid_3x3_rounded),
  _Nav('TP 4', 'TP 4 — Taquin 15 (Ctrl+4)', Icons.extension_rounded),
];

/// Coquille : rail de navigation, pages gardees en vie, raccourcis, mode presentation.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  static const _window = MethodChannel('tpro_lab/window');

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    presentation.addListener(_onPresentation);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    presentation.removeListener(_onPresentation);
    super.dispose();
  }

  /// Plein ecran natif (Windows). Sur les autres plateformes, seul l'agrandissement
  /// des polices s'applique.
  Future<void> _onPresentation() async {
    try {
      await _window.invokeMethod<bool>('setFullscreen', presentation.value);
    } on MissingPluginException {
      // pas de canal natif sur cette plateforme
    } on PlatformException {
      // plein ecran refuse : le mode presentation reste actif sans lui
    }
  }

  bool _typing() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    return ctx != null && (ctx.widget is EditableText || ctx.findAncestorWidgetOfExactType<EditableText>() != null);
  }

  bool _onKey(KeyEvent e) {
    // Une boite de dialogue ou un menu est ouvert : on ne touche a rien.
    if (!mounted || Navigator.of(context).canPop()) return false;
    final k = e.logicalKey;
    if (e is KeyDownEvent) {
      if (k == LogicalKeyboardKey.f11) {
        presentation.value = !presentation.value;
        return true;
      }
      if (k == LogicalKeyboardKey.escape && presentation.value) {
        presentation.value = false;
        return true;
      }
      if (HardwareKeyboard.instance.isControlPressed) {
        const digits = [
          [LogicalKeyboardKey.digit0, LogicalKeyboardKey.numpad0],
          [LogicalKeyboardKey.digit1, LogicalKeyboardKey.numpad1],
          [LogicalKeyboardKey.digit2, LogicalKeyboardKey.numpad2],
          [LogicalKeyboardKey.digit3, LogicalKeyboardKey.numpad3],
          [LogicalKeyboardKey.digit4, LogicalKeyboardKey.numpad4],
        ];
        for (var i = 0; i < digits.length; i++) {
          if (digits[i].contains(k)) {
            LabBus.active.value = i;
            return true;
          }
        }
      }
    }
    if (_typing() || HardwareKeyboard.instance.isControlPressed) return false;
    return LabBus.keyHandlers[LabBus.active.value]?.call(e) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([LabBus.active, presentation]),
        builder: (context, _) {
          final index = LabBus.active.value;
          final mq = MediaQuery.of(context);
          return Row(children: [
            _rail(index),
            Expanded(
              child: MediaQuery(
                data: mq.copyWith(textScaler: TextScaler.linear(presentation.value ? 1.25 : 1.0)),
                child: IndexedStack(index: index, children: const [
                  HomePage(),
                  CyclePage(),
                  TspPage(),
                  TttPage(),
                  PuzzlePage(),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _rail(int index) => Container(
        width: 76,
        decoration: const BoxDecoration(color: C.sidebar, border: Border(right: BorderSide(color: C.line))),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [C.cyan, C.violet], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: fade(C.cyan, 0.35), blurRadius: 14)],
            ),
            child: const Icon(Icons.science_rounded, color: C.bg, size: 22),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < _navs.length; i++) _item(i, index),
          const Spacer(),
          Tooltip(
            message: 'Mode présentation (F11)',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => presentation.value = !presentation.value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: presentation.value ? fade(C.cyan, 0.16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: presentation.value ? fade(C.cyan, 0.6) : C.line),
                ),
                child: Icon(presentation.value ? Icons.fullscreen_exit_rounded : Icons.slideshow_rounded,
                    size: 21, color: presentation.value ? C.cyan : C.muted),
              ),
            ),
          ),
        ]),
      );

  Widget _item(int i, int index) {
    final nav = _navs[i];
    final color = kAccents[i];
    final on = i == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Tooltip(
        message: nav.tip,
        waitDuration: const Duration(milliseconds: 300),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => LabBus.active.value = i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: on ? fade(color, 0.13) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: on ? fade(color, 0.55) : Colors.transparent),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(nav.icon, size: 21, color: on ? color : C.muted),
              const SizedBox(height: 4),
              Text(nav.label,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(color: on ? color : C.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            ]),
          ),
        ),
      ),
    );
  }
}
