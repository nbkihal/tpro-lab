/// MinMax avec elagage alpha/beta + approfondissement iteratif ("iterative deepening")
/// borne par une profondeur maximale HMAX et par un delai (TMO).
///
/// Equivalent des alarmes du programme C :
///   alarm(TMO)  -> une echeance (chronometre consulte tous les ~1000 noeuds)
///   SIGALRM     -> une exception privee [_Timeout] levee au coeur de la recherche
///   le handler  -> la boucle d'approfondissement l'attrape et renvoie le meilleur coup
///                  de la derniere profondeur terminee
library;

import 'dart:isolate';
import 'dart:typed_data';

import 'trace.dart';
import 'ttt_board.dart';

const int kWin = 1000000000;

/// Accelerations de la recherche, chacune desactivable pour montrer son effet.
class EngineOptions {
  /// Tri des coups (les plus prometteurs d'abord) et largeur limitee.
  final bool ordering;

  /// Coups candidats restreints aux cases proches d'un pion (distance <= 2).
  final bool nearOnly;

  /// Table de transposition (hachage de Zobrist).
  final bool useTT;

  /// Detection du gain immediat et du blocage force.
  final bool tactics;
  const EngineOptions({this.ordering = true, this.nearOnly = true, this.useTT = true, this.tactics = true});
}

/// Bilan d'une iteration de l'approfondissement iteratif.
class IterInfo {
  final int depth, move, score, nodes, millis;

  /// false si l'iteration a ete interrompue par l'alarme.
  final bool completed;
  const IterInfo(this.depth, this.move, this.score, this.nodes, this.millis, this.completed);
}

class SearchResult {
  final int move; // case choisie (ligne * n + colonne), -1 si aucun coup
  final int score; // du point de vue du joueur qui cherche
  final int depth; // derniere profondeur terminee
  final int nodes;
  final int millis;

  /// Nombre de coupes alpha/beta et de reponses de la table de transposition.
  final int cuts, ttHits;

  /// true si l'alarme a interrompu la recherche.
  final bool timedOut;
  final List<IterInfo> iters;
  const SearchResult(this.move, this.score, this.depth, this.nodes, this.millis,
      {this.cuts = 0, this.ttHits = 0, this.timedOut = false, this.iters = const []});
}

/// Noeud de l'arbre de recherche enregistre pour l'affichage pas a pas.
class TreeNode {
  final int id, parent, move, player, ply;

  /// Rang de l'etape a laquelle le noeud apparait.
  final int born;

  /// Valeur (du point de vue de X) et rang de l'etape ou elle est connue (-1 : pas encore).
  int value = 0, valueAt = -1;

  /// Branche non exploree a cause d'une coupe ('coupe α' / 'coupe β'), sinon ''.
  final String pruned;

  /// 'feuille', 'terminal', 'TT' ou ''.
  String tag = '';
  final List<int> children = [];

  /// Historique des bornes (du point de vue de X) : [rang, alpha, beta].
  final List<List<int>> ab = [];
  TreeNode(this.id, this.parent, this.move, this.player, this.ply, this.born, {this.pruned = ''});
}

class SearchTree {
  final int depth;
  final List<TreeNode> nodes = [];
  SearchTree(this.depth);
}

/// Instantane d'une etape de la recherche.
class TttView {
  /// Coups joues hypothetiquement depuis la position reelle (le premier est joue par [rootPlayer]).
  final List<int> path;
  final int rootPlayer;

  /// Indice de l'arbre de l'iteration en cours et noeud courant (-1 si aucun).
  final int tree, node;
  final int depth, bestMove, nodes, cuts;
  const TttView(this.path, this.rootPlayer, this.tree, this.node, this.depth, this.bestMove, this.nodes, this.cuts);
}

String fmtScore(int v) {
  if (v >= kWin * 2) return '+∞';
  if (v <= -kWin * 2) return '−∞';
  if (v > kWin - 1000) return 'gain X';
  if (v < -kWin + 1000) return 'gain O';
  return '$v';
}

String cellName(Board b, int cell) => '(${cell ~/ b.n}, ${cell % b.n})';

class _Timeout {
  const _Timeout();
}

