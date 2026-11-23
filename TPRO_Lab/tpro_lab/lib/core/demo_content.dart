/// Tous les textes de la demonstration : pseudo-codes, scripts, questions/reponses,
/// enonces, exemples. Dart pur : modifiez ce fichier pour adapter votre discours sans
/// toucher au code de l'interface.
library;

import 'dart:math';

/// Morceau d'enonce. Si [req] est renseigne, la phrase est une exigence cliquable :
/// l'interface met en evidence l'element qui y repond.
class Seg {
  final String text;
  final String? req;
  const Seg(this.text, [this.req]);
}

class QA {
  final String q, a;
  const QA(this.q, this.a);
}

class Scenario {
  final String title, detail;
  const Scenario(this.title, this.detail);
}

/// Exigence de l'enonce, cochee automatiquement quand elle a ete montree.
class CheckItem {
  final String id, label;
  const CheckItem(this.id, this.label);
}

class LabContent {
  final String tag, title, subtitle, source, algos;
  final int minutes;

  /// Enonce officiel (anglais), par paragraphes, et sa traduction francaise.
  final List<List<Seg>> statement;
  final List<String> statementFr;
  final List<String> script;
  final List<Scenario> scenarios;
  final List<String> complexity;
  final List<QA> qa;
  final List<String> pitfalls;
  final List<CheckItem> checklist;
  const LabContent({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.source,
    required this.algos,
    required this.minutes,
    required this.statement,
    required this.statementFr,
    required this.script,
    required this.scenarios,
    required this.complexity,
    required this.qa,
    required this.pitfalls,
    required this.checklist,
  });
}

// =====================================================================================
// Pseudo-codes (identiques a ceux du cours). Step.line est le numero de ligne, a partir de 1.
// =====================================================================================

const List<String> kCyclePseudo = [
  'best ← ∞',
  'pour chaque sommet s de V',
  '    pour chaque v : dist[v] ← -1, parent[v] ← nil',
  '    dist[s] ← 0 ; enfiler(Q, s)',
  '    tant que Q n\'est pas vide',
  '        u ← défiler(Q)',
  '        pour chaque voisin v de u',
  '            si dist[v] = -1                    // arête d\'arbre',
  '                dist[v] ← dist[u]+1 ; parent[v] ← u ; enfiler(Q, v)',
  '            sinon si v ≠ parent[u]   // arête hors arbre : cycle',
  '                best ← min(best, dist[u] + dist[v] + 1)',
  'retourner best (et le cycle)',
];

const List<String> kEnumPseudo = [
  'best ← ∞',
  'énumérer chaque ordre des villes 1..n-1 (ville 0 fixée au départ)',
  '    coût ← d(0, p1) + d(p1, p2) + … + d(p_{n-1}, 0)',
  '    si coût < best : best ← coût ; meilleureTournée ← cet ordre',
  'retourner best, meilleureTournée',
];

const List<String> kHkPseudo = [
  'pour j ← 1 à n-1 :  C({0,j}, j) ← d(0, j)   // initialisation',
  'pour taille ← 3 à n   // boucle 1 : taille de S',
  '    pour chaque S de cette taille contenant 0   // boucle 2 : sous-ensembles',
  '        pour chaque j dans S, j ≠ 0   // boucle 3 : dernière ville',
  '            C(S, j) ← min sur i dans S, i ≠ 0, i ≠ j   // boucle 4 : avant-dernière ville',
  '                        de C(S−{j}, i) + d(i, j)',
  'retourner min sur j ≠ 0 de C({0..n-1}, j) + d(j, 0)',
];

const List<String> kTttPseudo = [
  'fonction alphabeta(nœud, profondeur, α, β, maximisant)',
  '    si profondeur = 0 ou nœud terminal : retourner estimation(nœud)',
  '    si maximisant',
  '        v ← -∞',
  '        pour chaque fils c (les meilleurs d\'abord)',
  '            v ← max(v, alphabeta(c, profondeur-1, α, β, faux))',
  '            α ← max(α, v)',
  '            si α ≥ β : arrêter   // coupe β',
  '        retourner v',
  '    sinon',
  '        v ← +∞',
  '        pour chaque fils c',
  '            v ← min(v, alphabeta(c, profondeur-1, α, β, vrai))',
  '            β ← min(β, v)',
  '            si α ≥ β : arrêter   // coupe α',
  '        retourner v',
  'fonction meilleurCoup(position, HMAX, TMO)   // approfondissement itératif',
  '    armer l\'alarme pour TMO (moins une marge de sécurité)',
  '    best ← un coup légal (ne jamais répondre rien)',
  '    pour profondeur ← 1 à HMAX',
  '        résultat ← recherche à cette profondeur',
  '        si l\'alarme a sonné : arrêter, garder le best précédent',
  '        best ← résultat',
  '    retourner best',
];

const List<String> kAStarPseudo = [
  'ouverts ← {départ}  avec f(départ) = g + p·h   // p = 1 → A*, p > 1 → WA*',
  'fermés ← ∅',
  'tant que ouverts n\'est pas vide',
  '    x ← extraire de ouverts le nœud de f minimal',
  '    si x = but : retourner le chemin',
  '    ajouter x à fermés',
  '    pour chaque voisin y de x (déplacer la case vide)',
  '        g\' ← g(x) + 1',
  '        si y jamais vu, ou g\' < g(y)',
  '            g(y) ← g\' ; parent(y) ← x ; f(y) ← g\' + p·h(y)',
  '            insérer y dans ouverts',
  'retourner échec',
];

// =====================================================================================
// TP 1 - Plus petit cycle
// =====================================================================================

