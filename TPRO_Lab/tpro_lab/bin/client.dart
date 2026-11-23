// Client morpion du tournoi, en ligne de commande :
//   dart run bin/client.dart HMAX [nom] [hote] [port] [base] [fraction]
//     HMAX      profondeur maximale de l'approfondissement iteratif (defaut 6)
//     nom       nom du joueur envoye au serveur
//     hote      adresse du serveur (defaut 127.0.0.1)
//     port      port du serveur (defaut 12345)
//     base      0 si le serveur numerote lignes et colonnes a partir de 0, 1 sinon (defaut 0)
//     fraction  part de TMO utilisee pour reflechir, entre 0.5 et 0.95 (defaut 0.85)
// Compile :  dart compile exe bin/client.dart -o client.exe   puis   client.exe 5
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:tpro_lab/core/ttt_board.dart';
import 'package:tpro_lab/core/ttt_net.dart';

String _stamp() {
  final t = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.${t.millisecond.toString().padLeft(3, '0')}';
}

Future<void> main(List<String> args) async {
  final hmax = args.isNotEmpty ? int.tryParse(args[0]) ?? 6 : 6;
  String ask(String label, String def) {
    stdout.write('$label [$def] : ');
    final s = stdin.readLineSync()?.trim() ?? '';
    return s.isEmpty ? def : s;
  }

  final name = args.length > 1 ? args[1] : ask('Nom du joueur', 'TPRO-Lab');
  final host = args.length > 2 ? args[2] : ask('Adresse du serveur', '127.0.0.1');
  final port = int.tryParse(args.length > 3 ? args[3] : ask('Port', '12345')) ?? 12345;
  final base = args.length > 4 ? int.tryParse(args[4]) ?? 0 : 0;
  final fraction = (args.length > 5 ? double.tryParse(args[5]) ?? 0.85 : 0.85).clamp(0.5, 0.95);
  final c = TttClient(name: name, host: host, port: port, hmax: hmax, indexBase: base, timeFraction: fraction);
  c.onLog = (l) => stdout.writeln('${_stamp()}  $l');
  c.onStart = (n, m, tmo, me) => stdout.writeln(
      '# partie : grille $n x $n, aligner $m, $tmo s par coup, je joue ${me == kX ? "X" : "O"} '
      '(HMAX = $hmax, indices a partir de $base, reflexion limitee a ${TttClient.budgetFor(tmo, fraction)} ms)');
  c.onThought = (r) => stdout.writeln(
      '#   profondeur ${r.depth}${r.timedOut ? " (alarme : profondeur ${r.depth + 1} interrompue)" : ""}, '
      '${r.nodes} noeuds, ${r.cuts} coupes, ${r.millis} ms, score ${r.score}');
  c.onGameOver = (v) {
    final mine = c.me == kX ? v : -v;
    stdout.writeln('# gameover cost = $v : ${v == 0 ? "partie nulle" : (v == 1 ? "X gagne" : "O gagne")} '
        '-> ${mine > 0 ? "victoire" : (mine < 0 ? "defaite" : "nulle")} pour moi');
  };
  try {
    await c.run();
  } on SocketException catch (e) {
    stderr.writeln('Connexion impossible a $host:$port : ${e.message}. Le serveur est-il lance ?');
    exit(2);
  }
  exit(0);
}