class Engine {
  static const int _ttBits = 18;
  static const int _ttMask = (1 << _ttBits) - 1;
  final Int64List _ttKey = Int64List(1 << _ttBits);
  final Int64List _ttVal = Int64List(1 << _ttBits);
  final Int8List _ttDepth = Int8List(1 << _ttBits);
  final Int8List _ttFlag = Int8List(1 << _ttBits); // 0 vide, 1 exact, 2 borne inf, 3 borne sup
  final Int16List _ttMove = Int16List(1 << _ttBits);

  late Board _b;
  late List<int> _w;
  final Stopwatch _clock = Stopwatch();
  int _budgetMs = 0;
  int nodes = 0, cuts = 0, ttHits = 0;
  EngineOptions _opt = const EngineOptions();

  /// Nombre maximal de coups examines par noeud (les plus prometteurs selon l'estimation).
  int rootWidth = 24, innerWidth = 12;

  // --- enregistrement pas a pas (inactif quand _tr est null)
  Trace? _tr;
  List<SearchTree>? _trees;
  SearchTree? _tree;
  final List<int> _stack = []; // identifiants des noeuds sur le chemin courant (-1 : non enregistre)
  final List<int> _path = [];
  int _rootPlayer = kX, _iterDepth = 0, _bestSoFar = -1;
  int treePly = 3, treeCap = 500;

