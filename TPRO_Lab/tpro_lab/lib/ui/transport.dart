import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart' hide Step;
import 'package:flutter/services.dart';

import '../core/trace.dart';
import 'kit.dart';

const List<double> kSpeeds = [0.25, 0.5, 1, 2, 4, 8, 16];

/// Lecteur de trace : position courante, lecture automatique, vitesse.
/// Reculer est immediat : chaque etape porte son propre instantane.
class TracePlayer extends ChangeNotifier {
  List<Step> steps = const [];
  int index = 0;
  bool playing = false;
  double speed = 1;

  /// Incremente a chaque arrivee sur une etape importante (declenche le flash de la scene).
  int flash = 0;

  /// Appele a chaque changement d'etape (sert a cocher la liste des exigences).
  void Function(Step step)? onStep;
  Timer? _timer;

  bool get hasTrace => steps.isNotEmpty;
  Step? get current => steps.isEmpty ? null : steps[index];
  Step? get previous => steps.isEmpty || index == 0 ? null : steps[index - 1];
  bool get atEnd => steps.isEmpty || index == steps.length - 1;

  void load(List<Step> s, {bool autoplay = false, bool atEnd = false}) {
    _stop();
    steps = s;
    index = atEnd && s.isNotEmpty ? s.length - 1 : 0;
    if (s.isNotEmpty) onStep?.call(s[index]);
    notifyListeners();
    if (autoplay && s.length > 1) play();
  }

  void clear() {
    if (steps.isEmpty) return;
    _stop();
    steps = const [];
    index = 0;
    notifyListeners();
  }

  void seek(int i, {bool keepPlaying = false}) {
    if (steps.isEmpty) return;
    final j = i.clamp(0, steps.length - 1);
    if (!keepPlaying) _stop();
    if (j == index) {
      notifyListeners();
      return;
    }
    index = j;
    final s = steps[j];
    if (s.isImportant) flash++;
    onStep?.call(s);
    notifyListeners();
  }

  void next() => seek(index + 1);
  void prev() => seek(index - 1);
  void first() => seek(0);
  void last() => seek(steps.length - 1);

  void nextImportant() {
    for (var i = index + 1; i < steps.length; i++) {
      if (steps[i].isImportant) return seek(i);
    }
    last();
  }

  void prevImportant() {
    for (var i = index - 1; i >= 0; i--) {
      if (steps[i].isImportant) return seek(i);
    }
    first();
  }

  void play() {
    if (steps.length < 2) return;
    if (atEnd) index = 0;
    playing = true;
    _arm();
    notifyListeners();
  }

  void pause() {
    _stop();
    notifyListeners();
  }

  void toggle() => playing ? pause() : play();

  void setSpeed(double s) {
    speed = s;
    if (playing) _arm();
    notifyListeners();
  }

  void faster() => setSpeed(kSpeeds[min(kSpeeds.indexOf(speed) + 1, kSpeeds.length - 1)]);
  void slower() => setSpeed(kSpeeds[max(kSpeeds.indexOf(speed) - 1, 0)]);

