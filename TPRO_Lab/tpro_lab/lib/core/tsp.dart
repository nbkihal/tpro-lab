/// TP2 (TD3 ex.6) - Voyageur de commerce.
/// 1) methode exacte par enumeration de tous les cycles hamiltoniens : O(n!)
///    (deux styles : DFS / permutations, ou BFS sur une file de chemins partiels)
/// 2) Bellman-Held-Karp (programmation dynamique) : O(n^2 2^n)
library;

import 'dart:collection';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'trace.dart';

class TspResult {
  /// Villes dans l'ordre de visite, en partant de la ville 0 (le retour a 0 est implicite).
  final List<int> tour;
  final int cost;

  /// Enumeration : nombre de cycles evalues. Held-Karp : nombre de transitions
  /// C(S - {j}, i) + d(i, j) calculees.
  final int ops;
  final int micros;

  /// Enumeration BFS : taille maximale de la file. Held-Karp : nombre de cases C(S, j) remplies.
  final int extra;

  /// Held-Karp trace : les cases de la table dans l'ordre de remplissage.
  final List<HkCell> cells;
  const TspResult(this.tour, this.cost, this.ops, this.micros, {this.extra = 0, this.cells = const []});
}

/// Instantane d'une etape de l'enumeration.
class EnumView {
  /// Chemin en cours (complet ou partiel), en partant de 0.
  final List<int> tour;
  final bool partial;
  final int cost;
  final List<int> bestTour;

  /// Meilleur cout connu (-1 = infini).
  final int best;
  final int count, queueSize;
  const EnumView(this.tour, this.partial, this.cost, this.bestTour, this.best, this.count, this.queueSize);
}

/// Une case de la table de Held-Karp : C(S, j) = value, obtenue en venant de [from].
class HkCell {
  /// Ensemble S sous forme de masque sur les villes 0..n-1 (la ville 0 est toujours presente).
  final int set;
  final int j, value, from;
  const HkCell(this.set, this.j, this.value, this.from);

  int get size {
    var c = 0;
    for (var s = set; s != 0; s &= s - 1) {
      c++;
    }
    return c;
  }
}

/// Instantane d'une etape de Held-Karp.
class HkView {
  /// Ensemble S en cours (masque sur les villes 0..n-1), 0 si aucun.
  final int set;

  /// Derniere ville j et ville precedente i (-1 si non definies).
  final int j, i;

  /// Nombre de cases de la table deja remplies (indice dans TspResult.cells).
  final int filled;

  /// Tournee finale (vide tant qu'elle n'est pas connue) et son cout.
  final List<int> tour;
  final int cost;
  final int ops;
  const HkView(this.set, this.j, this.i, this.filled, this.tour, this.cost, this.ops);
}

String setName(int set) {
  final l = <int>[];
  for (var c = 0; set >> c != 0; c++) {
    if (set & (1 << c) != 0) l.add(c);
  }
  return '{${l.join(',')}}';
}

List<int> setCities(int set) => [
      for (var c = 0; set >> c != 0; c++)
        if (set & (1 << c) != 0) c
    ];

String _tourText(List<int> t) => '${t.join(' → ')} → 0';

String _sumText(List<List<int>> d, List<int> t) {
  final parts = <String>[];
  for (var i = 0; i < t.length; i++) {
    parts.add('${d[t[i]][t[(i + 1) % t.length]]}');
  }
  return parts.join(' + ');
}

