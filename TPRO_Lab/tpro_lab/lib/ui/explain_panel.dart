import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Step;

import '../core/demo_content.dart';
import '../core/trace.dart';
import 'kit.dart';
import 'transport.dart';

/// Etat partage d'un TP : lecteur de trace, exigences cochees, element mis en evidence,
/// onglet du panneau d'explication.
class LabHost {
  final TracePlayer player = TracePlayer();

  /// Exigences de l'enonce deja montrees pendant la seance.
  final ValueNotifier<Set<String>> checks = ValueNotifier<Set<String>>(<String>{});

  /// Identifiant de l'element d'interface a mettre en evidence (null : aucun).
  final ValueNotifier<String?> spot = ValueNotifier<String?>(null);

  /// Onglet du panneau : 0 Execution, 1 Demo, 2 Enonce.
  final ValueNotifier<int> tab = ValueNotifier<int>(0);
  final ValueNotifier<bool> bottomOpen = ValueNotifier<bool>(true);
  Timer? _spotTimer;

  void tick(String id) {
    if (checks.value.contains(id)) return;
    checks.value = {...checks.value, id};
  }

  void spotlight(String id) {
    _spotTimer?.cancel();
    spot.value = null;
    spot.value = id;
    _spotTimer = Timer(const Duration(milliseconds: 2800), () => spot.value = null);
  }

  void dispose() {
    _spotTimer?.cancel();
    player.dispose();
    checks.dispose();
    spot.dispose();
    tab.dispose();
    bottomOpen.dispose();
  }
}

/// Liaison entre la coquille (rail, raccourcis, accueil) et les pages des TP.
class LabBus {
  /// Page affichee : 0 accueil, 1..4 les TP.
  static final ValueNotifier<int> active = ValueNotifier<int>(0);

  /// Gestionnaire clavier de chaque TP (cle : indice de page).
  static final Map<int, bool Function(KeyEvent)> keyHandlers = {};

  /// Demande de chargement d'un scenario : [page, indice du scenario].
  static final ValueNotifier<List<int>?> scenario = ValueNotifier<List<int>?>(null);

  static void open(int page, {int? scenarioIndex}) {
    active.value = page;
    if (scenarioIndex != null) scenario.value = [page, scenarioIndex];
  }
}

/// Entoure un element d'interface qui repond a une exigence de l'enonce : il clignote
/// quand on clique la phrase correspondante dans l'onglet « Enonce ».
class SpotTarget extends StatelessWidget {
  final LabHost host;
  final List<String> ids;
  final Widget child;
  final Color color;
  final double radius;
  const SpotTarget({super.key, required this.host, required this.ids, required this.child, this.color = C.cyan, this.radius = 14});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: host.spot,
      child: child,
      builder: (context, spot, child) {
        if (spot == null || !ids.contains(spot)) return child!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Scrollable.maybeOf(context)?.position.ensureVisible(context.findRenderObject()!, alignment: 0.5, duration: const Duration(milliseconds: 250));
        });
        return TweenAnimationBuilder<double>(
          key: ValueKey(spot),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 2600),
          child: child,
          builder: (context, t, child) => DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: fade(color, 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 5 * 2 * pi - pi / 2))), width: 2.5),
              color: fade(color, 0.06),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