  /// Approfondissement iteratif : profondeurs 1, 2, ... jusqu'a [hmax] ou jusqu'a l'echeance
  /// de [timeMs] millisecondes. Retourne toujours un coup legal s'il en existe un.
  SearchResult think(Board board, int player,
      {required int hmax, required int timeMs, EngineOptions options = const EngineOptions(), Trace? trace, List<SearchTree>? trees}) {
    _b = board;
    _w = Board.defaultWeights(board.m);
    _budgetMs = timeMs;
    _opt = options;
    _tr = trace;
    _trees = trees;
    _rootPlayer = player;
    nodes = 0;
    cuts = 0;
    ttHits = 0;
    _clock
      ..reset()
      ..start();
    final b = board;
    final who = player == kX ? 'X' : 'O';
    final iters = <IterInfo>[];

    trace?.step(18, 'On arme l\'alarme : la recherche doit s\'arrêter au plus tard dans $timeMs ms (TMO moins la marge de sécurité).',
        vars: {'joueur': who, 'HMAX': hmax, 'échéance (ms)': timeMs}, view: _view());
    var moves = _orderedMoves(player, -1, rootWidth);
    if (moves.isEmpty) return const SearchResult(-1, 0, 0, 0, 0);
    var best = moves.first, bestScore = 0, done = 0, timedOut = false;
    _bestSoFar = best;
    trace?.step(19, 'Avant toute recherche, on retient un coup légal : ${cellName(b, best)}. Même si l\'alarme sonne tout de suite, on aura quelque chose à répondre.',
        vars: {'joueur': who, 'best': cellName(b, best), 'coups candidats': moves.length}, view: _view());
    if (moves.length > 1) {
      var depth = 1;
      var nodes0 = 0, ms0 = 0;
      try {
        for (; depth <= hmax; depth++) {
          nodes0 = nodes;
          ms0 = _clock.elapsedMilliseconds;
          _iterDepth = depth;
          if (trace != null) {
            _tree = SearchTree(depth);
            trees?.add(_tree!);
            _stack.clear();
            _path.clear();
            trace.step(20, 'Approfondissement itératif : on relance alpha-bêta depuis la position actuelle, cette fois à la profondeur $depth.',
                vars: {'profondeur': depth, 'best': cellName(b, best), 'nœuds': nodes}, view: _view(), kind: StepKind.important);
          }
          var alpha = -kWin * 2;
          const beta = kWin * 2;
          var dBest = moves.first;
          final rootId = _enter(player, 0, -1, alpha, beta);
          if (trace != null) {
            trace.step(player == kX ? 3 : 10,
                'Racine : c\'est à $who de jouer, donc nœud ${player == kX ? "MAX" : "MIN"}. On essaie ses ${moves.length} coups, les plus prometteurs d\'abord.',
                vars: _vars(player, alpha, beta, null), view: _view());
          }
          for (final mv in moves) {
            _push(mv, player);
            final int v;
            try {
              v = -_search(3 - player, depth - 1, -beta, -alpha, 1, mv);
            } finally {
              _pop(mv, player);
            }
            final improved = v > alpha;
            if (improved) {
              alpha = v;
              dBest = mv;
            }
            if (trace != null) {
              _bounds(rootId, player, alpha, beta);
              final xv = player == kX ? v : -v;
              trace.step(player == kX ? 7 : 14,
                  'Le coup ${cellName(b, mv)} vaut ${fmtScore(xv)}. ${improved ? "C'est le meilleur coup de $who pour l'instant." : "Il ne fait pas mieux que le meilleur coup déjà trouvé."}',
                  vars: _vars(player, alpha, beta, alpha), view: _view());
            }
          }
          _leave(rootId, player, alpha);
          best = dBest;
          _bestSoFar = best;
          bestScore = alpha;
          done = depth;
          iters.add(IterInfo(depth, best, bestScore, nodes - nodes0, _clock.elapsedMilliseconds - ms0, true));
          trace?.step(23, 'La profondeur $depth est terminée : meilleur coup ${cellName(b, best)}, valeur ${fmtScore(player == kX ? alpha : -alpha)}. On le retient.',
              vars: {'profondeur': depth, 'best': cellName(b, best), 'valeur': fmtScore(player == kX ? alpha : -alpha), 'nœuds': nodes, 'coupes': cuts},
              view: _view(),
              kind: StepKind.found);
          // Le meilleur coup passe en tete pour la profondeur suivante.
          if (_opt.ordering) moves = [best, ...moves.where((x) => x != best)];
          if (alpha.abs() > kWin - 1000) break; // gain ou perte forces : inutile d'aller plus loin
        }
      } on _Timeout {
        // delai ecoule : on garde le meilleur coup de la derniere profondeur terminee
        timedOut = true;
        iters.add(IterInfo(depth, -1, 0, nodes - nodes0, _clock.elapsedMilliseconds - ms0, false));
        _stack.clear();
        _path.clear();
        trace?.step(22, 'L\'alarme a sonné pendant la profondeur $depth : on abandonne cette itération et on garde le coup de la profondeur $done.',
            vars: {'profondeur interrompue': depth, 'best': cellName(b, best)}, view: _view(), kind: StepKind.pruned);
      }
    }
    _clock.stop();
    trace?.step(24, 'On répond ${cellName(b, best)} : meilleur coup de la dernière profondeur terminée ($done).',
        vars: {'best': cellName(b, best), 'profondeur': done, 'nœuds': nodes, 'coupes': cuts}, view: _view(), kind: StepKind.done);
    _tr = null;
    _trees = null;
    _tree = null;
    return SearchResult(best, bestScore, done, nodes, _clock.elapsedMilliseconds, cuts: cuts, ttHits: ttHits, timedOut: timedOut, iters: iters);
  }

  // ------------------------------------------------------------ aides pour la trace

  TttView _view() => TttView(List<int>.from(_path), _rootPlayer, (_trees?.length ?? 0) - 1, _currentNode(), _iterDepth, _bestSoFar, nodes, cuts);

  int _currentNode() {
    for (var i = _stack.length - 1; i >= 0; i--) {
      if (_stack[i] >= 0) return _stack[i];
    }
    return -1;
  }

  /// Variables affichees : bornes et valeur du point de vue de X.
  Map<String, Object?> _vars(int p, int alpha, int beta, int? v) => {
        'nœud': p == kX ? 'MAX (X)' : 'MIN (O)',
        'α': fmtScore(p == kX ? alpha : -beta),
        'β': fmtScore(p == kX ? beta : -alpha),
        if (v != null) 'v': fmtScore(p == kX ? v : -v),
        'profondeur': _iterDepth,
        'nœuds': nodes,
        'coupes': cuts,
      };

  void _push(int mv, int p) {
    _b.place(mv, p);
    if (_tr != null) _path.add(mv);
  }

  void _pop(int mv, int p) {
    _b.remove(mv, p);
    if (_tr != null) {
      _path.removeLast();
      if (_stack.isNotEmpty) _stack.removeLast();
    }
  }