const LabContent kCycleLab = LabContent(
  tag: 'TP 1',
  title: 'Plus petit cycle',
  subtitle: 'Graphe non orienté · un BFS depuis chaque sommet',
  source: 'T2 — Exercice 6',
  algos: 'BFS depuis chaque sommet — O(V·(V+E))',
  minutes: 3,
  statement: [
    [Seg('Exercise 6 — The shortest cycle in an undirected graph: This is a graded practical assignment')],
    [
      Seg('Write a program that determines and returns the shortest cycle in an undirected graph G=(V,E).', 'result'),
      Seg(' '),
      Seg('You may choose how to represent the graph.', 'repr'),
      Seg(' '),
      Seg('State the algorithm\'s complexity.', 'complexity'),
      Seg(' '),
      Seg('To do this, use a BFS (as covered in class) starting from each vertex of the graph.', 'bfs_each'),
    ],
  ],
  statementFr: [
    'Exercice 6 — Le plus court cycle dans un graphe non orienté : ceci est un TP noté.',
    'Écrire un programme qui détermine et retourne le plus court cycle d\'un graphe non orienté G=(V,E). '
        'Vous pouvez choisir la représentation du graphe. Donner la complexité de l\'algorithme. '
        'Pour cela, utiliser un BFS (vu en cours) à partir de chaque sommet du graphe.',
  ],
  script: [
    'Le graphe est non orienté et représenté par des listes d\'adjacence.',
    'Pour chaque sommet s, je lance un parcours en largeur qui calcule dist[] et parent[].',
    'Pendant le BFS, une arête vers un sommet déjà visité qui n\'est pas le parent ferme un cycle de longueur dist[u] + dist[v] + 1.',
    'Je garde le minimum sur toutes les arêtes et sur toutes les sources.',
    'Un seul BFS ne suffit pas : il peut surestimer un cycle qui ne passe pas par sa source. Le BFS lancé depuis un sommet du plus petit cycle trouve exactement sa longueur.',
    'Le cycle lui-même est reconstruit en remontant parent[] depuis u et v jusqu\'à leur ancêtre commun.',
    'Complexité : V parcours en O(V+E), donc O(V·(V+E)).',
  ],
  scenarios: [
    Scenario('Triangle dans un graphe', 'Charger l\'exemple puis avancer lentement dans le premier BFS : file, dist[], parent[], première arête hors arbre.'),
    Scenario('Graphe de Petersen', 'Lecture rapide (16×) : le plus petit cycle vaut 5.'),
    Scenario('Arbre', 'Aucune arête hors arbre : « aucun cycle (le graphe est une forêt) ».'),
    Scenario('Graphe du professeur', 'Scène vide : dessiner le graphe à la main (clic = sommet, glisser = arête) puis lancer.'),
  ],
  complexity: [
    'Un BFS visite chaque sommet une fois et examine chaque arête deux fois : O(V + E).',
    'On en lance un par sommet : O(V·(V + E)).',
    'Graphe connexe : E ≥ V−1 donc O(V·E). Graphe dense : E ≈ V², donc O(V³).',
    'Mémoire : O(V + E) pour les listes d\'adjacence, O(V) pour dist[], parent[] et la file.',
  ],
  qa: [
    QA('Pourquoi pas un DFS ?', 'Un DFS trouve un cycle, pas le plus court : la profondeur à laquelle il referme une arête ne dit rien de la longueur minimale. Le BFS donne des distances minimales depuis la source.'),
    QA('Pourquoi le test v ≠ parent[u] ?', 'Dans un graphe non orienté, l\'arête qui ramène au parent est celle par laquelle on est arrivé. Sans ce test, chaque arête serait comptée comme un « cycle » de longueur 2.'),
    QA('Pourquoi un seul BFS peut-il se tromper ?', 'dist[u] + dist[v] + 1 est la longueur d\'un parcours fermé passant par la source. Si les deux chemins se rejoignent avant la source, le vrai cycle est plus court et ne passe pas par la source. Le minimum sur toutes les sources est exact, car le BFS lancé sur un sommet du plus petit cycle le mesure exactement.'),
    QA('Et si le graphe n\'est pas connexe ?', 'Aucun problème : chaque sommet sert de source, donc chaque composante est explorée. On garde le plus petit cycle de toutes les composantes.'),
    QA('Complexité avec une matrice d\'adjacence ?', 'Chaque BFS coûte O(V²) (il faut balayer une ligne par sommet), donc O(V³) au total, même si le graphe est creux.'),
    QA('Est-ce que cela marche sur un graphe orienté ?', 'Non, pas tel quel : le test du parent n\'a plus de sens et la formule change. En orienté, on cherche pour chaque source s le plus court chemin qui revient vers s.'),
    QA('À quoi sert la coupe optionnelle ?', 'Si 2·dist[u] + 1 ≥ best, plus aucun cycle fermé depuis u ne peut améliorer best : on arrête ce BFS. Le résultat ne change pas, on gagne seulement du temps.'),
  ],
  pitfalls: [
    'Ne pas dire « le BFS trouve le plus court cycle » : c\'est le minimum sur tous les BFS qui est exact.',
    'Chaque arête hors arbre est vue deux fois (depuis u puis depuis v) : c\'est normal.',
    'Supprimer un sommet renumérote les suivants : vérifier les numéros avant de commenter.',
  ],
  checklist: [
    CheckItem('repr', 'Représentation du graphe annoncée (listes d\'adjacence)'),
    CheckItem('bfs_each', 'BFS lancé depuis chaque sommet'),
    CheckItem('result', 'Plus petit cycle déterminé et retourné'),
    CheckItem('complexity', 'Complexité annoncée : O(V·(V+E))'),
    CheckItem('nocycle', 'Cas sans cycle montré (forêt)'),
  ],
);

/// Exemple de graphe : positions normalisees (0..1) et aretes.
class GraphPreset {
  final String name;
  final List<List<double>> pos;
  final List<List<int>> edges;
  const GraphPreset(this.name, this.pos, this.edges);
}

List<List<double>> _circle(int n, {double cx = 0.5, double cy = 0.5, double r = 0.38, double phase = -pi / 2}) => [
      for (var i = 0; i < n; i++) [cx + r * cos(phase + 2 * pi * i / n), cy + r * sin(phase + 2 * pi * i / n)]
    ];

