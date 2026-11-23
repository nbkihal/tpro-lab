import 'package:flutter/material.dart' hide Step;

import '../core/demo_content.dart';
import '../core/trace.dart';
import 'explain_panel.dart';
import 'kit.dart';
import 'transport.dart';

/// Mise en page commune aux quatre TP :
///   en-tete · scene de demonstration · barre de transport · zone basse repliable
///   et, a droite, le panneau d'explication redimensionnable.
class LabScaffold extends StatefulWidget {
  /// Indice de page (1..4), utilise pour les raccourcis clavier et les scenarios.
  final int labIndex;
  final LabContent content;
  final LabHost host;
  final Widget canvas;

  /// Zone basse : reglages, resultats, tableaux, graphiques, journal.
  final Widget bottom;
  final double bottomHeight;
  final List<String> pseudo;
  final String pseudoTitle;
  final Map<String, String> Function()? counters;
  final Widget Function(BuildContext context, Step? step)? extra;
  final void Function(int index) onScenario;
  final void Function(String req) onRequirement;

  /// Raccourcis propres au TP, essayes avant ceux de la barre de transport.
  final bool Function(KeyEvent event)? onKey;
  final String idleText;
  final String transportHint;

  const LabScaffold({
    super.key,
    required this.labIndex,
    required this.content,
    required this.host,
    required this.canvas,
    required this.bottom,
    required this.pseudo,
    required this.pseudoTitle,
    required this.onScenario,
    required this.onRequirement,
    this.bottomHeight = 236,
    this.counters,
    this.extra,
    this.onKey,
    this.idleText = 'Lancez la démonstration : chaque étape sera expliquée ici.',
    this.transportHint = 'Lancez la démonstration pour obtenir une trace à rejouer',
  });

  @override
  State<LabScaffold> createState() => _LabScaffoldState();
}

class _LabScaffoldState extends State<LabScaffold> {
  double _panelWidth = 420;
  bool _panelOpen = true;

  Color get _accent => kAccents[widget.labIndex];