  void _arm() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: max(30, (640 / speed).round())), (_) {
      if (atEnd) {
        pause();
      } else {
        seek(index + 1, keepPlaying: true);
        if (atEnd) pause();
      }
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    playing = false;
  }

  /// Raccourcis clavier : Espace, fleches, Debut / Fin, + / -, N.
  bool handleKey(KeyEvent e) {
    if (e is KeyUpEvent || steps.isEmpty) return false;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.space) {
      if (e is KeyDownEvent) toggle();
    } else if (k == LogicalKeyboardKey.arrowRight) {
      next();
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      prev();
    } else if (k == LogicalKeyboardKey.home) {
      first();
    } else if (k == LogicalKeyboardKey.end) {
      last();
    } else if (k == LogicalKeyboardKey.keyN) {
      HardwareKeyboard.instance.isShiftPressed ? prevImportant() : nextImportant();
    } else if (k == LogicalKeyboardKey.add || k == LogicalKeyboardKey.numpadAdd || k == LogicalKeyboardKey.equal) {
      faster();
    } else if (k == LogicalKeyboardKey.minus || k == LogicalKeyboardKey.numpadSubtract) {
      slower();
    } else {
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

String speedLabel(double s) => s < 1 ? '${s.toString().replaceAll('.', ',')}×' : '${s.toInt()}×';

/// Barre de transport, identique pour les quatre TP.
class TransportBar extends StatelessWidget {
  final TracePlayer player;
  final Color accent;
  final String emptyHint;
  const TransportBar({super.key, required this.player, required this.accent, this.emptyHint = 'Lancez la démonstration pour obtenir une trace à rejouer'});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final has = player.hasTrace;
        final n = player.steps.length;
        return Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
          child: Row(children: [
            IconBtn(icon: Icons.skip_previous_rounded, tip: 'Début (Début)', onTap: has ? player.first : null),
            const SizedBox(width: 4),
            IconBtn(icon: Icons.chevron_left_rounded, tip: 'Étape précédente (←)', onTap: has ? player.prev : null),
            const SizedBox(width: 4),
            IconBtn(
                icon: player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                tip: player.playing ? 'Pause (Espace)' : 'Lecture (Espace)',
                onTap: has ? player.toggle : null,
                color: accent,
                active: has,
                size: 38),
            const SizedBox(width: 4),
            IconBtn(icon: Icons.chevron_right_rounded, tip: 'Étape suivante (→)', onTap: has ? player.next : null),
            const SizedBox(width: 4),
            IconBtn(icon: Icons.skip_next_rounded, tip: 'Fin (Fin)', onTap: has ? player.last : null),
            const SizedBox(width: 4),
            IconBtn(icon: Icons.star_rounded, tip: 'Étape importante suivante (N)', onTap: has ? player.nextImportant : null, color: accent),
            const SizedBox(width: 10),
            _speed(),
            const SizedBox(width: 12),
            Expanded(
              child: has
                  ? _Scrubber(player: player, accent: accent)
                  : Text(emptyHint, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 12.5)),
            ),
            if (has) ...[
              const SizedBox(width: 12),
              Text('étape ${player.index + 1} / $n', style: kMono.copyWith(color: C.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(width: 4),
          ]),
        );
      },
    );
  }

  Widget _speed() => PopupMenuButton<double>(
        tooltip: 'Vitesse (+ / −)',
        color: C.card2,
        onSelected: player.setSpeed,
        itemBuilder: (_) => [
          for (final s in kSpeeds)
            PopupMenuItem(
                value: s,
                height: 34,
                child: Text(speedLabel(s), style: kMono.copyWith(color: s == player.speed ? accent : C.text, fontSize: 13, fontWeight: FontWeight.w700))),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(9), border: Border.all(color: C.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.speed_rounded, size: 15, color: C.muted),
            const SizedBox(width: 6),
            Text(speedLabel(player.speed), style: kMono.copyWith(color: C.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

/// Curseur de position avec repere des etapes importantes.
class _Scrubber extends StatelessWidget {
  final TracePlayer player;
  final Color accent;
  const _Scrubber({required this.player, required this.accent});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      void at(double dx) {
        final n = player.steps.length;
        if (n < 2) return;
        player.seek(((dx - 8) / (box.maxWidth - 16) * (n - 1)).round());
      }

      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => at(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => at(d.localPosition.dx),
          child: CustomPaint(size: Size(box.maxWidth, 36), painter: _ScrubPainter(player.steps, player.index, accent)),
        ),
      );
    });
  }
}

class _ScrubPainter extends CustomPainter {
  final List<Step> steps;
  final int index;
  final Color accent;
  _ScrubPainter(this.steps, this.index, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final n = steps.length;
    final y = size.height / 2;
    const pad = 8.0;
    final w = size.width - 2 * pad;
    double x(int i) => pad + (n < 2 ? 0 : i / (n - 1)) * w;
    final track = Paint()
      ..color = C.line
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(pad, y), Offset(pad + w, y), track);
    canvas.drawLine(Offset(pad, y), Offset(x(index), y), track..color = fade(accent, 0.75));
    // Reperes des etapes importantes (echantillonnes si la trace est tres longue).
    final stride = max(1, n ~/ 4000);
    final mark = Paint()..strokeWidth = 1.5;
    var lastX = -10.0;
    for (var i = 0; i < n; i += stride) {
      final s = steps[i];
      if (!s.isImportant) continue;
      final px = x(i);
      if (px - lastX < 1.5 && s.kind != StepKind.found && s.kind != StepKind.done) continue;
      lastX = px;
      mark.color = switch (s.kind) {
        StepKind.found || StepKind.done => C.green,
        StepKind.pruned => C.red,
        _ => fade(accent, 0.8),
      };
      canvas.drawLine(Offset(px, y - 9), Offset(px, y - 4), mark);
    }
    canvas.drawCircle(Offset(x(index), y), 7, Paint()..color = accent);
    canvas.drawCircle(Offset(x(index), y), 3, Paint()..color = C.bg);
  }

  @override
  bool shouldRepaint(covariant _ScrubPainter old) => old.index != index || old.steps != steps || old.accent != accent;
}
