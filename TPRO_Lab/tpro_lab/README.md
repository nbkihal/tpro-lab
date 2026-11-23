# TPRO Lab — les 4 TP dans une seule application (Flutter desktop)

| Onglet | TP | Contenu |
|---|---|---|
| TP 1 | TD2 ex. 6 | Plus petit cycle d'un graphe non orienté (BFS depuis chaque sommet), éditeur de graphe, animation |
| TP 2 | TD3 ex. 6 | Voyageur de commerce : énumération exacte O(n!) contre Bellman-Held-Karp O(n² 2ⁿ), tableau et courbe des temps |
| TP 3 | TD4 ex. 6 | Morpion N×N (aligner M) : MinMax alpha/bêta, approfondissement itératif, délai TMO, client TCP du tournoi |
| TP 4 | TD5 ex. 5 | Taquin 15 : A* / WA*, file à tas contre file naïve, 3 heuristiques, comparaisons |

Aucune dépendance externe : uniquement le SDK Flutter.

## 1. Installation (une seule fois)

1. Installer Flutter (version stable récente, Dart ≥ 3.5) : https://docs.flutter.dev/get-started/install
2. Outils de compilation desktop :
   - **Windows** : Visual Studio 2022 avec la charge de travail « Développement Desktop en C++ »
   - **Linux** : `sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev`
   - **macOS** : Xcode
3. Vérifier : `flutter doctor` (la ligne Windows / Linux / macOS desktop doit être verte).

## 2. Lancer

Dans le dossier du projet :

```
flutter create --platforms=windows,linux,macos .
flutter pub get
flutter run -d windows        (ou -d linux / -d macos)
```

La première commande génère les dossiers `windows/`, `linux/`, `macos/` (ils ne sont pas dans le zip) ; elle ne touche pas à `lib/`.

Exécutable pour la démonstration : `flutter build windows --release`
→ `build\windows\x64\runner\Release\tpro_lab.exe` (copier tout le dossier `Release`).

## 3. Vérifier les algorithmes (sans interface)

```
dart run tool/selftest.dart
```

18 tests : cycles, TSP (les deux méthodes donnent le même coût), morpion (y compris une partie complète serveur + 2 clients), taquin.

## 4. TP 3 : jouer contre le serveur du professeur

Dans l'onglet TP 3, mode **Réseau** : nom, adresse du serveur, port (12345), HMAX, puis « Se connecter ».

Client en ligne de commande (même moteur) :

```
dart run bin/client.dart HMAX [nom] [hote] [port] [base]
dart run bin/client.dart 6 Ayoub 192.168.1.20 12345 0
```

Serveur de test (même protocole que l'énoncé), pour s'entraîner :

```
dart run bin/server.dart N M TMO [port]
dart run bin/server.dart 7 4 3
```

Le bouton « Serveur local + adversaire » fait la même chose sans terminal.

### À vérifier avec les fichiers C du professeur
- **Base des indices** : l'énoncé ne dit pas si les cases vont de 0 à N-1 ou de 1 à N. Réglage « à partir de 0 / à partir de 1 » dans l'interface, dernier argument du client en ligne de commande.
- Le format exact des messages (`N M TMO X|O`, `X at i j`, `gameover cost = v`) est analysé dans `lib/core/ttt_net.dart`.

## 5. Réglages

| Réglage | Où | Effet |
|---|---|---|
| N, M, TMO, HMAX | onglet TP 3 | taille, alignement, délai par coup, profondeur maximale |
| Part du délai utilisée | `timeFraction` (0.8) dans `lib/core/ttt_net.dart` | marge de sécurité avant le TMO en réseau |
| Largeur de recherche | `ttt_engine.dart` (24 coups à la racine, 12 ensuite) | plus large = plus sûr mais moins profond |
| Poids de l'estimation | `Board.defaultWeights` dans `ttt_board.dart` | valeur d'une fenêtre à k pions |
| Limites du taquin | `nodeLimit`, `timeLimitMs` dans `puzzle.dart` | arrêt de A* sur les instances trop dures |
| Couleurs | classe `C` dans `lib/ui/kit.dart` | thème |

## 6. Organisation

```
lib/core/   algorithmes purs (aucun import Flutter) : graph, tsp, ttt_board, ttt_engine, ttt_net, puzzle
lib/ui/     une page par TP + kit.dart (composants) + charts.dart
bin/        client.dart et server.dart du morpion
tool/       selftest.dart
```