final List<GraphPreset> kGraphPresets = [
  const GraphPreset('Triangle', [
    [0.12, 0.50], [0.30, 0.22], [0.30, 0.78], [0.50, 0.50], [0.70, 0.25], [0.70, 0.75], [0.90, 0.50], [0.50, 0.12],
  ], [
    [0, 1], [0, 2], [1, 3], [2, 3], [3, 4], [3, 5], [4, 5], [4, 6], [5, 6], [1, 7], [7, 4],
  ]),
  const GraphPreset('Carré', [
    [0.3, 0.25], [0.7, 0.25], [0.7, 0.75], [0.3, 0.75],
  ], [
    [0, 1], [1, 2], [2, 3], [3, 0],
  ]),
  GraphPreset('Petersen', [
    ..._circle(5, r: 0.42),
    ..._circle(5, r: 0.20),
  ], [
    [0, 1], [1, 2], [2, 3], [3, 4], [4, 0],
    [0, 5], [1, 6], [2, 7], [3, 8], [4, 9],
    [5, 7], [7, 9], [9, 6], [6, 8], [8, 5],
  ]),
  const GraphPreset('Arbre', [
    [0.5, 0.12], [0.28, 0.38], [0.72, 0.38], [0.14, 0.66], [0.38, 0.66], [0.62, 0.66], [0.86, 0.66], [0.08, 0.9], [0.22, 0.9], [0.62, 0.9],
  ], [
    [0, 1], [0, 2], [1, 3], [1, 4], [2, 5], [2, 6], [3, 7], [3, 8], [5, 9],
  ]),
  GraphPreset('2 composantes', [
    ..._circle(5, cx: 0.27, r: 0.2),
    ..._circle(3, cx: 0.73, r: 0.2),
    [0.73, 0.85],
  ], [
    [0, 1], [1, 2], [2, 3], [3, 4], [4, 0],
    [5, 6], [6, 7], [7, 5], [7, 8],
  ]),
  GraphPreset('Cycle C₈', _circle(8), [
    for (var i = 0; i < 8; i++) [i, (i + 1) % 8]
  ]),
  GraphPreset('Complet K₅', _circle(5), [
    for (var i = 0; i < 5; i++)
      for (var j = i + 1; j < 5; j++) [i, j]
  ]),
  GraphPreset('Grille 4×4', [
    for (var r = 0; r < 4; r++)
      for (var c = 0; c < 4; c++) [0.2 + 0.2 * c, 0.14 + 0.24 * r]
  ], [
    for (var r = 0; r < 4; r++)
      for (var c = 0; c < 4; c++) ...[
        if (c < 3) [r * 4 + c, r * 4 + c + 1],
        if (r < 3) [r * 4 + c, (r + 1) * 4 + c],
      ]
  ]),
];

// =====================================================================================
// TP 2 - Voyageur de commerce
// =====================================================================================