/// Enumeration exhaustive (style DFS) des (n-1)! permutations des villes 1..n-1.
TspResult tspBruteForce(List<List<int>> d, {Trace? trace}) {
  final sw = Stopwatch()..start();
  final n = d.length;
  if (n == 1) return const TspResult([0], 0, 1, 0);
  final perm = List<int>.generate(n, (i) => i);
  var best = 1 << 62;
  var bestTour = List<int>.from(perm);
  var ops = 0;

  trace?.step(1, 'On initialise best à ∞. La ville 0 est fixée au départ : il reste à ordonner les ${n - 1} autres villes.',
      vars: {'best': '∞', 'cycles': 0}, view: const EnumView([0], true, 0, [], -1, 0, 0));

  void rec(int k, int cost) {
    if (k == n) {
      ops++;
      final total = cost + d[perm[n - 1]][0];
      final better = total < best;
      if (trace != null) {
        final t = List<int>.from(perm);
        trace.step(3, 'Cycle n° $ops : ${_tourText(t)}. Coût = ${_sumText(d, t)} = $total.',
            vars: {'cycle': _tourText(t), 'coût': total, 'best': best == 1 << 62 ? '∞' : best, 'cycles': ops},
            view: EnumView(t, false, total, List<int>.from(bestTour), best == 1 << 62 ? -1 : best, ops, 0));
        if (better) {
          trace.step(4, 'Ce coût $total est plus petit que best : on retient ce cycle comme meilleure tournée.',
              vars: {'cycle': _tourText(t), 'coût': total, 'best': total, 'cycles': ops},
              view: EnumView(t, false, total, t, total, ops, 0),
              kind: StepKind.found);
        }
      }
      if (better) {
        best = total;
        bestTour = List<int>.from(perm);
      }
      return;
    }
    for (var i = k; i < n; i++) {
      var t = perm[k];
      perm[k] = perm[i];
      perm[i] = t;
      rec(k + 1, cost + d[perm[k - 1]][perm[k]]);
      t = perm[k];
      perm[k] = perm[i];
      perm[i] = t;
    }
  }

  rec(1, 0);
  sw.stop();
  trace?.step(5, 'Les $ops cycles hamiltoniens ((n−1)! = ${n - 1}!) ont tous été évalués. Tournée optimale : ${_tourText(bestTour)}, coût $best.',
      vars: {'best': best, 'tournée': _tourText(bestTour), 'cycles': ops},
      view: EnumView(bestTour, false, best, bestTour, best, ops, 0),
      kind: StepKind.done);
  return TspResult(bestTour, best, ops, sw.elapsedMicroseconds);
}

/// Limite du style BFS : la file contient jusqu'a (n-1)! chemins.
const int kBfsEnumMaxN = 11;

/// Enumeration exhaustive (style BFS, comme le suggere l'enonce) : une file de chemins
/// partiels partant de 0 ; on defile un chemin, on l'etend avec chaque ville non visitee.
/// Un chemin est code sur un entier : 4 bits par ville + le masque des villes visitees.
TspResult tspBruteForceBfs(List<List<int>> d, {Trace? trace}) {
  final sw = Stopwatch()..start();
  final n = d.length;
  if (n == 1) return const TspResult([0], 0, 1, 0);
  if (n > kBfsEnumMaxN + 1) throw ArgumentError('enumeration BFS limitee a n <= ${kBfsEnumMaxN + 1}');
  const shift = 48;
  final paths = ListQueue<int>();
  final costs = ListQueue<int>();
  paths.add(1 << shift); // chemin "0", masque {0}
  costs.add(0);
  var best = 1 << 62, bestCode = 0, ops = 0, maxQueue = 1;

  List<int> decode(int code, int len) => [for (var k = 0; k < len; k++) (code >> (4 * k)) & 15];
  int lenOf(int code) {
    var c = 0;
    for (var m = code >> shift; m != 0; m &= m - 1) {
      c++;
    }
    return c;
  }

  trace?.step(1, 'On initialise best à ∞ et la file avec le chemin partiel réduit à la ville de départ 0.',
      vars: {'best': '∞', 'file': 1, 'cycles': 0}, view: const EnumView([0], true, 0, [], -1, 0, 1));

  while (paths.isNotEmpty) {
    final code = paths.removeFirst();
    final cost = costs.removeFirst();
    final mask = code >> shift;
    final len = lenOf(code);
    final last = (code >> (4 * (len - 1))) & 15;
    if (len == n) {
      ops++;
      final total = cost + d[last][0];
      final better = total < best;
      if (trace != null) {
        final t = decode(code, n);
        final bt = bestCode == 0 ? <int>[] : decode(bestCode, n);
        trace.step(3, 'Chemin complet défilé — cycle n° $ops : ${_tourText(t)}. Coût = ${_sumText(d, t)} = $total.',
            vars: {'cycle': _tourText(t), 'coût': total, 'best': best == 1 << 62 ? '∞' : best, 'file': paths.length, 'cycles': ops},
            view: EnumView(t, false, total, bt, best == 1 << 62 ? -1 : best, ops, paths.length));
        if (better) {
          trace.step(4, 'Ce coût $total est plus petit que best : on retient ce cycle comme meilleure tournée.',
              vars: {'cycle': _tourText(t), 'coût': total, 'best': total, 'file': paths.length, 'cycles': ops},
              view: EnumView(t, false, total, t, total, ops, paths.length),
              kind: StepKind.found);
        }
      }
      if (better) {
        best = total;
        bestCode = code;
      }
      continue;
    }
    for (var c = 1; c < n; c++) {
      if (mask & (1 << c) != 0) continue;
      paths.add((code & ((1 << shift) - 1)) | (c << (4 * len)) | ((mask | (1 << c)) << shift));
      costs.add(cost + d[last][c]);
    }
    if (paths.length > maxQueue) maxQueue = paths.length;
    if (trace != null) {
      final t = decode(code, len);
      trace.step(2, 'On défile le chemin partiel ${t.join(' → ')} (coût $cost) et on enfile ses ${n - len} prolongements, un par ville non visitée.',
          vars: {'chemin': t.join(' → '), 'coût partiel': cost, 'best': best == 1 << 62 ? '∞' : best, 'file': paths.length, 'cycles': ops},
          view: EnumView(t, true, cost, bestCode == 0 ? const [] : decode(bestCode, n), best == 1 << 62 ? -1 : best, ops, paths.length));
    }
  }
  final bestTour = decode(bestCode, n);
  sw.stop();
  trace?.step(
      5,
      'La file est vide : les $ops cycles hamiltoniens ((n−1)! = ${n - 1}!) ont été évalués. Tournée optimale : ${_tourText(bestTour)}, coût $best. '
      'La file a contenu jusqu\'à $maxQueue chemins.',
      vars: {'best': best, 'tournée': _tourText(bestTour), 'file max': maxQueue, 'cycles': ops},
      view: EnumView(bestTour, false, best, bestTour, best, ops, 0),
      kind: StepKind.done);
  return TspResult(bestTour, best, ops, sw.elapsedMicroseconds, extra: maxQueue);
}

