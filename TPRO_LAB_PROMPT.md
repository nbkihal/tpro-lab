# PROMPT — TPRO Lab: one Flutter desktop app for the 4 graded TPs

> Give this whole file to Claude Code from an empty folder, or from the folder of the existing `tpro_lab` project (see section 2). Everything needed is inside: context, the exact exercise statements, the app design, the algorithms, the on-screen explanations, the demonstration material and the acceptance checks.

---

## 1. Context and goal

I am a 2CS student (SIQ/SIL) at ESI Algiers. The module is **TPRO**. The last exercise of each of the tutorial sheets T2, T3, T4 and T5 is a **graded practical assignment (TP)** that I must **demonstrate live to the professor**, with a graphical interface.

Build **one desktop application** that contains the four TPs. The application has three jobs, in this order of importance:

1. **Choose a lab** — a home screen where I pick one of the 4 TPs.
2. **See the demonstration** — each lab shows its algorithm running visually, step by step, on data I can edit.
3. **Side explanation of the execution** — while the algorithm runs, a side panel explains what is happening *right now* (current pseudo-code line, current data structures, a sentence in plain words), plus a "demonstration help" area with what I must say, the complexity, the scenarios to show and the questions the professor may ask.

The audience of the screen is a professor who knows the algorithms. The interface must make it obvious that I implemented exactly what the statement asks, and must let me answer "why" at any step.

**Quality bar:** the most attractive interface possible for a university demo — dark "laboratory" theme, smooth animations, one accent colour per lab, nothing that looks like a default Material app.

---

## 2. Technical constraints

- **Flutter desktop** (Windows first; Linux and macOS must also build). Dart ≥ 3.5.
- **No third-party packages.** Only the Flutter SDK (`flutter`, `flutter_test`). Charts, graph drawing, boards: all with `CustomPainter`.
- **Strict separation:**
  - `lib/core/` — pure Dart algorithms, **no Flutter import**, runnable and testable with `dart run`.
  - `lib/ui/` — pages and widgets.
- Heavy computations run in an **isolate** (`Isolate.run` called from top-level functions) so the interface never freezes.
- **UI language: French** (labels, explanations, demo notes). Code identifiers and comments in English or French, consistently.
- Minimum window 1280×760; layout must stay usable up to 4K.
- Use `Color.withAlpha(...)` for transparency (works on old and new Flutter versions).
- **If a `tpro_lab` project already exists in the folder:** keep `lib/core/` (it is tested and correct), keep the visual kit, and **upgrade** it to this specification — the main additions are the step-by-step execution engine (section 5), the explanation panel (section 6) and the demonstration help (section 7). Do not rewrite working algorithms; extend them so they can emit steps.
- **If the folder is empty:** create the project from scratch following the structure in section 10.

---

## 3. The four exercise statements (exact text from the tutorial sheets)

These are the official statements. The app must satisfy every sentence in them. Do not paraphrase them in the app: the "Énoncé" tab of each lab (section 6.4) shows them as given here (a faithful French translation may be shown under the English text).

### 3.1 TP 1 — Sheet T2 "Graphs and Graph Traversals" (October 2026), Exercise 6

> **Exercise 6 — The shortest cycle in an undirected graph: This is a graded practical assignment**
>
> Write a program that determines and returns the shortest cycle in an undirected graph G=(V,E). You may choose how to represent the graph. State the algorithm's complexity. To do this, use a BFS (as covered in class) starting from each vertex of the graph.

### 3.2 TP 2 — Sheet T3 "DAR and Dynamic Programming" (October 2026), Exercise 6

> **Exercise 6 — PVC with dynamic programming: this is a graded practical assignment.**
>
> Consider the Traveling Salesman Problem (TSP), defined as follows: We have a set of n cities, all of which are connected to one another (forming a complete graph), with a defined distance between every pair of cities. A traveling salesman wishes to perform the following task: starting from a given city A, he must visit every city—traveling from one to another—and finally return to the starting city, all while minimizing the total distance traveled. In graph-theoretic terms, this is equivalent to finding a Hamiltonian cycle of minimum length. This is a difficult problem—specifically, it is NP-complete. For n=6, we have the following graph: *[figure in the sheet]*
>
> You are therefore asked to do the following: implement the Traveling Salesman Problem (TSP) using an exact method (an algorithm with a complexity of n!) and by using the Bellman-Held–Karp algorithm, which employs dynamic programming to achieve a complexity of O(n² 2ⁿ)—still exponential, but significantly better than n!. For the exact method: enumerate all Hamiltonian cycles (for example, using BFS), calculate the cost of each cycle, and select the minimum. For n=6, you have the following graph: *[figure in the sheet]*
>
> The Bellman-Held–Karp algorithm employs dynamic programming to achieve a more efficient approach—though still exponential, with a complexity of n² 2ⁿ, which is better than n!. The algorithm is based on the following concept:
>
> • Calculate the minimum cost to reach a subset of cities, ending at a specific city.
> • Use previously computed results to incrementally construct the optimal solution.
>
> For a general case with n cities, we label the cities from 0 to n-1. We assume that the route always begins at city 0. Let C(S, j) be the minimum cost to reach a subset of cities S (which includes city j), ending at city j, starting from city 0.
>
> C(S, j) = min over i∈S, i≠j of [ C(S−{j}, i) + d(i, j) ]
>
> • d(i, j) is the distance from city i to city j.
> • In other words: to reach city j coming from a set of cities S, we consider the best path from city 0 to each city i in the set S−{j}, and then add the cost of traveling from i to j.
>
> With the following initializations: For each city j ≠ 0: C({0, j}, j) = d(0, j)
>
> The final solution to the TSP (a complete cycle) is: min over j≠0 of [ C({0, ..., n−1}, j) + d(j, 0) ]
>
> We are looking for the shortest path that visits all cities, ends at city j, and then returns to city 0. The algorithm that implements these recurrence equations has a time complexity of O(2ⁿ · n²). It consists of four nested loops, along with the initial setup steps. It is up to you to determine the bounds for these loops.
>
> After implementing both methods, perform tests using various values of n and compare their execution times; present your results in a table.

