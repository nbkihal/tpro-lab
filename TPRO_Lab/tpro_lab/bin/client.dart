// Client morpion en ligne de commande :  dart run bin/client.dart HMAX [nom] [hote] [port] [base]
// (ou, compile :  dart compile exe bin/client.dart -o client  puis  ./client 6)
import 'dart:io';

import 'package:tpro_lab/core/ttt_net.dart';

Future<void> main(List<String> args) async {
  final hmax = args.isNotEmpty ? int.parse(args[0]) : 6;
  String ask(String label, String def) {
    stdout.write('$label [$def] : ');
    final s = stdin.readLineSync()?.trim() ?? '';
    return s.isEmpty ? def : s;
  }

  final name = args.length > 1 ? args[1] : ask('Nom du joueur', 'TPRO-Lab');
  final host = args.length > 2 ? args[2] : ask('Adresse du serveur', '127.0.0.1');
  final port = int.parse(args.length > 3 ? args[3] : ask('Port', '12345'));
  final base = args.length > 4 ? int.parse(args[4]) : 0;
  final c = TttClient(name: name, host: host, port: port, hmax: hmax, indexBase: base);
  c.onLog = (l) => stdout.writeln(l);
  c.onThought = (r) => stdout.writeln('   profondeur ${r.depth}, ${r.nodes} noeuds, ${r.millis} ms, score ${r.score}');
  c.onGameOver = (v) => stdout.writeln(v == 0 ? 'Partie nulle' : (v == 1 ? 'X gagne' : 'O gagne'));
  await c.run();
  exit(0);
}