/// Bellman-Held-Karp.
/// C(S, j) = cout minimal d'un chemin partant de 0, visitant exactement S et finissant en j.
/// C({0, j}, j) = d(0, j) ;  C(S, j) = min_{i dans S, i != 0, i != j} C(S - {j}, i) + d(i, j)
/// Reponse : min_j C(toutes, j) + d(j, 0).
/// S est code par un masque de bits sur les villes 1..n-1 (bit k = ville k+1) ; la ville 0
/// appartient a tous les ensembles et n'est donc pas stockee.
TspResult tspHeldKarp(List<List<int>> d, {Trace? trace}) {
  final sw = Stopwatch()..start();
  final n = d.length;
  if (n == 1) return const TspResult([0], 0, 1, 0);
  final m = n - 1;
  final full = (1 << m) - 1;
  const inf = 0x3fffffff;
  final dp = Int32List((1 << m) * m)..fillRange(0, (1 << m) * m, inf);
  final par = Uint8List((1 << m) * m);
  var ops = 0, filled = 0;
  final cells = <HkCell>[];
  // Masque interne (villes 1..n-1) -> masque affiche (villes 0..n-1, avec la ville 0).
  int shown(int mask) => (mask << 1) | 1;

  // Initialisation : C({0, j}, j) = d(0, j).
  for (var j = 0; j < m; j++) {
    dp[(1 << j) * m + j] = d[0][j + 1];
    filled++;
    if (trace != null) {
      cells.add(HkCell(shown(1 << j), j + 1, d[0][j + 1], 0));
      trace.step(1, 'Initialisation : C({0,${j + 1}}, ${j + 1}) = d(0, ${j + 1}) = ${d[0][j + 1]} — aller directement de 0 à ${j + 1}.',
          vars: {'S': '{0,${j + 1}}', 'j': j + 1, 'C(S, j)': d[0][j + 1]},
          view: HkView(shown(1 << j), j + 1, -1, filled, const [], 0, ops));
    }
  }

  // Boucle 1 : la taille du sous-ensemble S (ville 0 comprise), de 3 a n.
  for (var size = 3; size <= n; size++) {
    trace?.step(2, 'Boucle 1 — on passe aux sous-ensembles de $size villes (ville 0 comprise). '
        'Ils ne dépendent que des sous-ensembles de ${size - 1} villes, déjà calculés.',
        vars: {'taille': size}, view: HkView(0, -1, -1, filled, const [], 0, ops), kind: StepKind.important);
    // Boucle 2 : tous les sous-ensembles S de cette taille (astuce de Gosper : masque
    // suivant ayant le meme nombre de bits).
    var mask = (1 << (size - 1)) - 1;
    while (mask <= full) {
      trace?.step(3, 'Boucle 2 — sous-ensemble S = ${setName(shown(mask))}.',
          vars: {'taille': size, 'S': setName(shown(mask))}, view: HkView(shown(mask), -1, -1, filled, const [], 0, ops));
      // Boucle 3 : la derniere ville j du chemin, j dans S, j != 0.
      for (var j = 0; j < m; j++) {
        if (mask & (1 << j) == 0) continue;
        final prev = mask ^ (1 << j);
        var bestVal = inf, bestI = 0;
        final cand = trace == null ? null : <String>[];
        trace?.step(4, 'Boucle 3 — on termine le chemin par la ville j = ${j + 1}. Il faut donc avoir visité S − {${j + 1}} = ${setName(shown(prev))} juste avant.',
            vars: {'taille': size, 'S': setName(shown(mask)), 'j': j + 1}, view: HkView(shown(mask), j + 1, -1, filled, const [], 0, ops));
        // Boucle 4 : l'avant-derniere ville i, i dans S, i != 0, i != j.
        for (var i = 0; i < m; i++) {
          if (prev & (1 << i) == 0) continue;
          ops++;
          final val = dp[prev * m + i] + d[i + 1][j + 1];
          final better = val < bestVal;
          if (better) {
            bestVal = val;
            bestI = i;
          }
          if (trace != null) {
            cand!.add('C(${setName(shown(prev))},${i + 1}) + d(${i + 1},${j + 1}) = ${dp[prev * m + i]} + ${d[i + 1][j + 1]} = $val');
            trace.step(
                5,
                'Boucle 4 — avant-dernière ville i = ${i + 1} : C(${setName(shown(prev))}, ${i + 1}) + d(${i + 1}, ${j + 1}) = '
                '${dp[prev * m + i]} + ${d[i + 1][j + 1]} = $val${better ? " — meilleur candidat pour l'instant." : " — pas mieux que $bestVal."}',
                vars: {'taille': size, 'S': setName(shown(mask)), 'j': j + 1, 'i': i + 1, 'candidat': val, 'min': bestVal},
                view: HkView(shown(mask), j + 1, i + 1, filled, const [], 0, ops));
          }
        }
        dp[mask * m + j] = bestVal;
        par[mask * m + j] = bestI;
        filled++;
        if (trace != null) {
          cells.add(HkCell(shown(mask), j + 1, bestVal, bestI + 1));
          trace.step(
              6,
              'C(${setName(shown(mask))}, ${j + 1}) = min( ${cand!.join(' ; ')} ) = $bestVal, en arrivant par la ville ${bestI + 1}. On range cette valeur dans la table.',
              vars: {'taille': size, 'S': setName(shown(mask)), 'j': j + 1, 'C(S, j)': bestVal, 'vient de': bestI + 1},
              view: HkView(shown(mask), j + 1, bestI + 1, filled, const [], 0, ops));
        }
      }
      final c = mask & -mask;
      final r = mask + c;
      mask = (((r ^ mask) >> 2) ~/ c) | r;
    }
  }

  // Fermeture du cycle : retour a la ville 0.
  var best = 1 << 62;
  var last = 0;
  final closing = <String>[];
  for (var j = 0; j < m; j++) {
    final val = dp[full * m + j] + d[j + 1][0];
    if (val < best) {
      best = val;
      last = j;
    }
    closing.add('C(${setName(shown(full))},${j + 1}) + d(${j + 1},0) = ${dp[full * m + j]} + ${d[j + 1][0]} = $val');
  }
  // Reconstruction de la tournee en remontant les predecesseurs.
  final rev = <int>[];
  var mask = full;
  var j = last;
  while (mask != 0) {
    rev.add(j + 1);
    final pj = par[mask * m + j];
    mask &= ~(1 << j);
    j = pj;
  }
  final tour = [0, ...rev.reversed];
  sw.stop();
  trace?.step(
      7,
      'On referme le cycle : min( ${closing.join(' ; ')} ) = $best. '
      'En remontant les prédécesseurs mémorisés, on retrouve la tournée ${_tourText(tour)}.',
      vars: {'coût optimal': best, 'tournée': _tourText(tour), 'cases remplies': filled, 'transitions': ops},
      view: HkView(shown(full), last + 1, -1, filled, tour, best, ops),
      kind: StepKind.done);
  return TspResult(tour, best, ops, sw.elapsedMicroseconds, extra: filled, cells: cells);
}

