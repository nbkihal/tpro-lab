/// TP1 (TD2 ex.6) - Plus court cycle d'un graphe non oriente.
/// Representation : listes d'adjacence. Methode : un BFS depuis chaque sommet.
/// Complexite : V parcours BFS en O(V + E) chacun, soit O(V (V + E)).
library;

import 'dart:collection';
import 'dart:math';

import 'trace.dart';

class Graph {
  final List<List<int>> adj = [];

  int get n => adj.length;

  int get m {
    var s = 0;
    for (final l in adj) {
      s += l.length;
    }
    return s ~/ 2;
  }

  int addVertex() {
    adj.add(<int>[]);
    return adj.length - 1;
  }

  bool hasEdge(int u, int v) => adj[u].contains(v);

  /// Ajoute l'arete {u, v}. Refuse les boucles et les aretes multiples.
  bool addEdge(int u, int v) {
    if (u == v || u < 0 || v < 0 || u >= n || v >= n || hasEdge(u, v)) return false;
    adj[u].add(v);
    adj[v].add(u);
    return true;
  }

  void removeEdge(int u, int v) {
    adj[u].remove(v);
    adj[v].remove(u);
  }

  /// Supprime le sommet v ; les sommets suivants sont renumerotes.
  void removeVertex(int v) {
    adj.removeAt(v);
    for (final l in adj) {
      l.remove(v);
      for (var i = 0; i < l.length; i++) {
        if (l[i] > v) l[i]--;
      }
    }
  }

  void clear() => adj.clear();

  List<List<int>> edges() {
    final out = <List<int>>[];
    for (var u = 0; u < n; u++) {
      for (final v in adj[u]) {
        if (u < v) out.add([u, v]);
      }
    }
    return out;
  }

  Graph copy() {
    final g = Graph();
    for (final l in adj) {
      g.adj.add(List<int>.from(l));
    }
    return g;
  }

  /// Construit un graphe a [n] sommets a partir d'une liste d'aretes.
  static Graph fromEdges(int n, List<List<int>> edges) {
    final g = Graph();
    for (var i = 0; i < n; i++) {
      g.addVertex();
    }
    for (final e in edges) {
      g.addEdge(e[0], e[1]);
    }
    return g;
  }

  /// Lit une liste d'aretes en texte ("0 1\n1 2\n..."). Les separateurs acceptes sont
  /// l'espace, la virgule, le point-virgule et le tiret. Une ligne avec un seul entier
  /// declare un sommet isole. Retourne null si le texte est invalide.
  static Graph? parseEdgeList(String text) {
    final pairs = <List<int>>[];
    var maxV = -1;
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final t = line.split(RegExp(r'[\s,;\-]+')).where((s) => s.isNotEmpty).toList();
      if (t.isEmpty || t.length > 2) return null;
      final a = int.tryParse(t[0]);
      final b = t.length == 2 ? int.tryParse(t[1]) : a;
      if (a == null || b == null || a < 0 || b < 0 || a > 999 || b > 999) return null;
      maxV = max(maxV, max(a, b));
      if (t.length == 2) pairs.add([a, b]);
    }
    return fromEdges(maxV + 1, pairs);
  }

  String toEdgeList() => edges().map((e) => '${e[0]} ${e[1]}').join('\n');

  static Graph random(int n, int m, Random rnd) {
    final g = Graph();
    for (var i = 0; i < n; i++) {
      g.addVertex();
    }
    final maxM = n * (n - 1) ~/ 2;
    if (m > maxM) m = maxM;
    var guard = 0;
    while (g.m < m && guard < 100000) {
      g.addEdge(rnd.nextInt(n), rnd.nextInt(n));
      guard++;
    }
    return g;
  }
}

/// Instantane d'une etape du plus court cycle, pour le dessin.
class CycleView {
  /// Source du BFS en cours (-1 avant le premier et apres le dernier).
  final int source;
  final List<int> dist, parent, queue;

  /// Sommet defile (-1 si aucun) et voisin examine (-1 si aucun).
  final int u, v;

  /// Cycle ferme a cette etape (vide sinon) et meilleur cycle connu.
  final List<int> closing, bestCycle;

  /// Longueur du meilleur cycle connu (0 = infini).
  final int best;
  final int visits, edgeChecks;
  const CycleView({
    required this.source,
    required this.dist,
    required this.parent,
    required this.queue,
    required this.u,
    required this.v,
    required this.closing,
    required this.bestCycle,
    required this.best,
    required this.visits,
    required this.edgeChecks,
  });
}

class CycleResult {
  /// Sommets du plus court cycle dans l'ordre (vide s'il n'y a aucun cycle).
  final List<int> cycle;

  /// Nombre total de sommets defiles, tous BFS confondus.
  final int visits;

  /// Nombre total d'examens d'arete (chaque arete est vue depuis ses deux extremites).
  final int edgeChecks;
  final int micros;
  const CycleResult(this.cycle, this.visits, this.edgeChecks, this.micros);

  int get length => cycle.length;
}

String _inf(int best) => best == 0 ? '∞' : '$best';

