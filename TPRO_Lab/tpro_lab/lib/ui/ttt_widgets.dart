import 'dart:math';

import 'package:flutter/material.dart' hide Step;

import '../core/ttt_board.dart';
import '../core/ttt_engine.dart';
import 'kit.dart';

/// Couleurs des deux joueurs (X = accent du TP, O = bleu clair).
const Color kXColor = C.violet;
const Color kOColor = Color(0xFF7DD3FC);

/// Carre occupe par la grille dans une scene de taille [size].
Rect boardRectFor(Size size) {
  const pad = 30.0;
  final side = max(40.0, min(size.width, size.height) - 2 * pad);
  return Rect.fromLTWH((size.width - side) / 2, (size.height - side) / 2 + 4, side, side);
}

/// Case sous le point [p] (-1 si hors grille).
int boardCellAt(Size size, int n, Offset p) {
  final r = boardRectFor(size);
  if (!r.contains(p)) return -1;
  final c = ((p.dx - r.left) / (r.width / n)).floor().clamp(0, n - 1);
  final l = ((p.dy - r.top) / (r.height / n)).floor().clamp(0, n - 1);
  return l * n + c;
}

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round;

/// Grille N x N : symboles animes, dernier coup, alignement gagnant, carte de chaleur,
/// coups hypothetiques de l'etape de trace courante.
class BoardPainter extends CustomPainter {
  final int n;
  final List<int> cells;
  final int lastMove;
  final List<int> winCells;

  /// Interet de chaque case vide (carte de chaleur), ou null.
  final List<int>? heat;

  /// Coups hypothetiques (chemin de la recherche) ; le premier est joue par [ghostFirst].
  final List<int> ghost;
  final int ghostFirst;

  /// Meilleur coup connu de la recherche tracee (-1 : aucun).
  final int bestMove;

  /// Avancement du trace de chaque symbole recent (case -> 0..1).
  final Map<int, double> progress;
  final double phase;
  final int labelBase;

  BoardPainter({
    required this.n,
    required this.cells,
    required this.lastMove,
    required this.winCells,
    required this.heat,
    required this.ghost,
    required this.ghostFirst,
    required this.bestMove,
    required this.progress,
    required this.phase,
    this.labelBase = 0,
  });

