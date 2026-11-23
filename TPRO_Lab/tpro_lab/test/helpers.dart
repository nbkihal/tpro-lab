// Outils communs aux tests d'interface.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpro_lab/ui/kit.dart';

final GlobalKey _shotKey = GlobalKey();
bool _fontsLoaded = false;

/// Dossier des captures d'ecran ; vide si la variable TPRO_SHOTS n'est pas definie.
String get shotsDir => Platform.environment['TPRO_SHOTS'] ?? '';

/// Charge de vraies polices si elles existent (Windows) : la police de test par defaut est
/// beaucoup plus large que la vraie et fausserait les verifications de mise en page.
Future<void> loadRealFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  Future<void> load(String family, List<String> paths) async {
    final files = paths.map(File.new).where((f) => f.existsSync()).toList();
    if (files.isEmpty) return;
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.view(Uint8List.fromList(f.readAsBytesSync()).buffer)));
    }
    await loader.load();
  }

  final fonts = '${Platform.environment['WINDIR'] ?? r'C:\Windows'}\\Fonts';
  await load('Roboto', ['$fonts\\segoeui.ttf', '$fonts\\segoeuib.ttf']);
  await load('Consolas', ['$fonts\\consola.ttf', '$fonts\\consolab.ttf']);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '';
  await load('MaterialIcons', ['$flutterRoot\\bin\\cache\\artifacts\\material_fonts\\MaterialIcons-Regular.otf']);
}

/// Monte [page] dans une fenetre de taille [size], avec le theme de l'application.
Future<void> pumpPage(WidgetTester tester, Widget page, {Size size = const Size(1440, 860)}) async {
  await loadRealFonts();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(
    key: _shotKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true, scaffoldBackgroundColor: C.bg),
      home: Scaffold(body: page),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Enregistre une capture de l'ecran courant (seulement si TPRO_SHOTS est defini).
Future<void> shot(WidgetTester tester, String name) async {
  if (shotsDir.isEmpty) return;
  await tester.runAsync(() async {
    final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(shotsDir).createSync(recursive: true);
    File('$shotsDir${Platform.pathSeparator}$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

/// Avance le temps par petits pas (les pages ont des animations en boucle : pas de pumpAndSettle).
Future<void> settle(WidgetTester tester, [int millis = 600]) async {
  for (var t = 0; t < millis; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