/// Plus court cycle : un BFS depuis chaque sommet.
/// [earlyCut] : coupe optionnelle (arret du BFS des que 2 dist[u] + 1 >= best).
/// [trace] : si fourni, enregistre les etapes ; sinon l'algorithme tourne a pleine vitesse.
CycleResult shortestCycle(Graph g, {Trace? trace, bool earlyCut = false}) {
  final sw = Stopwatch()..start();
  final n = g.n;
  var best = 0; // 0 = infini
  var bestCycle = <int>[];
  var visits = 0, edgeChecks = 0;
  final dist = List<int>.filled(n, -1);
  final parent = List<int>.filled(n, -1);
  final queue = Queue<int>();
  var src = -1;

  CycleView view({int u = -1, int v = -1, List<int> closing = const []}) => CycleView(
        source: src,
        dist: List<int>.from(dist),
        parent: List<int>.from(parent),
        queue: queue.toList(),
        u: u,
        v: v,
        closing: closing,
        bestCycle: bestCycle,
        best: best,
        visits: visits,
        edgeChecks: edgeChecks,
      );
  Map<String, Object?> vars({int u = -1}) => {
        's': src < 0 ? '—' : src,
        if (u >= 0) 'u': u,
        'best': _inf(best),
        'file Q': queue.toList(),
        'dist[]': List<int>.from(dist),
        'parent[]': [for (final p in parent) p < 0 ? '·' : p],
      };

  trace?.step(1, 'On initialise best à ∞ : aucun cycle n\'est encore connu.', vars: vars(), view: view());

  for (var s = 0; s < n; s++) {
    src = s;
    dist.fillRange(0, n, -1);
    parent.fillRange(0, n, -1);
    queue.clear();
    trace?.step(2, 'Nouveau parcours en largeur, cette fois depuis le sommet $s (${s + 1}ᵉ BFS sur $n).',
        vars: vars(), view: view(), kind: StepKind.important);
    dist[s] = 0;
    queue.add(s);
    trace?.step(4, 'Tous les sommets sont remis à « non visité ». La source $s est à la distance 0 et entre dans la file.',
        vars: vars(), view: view());
    while (queue.isNotEmpty) {
      final u = queue.removeFirst();
      visits++;
      trace?.step(6, 'On défile le sommet $u (distance ${dist[u]} de la source $s) et on examine ses voisins.',
          vars: vars(u: u), view: view(u: u));
      // Un cycle passant par u a une longueur >= 2 dist[u] + 1 : inutile d'aller plus loin.
      if (earlyCut && best != 0 && 2 * dist[u] + 1 >= best) {
        trace?.step(
            5,
            'Coupe : tout cycle fermé à partir de $u mesurerait au moins 2×${dist[u]} + 1 = ${2 * dist[u] + 1} ≥ best = $best. '
            'On arrête ce BFS.',
            vars: vars(u: u),
            view: view(u: u),
            kind: StepKind.pruned);
        break;
      }
      for (final v in g.adj[u]) {
        edgeChecks++;
        if (dist[v] < 0) {
          dist[v] = dist[u] + 1;
          parent[v] = u;
          queue.add(v);
          trace?.step(9, 'Le voisin $v n\'était pas visité : arête d\'arbre $u–$v. dist[$v] = ${dist[v]}, parent[$v] = $u, et $v entre dans la file.',
              vars: vars(u: u), view: view(u: u, v: v));
        } else if (v != parent[u]) {
          // Arete vers un sommet deja vu qui n'est pas le pere : elle ferme un cycle.
          final len = dist[u] + dist[v] + 1;
          final c = _buildCycle(u, v, parent);
          final improved = best == 0 || len < best;
          if (improved) {
            best = len;
            bestCycle = c;
          }
          if (trace != null) {
            final via = c.length < len
                ? ' (les deux chemins se rejoignent avant la source : le cycle réel ne compte que ${c.length} sommets ; '
                    'il sera mesuré exactement par le BFS lancé depuis l\'un de ses sommets)'
                : '';
            trace.step(
                11,
                'Le voisin $v est déjà visité et n\'est pas le parent de $u : l\'arête $u–$v ferme un cycle de longueur '
                'dist[$u] + dist[$v] + 1 = ${dist[u]} + ${dist[v]} + 1 = $len$via. '
                '${improved ? "C'est mieux que le meilleur connu : best = $len." : "Ce n'est pas mieux que best = $best."}',
                vars: vars(u: u),
                view: view(u: u, v: v, closing: c),
                kind: improved ? StepKind.found : StepKind.important);
          }
        } else {
          trace?.step(10, 'Le voisin $v est le parent de $u : c\'est l\'arête par laquelle on est arrivé, pas un cycle. On l\'ignore.',
              vars: vars(u: u), view: view(u: u, v: v));
        }
      }
    }
  }
  src = -1;
  sw.stop();
  if (trace != null) {
    dist.fillRange(0, n, -1);
    parent.fillRange(0, n, -1);
    queue.clear();
    trace.step(
        12,
        bestCycle.isEmpty
            ? 'Aucun BFS n\'a rencontré d\'arête hors arbre : aucun cycle (le graphe est une forêt).'
            : 'Tous les sommets ont servi de source. Le plus petit cycle a pour longueur $best : ${bestCycle.join(" → ")} → ${bestCycle.first}.',
        vars: vars(),
        view: view(),
        kind: StepKind.done);
  }
  return CycleResult(bestCycle, visits, edgeChecks, sw.elapsedMicroseconds);
}

/// Reconstruit le cycle ferme par l'arete (u, v) : on remonte les peres de u et de v
/// jusqu'a leur premier ancetre commun.
List<int> _buildCycle(int u, int v, List<int> parent) {
  final pu = <int>[];
  for (var x = u; x != -1; x = parent[x]) {
    pu.add(x);
  }
  final pv = <int>[];
  for (var x = v; x != -1; x = parent[x]) {
    pv.add(x);
  }
  while (pu.length >= 2 && pv.length >= 2 && pu[pu.length - 2] == pv[pv.length - 2]) {
    pu.removeLast();
    pv.removeLast();
  }
  pv.removeLast(); // l'ancetre commun est deja dans pu
  return [...pu, ...pv.reversed];
}
