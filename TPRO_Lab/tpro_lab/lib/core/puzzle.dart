/// TP4 (TD5 ex.5) - Taquin 4 x 4 (15-puzzle) : A* et WA*.
/// Un etat est code sur un entier 64 bits : 4 bits par case, la case i occupe les bits 4i..4i+3.
library;

import 'dart:collection';
import 'dart:isolate';
import 'dart:math';

import 'trace.dart';

const int kSide = 4, kCells = 16;

/// Configuration but : 1 2 3 ... 15 puis la case vide (0).
final int kGoal = fromTiles([for (var i = 0; i < kCells; i++) (i + 1) % kCells]);

int fromTiles(List<int> tiles) {
  var s = 0;
  for (var i = 0; i < kCells; i++) {
    s |= tiles[i] << (4 * i);
  }
  return s;
}

List<int> toTiles(int s) => [for (var i = 0; i < kCells; i++) (s >>> (4 * i)) & 15];

int tileAt(int s, int i) => (s >>> (4 * i)) & 15;

int blankOf(int s) {
  for (var i = 0; i < kCells; i++) {
    if ((s >>> (4 * i)) & 15 == 0) return i;
  }
  return -1;
}

/// Echange la case vide (en [blank]) avec la case [pos].
int swapBlank(int s, int blank, int pos) {
  final t = (s >>> (4 * pos)) & 15;
  return (s & ~(15 << (4 * pos))) | (t << (4 * blank));
}

/// Positions voisines de la case i (haut, bas, gauche, droite).
final List<List<int>> kNeighbors = [
  for (var i = 0; i < kCells; i++)
    [
      if (i >= kSide) i - kSide,
      if (i < kCells - kSide) i + kSide,
      if (i % kSide > 0) i - 1,
      if (i % kSide < kSide - 1) i + 1,
    ],
];

/// Melange par [moves] deplacements aleatoires depuis le but (toujours resoluble).
int scramble(int moves, Random rnd) {
  var s = kGoal, blank = kCells - 1, prev = -1;
  for (var k = 0; k < moves; k++) {
    final opts = kNeighbors[blank].where((p) => p != prev).toList();
    final p = opts[rnd.nextInt(opts.length)];
    s = swapBlank(s, blank, p);
    prev = blank;
    blank = p;
  }
  return s;
}

// ---------------------------------------------------------------- heuristiques

/// h1 : nombre de jetons mal places (la case vide ne compte pas).
int hMisplaced(int s) {
  var h = 0;
  for (var i = 0; i < kCells; i++) {
    final t = (s >>> (4 * i)) & 15;
    if (t != 0 && t != i + 1) h++;
  }
  return h;
}

/// h2 : somme des distances de Manhattan de chaque jeton a sa place finale.
int hManhattan(int s) {
  var h = 0;
  for (var i = 0; i < kCells; i++) {
    final t = (s >>> (4 * i)) & 15;
    if (t == 0) continue;
    final g = t - 1;
    h += (i ~/ kSide - g ~/ kSide).abs() + (i % kSide - g % kSide).abs();
  }
  return h;
}

/// h3 : Manhattan + conflits lineaires. Deux jetons deja dans leur ligne (ou colonne)
/// finale mais inverses obligent l'un des deux a sortir puis revenir : +2 deplacements
/// par jeton a sortir. Reste admissible et domine h2.
int hLinearConflict(int s) {
  var h = hManhattan(s);
  final line = <int>[];
  for (var r = 0; r < kSide; r++) {
    line.clear();
    for (var c = 0; c < kSide; c++) {
      final t = (s >>> (4 * (r * kSide + c))) & 15;
      if (t != 0 && (t - 1) ~/ kSide == r) line.add((t - 1) % kSide);
    }
    h += 2 * (line.length - _lis(line));
  }
  for (var c = 0; c < kSide; c++) {
    line.clear();
    for (var r = 0; r < kSide; r++) {
      final t = (s >>> (4 * (r * kSide + c))) & 15;
      if (t != 0 && (t - 1) % kSide == c) line.add((t - 1) ~/ kSide);
    }
    h += 2 * (line.length - _lis(line));
  }
  return h;
}

/// Longueur de la plus longue sous-suite croissante (au plus 4 elements).
int _lis(List<int> a) {
  var best = 0;
  final l = List<int>.filled(a.length, 1);
  for (var i = 0; i < a.length; i++) {
    for (var j = 0; j < i; j++) {
      if (a[j] < a[i] && l[j] + 1 > l[i]) l[i] = l[j] + 1;
    }
    if (l[i] > best) best = l[i];
  }
  return best;
}

const List<String> kHeuristicNames = ['Mal placés', 'Manhattan', 'Manhattan + conflits'];
const List<String> kHeuristicShort = ['h1', 'h2', 'h3'];