  void _mark(Canvas canvas, Offset c, double cell, int p, double f, double alpha) {
    final r = cell * 0.27;
    final w = max(2.0, cell * 0.085);
    if (p == kX) {
      final paint = _stroke(fade(kXColor, alpha), w);
      final f1 = min(1.0, f * 2), f2 = ((f - 0.5) * 2).clamp(0.0, 1.0);
      canvas.drawLine(c + Offset(-r, -r), c + Offset(-r + 2 * r * f1, -r + 2 * r * f1), paint);
      if (f2 > 0) canvas.drawLine(c + Offset(r, -r), c + Offset(r - 2 * r * f2, -r + 2 * r * f2), paint);
    } else {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2, 2 * pi * f, false, _stroke(fade(kOColor, alpha), w));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = boardRectFor(size);
    final cell = r.width / n;
    Offset center(int i) => Offset(r.left + (i % n + 0.5) * cell, r.top + (i ~/ n + 0.5) * cell);
    Rect rectOf(int i) => Rect.fromLTWH(r.left + (i % n) * cell, r.top + (i ~/ n) * cell, cell, cell);
    final pulse = 0.5 + 0.5 * sin(phase * 2 * pi);

    canvas.drawRRect(RRect.fromRectAndRadius(r.inflate(6), const Radius.circular(12)), Paint()..color = C.bg);
    // Carte de chaleur
    final h = heat;
    if (h != null && h.length == n * n) {
      var mx = 1;
      for (final v in h) {
        if (v > mx) mx = v;
      }
      for (var i = 0; i < n * n; i++) {
        if (h[i] < 0) continue;
        final t = log(1 + h[i]) / log(1 + mx);
        canvas.drawRect(rectOf(i).deflate(1), Paint()..color = fade(C.amber, 0.04 + 0.5 * t * t));
      }
    }
    if (lastMove >= 0 && lastMove < n * n) {
      canvas.drawRect(rectOf(lastMove).deflate(1), Paint()..color = fade(C.violet, 0.16));
      canvas.drawRect(rectOf(lastMove).deflate(1.5), _stroke(fade(C.violet, 0.75), 1.5));
    }
    if (bestMove >= 0 && bestMove < n * n) {
      canvas.drawRect(rectOf(bestMove).deflate(2.5), _stroke(fade(C.green, 0.5 + 0.4 * pulse), 2));
    }
    // Quadrillage
    final grid = _stroke(C.line, max(1.0, cell * 0.03));
    for (var i = 0; i <= n; i++) {
      canvas.drawLine(Offset(r.left + i * cell, r.top), Offset(r.left + i * cell, r.bottom), grid);
      canvas.drawLine(Offset(r.left, r.top + i * cell), Offset(r.right, r.top + i * cell), grid);
    }
    // Indices des lignes et des colonnes
    final fs = (cell * 0.26).clamp(8.0, 11.0);
    for (var i = 0; i < n; i++) {
      drawText(canvas, '${i + labelBase}', Offset(r.left + (i + 0.5) * cell, r.top - 9), kMono.copyWith(color: C.muted, fontSize: fs),
          anchor: Alignment.bottomCenter);
      drawText(canvas, '${i + labelBase}', Offset(r.left - 10, r.top + (i + 0.5) * cell), kMono.copyWith(color: C.muted, fontSize: fs),
          anchor: Alignment.centerRight);
    }
    // Symboles
    for (var i = 0; i < n * n; i++) {
      if (cells[i] == kEmpty) continue;
      _mark(canvas, center(i), cell, cells[i], progress[i] ?? 1.0, 1.0);
    }
    // Coups hypothetiques de la recherche
    var p = ghostFirst;
    for (var k = 0; k < ghost.length; k++) {
      final g = ghost[k];
      if (g >= 0 && g < n * n && cells[g] == kEmpty) {
        canvas.drawRect(rectOf(g).deflate(2), Paint()..color = fade(p == kX ? kXColor : kOColor, 0.10));
        _mark(canvas, center(g), cell, p, 1.0, 0.55);
        drawPill(canvas, '${k + 1}', rectOf(g).topLeft + Offset(cell * 0.2, cell * 0.2), color: p == kX ? kXColor : kOColor, size: (cell * 0.2).clamp(8.0, 11.0));
      }
      p = 3 - p;
    }
    // Alignement gagnant
    if (winCells.length >= 2) {
      final a = center(winCells.first), b = center(winCells.last);
      final d = (b - a) / (b - a).distance * cell * 0.38;
      canvas.drawLine(a - d, b + d, _stroke(fade(C.green, 0.22 + 0.2 * pulse), cell * (0.3 + 0.1 * pulse)));
      canvas.drawLine(a - d, b + d, _stroke(C.green, max(3.0, cell * 0.11)));
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) => true;
}

/// Barre d'evaluation (comme aux echecs) : part de X en bas, part de O en haut.
class EvalBar extends StatelessWidget {
  /// Part de X, entre 0 et 1.
  final double share;
  final String label;
  const EvalBar({super.key, required this.share, required this.label});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Estimation de la position du point de vue de X : $label',
      child: Column(children: [
        const Text('O', style: TextStyle(color: kOColor, fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            width: 16,
            decoration: BoxDecoration(color: fade(kOColor, 0.55), borderRadius: BorderRadius.circular(8), border: Border.all(color: C.line)),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.bottomCenter,
            child: AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              heightFactor: share.clamp(0.0, 1.0),
              widthFactor: 1,
              child: const ColoredBox(color: kXColor),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text('X', style: TextStyle(color: kXColor, fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        SizedBox(
          width: 44,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: kMono.copyWith(color: C.text, fontSize: 10.5, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

/// Anneau du compte a rebours TMO ; rouge dans le dernier quart.
class CountdownRing extends StatelessWidget {
  /// Part du delai restante (0..1).
  final double remaining;
  final String label, caption;
  const CountdownRing({super.key, required this.remaining, required this.label, required this.caption});

  @override
  Widget build(BuildContext context) {
    final color = remaining < 0.25 ? C.red : C.violet;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 58,
        height: 58,
        child: CustomPaint(
          painter: _RingPainter(remaining, color),
          child: Center(child: Text(label, textScaler: TextScaler.noScaling, style: kMono.copyWith(color: color, fontSize: 12.5, fontWeight: FontWeight.w800))),
        ),
      ),
      const SizedBox(height: 3),
      Text(caption, style: const TextStyle(color: C.muted, fontSize: 10.5)),
    ]);
  }
}

class _RingPainter extends CustomPainter {
  final double remaining;
  final Color color;
  _RingPainter(this.remaining, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    canvas.drawCircle(c, r, Paint()..color = fade(C.bg, 0.85));
    canvas.drawCircle(c, r, _stroke(C.line, 5));
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2, 2 * pi * remaining.clamp(0.0, 1.0), false, _stroke(color, 5));
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.remaining != remaining || old.color != color;
}

/// Bornes (du point de vue de X) d'un noeud au rang d'etape [seq].
List<int>? boundsAt(TreeNode node, int seq) {
  List<int>? last;
  for (final e in node.ab) {
    if (e[0] <= seq) last = e;
  }
  return last;
}

/// Arbre de recherche de l'iteration courante : valeurs MinMax, alpha/beta, branches coupees.
class SearchTreeView extends StatelessWidget {
  final SearchTree tree;

  /// Rang de l'etape courante et noeud courant.
  final int seq, current;
  final int boardN;
  final VoidCallback? onClose;
  const SearchTreeView({super.key, required this.tree, required this.seq, required this.current, required this.boardN, this.onClose});

  @override
  Widget build(BuildContext context) {
    Widget legend(Widget icon, String t) => Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [icon, const SizedBox(width: 4), Text(t, style: const TextStyle(color: C.muted, fontSize: 10.5))]),
        );
    return Container(
      decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 6, 4),
          child: Row(children: [
            Expanded(
              child: Text('ARBRE DE RECHERCHE · PROFONDEUR ${tree.depth}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
            ),
            if (onClose != null) IconBtn(icon: Icons.close_rounded, tip: 'Masquer l\'arbre', onTap: onClose, size: 24),
          ]),
        ),
        Expanded(
          child: InteractiveViewer(
            maxScale: 6,
            minScale: 1,
            child: CustomPaint(size: Size.infinite, painter: _TreePainter(tree, seq, current, boardN)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
          child: Wrap(children: [
            legend(Container(width: 10, height: 10, decoration: BoxDecoration(border: Border.all(color: kXColor, width: 1.6), borderRadius: BorderRadius.circular(2))),
                'MAX (X joue)'),
            legend(Container(width: 10, height: 10, decoration: BoxDecoration(border: Border.all(color: kOColor, width: 1.6), shape: BoxShape.circle)), 'MIN (O joue)'),
            legend(const Icon(Icons.close_rounded, size: 12, color: C.red), 'branche coupée'),
            legend(const Icon(Icons.zoom_in_rounded, size: 12, color: C.muted), 'molette : zoom'),
          ]),
        ),
      ]),
    );
  }
}

class _TreePainter extends CustomPainter {
  final SearchTree tree;
  final int seq, current, boardN;
  _TreePainter(this.tree, this.seq, this.current, this.boardN);

  @override
  void paint(Canvas canvas, Size size) {
    final nodes = tree.nodes;
    if (nodes.isEmpty) return;
    // Disposition : chaque feuille occupe une colonne, un noeud interne est centre sur ses fils.
    final x = List<double>.filled(nodes.length, 0);
    var leaves = 0, maxPly = 0;
    double place(int id) {
      final nd = nodes[id];
      if (nd.ply > maxPly) maxPly = nd.ply;
      if (nd.children.isEmpty) return x[id] = (leaves++) + 0.5;
      var s = 0.0;
      for (final c in nd.children) {
        s += place(c);
      }
      return x[id] = s / nd.children.length;
    }

    place(0);
    const slot = 46.0, levelH = 84.0, top = 34.0, radius = 15.0;
    final natW = max(leaves, 1) * slot, natH = maxPly * levelH + top + 44;
    final scale = min(1.25, min(size.width / natW, size.height / natH));
    canvas.save();
    canvas.translate((size.width - natW * scale) / 2, max(0.0, (size.height - natH * scale) / 2));
    canvas.scale(scale);
    Offset pos(int id) => Offset(x[id] * slot, top + nodes[id].ply * levelH);

    final onPath = <int>{};
    for (var id = current; id >= 0; id = nodes[id].parent) {
      onPath.add(id);
    }
    // Aretes
    for (final nd in nodes) {
      if (nd.parent < 0 || nd.born > seq) continue;
      final a = pos(nd.parent) + const Offset(0, radius), b = pos(nd.id) - const Offset(0, radius);
      if (nd.pruned.isNotEmpty) {
        drawDashed(canvas, a, b, _stroke(fade(C.red, 0.55), 1.3), dash: 4, gap: 4);
      } else {
        final hot = onPath.contains(nd.id);
        canvas.drawLine(a, b, _stroke(hot ? C.text : fade(C.muted, 0.55), hot ? 2.2 : 1.3));
      }
    }
    // Noeuds
    for (final nd in nodes) {
      if (nd.born > seq) continue;
      final c = pos(nd.id);
      final col = nd.player == kX ? kXColor : kOColor;
      final label = nd.move < 0 ? 'racine' : '${nd.move ~/ boardN},${nd.move % boardN}';
      if (nd.pruned.isNotEmpty) {
        canvas.drawCircle(c, radius * 0.7, _stroke(fade(C.red, 0.5), 1.2));
        canvas.drawLine(c + const Offset(-7, -7), c + const Offset(7, 7), _stroke(C.red, 2));
        canvas.drawLine(c + const Offset(7, -7), c + const Offset(-7, 7), _stroke(C.red, 2));
        drawText(canvas, label, c - const Offset(0, radius + 2), kMono.copyWith(color: fade(C.muted, 0.7), fontSize: 8.5), anchor: Alignment.bottomCenter);
        drawText(canvas, nd.pruned, c + const Offset(0, radius), kMono.copyWith(color: C.red, fontSize: 8.5, fontWeight: FontWeight.w700),
            anchor: Alignment.topCenter);
        continue;
      }
      final isCur = nd.id == current;
      final known = nd.valueAt >= 0 && nd.valueAt <= seq;
      if (isCur) canvas.drawCircle(c, radius * 1.75, Paint()..color = fade(col, 0.22));
      final fill = Paint()..color = known ? Color.lerp(C.card2, col, 0.25)! : C.card2;
      final border = _stroke(isCur ? C.text : (onPath.contains(nd.id) ? col : fade(col, 0.7)), isCur ? 2.6 : 1.8);
      if (nd.player == kX) {
        final rr = RRect.fromRectAndRadius(Rect.fromCircle(center: c, radius: radius), const Radius.circular(4));
        canvas.drawRRect(rr, fill);
        canvas.drawRRect(rr, border);
      } else {
        canvas.drawCircle(c, radius, fill);
        canvas.drawCircle(c, radius, border);
      }
      var txt = known ? fmtScore(nd.value) : '…';
      if (txt.startsWith('gain')) txt = txt.endsWith('X') ? '+G' : '−G';
      drawText(canvas, txt, c, kMono.copyWith(color: C.text, fontSize: txt.length > 4 ? 8.5 : 10.5, fontWeight: FontWeight.w800), anchor: Alignment.center);
      drawText(canvas, label, c - const Offset(0, radius + 2), kMono.copyWith(color: isCur ? C.text : C.muted, fontSize: 8.5), anchor: Alignment.bottomCenter);
      final ab = boundsAt(nd, seq);
      if (onPath.contains(nd.id) && ab != null && nd.tag.isEmpty) {
        drawPill(canvas, 'α ${fmtScore(ab[1])}  β ${fmtScore(ab[2])}', c + const Offset(0, radius + 10), color: C.amber, size: 8.5);
      } else if (nd.tag.isNotEmpty && known) {
        final t = switch (nd.tag) { 'feuille' => 'estim.', 'terminal' => 'fin', _ => nd.tag };
        drawText(canvas, t, c + const Offset(0, radius + 2), kMono.copyWith(color: fade(C.muted, 0.85), fontSize: 8), anchor: Alignment.topCenter);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TreePainter old) => old.seq != seq || old.current != current || old.tree != tree;
}

/// Petit tableau compact (en-tete + lignes), sans hauteur imposee.
class MiniTable extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;
  final Color accent;

  /// Indice d'une ligne a mettre en evidence (-1 : aucune).
  final int highlight;
  const MiniTable({super.key, required this.headers, required this.rows, this.accent = C.violet, this.highlight = -1});

  @override
  Widget build(BuildContext context) {
    TableRow row(List<String> cells, {bool head = false, bool hot = false, bool band = false}) => TableRow(
          decoration: BoxDecoration(color: head ? C.card2 : (hot ? fade(accent, 0.14) : (band ? fade(C.card2, 0.45) : Colors.transparent))),
          children: [
            for (var i = 0; i < cells.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(cells[i],
                    textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: head
                        ? const TextStyle(color: C.muted, fontSize: 10.5, fontWeight: FontWeight.w700)
                        : kMono.copyWith(color: C.text, fontSize: 11.5)),
              ),
          ],
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Table(defaultVerticalAlignment: TableCellVerticalAlignment.middle, children: [
        row(headers, head: true),
        for (var i = 0; i < rows.length; i++) row(rows[i], hot: i == highlight, band: i.isOdd),
      ]),
    );
  }
}