const LabContent kTspLab = LabContent(
  tag: 'TP 2',
  title: 'Voyageur de commerce',
  subtitle: 'Énumération exacte O(n!) contre Bellman-Held-Karp O(n²·2ⁿ)',
  source: 'T3 — Exercice 6',
  algos: 'Énumération O(n!) vs Bellman-Held-Karp O(n²·2ⁿ)',
  minutes: 4,
  statement: [
    [Seg('Exercise 6 — PVC with dynamic programming: this is a graded practical assignment.')],
    [
      Seg('Consider the Traveling Salesman Problem (TSP), defined as follows: We have a set of n cities, all of which are connected to one another (forming a complete graph), with a defined distance between every pair of cities. '
          'A traveling salesman wishes to perform the following task: starting from a given city A, he must visit every city—traveling from one to another—and finally return to the starting city, all while minimizing the total distance traveled. '
          'In graph-theoretic terms, this is equivalent to finding a Hamiltonian cycle of minimum length. This is a difficult problem—specifically, it is NP-complete. '),
      Seg('For n=6, we have the following graph: [figure in the sheet]', 'n6'),
    ],
    [
      Seg('You are therefore asked to do the following: '),
      Seg('implement the Traveling Salesman Problem (TSP) using an exact method (an algorithm with a complexity of n!)', 'enum'),
      Seg(' and '),
      Seg('by using the Bellman-Held–Karp algorithm, which employs dynamic programming to achieve a complexity of O(n² 2ⁿ)', 'hk'),
      Seg('—still exponential, but significantly better than n!. '),
      Seg('For the exact method: enumerate all Hamiltonian cycles (for example, using BFS), calculate the cost of each cycle, and select the minimum.', 'enum'),
      Seg(' '),
      Seg('For n=6, you have the following graph: [figure in the sheet]', 'n6'),
    ],
    [
      Seg('The Bellman-Held–Karp algorithm employs dynamic programming to achieve a more efficient approach—though still exponential, with a complexity of n² 2ⁿ, which is better than n!. The algorithm is based on the following concept:'),
    ],
    [Seg('• Calculate the minimum cost to reach a subset of cities, ending at a specific city.')],
    [Seg('• Use previously computed results to incrementally construct the optimal solution.')],
    [
      Seg('For a general case with n cities, we label the cities from 0 to n-1. We assume that the route always begins at city 0. '
          'Let C(S, j) be the minimum cost to reach a subset of cities S (which includes city j), ending at city j, starting from city 0.'),
    ],
    [Seg('C(S, j) = min over i∈S, i≠j of [ C(S−{j}, i) + d(i, j) ]', 'hk')],
    [Seg('• d(i, j) is the distance from city i to city j.')],
    [
      Seg('• In other words: to reach city j coming from a set of cities S, we consider the best path from city 0 to each city i in the set S−{j}, and then add the cost of traveling from i to j.'),
    ],
    [Seg('With the following initializations: For each city j ≠ 0: C({0, j}, j) = d(0, j)')],
    [Seg('The final solution to the TSP (a complete cycle) is: min over j≠0 of [ C({0, ..., n−1}, j) + d(j, 0) ]')],
    [
      Seg('We are looking for the shortest path that visits all cities, ends at city j, and then returns to city 0. The algorithm that implements these recurrence equations has a time complexity of O(2ⁿ · n²). '),
      Seg('It consists of four nested loops, along with the initial setup steps. It is up to you to determine the bounds for these loops.', 'loops'),
    ],
    [
      Seg('After implementing both methods, perform tests using various values of n and compare their execution times; present your results in a table.', 'bench'),
    ],
  ],
  statementFr: [
    'Exercice 6 — PVC par programmation dynamique : ceci est un TP noté.',
    'On considère le problème du voyageur de commerce (PVC) : n villes toutes reliées entre elles (graphe complet), avec une distance définie entre chaque paire de villes. '
        'Le voyageur part d\'une ville A, doit visiter toutes les villes puis revenir à la ville de départ, en minimisant la distance totale. '
        'En termes de graphes : trouver un cycle hamiltonien de longueur minimale. C\'est un problème difficile (NP-complet). Pour n=6, on a le graphe de la feuille de TD.',
    'Il est demandé d\'implémenter le PVC par une méthode exacte (complexité n!) et par l\'algorithme de Bellman-Held-Karp, qui utilise la programmation dynamique pour atteindre O(n² 2ⁿ) — toujours exponentiel, mais bien meilleur que n!. '
        'Pour la méthode exacte : énumérer tous les cycles hamiltoniens (par exemple avec un BFS), calculer le coût de chaque cycle et retenir le minimum.',
    'Bellman-Held-Karp : calculer le coût minimal pour atteindre un sous-ensemble de villes en terminant sur une ville donnée, et réutiliser les résultats déjà calculés pour construire la solution optimale.',
    'Les villes sont numérotées de 0 à n−1 et la tournée commence toujours en 0. C(S, j) est le coût minimal pour visiter le sous-ensemble S (contenant j) en partant de 0 et en finissant en j : '
        'C(S, j) = min sur i∈S, i≠j de [ C(S−{j}, i) + d(i, j) ], avec C({0, j}, j) = d(0, j). '
        'La solution finale est min sur j≠0 de [ C({0..n−1}, j) + d(j, 0) ].',
    'L\'algorithme a une complexité O(2ⁿ · n²). Il comporte quatre boucles imbriquées en plus de l\'initialisation ; à vous d\'en déterminer les bornes.',
    'Après avoir implémenté les deux méthodes, faire des tests pour différentes valeurs de n, comparer les temps d\'exécution et présenter les résultats dans un tableau.',
  ],
  script: [
    'Le problème : partir de la ville 0, visiter chaque ville une fois, revenir en 0, avec une distance totale minimale.',
    'Méthode 1 : j\'énumère tous les cycles hamiltoniens. La ville 0 est fixée, il reste (n−1)! ordres possibles ; je calcule le coût de chacun et je garde le minimum.',
    'Deux styles d\'énumération donnent le même résultat : un BFS sur une file de chemins partiels, comme le suggère l\'énoncé, ou un DFS par permutations qui ne consomme que O(n) mémoire.',
    'Méthode 2, Bellman-Held-Karp : C(S, j) est le coût minimal pour partir de 0, visiter exactement S et finir en j.',
    'Récurrence : C(S, j) = min sur i de C(S−{j}, i) + d(i, j). Quatre boucles : la taille de S, les sous-ensembles S, la dernière ville j, l\'avant-dernière ville i.',
    'L\'idée : un chemin est résumé par (ensemble visité, dernière ville). L\'ordre à l\'intérieur de l\'ensemble n\'a plus d\'importance, on passe de n! à n²·2ⁿ.',
    'Les deux méthodes sont exactes : elles donnent toujours le même coût optimal. Le banc d\'essai le vérifie et montre l\'écart des temps.',
  ],
  scenarios: [
    Scenario('Matrice n = 6 : les deux méthodes', 'Charge l\'instance à 6 villes (saisir d\'abord la matrice du professeur si besoin), lance l\'énumération : 120 cycles. Lancer ensuite Held-Karp : même coût, même tournée.'),
    Scenario('Held-Karp pas à pas, n = 4', 'Petite instance pour expliquer la récurrence : chaque étape affiche C(S, j) avec les vraies valeurs.'),
    Scenario('Banc d\'essai', 'Ouvre le tableau des temps et lance la comparaison de n = 4 à 20. Commenter la courbe en échelle logarithmique.'),
    Scenario('n = 18 avec Held-Karp seul', '17! ≈ 3,6·10¹⁴ cycles pour l\'énumération : impossible. Held-Karp répond en moins d\'une seconde.'),
  ],
  complexity: [
    'Énumération : (n−1)! cycles, chacun de coût O(n) à évaluer → O(n!). Mémoire O(n) en DFS, jusqu\'à (n−1)! chemins dans la file en BFS.',
    'Held-Karp : 2ⁿ⁻¹ sous-ensembles × (n−1) dernières villes × (n−1) avant-dernières villes → O(n²·2ⁿ).',
    'Mémoire de Held-Karp : une case par couple (S, j), soit O(n·2ⁿ). C\'est elle qui limite n (≈ 50 Mo pour n = 20).',
    'Les deux sont exponentiels, mais pour n = 12 : 11! ≈ 4·10⁷ contre 12²·2¹² ≈ 6·10⁵.',
  ],
  qa: [
    QA('Pourquoi (n−1)! et pas n! ?', 'Un cycle n\'a pas de début : fixer la ville 0 au départ supprime les n rotations du même cycle. Il reste (n−1)! ordres, chacun de coût O(n) → O(n!).'),
    QA('Pourquoi est-ce encore exponentiel ?', 'Il y a 2ⁿ⁻¹ sous-ensembles de villes à considérer et on ne connaît pas mieux : le problème est NP-difficile. On a seulement remplacé n! par 2ⁿ.'),
    QA('Pourquoi la ville 0 reste-t-elle fixe ?', 'Tout cycle hamiltonien passe par 0 : on peut donc toujours le lire en partant de 0 sans perdre de solution.'),
    QA('Que contient C(S, j) ?', 'Le coût minimal d\'un chemin qui part de 0, visite exactement les villes de S une fois chacune et se termine en j.'),
    QA('Comment la tournée est-elle reconstruite ?', 'À chaque case C(S, j) on mémorise la ville i qui a donné le minimum. On part de la meilleure dernière ville, puis on remonte : (S, j) → (S−{j}, i), jusqu\'à l\'ensemble {0}.'),
    QA('Quelles sont les bornes des quatre boucles ?', 'Boucle 1 : taille de S de 3 à n. Boucle 2 : les C(n−1, taille−1) sous-ensembles de cette taille contenant 0. Boucle 3 : j dans S, j ≠ 0. Boucle 4 : i dans S, i ≠ 0, i ≠ j.'),
    QA('Quel est le coût mémoire, et qu\'est-ce qui manque en premier ?', 'O(n·2ⁿ) cases. Pour Held-Karp c\'est la mémoire qui manque en premier (vers n ≈ 25) ; pour l\'énumération c\'est le temps (vers n ≈ 13).'),
    QA('Le résultat est-il exact ou approché ?', 'Exact pour les deux méthodes : elles renvoient toujours le même coût optimal. Le tableau le vérifie ligne par ligne.'),
    QA('Que change une matrice asymétrique ?', 'Rien pour Held-Karp : la récurrence utilise d(i, j) orienté. Pour l\'énumération, on ne peut plus diviser le travail par deux en ignorant le sens de parcours.'),
  ],
  pitfalls: [
    'Saisir la matrice du professeur avant la démonstration et vérifier la symétrie.',
    'Ne pas lancer l\'énumération animée au-delà de n = 11 : (n−1)! étapes.',
    'Les temps du tableau viennent d\'exécutions sans trace ; l\'animation est volontairement lente.',
  ],
  checklist: [
    CheckItem('n6', 'Instance n = 6 traitée'),
    CheckItem('enum', 'Méthode exacte : tous les cycles hamiltoniens énumérés, minimum retenu'),
    CheckItem('hk', 'Bellman-Held-Karp exécuté (même coût optimal)'),
    CheckItem('loops', 'Les quatre boucles et leurs bornes montrées'),
    CheckItem('bench', 'Tests pour plusieurs n : tableau des temps'),
  ],
);