Widget _sectionTitle(String t, Color accent, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Row(children: [
        Container(width: 4, height: 13, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(child: Text(t.toUpperCase(), style: const TextStyle(color: C.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2))),
        if (trailing != null) trailing,
      ]),
    );

/// Panneau d'explication : onglets Execution / Demo / Enonce.
class ExplainPanel extends StatelessWidget {
  final LabHost host;
  final LabContent content;
  final Color accent;
  final List<String> pseudo;
  final String pseudoTitle;

  /// Compteurs en direct (libelle -> valeur).
  final Map<String, String> Function()? counters;

  /// Zone propre au TP, sous les variables (table de PD, tableau de l'estimation, tas...).
  final Widget Function(BuildContext context, Step? step)? extra;
  final void Function(int index) onScenario;
  final void Function(String req) onRequirement;
  final String idleText;
  final VoidCallback? onCollapse;

  const ExplainPanel({
    super.key,
    required this.host,
    required this.content,
    required this.accent,
    required this.pseudo,
    required this.pseudoTitle,
    required this.onScenario,
    required this.onRequirement,
    this.counters,
    this.extra,
    this.idleText = 'Lancez la démonstration : chaque étape sera expliquée ici.',
    this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: Listenable.merge([host.tab, host.player, host.checks]),
        builder: (context, _) {
          final tab = host.tab.value;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Row(children: [
                Expanded(
                  child: SegBar(
                    options: ['Exécution', 'Démo  ${host.checks.value.length}/${content.checklist.length}', 'Énoncé'],
                    index: tab,
                    color: accent,
                    onChanged: (i) => host.tab.value = i,
                  ),
                ),
                if (onCollapse != null) ...[
                  const SizedBox(width: 6),
                  IconBtn(icon: Icons.chevron_right_rounded, tip: 'Replier le panneau', onTap: onCollapse, size: 32),
                ],
              ]),
            ),
            const Divider(height: 1, color: C.line),
            Expanded(
              child: IndexedStack(index: tab, children: [
                _execution(context),
                _DemoTab(host: host, content: content, accent: accent, onScenario: onScenario),
                _StatementTab(host: host, content: content, accent: accent, onRequirement: onRequirement),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  Widget _execution(BuildContext context) {
    final step = host.player.current;
    final prev = host.player.previous;
    final cnt = counters?.call() ?? const <String, String>{};
    final x = extra?.call(context, step);
    return ListView(padding: const EdgeInsets.all(14), children: [
      _sectionTitle('Pseudo-code · $pseudoTitle', accent),
      PseudoView(lines: pseudo, current: step?.line ?? 0, accent: accent),
      const SizedBox(height: 14),
      _sectionTitle('En ce moment', accent, trailing: step == null ? null : _kindBadge(step.kind)),
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: step == null ? C.card2 : fade(_kindColor(step.kind), 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: step == null ? C.line : _kindColor(step.kind), width: 3)),
        ),
        child: Text(step?.say ?? idleText,
            style: TextStyle(color: step == null ? C.muted : C.text, fontSize: step == null ? 13 : 15, height: 1.45, fontWeight: FontWeight.w500)),
      ),
      if (step != null && step.vars.isNotEmpty) ...[
        const SizedBox(height: 14),
        _sectionTitle('État', accent),
        _VarsView(vars: step.vars, prev: prev?.vars, accent: accent),
      ],
      if (x != null) ...[const SizedBox(height: 14), x],
      if (cnt.isNotEmpty) ...[
        const SizedBox(height: 14),
        _sectionTitle('Compteurs', accent),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in cnt.entries)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(e.value, style: kMono.copyWith(color: C.text, fontSize: 15, fontWeight: FontWeight.w700)),
                Text(e.key, style: const TextStyle(color: C.muted, fontSize: 10.5)),
              ]),
            ),
        ]),
      ],
    ]);
  }

  Color _kindColor(StepKind k) => switch (k) {
        StepKind.found || StepKind.done => C.green,
        StepKind.pruned => C.red,
        _ => accent,
      };

  Widget _kindBadge(StepKind k) {
    final label = switch (k) {
      StepKind.normal => null,
      StepKind.important => 'ÉTAPE CLÉ',
      StepKind.found => 'TROUVÉ',
      StepKind.pruned => 'COUPE',
      StepKind.done => 'RÉSULTAT',
    };
    if (label == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: fade(_kindColor(k), 0.16), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: _kindColor(k), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
    );
  }
}

/// Section titree reutilisable par les zones propres a chaque TP.
class PanelSection extends StatelessWidget {
  final String title;
  final Color accent;
  final Widget child;
  const PanelSection({super.key, required this.title, required this.accent, required this.child});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [_sectionTitle(title, accent), child]);
}

/// Pseudo-code numerote ; la ligne courante est surlignee et amenee dans la vue.
class PseudoView extends StatefulWidget {
  final List<String> lines;

  /// Numero de la ligne courante, a partir de 1 (0 : aucune).
  final int current;
  final Color accent;
  final int maxVisible;
  const PseudoView({super.key, required this.lines, required this.current, required this.accent, this.maxVisible = 13});

  @override
  State<PseudoView> createState() => _PseudoViewState();
}

class _PseudoViewState extends State<PseudoView> {
  final ScrollController _v = ScrollController();
  double _lh = 21;

  @override
  void didUpdateWidget(covariant PseudoView old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current && widget.current > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_v.hasClients) return;
        final view = _v.position.viewportDimension;
        final target = ((widget.current - 1) * _lh - view / 2 + _lh / 2).clamp(0.0, _v.position.maxScrollExtent);
        if ((target - _v.offset).abs() > _lh * 1.5) {
          _v.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  void dispose() {
    _v.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    _lh = 21 * scale;
    final n = widget.lines.length;
    final h = min(n, widget.maxVisible) * _lh + 12;
    return Container(
      height: h,
      decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, box) {
        return SingleChildScrollView(
          controller: _v,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: box.maxWidth),
              child: IntrinsicWidth(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (var i = 0; i < n; i++) _line(i),
                ]),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _line(int i) {
    final on = i + 1 == widget.current;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: _lh,
      padding: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: on ? fade(widget.accent, 0.16) : Colors.transparent,
        border: Border(left: BorderSide(color: on ? widget.accent : Colors.transparent, width: 3)),
      ),
      child: Row(children: [
        SizedBox(
          width: 30,
          child: Text('${i + 1}', textAlign: TextAlign.right, style: kMono.copyWith(color: on ? widget.accent : fade(C.muted, 0.6), fontSize: 11)),
        ),
        const SizedBox(width: 10),
        Text(widget.lines[i],
            softWrap: false,
            style: kMono.copyWith(color: on ? C.text : fade(C.text, 0.72), fontSize: 12, fontWeight: on ? FontWeight.w700 : FontWeight.w400)),
      ]),
    );
  }
}