*Note: the n=6 graph is a figure that is not available as text. The app ships with a default 6-city distance matrix that I can overwrite cell by cell so that I can type the professor's graph before the demo.*

### 3.3 TP 3 — Sheet T4 "Graph exploration and games" (November 2026), Exercise 6

> **Exercise 6 — The estimation function in Tic-Tac-Toe and alarms: This is a graded practical assignment.**
>
> In the two programs I sent you—which were developed by Mr. Hidouci—two clients play Tic-Tac-Toe via a server, using the Minimax algorithm. Here is a description of how everything works:
>
> In this practical assignment, you are asked to program a client (including an estimation function and alarm mechanisms—the specific requirements are detailed in the two C files I have provided; you are free to use any programming language you prefer) capable of playing a specific version of Tic-Tac-Toe on an N X N grid against an opponent (who is also a client program developed by another student). The objective in this N X N Tic-Tac-Toe game is to align M symbols ('X' or 'O') in any of the 8 possible directions (N, NE, E, SE, S, SW, W, and NW), where M <= N. Each player has a maximum of TMO seconds to make their move.
>
> N, M, and TMO are parameters set by the server program at the beginning of each game. At the end of the tournament, points are tallied to determine the final grades for the assignment (e.g., 0 points for a loss, 1 point for a draw, and 2 points for a win).
>
> Communication between the server and the clients follows the protocol outlined below (using TCP sockets; all messages are sent as character strings terminated by a newline character, `\n`):
>
> - Once launched, the server opens a TCP socket on port 12345 and listens for connections from two clients.
> - As soon as a client connects to the server, it must send a character string representing the player's name.
> - The server waits until both clients have connected and submitted their respective names.
> - Once both clients have connected (and their names have been sent), the server responds by sending the game parameters to each client: N, M, TMO, and the symbol 'X' or 'O' (the first client to connect is assigned 'X', and the second is assigned 'O'). For example, the response to the first client might be "7 4 5 X," meaning N=7, M=4, and TMO=5 seconds; the client receiving this message is designated as player 'X'.
> - Player 'X' moves first, and therefore has TMO seconds to send their initial move to the server.
> - The second client ('O') waits for the next prompt from the server before beginning their turn.
> - If the server does not receive a legal move from the active client within the TMO-second time limit, the game ends, and the opposing player is declared the winner.
> - During the allotted time (TMO seconds), the client determines its best move—that is, the coordinates (i, j) where it will place its symbol on the N×N grid. Each client is free to use any method or estimation strategy it chooses. The essential requirement is that the client must respond to the server with a legal (i.e., valid) move before the TMO timeout expires.
> - To place its symbol ('X' or 'O') at position (i, j) on the grid, a client simply sends a string containing two integers—i and j, separated by a space and terminated by a newline character ('\n')—to the server.
> - When the server receives a response from a player (i.e., coordinates i and j), it verifies that the move is legal, then sends a prompt to the opposing player, informing them of the move that has just been made. For example, if player 'X' places an 'X' symbol at position (2, 3) and the move is legal, the server sends a prompt to player 'O' in the format "X at 2 3". Player 'O' then updates their local grid by placing an 'X' at position (2, 3) and has TMO seconds to make their own move and respond to the server.
> - The game continues in this alternating fashion until the server signals the end of the game (which occurs if a player takes too long to respond, makes an illegal move, or if the game reaches a terminal state).
> - The end-of-game message consists of the string "gameover cost = val", where 'val' is -1, 0, or 1. This message is sent to both clients. The value 'val' is interpreted as follows: -1 means player 'X' has lost (i.e., 'O' has won), 0 means a draw, and 1 means player 'X' has won (i.e., 'O' has lost).
> - The server then shuts down, terminating the connections to both clients.
>
> The method used by this client to select the best move is "iterative deepening." Essentially, this involves running the minimax algorithm (with alpha-beta pruning) multiple times—redundantly—with progressively increasing search depths. This process continues until either a specified maximum depth (HMAX, defined at client startup) is reached or the designated timeout (TMO) expires. The best move identified up to that point is then sent by the client to the server.
>
> To implement the timeout, I utilized alarms. The `alarm(x)` function sets an alarm for `x` seconds; once this duration elapses, a `SIGALRM` signal is sent to the process that initiated the alarm. By intercepting this `SIGALRM` signal using the `signal(...)` function, the search process can be halted at the point of interruption, compelling the client to respond to the server with the best move found prior to the timeout. To run a demonstration, it is easiest to use 3 console (command-line) windows:
>
> 1) In the first window, launch the server program, specifying the game parameters in the command line. For example, for a 7x7 grid, a target of 4 in a row, and a 3-second timeout, you can use the following command: `server 7 4 3`
>
> 2) In the second window, launch the first client, specifying HMAX as a command-line argument. For example, for a maximum depth (HMAX) of 5 levels, you can use: `client 5`. The program will then prompt you to enter the client's name, followed by the server's IP address and port number (press Enter to keep the default values: 127.0.0.1 and 12345).
>
> 3) In the third window, launch the second client, specifying HMAX as a command-line argument. For example, for a maximum depth (HMAX) of 1 level (meaning the choice is guided solely by the estimation function), you can use: `client 1`. The program will again prompt you to enter the client's name, followed by the server's IP address and port number (press Enter to keep the default values: 127.0.0.1 and 12345).
>
> The game grid is displayed in text format within the server window (the first window).