  /// Enregistre l'entree dans un noeud ; retourne son identifiant (-1 si non enregistre).
  int _enter(int p, int ply, int move, int alpha, int beta, {String pruned = ''}) {
    final tr = _tr, tree = _tree;
    if (tr == null || tree == null) return -1;
    final parent = _stack.isEmpty ? -1 : _stack.last;
    var id = -1;
    if (ply <= treePly && tree.nodes.length < treeCap && (ply == 0 || parent >= 0)) {
      id = tree.nodes.length;
      final node = TreeNode(id, parent, move, p, ply, tr.total, pruned: pruned);
      node.ab.add([tr.total, p == kX ? alpha : -beta, p == kX ? beta : -alpha]);
      tree.nodes.add(node);
      if (parent >= 0) tree.nodes[parent].children.add(id);
    }
    if (pruned.isEmpty) _stack.add(id);
    return id;
  }

  void _bounds(int id, int p, int alpha, int beta) {
    if (id >= 0) _tree!.nodes[id].ab.add([_tr!.total, p == kX ? alpha : -beta, p == kX ? beta : -alpha]);
  }

  /// Enregistre la valeur [v] (pour le joueur [p]) du noeud [id].
  void _leave(int id, int p, int v, {String tag = ''}) {
    if (id < 0) return;
    final node = _tree!.nodes[id];
    node.value = p == kX ? v : -v;
    node.valueAt = _tr!.total;
    if (tag.isNotEmpty) node.tag = tag;
  }

  // ------------------------------------------------------------ alpha-beta