int heuristic(int kind, int s) => switch (kind) {
      0 => hMisplaced(s),
      1 => hManhattan(s),
      _ => hLinearConflict(s),
    };

/// Une configuration est resoluble si et seulement si (nombre d'inversions + numero de la
/// ligne de la case vide compte depuis le bas) est impair (grille de largeur paire).
bool isSolvable(List<int> tiles) {
  var inv = 0;
  for (var i = 0; i < kCells; i++) {
    for (var j = i + 1; j < kCells; j++) {
      if (tiles[i] != 0 && tiles[j] != 0 && tiles[i] > tiles[j]) inv++;
    }
  }
  final blankRowFromBottom = kSide - tiles.indexOf(0) ~/ kSide;
  return (inv + blankRowFromBottom).isOdd;
}

/// Lit 16 entiers (0 = case vide). Retourne null si ce n'est pas une permutation de 0..15.
List<int>? parseTiles(String text) {
  final t = text.split(RegExp(r'[\s,;]+')).where((s) => s.isNotEmpty).map(int.tryParse).toList();
  if (t.length != kCells || t.contains(null)) return null;
  final l = t.cast<int>();
  if (l.toSet().length != kCells || l.any((v) => v < 0 || v >= kCells)) return null;
  return l;
}

// ---------------------------------------------------------------- files de priorite

class Node {
  final int state, g, h;
  final double f;
  final Node? parent;

  /// Rang de creation : rend l'ordre total, donc identique pour les deux files.
  final int seq;
  Node(this.state, this.g, this.h, this.f, this.parent, [this.seq = 0]);

  /// Priorite : f croissant ; a egalite, le noeud le plus proche du but (h minimal) ;
  /// a egalite encore, le plus recent. L'ordre etant total, la file naive et le tas
  /// extraient exactement la meme suite de noeuds.
  bool before(Node o) => f < o.f || (f == o.f && (h < o.h || (h == o.h && seq > o.seq)));
}

abstract class PriorityQueue {
  int get length;
  void insert(Node n);
  Node removeMin();

  /// Indices du tableau touches par la derniere operation (pour l'affichage pas a pas).
  List<int> get lastPath;

  /// Les [k] premieres valeurs f du tableau interne (pour l'affichage pas a pas).
  List<double> peek(int k);
}

/// File naive : insertion O(1), retrait du minimum O(n) par balayage (version de l'enonce).
class NaiveQueue implements PriorityQueue {
  final List<Node> _a = [];
  int _last = -1;
  @override
  int get length => _a.length;
  @override
  void insert(Node n) {
    _a.add(n);
    _last = _a.length - 1;
  }

  @override
  Node removeMin() {
    var bi = 0;
    for (var i = 1; i < _a.length; i++) {
      if (_a[i].before(_a[bi])) bi = i;
    }
    final best = _a[bi];
    _a[bi] = _a.last;
    _a.removeLast();
    _last = bi;
    return best;
  }

  @override
  List<int> get lastPath => [_last];
  @override
  List<double> peek(int k) => [for (var i = 0; i < k && i < _a.length; i++) _a[i].f];
}

/// Tas binaire (min) range dans un tableau : insertion et retrait en O(log n).
/// Fils de i : 2i + 1 et 2i + 2 ; pere de i : (i - 1) / 2.
class HeapQueue implements PriorityQueue {
  final List<Node> _a = [];
  final List<int> _path = [];
  @override
  int get length => _a.length;

  /// Insertion : on ajoute en fin de tableau puis on fait remonter ("sift-up").
  @override
  void insert(Node n) {
    _a.add(n);
    var i = _a.length - 1;
    _path
      ..clear()
      ..add(i);
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (!_a[i].before(_a[p])) break;
      final t = _a[i];
      _a[i] = _a[p];
      _a[p] = t;
      i = p;
      _path.add(i);
    }
  }

  /// Retrait : la racine est le minimum ; le dernier element la remplace puis descend ("sift-down").
  @override
  Node removeMin() {
    final top = _a.first;
    final last = _a.removeLast();
    _path
      ..clear()
      ..add(0);
    if (_a.isNotEmpty) {
      _a[0] = last;
      var i = 0;
      final n = _a.length;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var s = i;
        if (l < n && _a[l].before(_a[s])) s = l;
        if (r < n && _a[r].before(_a[s])) s = r;
        if (s == i) break;
        final t = _a[i];
        _a[i] = _a[s];
        _a[s] = t;
        i = s;
        _path.add(i);
      }
    }
    return top;
  }

  @override
  List<int> get lastPath => List<int>.from(_path);
  @override
  List<double> peek(int k) => [for (var i = 0; i < k && i < _a.length; i++) _a[i].f];
}