*Note: the professor's two C files are not available to you. Two details are therefore unknown and must be **configurable in the interface and on the command line**: (a) whether the coordinates i, j are 0-based or 1-based; (b) the exact spacing of the messages — parse them tolerantly (trim, split on any whitespace, ignore case, accept "X at 2 3" and "X at 2,3"). If I place the C files in a folder `prof_c/`, read them first and align the client on them exactly.*

### 3.4 TP 4 — Sheet T5 "The heuristics" (November 2026), Exercise 5

> **Exercise 5 — The sliding puzzle (taquin): this is a graded practical assignment**
>
> This concerns the 15-puzzle (a 4x4 sliding tile puzzle) using the A* and WA* algorithms. The current version of the program includes an A* implementation for the 4x4 puzzle, featuring:
>
> - A naive implementation of the priority queue (O(n) for removal, O(1) for insertion).
> - A heuristic function, h(x), defined as the number of tiles misplaced in configuration x relative to the goal configuration.
>
> Your tasks are as follows:
>
> - Implement an efficient priority queue using a heap (O(log n) operations).
> - Add an alternative heuristic function based on the sum of the Manhattan distances of the misplaced tiles (you may also include other heuristics).
> - Implement WA* (where WA* is A* with the evaluation function f(x) = g(x) + p*h(x), with p > 1).
> - Conduct tests—starting from various initial configurations of your choosing—to compare performance. Analyze the impact of using a heap, the choice of heuristic function, and the effect of the parameter p in WA*. Examples of metrics for your evaluation include execution time, the number of nodes explored, the maximum size of the exploration frontier, and the quality of the solution.

---

## 4. Application structure

### 4.1 Shell

- **Left rail** (always visible, 76 px): logo, then 5 entries — Accueil, TP 1, TP 2, TP 3, TP 4 — each with its accent colour and a tooltip. Keyboard: `Ctrl+1…4` opens a lab, `Ctrl+0` goes home.
- Pages are kept alive when I switch (an `IndexedStack`), so a running demo is not lost.
- **Presentation mode** (`F11` or a button in the rail): fullscreen, larger fonts (×1.25), hides editing controls that are not needed while presenting.

### 4.2 Home screen — "choose a lab"

Four large animated cards (2×2 grid). Each card shows:

- tag ("TP 1"), title, the sheet and exercise it comes from ("T2 — Exercice 6");
- a small **live animated preview** of the lab drawn with `CustomPainter` (a pulsing cycle in a graph, a tour being traced between cities, an X/O grid filling, tiles sliding);
- the algorithm names and the complexity in one line;
- a "Lancer la démonstration" button.

Under the cards: a one-line reminder of the demo order and total estimated time (see section 7.5).

| Lab | Title | Accent | Algorithms |
|---|---|---|---|
| TP 1 | Plus petit cycle | cyan | BFS from every vertex — O(V·(V+E)) |
| TP 2 | Voyageur de commerce | amber | Exact enumeration O(n!) vs Bellman-Held-Karp O(n²·2ⁿ) |
| TP 3 | Morpion N×N | violet | MinMax + alpha-beta + iterative deepening + timeout, TCP client |
| TP 4 | Taquin 15 | green | A*, WA*, heap vs naive queue, 3 heuristics |

### 4.3 Lab page layout (identical for the 4 labs)

```
┌────────────────────────────────────────────────────────────┬──────────────────────────┐
│ Header: tag · title · subtitle · [Énoncé] [Mode présentation]                          │
├────────────────────────────────────────────────────────────┼──────────────────────────┤
│                                                            │ EXPLANATION PANEL (420px)│
│                 DEMONSTRATION CANVAS                       │ tabs:                    │
│        (graph / cities / board / puzzle, animated)         │  Exécution | Démo | Énoncé│
│                                                            │                          │
├────────────────────────────────────────────────────────────┤                          │
│ TRANSPORT BAR: ⏮ ◀ ▶/⏸ ▶| ⏭ · speed · step k / n · scrub   │                          │
├────────────────────────────────────────────────────────────┤                          │
│ BOTTOM AREA (collapsible): controls, results, tables, charts, log                     │
└────────────────────────────────────────────────────────────┴──────────────────────────┘
```