  @override
  void initState() {
    super.initState();
    LabBus.keyHandlers[widget.labIndex] = _onKey;
    LabBus.scenario.addListener(_onScenarioRequest);
    presentation.addListener(_onPresentation);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScenarioRequest());
  }

  @override
  void dispose() {
    if (LabBus.keyHandlers[widget.labIndex] == _onKey) LabBus.keyHandlers.remove(widget.labIndex);
    LabBus.scenario.removeListener(_onScenarioRequest);
    presentation.removeListener(_onPresentation);
    super.dispose();
  }

  bool _onKey(KeyEvent e) => (widget.onKey?.call(e) ?? false) || widget.host.player.handleKey(e);

  void _onScenarioRequest() {
    final r = LabBus.scenario.value;
    if (r == null || r[0] != widget.labIndex || !mounted) return;
    LabBus.scenario.value = null;
    widget.onScenario(r[1]);
  }

  // En mode presentation, la zone de reglages se replie pour laisser la place a la scene.
  void _onPresentation() => widget.host.bottomOpen.value = !presentation.value;

  @override
  Widget build(BuildContext context) {
    final c = widget.content;
    final host = widget.host;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(c),
        const SizedBox(height: 12),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: _canvas()),
                const SizedBox(height: 8),
                TransportBar(player: host.player, accent: _accent, emptyHint: widget.transportHint),
                const SizedBox(height: 8),
                _bottom(),
              ]),
            ),
            if (_panelOpen) ...[
              MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) => setState(() => _panelWidth = (_panelWidth - d.delta.dx).clamp(340.0, 720.0)),
                  child: SizedBox(
                    width: 12,
                    child: Center(child: Container(width: 3, height: 44, decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(2)))),
                  ),
                ),
              ),
              SizedBox(
                width: _panelWidth,
                child: ExplainPanel(
                  host: host,
                  content: c,
                  accent: _accent,
                  pseudo: widget.pseudo,
                  pseudoTitle: widget.pseudoTitle,
                  counters: widget.counters,
                  extra: widget.extra,
                  onScenario: (i) {
                    host.tab.value = 0;
                    widget.onScenario(i);
                  },
                  onRequirement: widget.onRequirement,
                  idleText: widget.idleText,
                  onCollapse: () => setState(() => _panelOpen = false),
                ),
              ),
            ] else ...[
              const SizedBox(width: 8),
              Column(children: [
                IconBtn(icon: Icons.chevron_left_rounded, tip: 'Afficher le panneau d\'explication', color: _accent, active: true, onTap: () => setState(() => _panelOpen = true)),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _header(LabContent c) => SizedBox(
        height: 40,
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: fade(_accent, 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(c.tag, style: TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ),
          const SizedBox(width: 12),
          Text(c.title, style: const TextStyle(color: C.text, fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(width: 12),
          Expanded(child: Text(c.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 13))),
          const SizedBox(width: 8),
          ChipBtn(
              label: 'Énoncé',
              icon: Icons.description_outlined,
              color: _accent,
              tip: 'Afficher l\'énoncé officiel (${c.source})',
              onTap: () {
                setState(() => _panelOpen = true);
                widget.host.tab.value = 2;
              }),
          const SizedBox(width: 8),
          ValueListenableBuilder<bool>(
            valueListenable: presentation,
            builder: (_, on, __) => ChipBtn(
                label: 'Mode présentation',
                icon: on ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                color: _accent,
                active: on,
                tip: 'Plein écran et grandes polices (F11)',
                onTap: () => presentation.value = !on),
          ),
        ]),
      );

  /// Scene de demonstration ; son contour clignote brievement sur les etapes importantes.
  Widget _canvas() => AnimatedBuilder(
        animation: widget.host.player,
        builder: (context, child) => Stack(fit: StackFit.expand, children: [
          child!,
          IgnorePointer(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(widget.host.player.flash),
              tween: Tween(begin: widget.host.player.flash == 0 ? 0.0 : 1.0, end: 0),
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeOut,
              builder: (_, t, __) => DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: fade(_flashColor(), t), width: 2.5),
                  color: fade(_flashColor(), 0.05 * t),
                ),
              ),
            ),
          ),
        ]),
        child: Container(
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
          clipBehavior: Clip.antiAlias,
          child: widget.canvas,
        ),
      );

  Color _flashColor() => switch (widget.host.player.current?.kind) {
        StepKind.found || StepKind.done => C.green,
        StepKind.pruned => C.red,
        _ => _accent,
      };

  Widget _bottom() => ValueListenableBuilder<bool>(
        valueListenable: widget.host.bottomOpen,
        builder: (context, open, _) => Container(
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
          clipBehavior: Clip.antiAlias,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            InkWell(
              onTap: () => widget.host.bottomOpen.value = !open,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(children: [
                  Icon(Icons.tune_rounded, size: 14, color: _accent),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('RÉGLAGES · RÉSULTATS · MESURES', style: TextStyle(color: C.muted, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  ),
                  AnimatedRotation(
                      turns: open ? 0 : 0.5, duration: const Duration(milliseconds: 180), child: const Icon(Icons.expand_more_rounded, size: 18, color: C.muted)),
                ]),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: open
                  ? SizedBox(
                      height: widget.bottomHeight,
                      child: Padding(padding: const EdgeInsets.fromLTRB(12, 2, 12, 12), child: widget.bottom),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ]),
        ),
      );
}

/// Onglets de la zone basse (Reglages / Resultats / Journal...).
class BottomTabs extends StatelessWidget {
  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  final Color accent;
  final List<Widget> children;
  final Widget? trailing;
  const BottomTabs({super.key, required this.tabs, required this.index, required this.onChanged, required this.accent, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        // Les onglets defilent si la place manque (fenetre minimale, grandes polices).
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (var i = 0; i < tabs.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChipBtn(label: tabs[i], color: accent, active: i == index, onTap: () => onChanged(i)),
                ),
            ]),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ]),
      const SizedBox(height: 8),
      Expanded(child: IndexedStack(index: index, children: children)),
    ]);
  }
}