List<List<int>> randomMatrix(int n, Random rnd, {int maxDist = 99, bool symmetric = true}) {
  final d = List.generate(n, (_) => List<int>.filled(n, 0));
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      d[i][j] = 1 + rnd.nextInt(maxDist);
      d[j][i] = symmetric ? d[i][j] : 1 + rnd.nextInt(maxDist);
    }
  }
  return d;
}

/// Matrice des distances euclidiennes arrondies entre des points (x, y).
List<List<int>> euclideanMatrix(List<List<double>> pts) => [
      for (final a in pts)
        [
          for (final b in pts) identical(a, b) ? 0 : max(1, sqrt(pow(a[0] - b[0], 2) + pow(a[1] - b[1], 2)).round())
        ]
    ];

int tourCost(List<List<int>> d, List<int> tour) {
  var c = 0;
  for (var i = 0; i < tour.length; i++) {
    c += d[tour[i]][tour[(i + 1) % tour.length]];
  }
  return c;
}

double factorial(int n) {
  var f = 1.0;
  for (var i = 2; i <= n; i++) {
    f *= i;
  }
  return f;
}

/// Estimation grossiere du temps de l'enumeration (en secondes) pour n villes.
double estimateBruteSeconds(int n, {double nanosPerCycle = 12}) => factorial(n - 1) * nanosPerCycle / 1e9;