The explanation panel can be resized by dragging its edge and collapsed with a button.

---

## 5. Step-by-step execution engine (the heart of the demo)

Every algorithm must be able to produce a **trace**: an ordered list of steps that the interface replays. This is what links the canvas and the explanation panel.

```dart
/// lib/core/trace.dart — pure Dart
class Step {
  final int line;            // index of the pseudo-code line being executed
  final String say;          // one French sentence: what happens and why
  final Map<String, Object?> vars;   // variables to show (queue, dist, best, alpha, beta, f, g, h...)
  final Object? view;        // lab-specific snapshot used by the painter
  final StepKind kind;       // normal, important, found, pruned, done
}
```

Rules:

- The algorithms in `lib/core/` take an optional `trace` flag (or a `void Function(Step)` callback). **Without tracing they run at full speed** (used for benchmarks and for the tournament client); with tracing they record steps. The measured times shown in tables always come from untraced runs.
- Cap the trace (for example 20 000 steps). When the cap is reached, keep the last steps and the final result and tell the user that the middle was skipped.
- **Transport bar** (same widget for all labs): first / previous / play-pause / next / last, a speed selector (0.25× to 16×), a scrubber, "step k / n". Keyboard: `Space` play-pause, `←` / `→` previous / next, `Home` / `End`, `+` / `-` speed.
- Going **backwards** must work (steps hold snapshots or are cheap to recompute).
- "Important" steps (a cycle found, a better tour, a pruning, the solution) make the canvas flash briefly and are marked on the scrubber so I can jump to them (`N` = next important step).

---

## 6. Explanation panel (right side)

Three tabs.

### 6.1 Tab "Exécution" (default)

From top to bottom:

1. **Pseudo-code** of the running algorithm in a monospace block, numbered, with the **current line highlighted** in the lab's accent colour and auto-scrolled into view. The pseudo-code must match what was taught (see section 8 for each lab's exact pseudo-code).
2. **"En ce moment"** — the `say` sentence of the current step, in large readable text. Written so that I can read it aloud. Example: "On défile le sommet 4 (distance 2). Son voisin 7 est déjà visité et n'est pas son parent : on vient de fermer un cycle de longueur 2 + 3 + 1 = 6."
3. **State** — the variables of the step shown as small labelled chips or mini-tables: the queue contents, `dist[]` and `parent[]`, the best value so far, α and β, f = g + p·h, the DP cell being filled, etc. Values that changed since the previous step are highlighted.
4. **Counters** — live numbers: steps, nodes visited or generated, prunings, frontier size, elapsed time.

### 6.2 Tab "Démo" — demonstration help

A scrollable sheet for me, the presenter. Contents per lab are specified in section 7. Sections:

- **Ce qu'il faut dire** — a 5–8 line script for the oral presentation.
- **Scénario conseillé** — numbered actions to perform, each with a **"Charger"** button that sets up the app in that state (loads a preset graph, matrix, position or puzzle and selects the right options).
- **Complexité** — the result and the justification in 3–4 lines.
- **Questions probables du professeur** — expandable question / answer cards.
- **Pièges** — what not to say or what can go wrong live.

### 6.3 Presenter checklist

At the top of the "Démo" tab: checkboxes for each requirement of the statement ("BFS depuis chaque sommet ✔", "complexité annoncée ✔", "tableau des temps ✔"…). They tick automatically when the corresponding feature has been shown during the session, so I can see what I have not demonstrated yet.

### 6.4 Tab "Énoncé"

The exact statement from section 3, with each requirement sentence clickable: clicking it highlights the part of the interface that fulfils it (or opens it).

---

## 7. Per-lab specification

### 7.1 TP 1 — Shortest cycle in an undirected graph

**Representation:** adjacency lists (say so on screen).

**Canvas — graph editor and animation**
- Click empty space: add a vertex. Drag a vertex: move it. Drag from one vertex to another: add an edge. Right-click a vertex or an edge: delete it. No self-loops, no multi-edges.
- Presets (buttons): triangle inside a larger graph, square, Petersen graph (girth 5), a tree (no cycle), two components with one cycle each, cycle C₈, complete graph K₅, grid 4×4, "random (n, density)".
- Also allow loading/typing an edge list as text ("0 1\n1 2\n…") and exporting it.
- During the run: the current BFS source glows; vertices are coloured by BFS level; tree edges are drawn solid, the non-tree edge that closes a cycle flashes; the best cycle so far is drawn thick; the final shortest cycle pulses.

**Algorithm**
```
1  best ← ∞
2  for each vertex s of V
3      for each v: dist[v] ← -1, parent[v] ← nil
4      dist[s] ← 0 ; enqueue(Q, s)
5      while Q is not empty
6          u ← dequeue(Q)
7          for each neighbour v of u
8              if dist[v] = -1                     // tree edge
9                  dist[v] ← dist[u]+1 ; parent[v] ← u ; enqueue(Q, v)
10             else if v ≠ parent[u]               // non-tree edge: a cycle is closed
11                 best ← min(best, dist[u] + dist[v] + 1)
12 return best (and the cycle)
```
- Rebuild the actual cycle: climb from `u` and `v` through `parent[]` to their lowest common ancestor.
- Optional early cut (toggle, off by default so the demo matches the class version): stop the BFS from `s` when `2·dist[u] + 1 ≥ best`.
- If the graph has no cycle (forest): say "aucun cycle (le graphe est une forêt)".

