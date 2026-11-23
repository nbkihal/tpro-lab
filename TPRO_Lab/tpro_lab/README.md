# TPRO Lab

Une seule application de bureau (Flutter) pour les quatre TP notés du module TPRO (ESI Alger, 2CS) :

| TP | Feuille | Sujet | Algorithmes |
|---|---|---|---|
| TP 1 | T2 — exercice 6 | Plus petit cycle d'un graphe non orienté | BFS depuis chaque sommet — O(V·(V+E)) |
| TP 2 | T3 — exercice 6 | Voyageur de commerce | Énumération O(n!) contre Bellman-Held-Karp O(n²·2ⁿ) |
| TP 3 | T4 — exercice 6 | Morpion N×N | MinMax + alpha-bêta + approfondissement itératif + délai, client TCP |
| TP 4 | T5 — exercice 5 | Taquin 15 | A*, WA*, tas contre file naïve, 3 heuristiques |

Chaque TP montre son algorithme **pas à pas** sur des données modifiables, avec à droite un panneau
qui explique l'étape en cours (ligne de pseudo-code, phrase en français, variables), l'aide à la
démonstration (script, scénarios, complexité, questions probables) et l'énoncé officiel.

## 1. Prérequis

- Flutter 3.24 ou plus récent (Dart ≥ 3.5), avec le support bureau activé.
- Windows : Visual Studio 2022 avec la charge de travail « Développement Desktop en C++ ».
- Linux : `clang cmake ninja-build pkg-config libgtk-3-dev`. macOS : Xcode.
- Aucun paquet tiers : uniquement le SDK Flutter. L'application fonctionne hors ligne.

Vérifier l'installation : `flutter doctor`.

## 2. Installer et lancer

```
cd tpro_lab
flutter pub get
flutter run -d windows          # ou : -d linux, -d macos
```

Si les dossiers `windows/`, `linux/` ou `macos/` manquent :

```
flutter create --platforms=windows,linux,macos .
```

(Attention : cette commande régénère les fichiers natifs. Les réglages « taille minimale de
fenêtre » et « plein écran » se trouvent dans `windows/runner/flutter_window.cpp`.)

## 3. Construire l'exécutable

```
flutter build windows --release
```