/// Memoire de la table de Held-Karp (octets) : 2^(n-1) (n-1) cases de 4 + 1 octets.
double heldKarpBytes(int n) => pow(2, n - 1) * (n - 1) * 5.0;

// ---------------------------------------------------------------- banc d'essai

class BenchRow {
  final int n;

  /// Temps medians en microsecondes (null : methode non executee pour ce n).
  final int? bruteMicros, hkMicros;

  /// Les deux methodes ont trouve le meme cout sur toutes les instances (null si non comparable).
  final bool? sameCost;
  final int instances;
  const BenchRow(this.n, this.bruteMicros, this.hkMicros, this.sameCost, this.instances);
}

/// Mesure les deux methodes sur [instances] matrices aleatoires de taille n (temps median).
/// Les mesures viennent toujours d'executions sans trace.
BenchRow benchTspN(int n, {int instances = 3, int seed = 1, bool brute = true, bool heldKarp = true}) {
  final rnd = Random(seed * 1000 + n);
  final tb = <int>[], th = <int>[];
  bool? same;
  for (var k = 0; k < instances; k++) {
    final d = randomMatrix(n, rnd);
    TspResult? a, b;
    if (brute) {
      a = tspBruteForce(d);
      tb.add(a.micros);
    }
    if (heldKarp) {
      b = tspHeldKarp(d);
      th.add(b.micros);
    }
    if (a != null && b != null) same = (same ?? true) && a.cost == b.cost && tourCost(d, b.tour) == b.cost;
  }
  int? median(List<int> l) {
    if (l.isEmpty) return null;
    l.sort();
    return l[l.length ~/ 2];
  }

  return BenchRow(n, median(tb), median(th), same, instances);
}

/// Execute le calcul dans un isolate (l'interface reste fluide).
/// [method] : 0 = enumeration DFS, 1 = enumeration BFS, 2 = Held-Karp.
Future<TspResult> tspInIsolate(List<List<int>> d, {required int method}) {
  final copy = [for (final r in d) List<int>.from(r)];
  return Isolate.run(() => switch (method) {
        0 => tspBruteForce(copy),
        1 => tspBruteForceBfs(copy),
        _ => tspHeldKarp(copy),
      });
}

/// Execution tracee dans un isolate : retourne le resultat et la trace.
Future<(TspResult, Trace)> tspTracedInIsolate(List<List<int>> d, {required int method, int cap = 20000}) {
  final copy = [for (final r in d) List<int>.from(r)];
  return Isolate.run(() {
    final t = Trace(cap: cap);
    final r = switch (method) {
      0 => tspBruteForce(copy, trace: t),
      1 => tspBruteForceBfs(copy, trace: t),
      _ => tspHeldKarp(copy, trace: t),
    };
    return (r, t);
  });
}