**Explanation content**
- Why BFS from every vertex is needed: a single BFS can report a cycle that does not pass through its source and overestimate its length; the minimum over all sources is exact because a BFS started **on** a vertex of the shortest cycle finds exactly its length.
- State shown: queue, `dist[]`, `parent[]`, `best`, current source.

**Complexity to state:** one BFS is O(V+E); V of them → **O(V·(V+E))**, that is O(V·E) for a connected graph and O(V³) for a dense one. Memory O(V+E). Show live counters "sommets défilés" and "arêtes examinées" next to the theoretical bound V·(V+2E).

**Demo help**
- Scenario: (1) triangle preset, step through the first BFS slowly; (2) Petersen graph at high speed → 5; (3) tree → no cycle; (4) draw the professor's graph by hand.
- Probable questions: Why not DFS? (DFS finds *a* cycle, not the shortest.) Why the test `v ≠ parent[u]`? (In an undirected graph the edge back to the parent is not a cycle.) Why can one BFS be wrong? What about a disconnected graph? What is the complexity with an adjacency matrix? (O(V³).) Does it work on a directed graph? (No: the parent test and the length formula change.)

---

### 7.2 TP 2 — Travelling salesman: exact enumeration vs Bellman-Held-Karp

**Canvas**
- Cities as points on a plane (drag to move; distances are then Euclidean, rounded), **or** an explicit distance matrix (editable table dialog, symmetric by default, with an "asymétrique" switch). A default **n = 6** instance is loaded at start; I must be able to type the professor's 6-city matrix quickly (Tab moves across cells; editing d(i,j) mirrors d(j,i) when symmetric).
- City 0 is the start and is drawn differently.
- During enumeration: the tour being tested is drawn thin, the best tour so far thick. During Held-Karp: the subset S being processed is shown as highlighted cities and the DP cell C(S, j) being filled is shown in the side panel.
- At the end: the optimal tour is traced with an animated moving dot, with its cost.

**Method 1 — exact enumeration (n!)**
```
1  best ← ∞
2  enumerate every ordering of cities 1..n-1 (city 0 fixed at the start)
3      cost ← d(0, p1) + d(p1, p2) + … + d(p_{n-1}, 0)
4      if cost < best: best ← cost ; bestTour ← this ordering
5  return best, bestTour
```
- Offer two enumeration styles and say which is used: BFS over partial paths (as the statement suggests — a queue of partial paths, memory-hungry) and DFS/permutations (same result, O(n) memory). Count the cycles enumerated: (n−1)!.
- Time grows as O(n!) (precisely (n−1)!·n). Hard limit in the UI: n ≤ 11 for the traced/animated run, n ≤ 12 for benchmark, with a warning and estimated time above that.

**Method 2 — Bellman-Held-Karp (dynamic programming)**
```
1  for j ← 1 to n-1:  C({0,j}, j) ← d(0, j)                      // initialisation
2  for size ← 3 to n                                              // loop 1: subset size
3      for each subset S of size 'size' containing 0              // loop 2: subsets
4          for each j in S, j ≠ 0                                 // loop 3: last city
5              C(S, j) ← min over i in S, i ≠ 0, i ≠ j            // loop 4: previous city
6                          of C(S−{j}, i) + d(i, j)
7  return min over j ≠ 0 of C({0..n-1}, j) + d(j, 0)
```
- Implementation: bitmask over the cities, table of size 2ⁿ·n, parent table to rebuild the tour. The four nested loops asked by the statement must be visible in the code and highlighted in the pseudo-code.
- Time O(n²·2ⁿ), memory O(n·2ⁿ). Limit n ≤ 20 (memory warning above 18).

**Explanation content**
- Show the recurrence C(S, j) = min[C(S−{j}, i) + d(i, j)] with the current S, j, i substituted by real numbers at each step ("C({0,1,3}, 3) = min( C({0,1},1) + d(1,3) ) = 12 + 7 = 19").
- A small view of the DP table rows already filled, grouped by subset size.
- Why it is faster: a path is summarised by (set visited, last city) — orders inside the set no longer matter.

**Comparison (required by the statement)**
- "Lancer le banc d'essai": for n = 4 … 12 run both methods (enumeration skipped beyond its limit and marked "—"), Held-Karp continues to n = 20. Several random instances per n, report the median.
- **Table**: n, (n−1)!, n²·2ⁿ, time enumeration, time Held-Karp, ratio, same optimal cost ✔.
- **Chart**: both curves on a logarithmic time axis, with n on the x-axis.
- Export the table as CSV. Both methods must always return the same optimal cost; show a green check per row.

**Demo help**
- Scenario: (1) type the professor's n=6 matrix, run both, same cost and same tour; (2) step through Held-Karp for n=4 to explain the recurrence; (3) run the benchmark and comment the curve; (4) show n=18 with Held-Karp only.
- Probable questions: Why (n−1)! and not n!? Why still exponential? Why does city 0 stay fixed? What is stored in C(S, j)? How is the tour rebuilt? What are the bounds of the four loops? What is the memory cost and which runs out first, time or memory? Is the result exact or approximate? (Exact, both.) What changes if distances are asymmetric? (Nothing in Held-Karp; enumeration can no longer halve the work.)