// ---------------------------------------------------------------- A* / WA*

/// Sort reserve a un voisin pendant le developpement d'un noeud.
class NeighborInfo {
  final int state, g, h;
  final double f;

  /// 'inséré', 'amélioré' ou 'ignoré'.
  final String verdict;
  const NeighborInfo(this.state, this.g, this.h, this.f, this.verdict);
}

/// Instantane d'une etape de A* / WA*.
class PuzzleView {
  final int state, g, h;
  final double f;
  final List<NeighborInfo> neighbors;
  final int open, closed, generated;

  /// Debut du tableau de la file (valeurs f) et indices touches par la derniere operation.
  final List<double> queueHead;
  final List<int> queuePath;

  /// 'insertion', 'retrait' ou ''.
  final String queueOp;

  /// Rang dans la solution rejouee (-1 pendant la recherche).
  final int solutionIndex;
  const PuzzleView(this.state, this.g, this.h, this.f, this.neighbors, this.open, this.closed, this.generated,
      {this.queueHead = const [], this.queuePath = const [], this.queueOp = '', this.solutionIndex = -1});
}

class AStarResult {
  /// 'ok', 'limite' (trop de noeuds), 'delai' ou 'echec'.
  final String status;

  /// Suite des etats du depart au but (vide en cas d'echec).
  final List<int> path;
  final int expanded, generated, maxFrontier, micros;
  const AStarResult(this.status, this.path, this.expanded, this.generated, this.maxFrontier, this.micros);

  int get moves => path.isEmpty ? -1 : path.length - 1;
}

String fmtF(double f) => f == f.roundToDouble() ? f.toStringAsFixed(0) : f.toStringAsFixed(1);

/// Etapes qui rejouent une solution (utilisees apres une recherche, tracee ou non).
void appendSolutionSteps(Trace trace, List<int> path, int heuristicKind, double weight, {int open = 0, int closed = 0, int generated = 0}) {
  for (var i = 0; i < path.length; i++) {
    final h = heuristic(heuristicKind, path[i]);
    final f = i + weight * h;
    final lastOne = i == path.length - 1;
    trace.step(
        5,
        i == 0
            ? 'Relecture de la solution : ${path.length - 1} déplacements. État de départ, h = $h.'
            : lastOne
                ? 'Déplacement $i sur ${path.length - 1} : le but est atteint (h = 0).'
                : 'Déplacement $i sur ${path.length - 1} : g = $i, h = $h, f = g + p·h = ${fmtF(f)}.',
        vars: {'coup': '$i / ${path.length - 1}', 'g': i, 'h': h, 'f': fmtF(f)},
        view: PuzzleView(path[i], i, h, f, const [], open, closed, generated, solutionIndex: i),
        kind: lastOne ? StepKind.done : StepKind.normal);
  }
}