  /// Valeur de la position pour le joueur [p] qui doit jouer (forme "negamax" du MinMax :
  /// un noeud ou X joue est un noeud MAX, un noeud ou O joue est un noeud MIN).
  int _search(int p, int depth, int alpha, int beta, int ply, int lastMove) {
    nodes++;
    // L'equivalent de SIGALRM : l'echeance est depassee, on interrompt toute la recherche.
    if ((nodes & 1023) == 0 && _clock.elapsedMilliseconds >= _budgetMs) throw const _Timeout();
    final b = _b;
    final tr = _tr;
    final id = _enter(p, ply, lastMove, alpha, beta);
    final who = p == kX ? 'X' : 'O';

    int leaf(int v, String tag, String say) {
      if (tr != null) {
        _leave(id, p, v, tag: tag);
        tr.step(2, say, vars: _vars(p, alpha, beta, v), view: _view());
      }
      return v;
    }

    if (b.wins(3 - p)) {
      // l'adversaire vient d'aligner M symboles
      return leaf(-(kWin - ply), 'terminal', 'Position terminale : ${p == kX ? "O" : "X"} vient d\'aligner ${b.m} symboles. Valeur = ${p == kX ? "gain O" : "gain X"}.');
    }
    if (b.full) return leaf(0, 'terminal', 'Position terminale : la grille est pleine, partie nulle. Valeur = 0.');
    if (_opt.tactics && b.open[p][b.m - 1] > 0) {
      // p complete un alignement au prochain coup
      return leaf(kWin - ply - 1, 'terminal', '$who a ${b.m - 1} symboles alignés et une case libre : il gagne au coup suivant. Inutile de chercher plus loin.');
    }
    if (depth <= 0) {
      final e = b.estimation(_w);
      return leaf(p == kX ? e : -e, 'feuille', 'Profondeur 0 : on n\'explore plus, on appelle la fonction d\'estimation. E = $e (du point de vue de X).');
    }

    // Table de transposition
    final key = b.hash ^ (p == kX ? 0x5bd1e995 : 0);
    final slot = key & _ttMask;
    var ttMove = -1;
    if (_opt.useTT && _ttFlag[slot] != 0 && _ttKey[slot] == key) {
      ttMove = _ttMove[slot];
      if (_ttDepth[slot] >= depth) {
        var v = _ttVal[slot];
        if (v > kWin - 1000) v -= ply;
        if (v < -kWin + 1000) v += ply;
        final f = _ttFlag[slot];
        if (f == 1 || (f == 2 && v >= beta) || (f == 3 && v <= alpha)) {
          ttHits++;
          return leaf(v, 'TT', 'Cette position a déjà été évaluée par un autre ordre de coups : la table de transposition donne directement ${fmtScore(p == kX ? v : -v)}.');
        }
      }
    }

    final moves = _orderedMoves(p, ttMove, innerWidth);
    tr?.step(p == kX ? 3 : 10, 'C\'est à $who de jouer : nœud ${p == kX ? "MAX, on part de v = −∞" : "MIN, on part de v = +∞"}. ${moves.length} coups à essayer.',
        vars: _vars(p, alpha, beta, null), view: _view());

    final alpha0 = alpha;
    var best = -kWin * 2, bestMove = -1;
    for (var k = 0; k < moves.length; k++) {
      final mv = moves[k];
      _push(mv, p);
      final int v;
      try {
        v = -_search(3 - p, depth - 1, -beta, -alpha, ply + 1, mv);
      } finally {
        _pop(mv, p);
      }
      if (v > best) {
        best = v;
        bestMove = mv;
      }
      if (best > alpha) alpha = best;
      if (tr != null) {
        _bounds(id, p, alpha, beta);
        tr.step(
            p == kX ? 7 : 14,
            p == kX
                ? 'Retour du coup ${cellName(b, mv)} : il vaut ${fmtScore(v)}. v = max = ${fmtScore(best)}, donc α = ${fmtScore(alpha)}.'
                : 'Retour du coup ${cellName(b, mv)} : il vaut ${fmtScore(-v)}. v = min = ${fmtScore(-best)}, donc β = ${fmtScore(-alpha)}.',
            vars: _vars(p, alpha, beta, best),
            view: _view());
      }
      if (alpha >= beta) {
        // coupe alpha/beta : l'adversaire ne laissera jamais atteindre cette position
        final left = moves.length - k - 1;
        cuts++;
        if (tr != null) {
          final label = p == kX ? 'coupe β' : 'coupe α';
          for (var r = k + 1; r < moves.length; r++) {
            _enter(3 - p, ply + 1, moves[r], -beta, -alpha, pruned: label);
          }
          tr.step(
              p == kX ? 8 : 15,
              'α = ${fmtScore(p == kX ? alpha : -beta)} ≥ β = ${fmtScore(p == kX ? beta : -alpha)} : ${p == kX ? "coupe β" : "coupe α"}. '
              '${p == kX ? "O" : "X"} a déjà mieux ailleurs et n\'ira jamais dans cette branche : '
              '${left == 0 ? "c'était le dernier coup" : "les $left coups restants ne sont pas explorés"}.',
              vars: _vars(p, alpha, beta, best),
              view: _view(),
              kind: StepKind.pruned);
        }
        break;
      }
    }

    if (_opt.useTT) {
      var store = best;
      if (store > kWin - 1000) store += ply;
      if (store < -kWin + 1000) store -= ply;
      _ttKey[slot] = key;
      _ttVal[slot] = store;
      _ttDepth[slot] = depth;
      _ttFlag[slot] = best <= alpha0 ? 3 : (best >= beta ? 2 : 1);
      _ttMove[slot] = bestMove;
    }
    if (tr != null) {
      _leave(id, p, best);
      tr.step(p == kX ? 9 : 16, 'Tous les coups utiles de $who sont vus : ce nœud ${p == kX ? "MAX" : "MIN"} renvoie ${fmtScore(p == kX ? best : -best)} à son parent.',
          vars: _vars(p, alpha, beta, best), view: _view());
    }
    return best;
  }