---

### 7.3 TP 3 — N×N tic-tac-toe: estimation function, alarms, iterative deepening, TCP client

This lab has two faces: a **visual lab** to explain the search, and the **real tournament client**.

**Modes**
1. **Moi contre l'IA** — I click cells.
2. **IA contre IA** — two engines with different HMAX (for example 5 against 1, as in the statement).
3. **Réseau** — the real client: name, server address (default 127.0.0.1), port (default 12345), HMAX, index base (0 or 1), then "Se connecter".
4. **Démonstration locale** — starts, inside the app, a server that follows the same protocol plus an automatic opponent, so the whole protocol can be shown without the professor's server.

**Canvas**
- N×N grid (N from 3 to 15, M from 3 to min(N, 6), TMO in seconds, HMAX), X and O drawn with animation, last move highlighted, winning alignment drawn through.
- **Heat map** toggle: each empty cell tinted by its move-ordering score.
- **Evaluation bar** (like a chess evaluation bar) showing the estimation of the position from X's point of view.
- **TMO countdown ring** during each search; it turns red in the last quarter.
- **Search view** (collapsible, used in step mode): the tree explored for the current move down to a small depth (for example on a 3×3 or 4×4 board), with node values, α/β on each node, and pruned branches crossed out and labelled "coupe α" / "coupe β".

**Engine**
```
1  function alphabeta(node, depth, α, β, maximizing)
2      if depth = 0 or node is terminal: return estimation(node)
3      if maximizing
4          v ← -∞
5          for each child c (best-ordered first)
6              v ← max(v, alphabeta(c, depth-1, α, β, false))
7              α ← max(α, v)
8              if α ≥ β: break                      // β cut
9          return v
10     else
11         v ← +∞
12         for each child c
13             v ← min(v, alphabeta(c, depth-1, α, β, true))
14             β ← min(β, v)
15             if α ≥ β: break                      // α cut
16         return v

17 function bestMove(position, HMAX, TMO)             // iterative deepening
18     arm the alarm for TMO (minus a safety margin)
19     best ← a legal move (never answer nothing)
20     for depth ← 1 to HMAX
21         result ← search at this depth
22         if the alarm fired: stop, keep the previous best
23         best ← result
24     return best
```
- **Estimation function** (must be explained clearly on screen): consider every window of M aligned cells in the 4 line directions (which covers the 8 directions of the statement). A window that contains both symbols is worth 0. A window with k symbols of one player and none of the other is worth weight(k), counted positively for X and negatively for O. E = Σ weight(k) · (X windows with k − O windows with k). Weights grow fast with k (geometric), a completed window is a win. Window counts are maintained incrementally when a move is played or undone.
- **Alarm / timeout:** Dart has no `alarm()`/`SIGALRM`. Reproduce the mechanism with a deadline: a stopwatch checked every ~1000 nodes that throws a private exception caught by the iterative-deepening loop (plus a `Timer` in the UI). Explain this equivalence on screen: "alarm(TMO) → échéance ; SIGALRM → exception d'interruption ; le handler → on renvoie le meilleur coup de la dernière profondeur terminée". Use about 80–90 % of TMO to keep a network margin; the fraction is a setting.
- Speed helpers (each one a toggle so that I can show its effect on nodes explored): move ordering, candidate moves restricted to cells near existing symbols, transposition table (Zobrist hashing), immediate win / forced block detection.
- The move sent must **always be legal**, even if the search was interrupted at depth 1.