/// A* avec f(x) = g(x) + weight * h(x). weight = 1 : A* ; weight > 1 : WA*.
/// [trace] : si fourni, enregistre les etapes ; sinon la recherche tourne a pleine vitesse.
AStarResult solvePuzzle(
  int start, {
  int heuristicKind = 1,
  double weight = 1.0,
  bool useHeap = true,
  int nodeLimit = 1500000,
  int timeLimitMs = 20000,
  Trace? trace,
}) {
  final sw = Stopwatch()..start();
  final PriorityQueue open = useHeap ? HeapQueue() : NaiveQueue();
  final bestG = HashMap<int, int>();
  final h0 = heuristic(heuristicKind, start);
  open.insert(Node(start, 0, h0, weight * h0, null));
  bestG[start] = 0;
  var expanded = 0, generated = 1, maxFrontier = 1;
  final qName = useHeap ? 'tas' : 'file naïve';
  final pTxt = weight == 1.0 ? '' : '${fmtF(weight)}·';

  PuzzleView view(Node x, List<NeighborInfo> nb, String op) =>
      PuzzleView(x.state, x.g, x.h, x.f, List<NeighborInfo>.from(nb), open.length, expanded, generated,
          queueHead: open.peek(15), queuePath: open.lastPath, queueOp: op);
  Map<String, Object?> vars(Node x) => {
        'g': x.g,
        'h': x.h,
        'f': fmtF(x.f),
        'frontière': open.length,
        'fermés': expanded,
        'générés': generated,
      };

  if (trace != null) {
    final s = Node(start, 0, h0, weight * h0, null);
    trace.step(
        1,
        'On place l\'état de départ dans la frontière : g = 0, h = $h0, f = g + ${pTxt}h = ${fmtF(s.f)}. '
        '${weight == 1.0 ? "p = 1 : c'est A*." : "p = ${fmtF(weight)} > 1 : c'est WA*."}',
        vars: vars(s),
        view: view(s, const [], 'insertion'));
  }

  while (open.length > 0) {
    final cur = open.removeMin();
    if (cur.g > bestG[cur.state]!) {
      // entree perimee : un meilleur chemin vers cet etat a ete trouve depuis
      trace?.step(4, 'L\'entrée extraite est périmée : un chemin plus court vers cet état (g = ${bestG[cur.state]}) a été trouvé depuis. On la jette.',
          vars: vars(cur), view: view(cur, const [], 'retrait'));
      continue;
    }
    trace?.step(
        4,
        'On extrait du $qName l\'état de plus petit f = ${fmtF(cur.f)} (g = ${cur.g}, h = ${cur.h}). '
        '${useHeap ? "Retrait en O(log n) : la racine sort, le dernier élément la remplace puis redescend." : "Retrait en O(n) : il faut balayer toute la file."}',
        vars: vars(cur),
        view: view(cur, const [], 'retrait'),
        kind: StepKind.important);
    if (cur.state == kGoal) {
      final path = <int>[];
      for (Node? x = cur; x != null; x = x.parent) {
        path.add(x.state);
      }
      sw.stop();
      final sol = path.reversed.toList();
      if (trace != null) {
        trace.step(5, 'L\'état extrait est le but : solution trouvée en ${cur.g} déplacements, après $expanded états développés et $generated états générés.',
            vars: vars(cur), view: view(cur, const [], ''), kind: StepKind.found);
        appendSolutionSteps(trace, sol, heuristicKind, weight, open: open.length, closed: expanded, generated: generated);
      }
      return AStarResult('ok', sol, expanded, generated, maxFrontier, sw.elapsedMicroseconds);
    }
    expanded++;
    if (expanded > nodeLimit) {
      return AStarResult('limite', const [], expanded, generated, maxFrontier, sw.elapsedMicroseconds);
    }
    if ((expanded & 255) == 0 && sw.elapsedMilliseconds > timeLimitMs) {
      return AStarResult('delai', const [], expanded, generated, maxFrontier, sw.elapsedMicroseconds);
    }
    trace?.step(6, 'Ce n\'est pas le but : on le range dans les états fermés ($expanded fermés) et on génère ses voisins en déplaçant la case vide.',
        vars: vars(cur), view: view(cur, const [], ''));
    final blank = blankOf(cur.state);
    final g = cur.g + 1;
    final nb = <NeighborInfo>[];
    for (final pos in kNeighbors[blank]) {
      final ns = swapBlank(cur.state, blank, pos);
      final old = bestG[ns];
      if (old != null && old <= g) {
        // programmation dynamique : on garde le meilleur chemin
        if (trace != null) {
          final h = heuristic(heuristicKind, ns);
          nb.add(NeighborInfo(ns, g, h, g + weight * h, 'ignoré'));
          trace.step(9, 'Voisin obtenu en déplaçant le jeton ${tileAt(cur.state, pos)} : déjà vu avec g = $old ≤ $g. Ignoré.',
              vars: vars(cur), view: view(cur, nb, ''));
        }
        continue;
      }
      bestG[ns] = g;
      final h = heuristic(heuristicKind, ns);
      open.insert(Node(ns, g, h, g + weight * h, cur, generated));
      generated++;
      if (trace != null) {
        nb.add(NeighborInfo(ns, g, h, g + weight * h, old == null ? 'inséré' : 'amélioré'));
        trace.step(
            11,
            'Voisin obtenu en déplaçant le jeton ${tileAt(cur.state, pos)} : ${old == null ? "nouvel état" : "meilleur chemin (g = $g < $old)"}. '
            'g = $g, h = $h, f = $g + $pTxt$h = ${fmtF(g + weight * h)}. Inséré dans le $qName'
            '${useHeap ? " (ajout en fin de tableau puis remontée, O(log n))." : " (ajout en fin de file, O(1))."}',
            vars: vars(cur),
            view: view(cur, nb, 'insertion'));
      }
    }
    if (open.length > maxFrontier) maxFrontier = open.length;
  }
  return AStarResult('echec', const [], expanded, generated, maxFrontier, sw.elapsedMicroseconds);
}

/// Execute la recherche dans un isolate (l'interface reste fluide).
Future<AStarResult> solvePuzzleInIsolate(
  int start, {
  required int heuristicKind,
  required double weight,
  required bool useHeap,
  int nodeLimit = 1500000,
  int timeLimitMs = 20000,
}) {
  return Isolate.run(() => solvePuzzle(start,
      heuristicKind: heuristicKind, weight: weight, useHeap: useHeap, nodeLimit: nodeLimit, timeLimitMs: timeLimitMs));
}
