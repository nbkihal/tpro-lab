// Serveur de test du morpion (meme protocole que celui du TP) :
//   dart run bin/server.dart N M TMO [port] [base]
//     N M TMO   taille de la grille, nombre de symboles a aligner, delai par coup en secondes
//     port      port d'ecoute (defaut 12345)
//     base      0 ou 1 : numerotation des lignes et colonnes dans les messages (defaut 0)
// La grille est affichee en texte apres chaque coup, comme dans le serveur du professeur.
// Compile :  dart compile exe bin/server.dart -o server.exe   puis   server.exe 7 4 3
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:tpro_lab/core/ttt_net.dart';

Future<void> main(List<String> args) async {
  int arg(int i, int def) => args.length > i ? int.tryParse(args[i]) ?? def : def;
  final n = arg(0, 7).clamp(3, 30);
  final m = arg(1, 4).clamp(2, n);
  final tmo = arg(2, 3).clamp(1, 600);
  final port = arg(3, 12345);
  final base = arg(4, 0).clamp(0, 1);
  try {
    await runTttServer(
      n: n,
      m: m,
      tmo: tmo,
      port: port,
      indexBase: base,
      log: (s) => stdout.writeln(s),
      onBoard: (b) => stdout.writeln(boardToText(b)),
    );
  } on SocketException catch (e) {
    stderr.writeln('Impossible d\'ouvrir le port $port : ${e.message}. Un autre serveur tourne peut-etre deja.');
    exit(2);
  }
  exit(0);
}