**Network client**
- Exactly the protocol of section 3.3. Log every message in a panel, with direction (`>` sent, `<` received) and a timestamp.
- Also provide command-line programs: `dart run bin/client.dart HMAX [name] [host] [port] [base]` and `dart run bin/server.dart N M TMO [port]` (the test server prints the grid in text after each move, as the professor's does). Document `dart compile exe` for both.
- Handle: connection refused, server closing early, malformed line, opponent's illegal move, game over arriving during my search.

**Explanation content**
- In play mode, after each AI move: depth reached, nodes explored, prunings, time used out of TMO, score, and one sentence ("Profondeur 6 atteinte en 2,1 s ; la profondeur 7 a été interrompue par l'alarme, on joue le coup de la profondeur 6").
- A small table per iteration of the deepening: depth, best move, score, nodes, time.
- The estimation table: k, weight, number of X windows, number of O windows, contribution.

**Demo help**
- Scenario: (1) 3×3 M=3 in step mode to show MinMax values and cuts on the tree; (2) 7×7 M=4 TMO=3, HMAX 5 against HMAX 1, as in the statement; (3) set TMO=1 and HMAX=20 to show the alarm interrupting the deepening; (4) switch ordering off to show how many more nodes are explored; (5) network mode against the professor's server.
- Probable questions: What does your estimation function compute and why these weights? Why iterative deepening if shallower searches are thrown away? (Their cost is small compared with the last depth; they give a move at any time and improve ordering.) What happens exactly when the alarm fires? How many nodes does alpha-beta save, best case? (About the square root: O(b^(d/2)) with perfect ordering.) Why can HMAX=1 play reasonably? What if the timeout hits before depth 1 ends? How do you detect M aligned in 8 directions with 4 scans? What is `gameover cost = -1` for the O player? How is a draw scored in the tournament?
- Pitfalls: check the index base against the C files before the tournament; never use 100 % of TMO.

---

### 7.4 TP 4 — 15-puzzle: A*, WA*, heap, heuristics

**Canvas**
- 4×4 board with animated sliding tiles; click a tile next to the blank to move it; arrow keys also move.
- Buttons: "Mélanger (k coups)" (always solvable because produced by legal moves), "But", "Saisir une configuration" (16 numbers; reject unsolvable ones with the parity explanation), presets "facile (≈10)", "moyen (≈25)", "difficile (≈40)".
- After solving: replay the solution with the transport bar; tiles that are misplaced are tinted; show g, h and f of the current state.

**Algorithm**
```
1  open ← {start}  with f(start) = g + p·h          // p = 1 → A*, p > 1 → WA*
2  closed ← ∅
3  while open is not empty
4      x ← extract the node of minimum f from open
5      if x = goal: return path
6      add x to closed
7      for each neighbour y of x (move the blank)
8          g' ← g(x) + 1
9          if y not seen, or g' < g(y)
10             g(y) ← g' ; parent(y) ← x ; f(y) ← g' + p·h(y)
11             insert y into open
12 return failure
```
- **Two priority queues behind one interface**, selectable in the UI: `NaiveQueue` (insert O(1), extract-min O(n) by scanning — the version of the statement) and `HeapQueue` (binary min-heap in an array, insert and extract O(log n)). Show the heap as a small tree/array in step mode with the sift-up / sift-down highlighted.
- **Heuristics** (selectable): h1 = number of misplaced tiles (given); h2 = sum of Manhattan distances (required); h3 = Manhattan + linear conflict (bonus). State for each whether it is admissible (all three are) and that h1 ≤ h2 ≤ h3.
- **WA\***: slider p from 1.0 to 5.0. Explain: larger p → fewer nodes, faster, but the solution may be longer; its cost is at most p times the optimum.
- Safety limits (node count, time) with a clear message when reached; run in an isolate with a "Stop" button.
- State encoding compact (64-bit integer, 4 bits per tile) for speed; say so in the explanation.

**Comparison (required by the statement)**
- "Comparer" runs, on the same start configuration (and optionally on a batch of random configurations), every combination I tick among: queue {naïve, tas} × heuristic {h1, h2, h3} × p {1, 1.5, 2, 3}.
- **Table**: variant, time (ms), nodes explored, nodes generated, maximum frontier size, solution length, optimal? (compared with A* + admissible heuristic).
- **Charts**: bars on a logarithmic scale for time and for nodes explored.
- Export CSV.

**Explanation content**
- Step mode shows: the node extracted with its g, h, f; its neighbours and whether each is inserted, improved or ignored; frontier size; closed size.
- A sentence on each important step ("On extrait l'état de plus petit f = 14 (g = 6, h = 8). Trois voisins générés, un déjà fermé.").

**Demo help**
- Scenario: (1) easy puzzle in step mode with h2 to explain f = g + h; (2) same medium puzzle with h1 then h2: compare nodes; (3) naive queue against heap on a hard puzzle: same nodes, very different time; (4) WA* with p = 1, 2, 3: fewer nodes, longer solution; (5) show the comparison table and export.
- Probable questions: Why is A* optimal with an admissible heuristic? Why does Manhattan dominate misplaced tiles? Why does the heap not change the number of nodes explored? What is the cost of extract-min in each queue? What does WA* guarantee? Why are half of the configurations unsolvable? What is the difference between "explored" and "generated"? What limits A* on the 15-puzzle — time or memory? (Memory: the frontier.) What would IDA* change?

---

### 7.5 Suggested order and timing for the live demonstration

Show this as a compact strip on the home screen: TP 1 (3 min) → TP 2 (4 min) → TP 4 (4 min) → TP 3 (6 min, ends with the network game). Each item is a button that opens the lab with its first scenario loaded.

---

## 8. Visual design

- **Theme:** dark, deep blue-black background, slightly lighter panels with a 1 px border and soft radius (14–16 px), monospace font for numbers, code and logs; a clean sans-serif for text. No default AppBar, no default Material blue.
- **Palette:** background `#0B0F17`, panel `#121826`, panel-2 `#1A2233`, line `#263047`, text `#E6EAF2`, muted `#8A94A8`; accents cyan `#22D3EE`, amber `#F59E0B`, violet `#A78BFA`, green `#34D399`, red `#F87171` (errors, timeouts).
- **Motion:** 150–350 ms eased transitions; pulsing glow on results; animated dashed line on the "current" edge; numbers that count up. Never block interaction during an animation.
- **Canvas quality:** antialiased, vertices with a soft halo, labels always readable (text on a small dark pill), consistent stroke widths that scale with the canvas size.
- **Readability from a distance:** in presentation mode the pseudo-code, the "En ce moment" sentence and the result must be readable from 3 metres.
- Empty states are designed ("Ajoutez des sommets en cliquant, ou chargez un exemple").
- Every destructive action (clear graph, new game) is one click with an "Annuler" toast.

---

## 9. Robustness

- No crash on: empty graph, graph with one vertex, n = 2 or 3 cities, N = M = 3, already-solved puzzle, port already in use, server unreachable.
- All long computations are cancellable and report progress.
- All numeric inputs are clamped to safe ranges with an explanation when a limit is hit ("au-delà de n = 11, l'énumération prendrait environ … ").
- The app works fully offline.

---

## 10. Project structure

```
pubspec.yaml
README.md                     # French: install, run, build, configure, demo checklist
lib/main.dart                 # shell: rail + pages + presentation mode + shortcuts
lib/core/trace.dart           # Step, StepKind, Trace
lib/core/graph.dart           # Graph, shortestCycle (+ trace)
lib/core/tsp.dart             # brute force (BFS and DFS styles), Held-Karp (+ trace), benchmark helpers
lib/core/ttt_board.dart       # board, windows, estimation
lib/core/ttt_engine.dart      # alpha-beta, iterative deepening, deadline, toggles (+ trace/tree)
lib/core/ttt_net.dart         # TCP client, test server, tolerant parsing
lib/core/puzzle.dart          # state encoding, heuristics, queues, A*/WA* (+ trace)
lib/core/demo_content.dart    # all French texts: pseudo-code, scripts, Q&A, statements, presets
lib/ui/kit.dart               # palette, panels, buttons, steppers, tables, toasts
lib/ui/charts.dart            # log line chart, log bar chart
lib/ui/transport.dart         # transport bar + keyboard shortcuts
lib/ui/explain_panel.dart     # tabs Exécution / Démo / Énoncé, pseudo-code viewer, state chips, checklist
lib/ui/home_page.dart
lib/ui/cycle_page.dart
lib/ui/tsp_page.dart
lib/ui/ttt_page.dart
lib/ui/puzzle_page.dart
bin/client.dart               # tournament client, command line
bin/server.dart               # test server, command line
tool/selftest.dart            # algorithm checks, no Flutter needed
test/                         # flutter_test: core tests + one smoke test per page
```

Keep all demonstration texts in `demo_content.dart` so I can edit my script without touching UI code.

---

## 11. Tests and acceptance

`dart run tool/selftest.dart` must pass and cover at least:

- **Cycle:** triangle → 3; square → 4; Petersen → 5; tree → none; two components → the smaller cycle; random graphs checked against a brute-force reference; the returned cycle is a real cycle of the announced length.
- **TSP:** both methods give the same cost on 200 random instances with n from 3 to 9; the tour visits every city once and its cost equals the announced cost; n = 15 with Held-Karp finishes in well under a second.
- **Tic-tac-toe:** win detection in the 4 line directions; estimation is 0 on an empty board and antisymmetric; the engine takes an immediate win and blocks an immediate loss; the search respects the time budget on 11×11; a deeper engine beats a depth-1 engine over several games; a full game runs through the test server with two clients and ends with a valid `gameover` message; the tolerant parser accepts the spacing variants.
- **Puzzle:** h(goal) = 0 for every heuristic; h1 ≤ h2 ≤ h3 on random states; A* with heap and A* with naive queue return the same length; A* length equals a BFS reference on shallow scrambles; WA* length ≤ p × optimal; unsolvable configurations are rejected.
- **Trace:** for each lab the traced run and the untraced run return the same result, and every step's `line` index exists in the pseudo-code.

Acceptance checklist for the interface (verify each by running the app):

1. From the home screen I can open each lab in one click and come back without losing its state.
2. In each lab I can run the demonstration, pause it, go one step forward and one step **back**, and change the speed.
3. At every step the right panel shows the highlighted pseudo-code line, a French sentence, and the current variables — and they agree with what the canvas shows.
4. The "Démo" tab of each lab contains the script, the scenario with working "Charger" buttons, the complexity and the question cards.
5. The "Énoncé" tab shows the exact statement of section 3.
6. TP 2 and TP 4 produce their comparison table and chart and export CSV.
7. TP 3 plays a full game in each of its four modes, never exceeds TMO, and logs the protocol.
8. `flutter analyze` reports no error and no warning; `flutter build windows --release` succeeds.

---

## 12. How to work

1. Read this file completely. If `prof_c/` exists, read the C files and note any difference with section 3.3 before writing network code.
2. Build `lib/core/` first, with `tool/selftest.dart`, and make it pass.
3. Build the shared pieces: kit, transport bar, explanation panel, trace replay.
4. Build the labs in the order TP 1, TP 4, TP 2, TP 3 (simplest trace first).
5. Write `demo_content.dart` with all the French texts of section 7.
6. Run `flutter analyze` and the tests, launch the app, go through the acceptance checklist, fix what fails.
7. Finish with the README (French): prerequisites, `flutter create --platforms=windows,linux,macos .` if the platform folders are missing, `flutter pub get`, `flutter run -d windows`, `flutter build windows --release`, the command-line client and server, every setting and where it lives, and a one-page "avant la démonstration" checklist.

At the end, give me a short summary: what was built, what you verified by running it, and anything you could not verify.
