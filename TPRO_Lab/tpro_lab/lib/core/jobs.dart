/// Calculs longs annulables : le travail tourne dans un isolate que l'on peut tuer.
/// Dart pur : aucun import Flutter.
library;

import 'dart:async';
import 'dart:isolate';

class Job<T> {
  final Completer<T?> _done = Completer<T?>();
  Isolate? _isolate;
  final ReceivePort _port = ReceivePort();
  bool _cancelled = false;

  /// Resultat du calcul ; null si le calcul a ete annule. Une erreur du calcul est propagee.
  Future<T?> get result => _done.future;
  bool get cancelled => _cancelled;

  /// Arrete immediatement le calcul.
  void cancel() {
    if (_done.isCompleted) return;
    _cancelled = true;
    _isolate?.kill(priority: Isolate.immediate);
    _port.close();
    _done.complete(null);
  }
}

void _jobEntry(List<Object?> args) {
  final port = args[0] as SendPort;
  final work = args[1] as Object? Function(void Function(Object?) progress);
  try {
    final r = work((p) => port.send(['p', p]));
    Isolate.exit(port, ['r', r]);
  } catch (e, st) {
    Isolate.exit(port, ['e', '$e', '$st']);
  }
}

/// Lance [work] dans un isolate. [work] recoit une fonction pour signaler sa progression.
/// La fermeture ne doit capturer que des valeurs transmissibles entre isolates.
Job<T> startJob<T>(T Function(void Function(Object?) progress) work, {void Function(Object?)? onProgress}) {
  final job = Job<T>();
  job._port.listen((msg) {
    final m = msg as List<Object?>;
    if (m[0] == 'p') {
      onProgress?.call(m[1]);
      return;
    }
    job._port.close();
    if (job._done.isCompleted) return;
    if (m[0] == 'r') {
      job._done.complete(m[1] as T);
    } else {
      job._done.completeError(StateError('${m[1]}'));
    }
  });
  Isolate.spawn(_jobEntry, [job._port.sendPort, work]).then((iso) {
    job._isolate = iso;
    if (job._cancelled) iso.kill(priority: Isolate.immediate);
  }, onError: (Object e) {
    if (!job._done.isCompleted) job._done.completeError(e);
  });
  return job;
}
