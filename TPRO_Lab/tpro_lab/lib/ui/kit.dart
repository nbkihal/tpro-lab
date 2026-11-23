import 'package:flutter/material.dart';

/// Palette et composants partages par les quatre modules.
class C {
  static const bg = Color(0xFF0F1117);
  static const sidebar = Color(0xFF0A0C11);
  static const card = Color(0xFF181B25);
  static const card2 = Color(0xFF222636);
  static const line = Color(0xFF2B3042);
  static const text = Color(0xFFE8EAF0);
  static const muted = Color(0xFF8B93A7);
  static const cyan = Color(0xFF22D3EE);
  static const amber = Color(0xFFFBBF24);
  static const violet = Color(0xFFA78BFA);
  static const green = Color(0xFF34D399);
  static const red = Color(0xFFF87171);
}

Color fade(Color c, double opacity) => c.withAlpha((opacity * 255).round().clamp(0, 255));

const TextStyle kMono = TextStyle(
  fontFamily: 'Consolas',
  fontFamilyFallback: ['Menlo', 'DejaVu Sans Mono', 'Courier New', 'monospace'],
);

class Panel extends StatelessWidget {
  final String? title;
  final Widget child;
  final Color? accent;
  final EdgeInsets padding;
  const Panel({super.key, this.title, required this.child, this.accent, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.line),
      ),
      child: title == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Container(width: 4, height: 14, decoration: BoxDecoration(color: accent ?? C.muted, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Text(title!.toUpperCase(),
                      style: const TextStyle(color: C.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                ]),
                const SizedBox(height: 12),
                child,
              ],
            ),
    );
  }
}

class Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const Stat({super.key, required this.label, required this.value, this.color = C.text});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: kMono.copyWith(color: color, fontSize: 22, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: C.muted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

class StatRow extends StatelessWidget {
  final List<Stat> stats;
  const StatRow(this.stats, {super.key});

  @override
  Widget build(BuildContext context) {
    final kids = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      if (i > 0) kids.add(const SizedBox(width: 8));
      kids.add(stats[i]);
    }
    return Row(children: kids);
  }
}

class NumStepper extends StatelessWidget {
  final String label;
  final int value, min, max, step;
  final ValueChanged<int> onChanged;
  final String Function(int)? format;
  final bool enabled;
  const NumStepper({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.format,
    this.enabled = true,
  });

  Widget _btn(IconData icon, bool ok, int delta) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: ok && enabled ? () => onChanged((value + delta).clamp(min, max)) : null,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: ok && enabled ? C.text : C.line),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: C.text, fontSize: 13))),
        _btn(Icons.remove, value > min, -step),
        SizedBox(
          width: 54,
          child: Text(format?.call(value) ?? '$value',
              textAlign: TextAlign.center, style: kMono.copyWith(color: C.text, fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        _btn(Icons.add, value < max, step),
      ]),
    );
  }
}

class Seg extends StatelessWidget {
  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;
  final Color color;
  final bool enabled;
  const Seg({super.key, required this.options, required this.index, required this.onChanged, this.color = C.cyan, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        for (var i = 0; i < options.length; i++)
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: enabled ? () => onChanged(i) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: i == index ? fade(color, 0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: i == index ? fade(color, 0.7) : Colors.transparent),
                ),
                child: Text(options[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: i == index ? color : C.muted, fontSize: 12, fontWeight: i == index ? FontWeight.w700 : FontWeight.w500)),
              ),
            ),
          ),
      ]),
    );
  }
}

class ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool filled;
  const ActionBtn({super.key, required this.label, required this.icon, this.color = C.cyan, this.onPressed, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final on = onPressed != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: filled ? (on ? color : C.card2) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: filled ? Colors.transparent : (on ? fade(color, 0.6) : C.line)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 17, color: filled ? (on ? C.bg : C.muted) : (on ? color : C.muted)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: filled ? (on ? C.bg : C.muted) : (on ? color : C.muted), fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Encadre explicatif (methode, complexite).
class InfoBox extends StatelessWidget {
  final List<String> lines;
  final Color color;
  const InfoBox(this.lines, {super.key, this.color = C.cyan});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final l in lines)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ),
            Expanded(child: Text(l, style: const TextStyle(color: C.text, fontSize: 12.5, height: 1.35))),
          ]),
        ),
    ]);
  }
}

class SimpleTable extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;
  final List<int> flex;
  final Color accent;
  const SimpleTable({super.key, required this.headers, required this.rows, required this.flex, this.accent = C.cyan});

  Widget _row(List<String> cells, {bool head = false, bool band = false}) => Container(
        color: head ? C.card2 : (band ? fade(C.card2, 0.45) : Colors.transparent),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: flex[i],
              child: Text(cells[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                  style: head
                      ? const TextStyle(color: C.muted, fontSize: 11, fontWeight: FontWeight.w700)
                      : kMono.copyWith(color: C.text, fontSize: 12)),
            ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(children: [
        _row(headers, head: true),
        Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('Aucune mesure pour le moment', style: TextStyle(color: C.muted, fontSize: 12)))
              : ListView.builder(itemCount: rows.length, itemBuilder: (_, i) => _row(rows[i], band: i.isOdd)),
        ),
      ]),
    );
  }
}

/// Mise en page commune : en-tete, scene a gauche, colonne de reglages a droite, zone basse optionnelle.
class PageScaffold extends StatelessWidget {
  final String tag, title, subtitle;
  final Color accent;
  final Widget canvas;
  final List<Widget> side;
  final Widget? bottom;
  final double bottomHeight;
  const PageScaffold({
    super.key,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.canvas,
    required this.side,
    this.bottom,
    this.bottomHeight = 240,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: fade(accent, 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(tag, style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: C.text, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Column(children: [
                Expanded(child: canvas),
                if (bottom != null) ...[const SizedBox(height: 14), SizedBox(height: bottomHeight, child: bottom)],
              ]),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 340,
              child: SingleChildScrollView(
                child: Column(children: [
                  for (var i = 0; i < side.length; i++) ...[if (i > 0) const SizedBox(height: 12), side[i]],
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

void drawText(Canvas canvas, String text, Offset at, TextStyle style, {Alignment anchor = Alignment.topLeft, double maxWidth = 400}) {
  final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, maxLines: 2)
    ..layout(maxWidth: maxWidth);
  final dx = at.dx - tp.width * (anchor.x + 1) / 2;
  final dy = at.dy - tp.height * (anchor.y + 1) / 2;
  tp.paint(canvas, Offset(dx, dy));
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 4)));
}
