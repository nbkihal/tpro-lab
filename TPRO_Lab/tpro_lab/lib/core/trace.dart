/// Moteur d'execution pas a pas : chaque algorithme peut produire une trace,
/// c'est-a-dire une liste ordonnee d'etapes que l'interface rejoue.
/// Dart pur : aucun import Flutter.
library;

import 'dart:collection';

enum StepKind { normal, important, found, pruned, done }

class Step {
  /// Numero (a partir de 1) de la ligne de pseudo-code en cours d'execution.
  final int line;

  /// Une phrase en francais : ce qui se passe et pourquoi.
  final String say;

  /// Variables a afficher (file, dist, best, alpha, beta, f, g, h...).
  final Map<String, Object?> vars;

  /// Instantane propre au TP, utilise par le dessin de la scene.
  final Object? view;
  final StepKind kind;

  /// Rang de l'etape dans l'execution complete (meme si le milieu a ete saute).
  int seq = 0;

  Step(this.line, this.say, {this.vars = const {}, this.view, this.kind = StepKind.normal});

  bool get isImportant => kind != StepKind.normal;
}

/// Enregistreur d'etapes avec plafond : on garde le debut et la fin de l'execution ;
/// si le plafond est depasse, le milieu est saute (et signale par [skipped]).
class Trace {
  final int cap;
  final List<Step> _head = [];
  final Queue<Step> _tail = Queue<Step>();

  /// Nombre total d'etapes produites par l'algorithme.
  int total = 0;

  /// Nombre d'etapes du milieu qui n'ont pas ete conservees.
  int skipped = 0;

  Trace({this.cap = 20000});

  bool get truncated => skipped > 0;

  void add(Step s) {
    s.seq = total++;
    final half = cap ~/ 2;
    if (_head.length < half) {
      _head.add(s);
      return;
    }
    _tail.add(s);
    if (_tail.length > cap - half) {
      _tail.removeFirst();
      skipped++;
    }
  }

  /// Raccourci : ajoute une etape.
  void step(int line, String say, {Map<String, Object?> vars = const {}, Object? view, StepKind kind = StepKind.normal}) =>
      add(Step(line, say, vars: vars, view: view, kind: kind));

  /// Les etapes conservees, dans l'ordre. Si le milieu a ete saute, une etape
  /// d'information est inseree a la jonction.
  List<Step> get steps {
    if (!truncated) return [..._head, ..._tail];
    final first = _tail.first;
    final gap = Step(
      first.line,
      'Trace trop longue : $skipped étapes du milieu ont été sautées. '
      'Le début et la fin de l\'exécution sont conservés, ainsi que le résultat final.',
      vars: first.vars,
      view: first.view,
      kind: StepKind.important,
    )..seq = first.seq;
    return [..._head, gap, ..._tail];
  }
}