Résultat : `build\windows\x64\runner\Release\tpro_lab.exe`. Copier **tout le dossier `Release`**
(l'exécutable a besoin des DLL et du dossier `data` voisins).

## 4. Vérifier les algorithmes

```
dart run tool/selftest.dart     # 41 vérifications, sans Flutter (≈ 20 s)
flutter test                    # tests du noyau + un test de fumée par page
flutter analyze
```

`tool/selftest.dart` couvre : cycles (triangle, carré, Petersen, arbre, deux composantes, 300 graphes
aléatoires contre une référence exhaustive), PVC (200 matrices, les trois méthodes donnent le même
coût), morpion (alignements, estimation, tactique, respect du délai, HMAX 5 contre HMAX 1, partie
complète par le réseau avec indices à partir de 0 puis de 1, analyse tolérante des messages),
taquin (heuristiques, A* contre BFS, tas = file naïve, WA* ≤ p × optimal, parité) et, pour chaque
TP, « exécution tracée = exécution normale ».

## 5. Client et serveur du morpion en ligne de commande

Trois consoles, comme dans l'énoncé :

```
dart run bin/server.dart 7 4 3                 # N M TMO [port] [base]
dart run bin/client.dart 5                     # HMAX [nom] [hote] [port] [base] [fraction]
dart run bin/client.dart 1
```

Sans arguments supplémentaires, le client demande le nom, l'adresse (127.0.0.1) et le port (12345) ;
Entrée garde les valeurs par défaut. Le serveur de test affiche la grille en texte après chaque coup.

Exécutables autonomes (aucune installation de Dart nécessaire sur la machine du tournoi) :

```
dart compile exe bin/client.dart -o client.exe
dart compile exe bin/server.dart -o server.exe
client.exe 5 MonNom 192.168.1.10 12345 0
```

Arguments du client :

| Argument | Rôle | Défaut |
|---|---|---|
| `HMAX` | profondeur maximale de l'approfondissement itératif | 6 |
| `nom` | nom envoyé au serveur | demandé |
| `hote`, `port` | adresse du serveur | 127.0.0.1, 12345 |
| `base` | 0 si le serveur numérote lignes et colonnes à partir de 0, 1 sinon | 0 |
| `fraction` | part de TMO utilisée pour réfléchir (0.5 à 0.95) | 0.85 |

**Les deux fichiers C du professeur n'étaient pas disponibles.** Deux détails sont donc réglables :
la base des indices (`base`, ou « indices à partir de » dans l'application) et l'espacement des
messages, analysés de façon tolérante (`X at 2 3`, `x AT 2,3`, espaces multiples, casse). Si vous
obtenez les fichiers C, vérifiez la base des indices avant le tournoi.

## 6. Utiliser l'application

- **Rail de gauche** : Accueil, TP 1 à TP 4. `Ctrl+1…4` ouvre un TP, `Ctrl+0` revient à l'accueil.
  Les pages restent vivantes : une démonstration en cours n'est pas perdue en changeant de page.
- **Accueil** : quatre cartes, et la bande « ordre conseillé » dont chaque bouton ouvre le TP avec
  son premier scénario chargé.
- **Barre de transport** (identique partout) : début, précédent, lecture/pause, suivant, fin,
  étape importante suivante, vitesse 0,25× à 16×, curseur.

| Touche | Action |
|---|---|
| `Espace` | lecture / pause |
| `←` `→` | étape précédente / suivante |
| `Début` `Fin` | première / dernière étape |
| `+` `-` | vitesse |
| `N` (`Maj+N`) | étape importante suivante (précédente) |
| `F11` | mode présentation (plein écran, polices ×1,25) ; `Échap` pour en sortir |

- **Panneau d'explication** (à droite, redimensionnable en tirant son bord, repliable) :
  - *Exécution* : pseudo-code avec la ligne courante, « En ce moment », variables, compteurs ;
  - *Démo* : liste des exigences de l'énoncé (cochées automatiquement quand elles ont été
    montrées), ce qu'il faut dire, scénarios avec bouton **Charger**, complexité, questions
    probables, pièges ;
  - *Énoncé* : texte officiel ; cliquer une phrase soulignée met en évidence l'endroit de
    l'interface qui y répond.
- **Zone basse** (repliable) : réglages, résultats, tableaux, graphiques, journal.

### Où sont les réglages

| Réglage | Emplacement |
|---|---|
| Graphe (exemples, aléatoire, liste d'arêtes, coupe optionnelle) | TP 1, zone basse, onglet « Graphe » |
| Matrice des distances (saisie cellule par cellule, `Tab` passe à la suivante), symétrie, n | TP 2, zone basse |
| Banc d'essai, export CSV | TP 2, onglet « Banc d'essai » |
| N, M, TMO, HMAX, part de TMO utilisée, accélérations du moteur | TP 3, zone basse |
| Nom, adresse, port, base des indices, journal du protocole | TP 3, onglet « Réseau » |
| File (naïve / tas), heuristique, p, limites de nœuds et de temps | TP 4, zone basse |
| Comparaison des variantes, export CSV | TP 4, onglet « Comparaison » |
| Tous les textes (script, questions, énoncés, pseudo-codes, exemples) | `lib/core/demo_content.dart` |

Les fichiers CSV et les listes d'arêtes exportés sont enregistrés dans le dossier `Documents`.

## 7. Organisation du code

```
lib/core/   Dart pur, aucun import Flutter (testable avec « dart run »)
  trace.dart         Step, StepKind, Trace (plafond de 20 000 étapes, début et fin conservés)
  graph.dart         Graph, shortestCycle (+ trace)
  tsp.dart           énumération DFS et BFS, Held-Karp (+ trace), banc d'essai
  ttt_board.dart     grille, fenêtres, estimation incrémentale
  ttt_engine.dart    alpha-bêta, approfondissement itératif, échéance, options (+ trace, arbre)
  ttt_net.dart       client TCP, serveur de test, analyse tolérante
  puzzle.dart        codage 64 bits, heuristiques, files, A*/WA* (+ trace)
  jobs.dart          calculs annulables (isolate que l'on peut arrêter)
  demo_content.dart  tous les textes français
lib/ui/     pages et composants
  kit.dart, charts.dart, transport.dart, explain_panel.dart, lab_scaffold.dart
  home_page.dart, cycle_page.dart, tsp_page.dart, ttt_page.dart, puzzle_page.dart
bin/        client.dart, server.dart (ligne de commande)
tool/       selftest.dart
test/       tests du noyau + tests de fumée des pages
```

Sans trace, les algorithmes tournent à pleine vitesse (bancs d'essai, client du tournoi) ; les temps
affichés dans les tableaux viennent toujours d'exécutions sans trace.

## 8. Avant la démonstration

1. `dart run tool/selftest.dart` → « Tous les tests passent ».
2. Lancer l'exécutable *release* (pas `flutter run`) et passer en mode présentation (`F11`).
3. **TP 2** : saisir la matrice à 6 villes du professeur (zone basse → éditeur de matrice) et
   vérifier que les deux méthodes donnent le même coût.
4. **TP 3** : régler « indices à partir de » d'après les fichiers C ; lancer une « démonstration
   locale » pour vérifier le port 12345 ; garder `client.exe` et `server.exe` compilés à portée de main.
5. Parcourir l'onglet « Démo » de chaque TP : charger chaque scénario une fois.
6. Ordre conseillé : TP 1 (3 min) → TP 2 (4 min) → TP 4 (4 min) → TP 3 (6 min, on finit par la
   partie en réseau).
7. Pendant la démonstration, l'onglet « Démo » montre les exigences non encore cochées : c'est ce
   qu'il reste à montrer.