/// Variables de l'etape : pastilles pour les scalaires, mini-tableaux pour les listes.
/// Les valeurs qui ont change depuis l'etape precedente sont surlignees.
class _VarsView extends StatelessWidget {
  final Map<String, Object?> vars;
  final Map<String, Object?>? prev;
  final Color accent;
  const _VarsView({required this.vars, required this.prev, required this.accent});

  @override
  Widget build(BuildContext context) {
    final scalars = vars.entries.where((e) => e.value is! List).toList();
    final lists = vars.entries.where((e) => e.value is List).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (scalars.isNotEmpty)
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in scalars) _chip(e.key, '${e.value}', prev != null && '${prev![e.key]}' != '${e.value}'),
        ]),
      for (final e in lists) Padding(padding: const EdgeInsets.only(top: 8), child: _list(e.key, e.value as List, prev?[e.key])),
    ]);
  }

  Widget _chip(String k, String v, bool changed) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: changed ? fade(accent, 0.16) : C.card2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: changed ? fade(accent, 0.8) : C.line),
        ),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$k  ', style: const TextStyle(color: C.muted, fontSize: 11.5)),
          TextSpan(text: v, style: kMono.copyWith(color: changed ? accent : C.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ])),
      );

  Widget _list(String k, List list, Object? before) {
    final old = before is List ? before : null;
    final indexed = k.endsWith('[]');
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      SizedBox(width: 68, child: Text(k, style: const TextStyle(color: C.muted, fontSize: 11.5))),
      Expanded(
        child: list.isEmpty
            ? Text('vide', style: kMono.copyWith(color: C.muted, fontSize: 12))
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (var i = 0; i < list.length; i++)
                    () {
                      final changed = old != null && (indexed ? (i >= old.length || '${old[i]}' != '${list[i]}') : !old.any((o) => '$o' == '${list[i]}'));
                      return Container(
                        margin: const EdgeInsets.only(right: 3),
                        constraints: const BoxConstraints(minWidth: 24),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: changed ? fade(accent, 0.18) : C.card2,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: changed ? fade(accent, 0.8) : Colors.transparent),
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          if (indexed) Text('$i', style: kMono.copyWith(color: fade(C.muted, 0.7), fontSize: 9)),
                          Text('${list[i]}', style: kMono.copyWith(color: changed ? accent : C.text, fontSize: 12, fontWeight: FontWeight.w700)),
                        ]),
                      );
                    }(),
                ]),
              ),
      ),
    ]);
  }
}

// ------------------------------------------------------------------ onglet Demo

class _DemoTab extends StatelessWidget {
  final LabHost host;
  final LabContent content;
  final Color accent;
  final void Function(int) onScenario;
  const _DemoTab({required this.host, required this.content, required this.accent, required this.onScenario});

