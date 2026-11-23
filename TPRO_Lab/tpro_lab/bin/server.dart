// Serveur de test du morpion :  dart run bin/server.dart N M TMO [port]
import 'dart:io';

import 'package:tpro_lab/core/ttt_net.dart';

Future<void> main(List<String> args) async {
  final n = args.isNotEmpty ? int.parse(args[0]) : 7;
  final m = args.length > 1 ? int.parse(args[1]) : 4;
  final tmo = args.length > 2 ? int.parse(args[2]) : 3;
  final port = args.length > 3 ? int.parse(args[3]) : 12345;
  await runTttServer(
    n: n,
    m: m,
    tmo: tmo,
    port: port,
    log: (s) => stdout.writeln(s),
    onBoard: (b) => stdout.writeln(boardToText(b)),
  );
  exit(0);
}