/// Instance par defaut a 6 villes (a remplacer par la matrice du professeur).
const List<List<int>> kTspDefault6 = [
  [0, 10, 15, 20, 12, 18],
  [10, 0, 35, 25, 17, 9],
  [15, 35, 0, 30, 14, 22],
  [20, 25, 30, 0, 16, 11],
  [12, 17, 14, 16, 0, 13],
  [18, 9, 22, 11, 13, 0],
];

const List<List<int>> kTspDemo4 = [
  [0, 10, 15, 20],
  [10, 0, 35, 25],
  [15, 35, 0, 30],
  [20, 25, 30, 0],
];

// =====================================================================================
// TP 3 - Morpion N x N
// =====================================================================================

const LabContent kTttLab = LabContent(
  tag: 'TP 3',
  title: 'Morpion N×N',
  subtitle: 'Fonction d\'estimation · alpha-bêta · approfondissement itératif · alarme · client TCP',
  source: 'T4 — Exercice 6',
  algos: 'MinMax + alpha-bêta + approfondissement itératif + délai, client TCP',
  minutes: 6,
  statement: [
    [Seg('Exercise 6 — The estimation function in Tic-Tac-Toe and alarms: This is a graded practical assignment.')],
    [
      Seg('In the two programs I sent you—which were developed by Mr. Hidouci—two clients play Tic-Tac-Toe via a server, using the Minimax algorithm. Here is a description of how everything works:'),
    ],
    [
      Seg('In this practical assignment, you are asked to '),
      Seg('program a client (including an estimation function and alarm mechanisms', 'estim'),
      Seg('—the specific requirements are detailed in the two C files I have provided; you are free to use any programming language you prefer) capable of playing a specific version of Tic-Tac-Toe on an N X N grid against an opponent (who is also a client program developed by another student). '),
      Seg('The objective in this N X N Tic-Tac-Toe game is to align M symbols (\'X\' or \'O\') in any of the 8 possible directions (N, NE, E, SE, S, SW, W, and NW), where M <= N.', 'align'),
      Seg(' '),
      Seg('Each player has a maximum of TMO seconds to make their move.', 'alarm'),
    ],
    [
      Seg('N, M, and TMO are parameters set by the server program at the beginning of each game. At the end of the tournament, points are tallied to determine the final grades for the assignment (e.g., 0 points for a loss, 1 point for a draw, and 2 points for a win).'),
    ],
    [
      Seg('Communication between the server and the clients follows the protocol outlined below (using TCP sockets; all messages are sent as character strings terminated by a newline character, `\\n`):', 'net'),
    ],
    [Seg('- Once launched, the server opens a TCP socket on port 12345 and listens for connections from two clients.')],
    [Seg('- As soon as a client connects to the server, it must send a character string representing the player\'s name.')],
    [Seg('- The server waits until both clients have connected and submitted their respective names.')],
    [
      Seg('- Once both clients have connected (and their names have been sent), the server responds by sending the game parameters to each client: N, M, TMO, and the symbol \'X\' or \'O\' (the first client to connect is assigned \'X\', and the second is assigned \'O\'). '
          'For example, the response to the first client might be "7 4 5 X," meaning N=7, M=4, and TMO=5 seconds; the client receiving this message is designated as player \'X\'.'),
    ],
    [Seg('- Player \'X\' moves first, and therefore has TMO seconds to send their initial move to the server.')],
    [Seg('- The second client (\'O\') waits for the next prompt from the server before beginning their turn.')],
    [
      Seg('- If the server does not receive a legal move from the active client within the TMO-second time limit, the game ends, and the opposing player is declared the winner.'),
    ],
    [
      Seg('- During the allotted time (TMO seconds), the client determines its best move—that is, the coordinates (i, j) where it will place its symbol on the N×N grid. Each client is free to use any method or estimation strategy it chooses. '),
      Seg('The essential requirement is that the client must respond to the server with a legal (i.e., valid) move before the TMO timeout expires.', 'alarm'),
    ],
    [
      Seg('- To place its symbol (\'X\' or \'O\') at position (i, j) on the grid, a client simply sends a string containing two integers—i and j, separated by a space and terminated by a newline character (\'\\n\')—to the server.'),
    ],
    [
      Seg('- When the server receives a response from a player (i.e., coordinates i and j), it verifies that the move is legal, then sends a prompt to the opposing player, informing them of the move that has just been made. '
          'For example, if player \'X\' places an \'X\' symbol at position (2, 3) and the move is legal, the server sends a prompt to player \'O\' in the format "X at 2 3". '
          'Player \'O\' then updates their local grid by placing an \'X\' at position (2, 3) and has TMO seconds to make their own move and respond to the server.'),
    ],
    [
      Seg('- The game continues in this alternating fashion until the server signals the end of the game (which occurs if a player takes too long to respond, makes an illegal move, or if the game reaches a terminal state).'),
    ],
    [
      Seg('- The end-of-game message consists of the string "gameover cost = val", where \'val\' is -1, 0, or 1. This message is sent to both clients. '
          'The value \'val\' is interpreted as follows: -1 means player \'X\' has lost (i.e., \'O\' has won), 0 means a draw, and 1 means player \'X\' has won (i.e., \'O\' has lost).'),
    ],
    [Seg('- The server then shuts down, terminating the connections to both clients.')],
    [
      Seg('The method used by this client to select the best move is "iterative deepening." Essentially, this involves running the minimax algorithm (with alpha-beta pruning) multiple times—redundantly—with progressively increasing search depths.', 'iter'),
      Seg(' '),
      Seg('This process continues until either a specified maximum depth (HMAX, defined at client startup) is reached or the designated timeout (TMO) expires. The best move identified up to that point is then sent by the client to the server.', 'hmax'),
    ],
    [
      Seg('To implement the timeout, I utilized alarms. The `alarm(x)` function sets an alarm for `x` seconds; once this duration elapses, a `SIGALRM` signal is sent to the process that initiated the alarm. '
          'By intercepting this `SIGALRM` signal using the `signal(...)` function, the search process can be halted at the point of interruption, compelling the client to respond to the server with the best move found prior to the timeout.', 'alarm'),
      Seg(' To run a demonstration, it is easiest to use 3 console (command-line) windows:'),
    ],
    [
      Seg('1) In the first window, launch the server program, specifying the game parameters in the command line. For example, for a 7x7 grid, a target of 4 in a row, and a 3-second timeout, you can use the following command: `server 7 4 3`'),
    ],
    [
      Seg('2) In the second window, launch the first client, specifying HMAX as a command-line argument. For example, for a maximum depth (HMAX) of 5 levels, you can use: `client 5`. '
          'The program will then prompt you to enter the client\'s name, followed by the server\'s IP address and port number (press Enter to keep the default values: 127.0.0.1 and 12345).'),
    ],
    [
      Seg('3) In the third window, launch the second client, specifying HMAX as a command-line argument. For example, for a maximum depth (HMAX) of 1 level (meaning the choice is guided solely by the estimation function), you can use: `client 1`. '
          'The program will again prompt you to enter the client\'s name, followed by the server\'s IP address and port number (press Enter to keep the default values: 127.0.0.1 and 12345).'),
    ],
    [Seg('The game grid is displayed in text format within the server window (the first window).')],
  ],
  statementFr: [
    'Exercice 6 — La fonction d\'estimation au morpion et les alarmes : ceci est un TP noté.',
    'Dans les deux programmes envoyés (développés par M. Hidouci), deux clients jouent au morpion à travers un serveur, avec l\'algorithme MinMax.',
    'Il est demandé de programmer un client (avec une fonction d\'estimation et un mécanisme d\'alarme ; langage libre) capable de jouer à un morpion sur une grille N×N contre un adversaire (le client d\'un autre étudiant). '
        'Le but est d\'aligner M symboles (« X » ou « O ») dans l\'une des 8 directions (N, NE, E, SE, S, SO, O, NO), avec M ≤ N. Chaque joueur dispose d\'au plus TMO secondes par coup.',
    'N, M et TMO sont fixés par le serveur au début de chaque partie. À la fin du tournoi, les points sont additionnés (par exemple 0 pour une défaite, 1 pour une nulle, 2 pour une victoire).',
    'Protocole (sockets TCP, messages texte terminés par « \\n ») : le serveur écoute sur le port 12345 et attend deux clients ; chaque client envoie d\'abord son nom ; '
        'le serveur répond « N M TMO X » au premier connecté et « N M TMO O » au second (exemple : « 7 4 5 X ») ; X joue en premier et a TMO secondes ; '
        'un coup s\'envoie sous la forme « i j » ; le serveur vérifie le coup puis prévient l\'adversaire par « X at 2 3 » ; '
        'sans coup légal dans le délai, la partie est perdue ; la fin de partie est annoncée par « gameover cost = val » (−1 : O gagne, 0 : nulle, 1 : X gagne), puis le serveur ferme les connexions.',
    'La méthode de choix du coup est l\'approfondissement itératif : on relance MinMax avec élagage alpha-bêta à des profondeurs croissantes, '
        'jusqu\'à la profondeur maximale HMAX (donnée au lancement du client) ou jusqu\'à l\'expiration du délai TMO. Le meilleur coup trouvé jusque-là est envoyé au serveur.',
    'Le délai est réalisé avec des alarmes : alarm(x) programme un signal SIGALRM dans x secondes ; en l\'interceptant avec signal(...), on arrête la recherche là où elle en est '
        'et le client répond avec le meilleur coup trouvé avant l\'interruption.',
    'Démonstration avec 3 consoles : (1) « server 7 4 3 » ; (2) « client 5 » (HMAX = 5), puis nom, adresse IP et port (Entrée pour garder 127.0.0.1 et 12345) ; '
        '(3) « client 1 » (HMAX = 1 : choix guidé par la seule fonction d\'estimation). La grille s\'affiche en texte dans la fenêtre du serveur.',
  ],
  script: [
    'Mon client joue au morpion N×N où il faut aligner M symboles ; il dialogue avec le serveur en TCP en suivant exactement le protocole de l\'énoncé.',
    'La fonction d\'estimation regarde toutes les fenêtres de M cases alignées, dans les 4 directions de ligne (ce qui couvre les 8 directions).',
    'Une fenêtre qui contient les deux symboles vaut 0. Une fenêtre avec k symboles d\'un seul joueur vaut poids(k), compté en plus pour X et en moins pour O. Les poids croissent géométriquement.',
    'La recherche est un MinMax avec élagage alpha-bêta : une branche est coupée dès que α ≥ β, car l\'adversaire ne laissera jamais y arriver.',
    'L\'approfondissement itératif relance la recherche aux profondeurs 1, 2, 3… jusqu\'à HMAX ou jusqu\'à l\'alarme.',
    'L\'alarme : en C, alarm(TMO) puis SIGALRM. Ici, une échéance vérifiée tous les mille nœuds lève une exception ; la boucle l\'attrape et renvoie le meilleur coup de la dernière profondeur terminée.',
    'Le coup envoyé est toujours légal : avant toute recherche, je retiens un coup valide, et je n\'utilise que 80 à 90 % de TMO pour garder une marge réseau.',
  ],
  scenarios: [
    Scenario('3×3 pas à pas', 'Position de milieu de partie, M = 3 : l\'arbre de recherche montre les valeurs MinMax, α/β sur chaque nœud et les branches coupées.'),
    Scenario('7×7, M = 4, TMO = 3 : HMAX 5 contre HMAX 1', 'Comme dans l\'énoncé : IA contre IA. Le client HMAX = 1 ne joue qu\'avec la fonction d\'estimation.'),
    Scenario('L\'alarme en action', 'TMO = 1 s et HMAX = 20 : l\'approfondissement est interrompu par l\'alarme, le tableau des itérations montre la profondeur abandonnée.'),
    Scenario('Sans tri des coups', 'Même position, tri désactivé : comparer le nombre de nœuds explorés et de coupes.'),
    Scenario('Réseau', 'Démonstration locale (serveur intégré) ou connexion au serveur du professeur : journal du protocole en direct.'),
  ],
  complexity: [
    'MinMax seul : O(b^d) nœuds pour un facteur de branchement b et une profondeur d.',
    'Alpha-bêta avec un tri parfait des coups : O(b^(d/2)) — on double la profondeur atteinte dans le même temps.',
    'Approfondissement itératif : le coût total est dominé par la dernière profondeur (somme géométrique), le surcoût est d\'environ 1/(b−1).',
    'Estimation en O(1) : le nombre de fenêtres ouvertes par joueur et par k est tenu à jour à chaque coup joué ou annulé.',
  ],
  qa: [
    QA('Que calcule votre fonction d\'estimation, et pourquoi ces poids ?', 'E = Σ poids(k) × (fenêtres de X avec k symboles − fenêtres de O avec k symboles), sur les fenêtres de M cases où un seul joueur est présent. Les poids sont géométriques (×6) pour qu\'une fenêtre presque complète pèse plus que plusieurs fenêtres peu avancées.'),
    QA('Pourquoi l\'approfondissement itératif si les recherches moins profondes sont jetées ?', 'Leur coût est faible devant la dernière profondeur. Elles garantissent un coup disponible à tout instant (indispensable avec le délai) et améliorent le tri des coups de la profondeur suivante.'),
    QA('Que se passe-t-il exactement quand l\'alarme sonne ?', 'La recherche en cours est abandonnée là où elle est (exception, l\'équivalent du handler de SIGALRM). La grille est remise en état, et on joue le meilleur coup de la dernière profondeur entièrement terminée.'),
    QA('Combien de nœuds alpha-bêta économise-t-il au mieux ?', 'Avec un tri parfait, environ la racine carrée : O(b^(d/2)) au lieu de O(b^d).'),
    QA('Pourquoi HMAX = 1 joue-t-il correctement ?', 'À profondeur 1, chaque coup est noté par la fonction d\'estimation, qui récompense déjà les alignements et pénalise ceux de l\'adversaire. Il ne voit simplement pas les menaces à deux coups.'),
    QA('Et si le délai expire avant la fin de la profondeur 1 ?', 'Avant toute recherche, un coup légal (le mieux classé par le tri) est retenu. On le joue : le client ne répond jamais « rien ».'),
    QA('Comment détecter M alignés dans 8 directions avec 4 balayages ?', 'Les directions vont par paires opposées (E/O, N/S, NE/SO, NO/SE). Une fenêtre de M cases parcourue vers l\'est est la même que parcourue vers l\'ouest : 4 directions suffisent.'),
    QA('Que signifie « gameover cost = -1 » pour le joueur O ?', 'Le coût est toujours donné du point de vue de X : −1 veut dire que X a perdu, donc que O a gagné.'),
    QA('Comment une nulle est-elle comptée dans le tournoi ?', '1 point pour chaque joueur (0 pour une défaite, 2 pour une victoire, selon l\'exemple de l\'énoncé).'),
  ],
  pitfalls: [
    'Vérifier la base des indices (0 ou 1) dans les fichiers C avant le tournoi, et régler « indices à partir de ».',
    'Ne jamais utiliser 100 % de TMO : garder la marge réseau (80 à 90 %).',
    'Le port 12345 peut être déjà pris par un autre serveur : fermer les anciennes consoles.',
  ],
  checklist: [
    CheckItem('estim', 'Fonction d\'estimation expliquée (tableau k / poids / fenêtres)'),
    CheckItem('align', 'Alignement de M symboles détecté (fin de partie)'),
    CheckItem('iter', 'Approfondissement itératif montré (tableau par profondeur)'),
    CheckItem('hmax', 'Deux profondeurs HMAX différentes comparées (IA contre IA)'),
    CheckItem('alarm', 'Alarme / délai TMO : recherche interrompue, coup légal joué'),
    CheckItem('net', 'Partie complète par le protocole TCP (journal)'),
  ],
);