  @override
  Widget build(BuildContext context) {
    final done = host.checks.value;
    return ListView(padding: const EdgeInsets.all(14), children: [
      _sectionTitle('Exigences de l\'énoncé montrées', accent,
          trailing: Text('${done.length} / ${content.checklist.length}', style: kMono.copyWith(color: accent, fontSize: 12, fontWeight: FontWeight.w700))),
      for (final c in content.checklist)
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(done.contains(c.id) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  key: ValueKey(done.contains(c.id)), size: 17, color: done.contains(c.id) ? C.green : C.muted),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(c.label, style: TextStyle(color: done.contains(c.id) ? C.text : C.muted, fontSize: 12.5, height: 1.3))),
          ]),
        ),
      const SizedBox(height: 14),
      _sectionTitle('Ce qu\'il faut dire', accent),
      for (var i = 0; i < content.script.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 20, child: Text('${i + 1}.', style: kMono.copyWith(color: accent, fontSize: 12, fontWeight: FontWeight.w700))),
            Expanded(child: Text(content.script[i], style: const TextStyle(color: C.text, fontSize: 13, height: 1.4))),
          ]),
        ),
      const SizedBox(height: 14),
      _sectionTitle('Scénario conseillé', accent),
      for (var i = 0; i < content.scenarios.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: fade(accent, 0.18), shape: BoxShape.circle),
              child: Text('${i + 1}', style: kMono.copyWith(color: accent, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(content.scenarios[i].title, style: const TextStyle(color: C.text, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(content.scenarios[i].detail, style: const TextStyle(color: C.muted, fontSize: 12, height: 1.35)),
              ]),
            ),
            const SizedBox(width: 8),
            ChipBtn(label: 'Charger', icon: Icons.download_done_rounded, color: accent, active: true, onTap: () => onScenario(i)),
          ]),
        ),
      const SizedBox(height: 8),
      _sectionTitle('Complexité', accent),
      InfoBox(content.complexity, color: accent),
      const SizedBox(height: 10),
      _sectionTitle('Questions probables du professeur', accent),
      for (final qa in content.qa) _QaCard(qa: qa, accent: accent),
      const SizedBox(height: 10),
      _sectionTitle('Pièges', C.red),
      InfoBox(content.pitfalls, color: C.red),
    ]);
  }
}

class _QaCard extends StatefulWidget {
  final QA qa;
  final Color accent;
  const _QaCard({required this.qa, required this.accent});

  @override
  State<_QaCard> createState() => _QaCardState();
}

class _QaCardState extends State<_QaCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _open = !_open),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
          decoration: BoxDecoration(
            color: C.card2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _open ? fade(widget.accent, 0.5) : Colors.transparent),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(widget.qa.q, style: const TextStyle(color: C.text, fontSize: 12.8, fontWeight: FontWeight.w700, height: 1.3))),
              AnimatedRotation(
                  turns: _open ? 0.5 : 0, duration: const Duration(milliseconds: 180), child: const Icon(Icons.expand_more_rounded, size: 18, color: C.muted)),
            ]),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.topLeft,
              child: _open
                  ? Padding(
                      padding: const EdgeInsets.only(top: 7, right: 6),
                      child: Text(widget.qa.a, style: TextStyle(color: fade(C.text, 0.88), fontSize: 12.8, height: 1.45)),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ]),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ onglet Enonce

class _StatementTab extends StatefulWidget {
  final LabHost host;
  final LabContent content;
  final Color accent;
  final void Function(String) onRequirement;
  const _StatementTab({required this.host, required this.content, required this.accent, required this.onRequirement});

  @override
  State<_StatementTab> createState() => _StatementTabState();
}

class _StatementTabState extends State<_StatementTab> {
  final Map<String, TapGestureRecognizer> _taps = {};
  bool _fr = false;

  TapGestureRecognizer _tap(String req) => _taps.putIfAbsent(req, () => TapGestureRecognizer()..onTap = () => widget.onRequirement(req));

  @override
  void dispose() {
    for (final t in _taps.values) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.content;
    final done = widget.host.checks.value;
    return ListView(padding: const EdgeInsets.all(14), children: [
      _sectionTitle('Énoncé officiel · ${c.source}', widget.accent),
      Text('Les phrases soulignées sont les exigences : cliquez pour voir où l\'application y répond.',
          style: const TextStyle(color: C.muted, fontSize: 11.5, height: 1.35)),
      const SizedBox(height: 10),
      for (var p = 0; p < c.statement.length; p++)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Text.rich(TextSpan(children: [
            for (final s in c.statement[p])
              s.req == null
                  ? TextSpan(text: s.text)
                  : TextSpan(
                      text: s.text,
                      recognizer: _tap(s.req!),
                      mouseCursor: SystemMouseCursors.click,
                      style: TextStyle(
                        color: done.contains(s.req) ? C.green : widget.accent,
                        decoration: TextDecoration.underline,
                        decorationColor: fade(done.contains(s.req) ? C.green : widget.accent, 0.6),
                        decorationStyle: TextDecorationStyle.dotted,
                      ),
                    ),
          ]), style: TextStyle(color: C.text, fontSize: 13, height: 1.5, fontWeight: p == 0 ? FontWeight.w700 : FontWeight.w400)),
        ),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerLeft,
        child: ChipBtn(
            label: _fr ? 'Masquer la traduction' : 'Traduction française',
            icon: Icons.translate_rounded,
            color: widget.accent,
            active: _fr,
            onTap: () => setState(() => _fr = !_fr)),
      ),
      if (_fr) ...[
        const SizedBox(height: 10),
        for (final p in c.statementFr)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(p, style: TextStyle(color: fade(C.text, 0.82), fontSize: 12.8, height: 1.5, fontStyle: FontStyle.italic)),
          ),
      ],
    ]);
  }
}
