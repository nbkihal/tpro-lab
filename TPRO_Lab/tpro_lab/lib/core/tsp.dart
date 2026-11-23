/// TP2 (TD3 ex.6) - Voyageur de commerce.
/// 1) methode exacte par enumeration de tous les cycles hamiltoniens : O(n!)
/// 2) Bellman-Held-Karp (programmation dynamique) : O(n^2 2^n)
library;

import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

class TspResult {
  /// Villes dans l'ordre de visite, en partant de la ville 0 (le retour a 0 est implicite).
  final List<int> tour;
  final int cost;

  /// Enumeration : nombre de cycles evalues. Held-Karp : nombre de transitions C(S, j) calculees.
  final int ops;
  final int micros;
  const TspResult(this.tour, this.cost, this.ops, this.micros);
}

/// Enumeration exhaustive des (n-1)! permutations des villes 1..n-1.
TspResult tspBruteForce(List<List<int>> d) {
  final sw = Stopwatch()..start();
  final n = d.length;
  if (n == 1) return const TspResult([0], 0, 1, 0);
  final perm = List<int>.generate(n, (i) => i);
  var best = 1 << 62;
  var bestTour = List<int>.from(perm);
  var ops = 0;

  void rec(int k, int cost) {
    if (k == n) {
      ops++;
      final total = cost + d[perm[n - 1]][0];
      if (total < best) {
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
  return TspResult(bestTour, best, ops, sw.elapsedMicroseconds);
}

/// Bellman-Held-Karp.
/// C(S, j) = cout minimal d'un chemin partant de 0, visitant exactement S et finissant en j.
/// C({j}, j) = d(0, j) ;  C(S, j) = min_{i dans S, i != j} C(S - {j}, i) + d(i, j)
/// Reponse : min_j C(toutes, j) + d(j, 0).
/// S est code par un masque de bits sur les villes 1..n-1 (bit k = ville k+1).
TspResult tspHeldKarp(List<List<int>> d) {
  final sw = Stopwatch()..start();
  final n = d.length;
  if (n == 1) return const TspResult([0], 0, 1, 0);
  final m = n - 1;
  final full = (1 << m) - 1;
  const inf = 0x3fffffff;
  final dp = Int32List((1 << m) * m)..fillRange(0, (1 << m) * m, inf);
  final par = Uint8List((1 << m) * m);
  var ops = 0;

  for (var j = 0; j < m; j++) {
    dp[(1 << j) * m + j] = d[0][j + 1];
  }
  // Boucle 1 : les sous-ensembles (un masque plus petit est toujours traite avant).
  for (var mask = 1; mask <= full; mask++) {
    // Boucle 2 : la ville d'arrivee j dans S.
    for (var j = 0; j < m; j++) {
      if (mask & (1 << j) == 0) continue;
      final cur = dp[mask * m + j];
      if (cur >= inf) continue;
      // Boucle 3 : la ville suivante k hors de S.
      for (var k = 0; k < m; k++) {
        if (mask & (1 << k) != 0) continue;
        ops++;
        final nm = mask | (1 << k);
        final val = cur + d[j + 1][k + 1];
        if (val < dp[nm * m + k]) {
          dp[nm * m + k] = val;
          par[nm * m + k] = j;
        }
      }
    }
  }
  var best = 1 << 62;
  var last = 0;
  for (var j = 0; j < m; j++) {
    final val = dp[full * m + j] + d[j + 1][0];
    if (val < best) {
      best = val;
      last = j;
    }
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
  sw.stop();
  return TspResult([0, ...rev.reversed], best, ops, sw.elapsedMicroseconds);
}

List<List<int>> randomMatrix(int n, Random rnd, {int maxDist = 99}) {
  final d = List.generate(n, (_) => List<int>.filled(n, 0));
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      d[i][j] = d[j][i] = 1 + rnd.nextInt(maxDist);
    }
  }
  return d;
}

int tourCost(List<List<int>> d, List<int> tour) {
  var c = 0;
  for (var i = 0; i < tour.length; i++) {
    c += d[tour[i]][tour[(i + 1) % tour.length]];
  }
  return c;
}

/// Execute le calcul dans un isolate (l'interface reste fluide).
Future<TspResult> tspInIsolate(List<List<int>> d, {required bool heldKarp}) {
  final copy = [for (final r in d) List<int>.from(r)];
  return Isolate.run(() => heldKarp ? tspHeldKarp(copy) : tspBruteForce(copy));
}