  /// Coups candidats, tries par interet decroissant (selon les options actives).
  List<int> _orderedMoves(int p, int ttMove, int width) {
    final b = _b;
    if (b.count == 0) return [(b.n ~/ 2) * b.n + b.n ~/ 2];
    final nn = b.n * b.n;
    // Blocage force : l'adversaire menace de gagner au prochain coup et je ne peux pas
    // gagner tout de suite -> seuls les coups qui bouchent une menace sont utiles.
    if (_opt.tactics && b.open[p][b.m - 1] == 0 && b.open[3 - p][b.m - 1] > 0) {
      final blocks = <int>[];
      for (var w = 0; w < b.numWindows(); w++) {
        final mine = p == kX ? b.xIn(w) : b.oIn(w);
        final theirs = p == kX ? b.oIn(w) : b.xIn(w);
        if (mine != 0 || theirs != b.m - 1) continue;
        for (final c in b.winCells[w]) {
          if (b.cells[c] == kEmpty && !blocks.contains(c)) blocks.add(c);
        }
      }
      if (blocks.isNotEmpty) return blocks;
    }
    final cand = <int>[];
    for (var c = 0; c < nn; c++) {
      if (b.cells[c] != kEmpty) continue;
      if (_opt.nearOnly && b.near[c] == 0) continue;
      cand.add(c);
    }
    if (cand.isEmpty) {
      for (var c = 0; c < nn; c++) {
        if (b.cells[c] == kEmpty) cand.add(c);
      }
    }
    if (!_opt.ordering) return cand;
    final sc = [for (final c in cand) c == ttMove ? 1 << 60 : moveScore(b, c, p)];
    final idx = List<int>.generate(cand.length, (i) => i)..sort((x, y) => sc[y].compareTo(sc[x]));
    final len = idx.length < width ? idx.length : width;
    return [for (var i = 0; i < len; i++) cand[idx[i]]];
  }
}

/// Interet statique de jouer en [cell] pour le joueur [p] : attaque (prolonger ses
/// propres fenetres) + defense (bloquer celles de l'adversaire).
int moveScore(Board b, int cell, int p) {
  var s = 0;
  final m = b.m;
  for (final w in b.windowIdsOf(cell)) {
    final mine = p == kX ? b.xIn(w) : b.oIn(w);
    final theirs = p == kX ? b.oIn(w) : b.xIn(w);
    if (theirs == 0) {
      s += mine == m - 1 ? 100000000 : 2 * _pow8[mine];
    }
    if (mine == 0 && theirs > 0) {
      s += theirs == m - 1 ? 10000000 : _pow8[theirs];
    }
  }
  return s;
}

const List<int> _pow8 = [1, 8, 64, 512, 4096, 32768, 262144, 2097152, 16777216, 134217728];

/// Estimation de chaque case vide pour le joueur p (-1 pour une case occupee) : carte de chaleur.
List<int> moveScores(Board b, int p) => [
      for (var c = 0; c < b.n * b.n; c++) b.cells[c] != kEmpty ? -1 : moveScore(b, c, p),
    ];

/// Une ligne du tableau de l'estimation : k symboles alignes, poids, fenetres de X, de O, contribution.
class EstimRow {
  final int k, weight, xWindows, oWindows;
  const EstimRow(this.k, this.weight, this.xWindows, this.oWindows);
  int get contribution => weight * (xWindows - oWindows);
}

/// Detail de la fonction d'estimation : E = somme des contributions.
List<EstimRow> estimationTable(Board b) {
  final w = Board.defaultWeights(b.m);
  return [for (var k = 1; k < b.m; k++) EstimRow(k, w[k], b.open[kX][k], b.open[kO][k])];
}

/// Lance la recherche dans un isolate pour ne pas bloquer l'interface.
Future<SearchResult> thinkInIsolate(int n, int m, List<int> cells, int player, int hmax, int timeMs,
    {EngineOptions options = const EngineOptions()}) {
  final copy = List<int>.from(cells);
  return Isolate.run(() => Engine().think(Board.fromCells(n, m, copy), player, hmax: hmax, timeMs: timeMs, options: options));
}

/// Recherche tracee (mode pas a pas) dans un isolate : resultat, trace et arbres par iteration.
Future<(SearchResult, Trace, List<SearchTree>)> thinkTracedInIsolate(int n, int m, List<int> cells, int player, int hmax, int timeMs,
    {EngineOptions options = const EngineOptions(), int cap = 20000, int treePly = 3}) {
  final copy = List<int>.from(cells);
  return Isolate.run(() {
    final t = Trace(cap: cap);
    final trees = <SearchTree>[];
    final e = Engine()..treePly = treePly;
    final r = e.think(Board.fromCells(n, m, copy), player, hmax: hmax, timeMs: timeMs, options: options, trace: t, trees: trees);
    return (r, t, trees);
  });
}