/// Position 3 x 3 du scenario pas a pas : X en 4 et 1, O en 0 et 7 ; X joue.
const List<int> kTttDemoCells = [2, 1, 0, 0, 1, 0, 0, 2, 0];

// =====================================================================================
// TP 4 - Taquin
// =====================================================================================

const LabContent kPuzzleLab = LabContent(
  tag: 'TP 4',
  title: 'Taquin 15',
  subtitle: 'A* et WA* · tas contre file naïve · trois heuristiques',
  source: 'T5 — Exercice 5',
  algos: 'A*, WA*, tas vs file naïve, 3 heuristiques',
  minutes: 4,
  statement: [
    [Seg('Exercise 5 — The sliding puzzle (taquin): this is a graded practical assignment')],
    [
      Seg('This concerns the 15-puzzle (a 4x4 sliding tile puzzle) using the A* and WA* algorithms. The current version of the program includes an A* implementation for the 4x4 puzzle, featuring:'),
    ],
    [Seg('- A naive implementation of the priority queue (O(n) for removal, O(1) for insertion).', 'naive')],
    [Seg('- A heuristic function, h(x), defined as the number of tiles misplaced in configuration x relative to the goal configuration.', 'h1')],
    [Seg('Your tasks are as follows:')],
    [Seg('- Implement an efficient priority queue using a heap (O(log n) operations).', 'heap')],
    [
      Seg('- Add an alternative heuristic function based on the sum of the Manhattan distances of the misplaced tiles (you may also include other heuristics).', 'h2'),
    ],
    [Seg('- Implement WA* (where WA* is A* with the evaluation function f(x) = g(x) + p*h(x), with p > 1).', 'wastar')],
    [
      Seg('- Conduct tests—starting from various initial configurations of your choosing—to compare performance. Analyze the impact of using a heap, the choice of heuristic function, and the effect of the parameter p in WA*. '
          'Examples of metrics for your evaluation include execution time, the number of nodes explored, the maximum size of the exploration frontier, and the quality of the solution.', 'compare'),
    ],
  ],
  statementFr: [
    'Exercice 5 — Le taquin : ceci est un TP noté.',
    'Il s\'agit du taquin 4×4 (15-puzzle) avec les algorithmes A* et WA*. La version actuelle du programme contient un A* pour le taquin 4×4 avec : '
        'une file de priorité naïve (retrait en O(n), insertion en O(1)) et une heuristique h(x) égale au nombre de jetons mal placés par rapport au but.',
    'Travail demandé : implémenter une file de priorité efficace par un tas (opérations en O(log n)) ; '
        'ajouter une heuristique basée sur la somme des distances de Manhattan des jetons mal placés (d\'autres heuristiques sont possibles) ; '
        'implémenter WA* (A* avec f(x) = g(x) + p·h(x), p > 1).',
    'Faire des tests à partir de plusieurs configurations initiales pour comparer les performances : effet du tas, du choix de l\'heuristique et du paramètre p de WA*. '
        'Mesures possibles : temps d\'exécution, nombre de nœuds explorés, taille maximale de la frontière, qualité de la solution.',
  ],
  script: [
    'Un état du taquin est codé sur un entier de 64 bits, 4 bits par case : copier et comparer un état coûte une instruction.',
    'A* développe toujours l\'état de plus petit f = g + h : g est le nombre de coups déjà joués, h une estimation du reste.',
    'La file de priorité existe en deux versions derrière la même interface : la file naïve de l\'énoncé (retrait en O(n)) et mon tas binaire (insertion et retrait en O(log n)).',
    'Trois heuristiques : h1 jetons mal placés, h2 somme des distances de Manhattan, h3 Manhattan + conflits linéaires. Toutes sont admissibles et h1 ≤ h2 ≤ h3.',
    'WA* utilise f = g + p·h avec p > 1 : il fonce vers le but, explore moins de nœuds, mais la solution peut être plus longue — au plus p fois l\'optimum.',
    'Le tableau de comparaison mesure le temps, les nœuds explorés et générés, la taille maximale de la frontière et la longueur de la solution pour chaque variante.',
  ],
  scenarios: [
    Scenario('Puzzle facile, pas à pas, h2', 'Explique f = g + h : état extrait, voisins insérés ou ignorés, contenu du tas.'),
    Scenario('Puzzle moyen : h1 puis h2', 'Même configuration, comparer le nombre de nœuds explorés avec « mal placés » puis « Manhattan ».'),
    Scenario('Puzzle difficile : file naïve contre tas', 'Mêmes nœuds explorés, temps très différents.'),
    Scenario('WA* : p = 1, 2, 3', 'Moins de nœuds à mesure que p augmente, solution plus longue.'),
    Scenario('Tableau de comparaison', 'Lance toutes les variantes cochées sur la configuration courante, puis export CSV.'),
  ],
  complexity: [
    'A* : dans le pire cas exponentiel en la longueur de la solution ; le nombre de nœuds dépend de la qualité de h.',
    'File naïve : insertion O(1), extraction du minimum O(n) → une recherche de N extractions coûte O(N²).',
    'Tas binaire : insertion et extraction O(log n) → O(N log N). Le nombre de nœuds explorés ne change pas, seul le temps par opération change.',
    'Mémoire : tous les états générés sont conservés (frontière + fermés) ; c\'est la limite d\'A* sur le taquin 15.',
  ],
  qa: [
    QA('Pourquoi A* est-il optimal avec une heuristique admissible ?', 'Si h ne surestime jamais le coût restant, f ne surestime jamais le coût d\'une solution passant par l\'état. Quand le but sort de la file, tout autre chemin a un f au moins aussi grand : aucun ne peut être plus court.'),
    QA('Pourquoi Manhattan domine-t-elle « mal placés » ?', 'Un jeton mal placé est à une distance de Manhattan d\'au moins 1 : h2 ≥ h1 pour tout état. Plus h est proche du vrai coût (tout en restant admissible), moins A* explore de nœuds.'),
    QA('Pourquoi le tas ne change-t-il pas le nombre de nœuds explorés ?', 'Les deux files extraient le même état de f minimal (même règle de départage) : l\'ordre d\'exploration est identique. Seul le coût de chaque extraction change.'),
    QA('Quel est le coût d\'extraction du minimum dans chaque file ?', 'File naïve : O(n), il faut balayer tous les éléments. Tas : O(log n), la racine est le minimum et on répare le tas en descendant un seul chemin.'),
    QA('Que garantit WA* ?', 'Avec une heuristique admissible, la solution trouvée coûte au plus p fois l\'optimum. En pratique elle est souvent bien meilleure que cette borne.'),
    QA('Pourquoi la moitié des configurations sont-elles insolubles ?', 'Chaque déplacement conserve la parité de (inversions + ligne de la case vide). Les 16! configurations se séparent en deux classes de même taille ; seule celle du but est atteignable.'),
    QA('Différence entre « explorés » et « générés » ?', 'Un nœud est généré quand il est créé et inséré dans la frontière ; il est exploré (développé) quand il est extrait et que ses voisins sont générés. Générés ≥ explorés.'),
    QA('Qu\'est-ce qui limite A* sur le taquin 15 : le temps ou la mémoire ?', 'La mémoire : la frontière et l\'ensemble des fermés grossissent exponentiellement. C\'est pour cela qu\'on fixe une limite de nœuds.'),
    QA('Que changerait IDA* ?', 'IDA* fait des parcours en profondeur bornés par un seuil sur f qui augmente à chaque itération : mémoire linéaire, au prix de nœuds revisités. C\'est la méthode usuelle pour le taquin 15.'),
  ],
  pitfalls: [
    'Sur un puzzle difficile, h1 avec A* atteint la limite de nœuds : c\'est un résultat à commenter, pas un bug.',
    'Avec p > 1 la solution n\'est plus garantie optimale : le dire avant que le professeur ne le demande.',
    'Comparer les files sur la même configuration et la même heuristique, sinon les nœuds explorés diffèrent.',
  ],
  checklist: [
    CheckItem('heap', 'File de priorité par tas (O(log n)) utilisée'),
    CheckItem('naive', 'File naïve de l\'énoncé utilisée pour comparaison'),
    CheckItem('h2', 'Heuristique de Manhattan utilisée'),
    CheckItem('wastar', 'WA* exécuté avec p > 1'),
    CheckItem('compare', 'Tests comparatifs : tableau des mesures'),
  ],
);

/// Configuration de taquin fournie (0 = case vide), avec sa longueur optimale.
class PuzzlePreset {
  final String name;
  final int optimal;
  final List<int> tiles;
  const PuzzlePreset(this.name, this.optimal, this.tiles);
}

const List<PuzzlePreset> kPuzzlePresets = [
  PuzzlePreset('Facile', 10, [1, 6, 2, 4, 5, 3, 7, 8, 9, 10, 11, 12, 13, 0, 14, 15]),
  PuzzlePreset('Moyen', 25, [5, 0, 1, 3, 2, 14, 8, 11, 9, 7, 6, 4, 13, 10, 15, 12]),
  PuzzlePreset('Difficile', 40, [3, 1, 8, 10, 2, 7, 4, 12, 0, 5, 13, 15, 11, 6, 9, 14]),
];

/// Les quatre TP, dans l'ordre des onglets.
const List<LabContent> kLabs = [kCycleLab, kTspLab, kTttLab, kPuzzleLab];

/// Ordre conseille de la demonstration (indices dans [kLabs]).
const List<int> kDemoOrder = [0, 1, 3, 2];
