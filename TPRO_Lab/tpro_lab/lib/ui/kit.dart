import 'dart:io';

import 'package:flutter/material.dart';

/// Palette et composants partages par les quatre modules.
class C {
  static const bg = Color(0xFF0B0F17);
  static const sidebar = Color(0xFF070A10);
  static const card = Color(0xFF121826);
  static const card2 = Color(0xFF1A2233);
  static const line = Color(0xFF263047);
  static const text = Color(0xFFE6EAF2);
  static const muted = Color(0xFF8A94A8);
  static const cyan = Color(0xFF22D3EE);
  static const amber = Color(0xFFF59E0B);
  static const violet = Color(0xFFA78BFA);
  static const green = Color(0xFF34D399);
  static const red = Color(0xFFF87171);
}

/// Couleur d'accent de chaque TP (indice 0 : accueil).
const List<Color> kAccents = [C.text, C.cyan, C.amber, C.violet, C.green];

/// Mode presentation : plein ecran, polices agrandies, zone de reglages repliee.
final ValueNotifier<bool> presentation = ValueNotifier<bool>(false);

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

class SegBar extends StatelessWidget {
  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;
  final Color color;
  final bool enabled;
  const SegBar({super.key, required this.options, required this.index, required this.onChanged, this.color = C.cyan, this.enabled = true});

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

void drawText(Canvas canvas, String text, Offset at, TextStyle style, {Alignment anchor = Alignment.topLeft, double maxWidth = 400}) {
  final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, maxLines: 2)
    ..layout(maxWidth: maxWidth);
  final dx = at.dx - tp.width * (anchor.x + 1) / 2;
  final dy = at.dy - tp.height * (anchor.y + 1) / 2;
  tp.paint(canvas, Offset(dx, dy));
}

void toast(BuildContext context, String msg, {VoidCallback? onUndo, bool error = false}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(color: C.text)),
    backgroundColor: C.card2,
    behavior: SnackBarBehavior.floating,
    width: 560,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: error ? C.red : C.line)),
    duration: Duration(seconds: onUndo != null ? 6 : 4),
    action: onUndo == null ? null : SnackBarAction(label: 'Annuler', textColor: C.cyan, onPressed: onUndo),
  ));
}

/// Petit bouton carre avec icone et info-bulle.
class IconBtn extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback? onTap;
  final Color color;
  final bool active;
  final double size;
  const IconBtn({super.key, required this.icon, required this.tip, this.onTap, this.color = C.text, this.active = false, this.size = 34});

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return Tooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: active ? fade(color, 0.18) : C.card2,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: active ? fade(color, 0.7) : Colors.transparent),
          ),
          child: Icon(icon, size: size * 0.53, color: on ? (active ? color : C.text) : C.line),
        ),
      ),
    );
  }
}

/// Bouton compact (texte + icone optionnelle) pour les barres d'outils.
class ChipBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color color;
  final bool active;
  final String? tip;
  const ChipBtn({super.key, required this.label, this.icon, this.onTap, this.color = C.cyan, this.active = false, this.tip});

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    final w = InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? fade(color, 0.18) : C.card2,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: active ? fade(color, 0.7) : C.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 15, color: on ? (active ? color : C.text) : C.muted), const SizedBox(width: 6)],
          Text(label, style: TextStyle(color: on ? (active ? color : C.text) : C.muted, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
    return tip == null ? w : Tooltip(message: tip!, waitDuration: const Duration(milliseconds: 400), child: w);
  }
}

/// Interrupteur avec libelle.
class Toggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color color;
  const Toggle({super.key, required this.label, required this.value, this.onChanged, this.color = C.cyan});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 30,
            height: 17,
            padding: const EdgeInsets.all(2),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(color: value ? fade(color, 0.85) : C.line, borderRadius: BorderRadius.circular(9)),
            child: Container(width: 13, height: 13, decoration: const BoxDecoration(color: C.bg, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: TextStyle(color: onChanged == null ? C.muted : C.text, fontSize: 12.5))),
        ]),
      ),
    );
  }
}

/// Champ de saisie sombre.
class DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final bool mono;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  const DarkField(
      {super.key, required this.controller, this.hint, this.maxLines = 1, this.mono = false, this.onSubmitted, this.onChanged, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: c));
    return TextField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      cursorColor: C.cyan,
      style: (mono ? kMono : const TextStyle()).copyWith(color: C.text, fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(color: C.muted, fontSize: 12.5),
        filled: true,
        fillColor: C.card2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: border(C.line),
        enabledBorder: border(C.line),
        disabledBorder: border(C.line),
        focusedBorder: border(C.cyan),
      ),
    );
  }
}

/// Boite de dialogue sombre standard.
Future<T?> showDarkDialog<T>(BuildContext context,
    {required String title, required Widget child, List<Widget> Function(BuildContext)? actions, double width = 520}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: C.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.line)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: C.text, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Flexible(child: child),
            if (actions != null) ...[
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                for (final a in actions(ctx)) Padding(padding: const EdgeInsets.only(left: 8), child: a),
              ]),
            ],
          ]),
        ),
      ),
    ),
  );
}

/// Etat vide dessine : icone et phrase d'invitation.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const EmptyState({super.key, required this.icon, required this.text, this.color = C.muted});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 34, color: fade(color, 0.7)),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: C.muted, fontSize: 13, height: 1.4)),
        ),
      ]),
    );
  }
}

/// Texte sur une pastille sombre : toujours lisible sur la scene.
void drawPill(Canvas canvas, String text, Offset center, {Color color = C.text, double size = 11, Color? bg}) {
  final tp = TextPainter(
      text: TextSpan(text: text, style: kMono.copyWith(color: color, fontSize: size, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr)
    ..layout();
  final r = Rect.fromCenter(center: center, width: tp.width + size, height: tp.height + size * 0.35);
  canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(r.height / 2)), Paint()..color = bg ?? fade(C.bg, 0.86));
  tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
}

/// Trait pointille anime (le decalage [phase] fait defiler les tirets).
void drawDashed(Canvas canvas, Offset a, Offset b, Paint paint, {double dash = 8, double gap = 6, double phase = 0}) {
  final len = (b - a).distance;
  if (len < 1) return;
  final dir = (b - a) / len;
  var t = -((phase % 1) * (dash + gap));
  while (t < len) {
    final s = t < 0 ? 0.0 : t;
    final e = (t + dash) > len ? len : t + dash;
    if (e > s) canvas.drawLine(a + dir * s, a + dir * e, paint);
    t += dash + gap;
  }
}

/// Une ligne de fichier CSV (separateur ';', lisible par Excel en francais).
String csvLine(List<Object?> cells) => cells.map((c) => '"${'${c ?? ''}'.replaceAll('"', '""')}"').join(';');

/// Enregistre [content] dans le dossier Documents (ou le dossier courant) ; retourne le chemin.
String saveTextFile(String name, String content) {
  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '.';
  final docs = Directory('$home${Platform.pathSeparator}Documents');
  final dir = docs.existsSync() ? docs : Directory(home);
  final f = File('${dir.path}${Platform.pathSeparator}$name');
  f.writeAsStringSync('﻿$content');
  return f.path;
}
