/// Generación del draw: siembra, eliminación directa, grupos + llave,
/// americano y relámpago. Dart puro y determinista (misma semilla → mismo draw).
library;

import 'dart:math';

import 'draw_models.dart';

/// Formato del draw. Los ids coinciden con `DrawFormat` del evento.
enum DrawKind { groupsKnockout, singleElim, americano, relampago }

class DrawConfig {
  const DrawConfig({
    required this.kind,
    this.groupSize = 4,
    this.qualifiersPerGroup = 2,
    this.avoidSameClub = true,
    this.seedByRanking = true,
    this.seed = 1,
  });

  final DrawKind kind;

  /// Tamaño preferido de grupo (3 o 4; algunos grupos pueden quedar de uno menos).
  final int groupSize;

  /// Pasan a la llave por grupo.
  final int qualifiersPerGroup;
  final bool avoidSameClub;

  /// Si es false, el orden es el de inscripción.
  final bool seedByRanking;

  /// Semilla del azar (los no sembrados se sortean).
  final int seed;

  /// Relámpago: grupos de 3 y pasa solo el primero (jornada corta).
  /// Las reglas de puntuación cortas (set a 4, punto de oro) se configuran en el evento.
  DrawConfig get effective => kind == DrawKind.relampago
      ? DrawConfig(
          kind: kind,
          groupSize: 3,
          qualifiersPerGroup: 1,
          avoidSameClub: avoidSameClub,
          seedByRanking: seedByRanking,
          seed: seed,
        )
      : this;
}

class DrawError implements Exception {
  const DrawError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Genera el draw para las parejas confirmadas.
Draw generateDraw(List<DrawTeam> teams, DrawConfig config) {
  final c = config.effective;
  final minTeams = c.kind == DrawKind.singleElim ? 2 : 3;
  if (teams.length < minTeams) {
    throw DrawError(
      'Se necesitan al menos $minTeams parejas confirmadas para este formato.',
    );
  }
  final ids = {for (final t in teams) t.id};
  if (ids.length != teams.length) {
    throw const DrawError('Hay parejas repetidas.');
  }

  final seeded = seedTeams(teams, byRanking: c.seedByRanking);
  final rng = Random(c.seed);
  return switch (c.kind) {
    DrawKind.singleElim => _singleElim(seeded, c, rng),
    DrawKind.groupsKnockout || DrawKind.relampago => _groupsKnockout(seeded, c),
    DrawKind.americano => _americano(seeded),
  };
}

/// Orden de siembra: más ranking primero; empate → el que se inscribió antes.
List<DrawTeam> seedTeams(List<DrawTeam> teams, {bool byRanking = true}) {
  final list = [...teams];
  list.sort((x, y) {
    if (byRanking && x.ranking != y.ranking) {
      return y.ranking.compareTo(x.ranking);
    }
    return x.order.compareTo(y.order);
  });
  return list;
}

/// Potencia de 2 mayor o igual a n.
int bracketSize(int n) {
  var s = 1;
  while (s < n) {
    s <<= 1;
  }
  return s;
}

/// Posiciones estándar de siembra: para 8 → [1, 8, 4, 5, 2, 7, 3, 6].
/// Parejas consecutivas juegan entre sí (1v8, 4v5, 2v7, 3v6), así los
/// mejores sembrados solo se cruzan al final.
List<int> seedPositions(int size) {
  var order = [1];
  while (order.length < size) {
    final n = order.length * 2;
    order = [
      for (final s in order) ...[s, n + 1 - s],
    ];
  }
  return order;
}

// ---------------------------------------------------------------------------
// Eliminación directa
// ---------------------------------------------------------------------------

Draw _singleElim(List<DrawTeam> seeded, DrawConfig c, Random rng) {
  final size = bracketSize(seeded.length);
  // Sembrados fijos: 1/4 del cuadro (mínimo 2). El resto se sortea.
  final protectedCount = max(2, size ~/ 4).clamp(0, seeded.length);
  final fixed = seeded.take(protectedCount).toList();
  final rest = seeded.skip(protectedCount).toList()..shuffle(rng);
  final bySeed = [...fixed, ...rest];

  // Ubicación en el cuadro: posición → pareja (null = bye).
  final positions = seedPositions(size);
  final slots = <DrawTeam?>[
    for (final s in positions) s <= bySeed.length ? bySeed[s - 1] : null,
  ];
  final protectedIds = {for (final t in fixed) t.id};

  final warnings = <DrawWarning>[];
  if (c.avoidSameClub) {
    final unresolved = _repairFirstRound(
      slots,
      protectedIds,
      (a, b) => a.sharesClubWith(b),
    );
    for (final pair in unresolved) {
      warnings.add(
        DrawWarning(
          '${pair.$1.label} y ${pair.$2.label} son del mismo club y se cruzan en la primera ronda.',
        ),
      );
    }
  }
  final matches = _knockoutMatches([
    for (final t in slots) t == null ? const ByeSlot() : TeamSlot(t.id),
  ]);
  return Draw(groups: const [], matches: matches, warnings: warnings);
}

/// Intercambia parejas no protegidas para que ningún partido de primera ronda
/// tenga un conflicto. Devuelve los conflictos que no se pudieron resolver.
List<(DrawTeam, DrawTeam)> _repairFirstRound(
  List<DrawTeam?> slots,
  Set<String> protectedIds,
  bool Function(DrawTeam a, DrawTeam b) conflict,
) {
  bool bad(int match) {
    final a = slots[match * 2], b = slots[match * 2 + 1];
    return a != null && b != null && conflict(a, b);
  }

  final matchCount = slots.length ~/ 2;
  for (var pass = 0; pass < 3; pass++) {
    var changed = false;
    for (var m = 0; m < matchCount; m++) {
      if (!bad(m)) continue;
      // Movemos al lado no protegido del partido en conflicto.
      final candidates = [
        m * 2 + 1,
        m * 2,
      ].where((i) => !protectedIds.contains(slots[i]!.id));
      var fixed = false;
      for (final i in candidates) {
        for (var j = 0; j < slots.length && !fixed; j++) {
          if (j ~/ 2 == m ||
              slots[j] == null ||
              protectedIds.contains(slots[j]!.id)) {
            continue;
          }
          final other = j ~/ 2;
          final tmp = slots[i];
          slots[i] = slots[j];
          slots[j] = tmp;
          if (!bad(m) && !bad(other)) {
            fixed = true;
            changed = true;
          } else {
            slots[j] = slots[i];
            slots[i] = tmp;
          }
        }
        if (fixed) break;
      }
    }
    if (!changed) break;
  }
  return [
    for (var m = 0; m < matchCount; m++)
      if (bad(m)) (slots[m * 2]!, slots[m * 2 + 1]!),
  ];
}

/// Arma todas las rondas de la llave a partir de los lugares de la primera.
/// Los byes hacen avanzar a su rival directamente a la segunda ronda.
List<DrawMatch> _knockoutMatches(List<DrawSlot> first) {
  final size = first.length;
  final rounds = (log(size) / ln2).round();
  final matches = <DrawMatch>[];
  final names = <int, String>{};

  String id(int round, int order) => 'ko-$round-$order';

  for (var r = 1; r <= rounds; r++) {
    final count = size >> r;
    for (var o = 0; o < count; o++) {
      final last = r == rounds;
      final DrawSlot a, b;
      if (r == 1) {
        a = first[o * 2];
        b = first[o * 2 + 1];
      } else {
        a = PlaceholderSlot('Ganador ${names[(r - 1) * 1000 + o * 2]}');
        b = PlaceholderSlot('Ganador ${names[(r - 1) * 1000 + o * 2 + 1]}');
      }
      names[r * 1000 + o] =
          '${knockoutRoundName(r, rounds)}${count > 1 ? ' ${o + 1}' : ''}';
      matches.add(
        DrawMatch(
          id: id(r, o),
          stage: DrawStage.knockout,
          round: r,
          order: o,
          a: a,
          b: b,
          nextMatchId: last ? null : id(r + 1, o ~/ 2),
          nextSlot: last ? null : o % 2,
        ),
      );
    }
  }
  return propagateByes(matches);
}

/// Si un partido tiene bye, su rival pasa directo al siguiente.
List<DrawMatch> propagateByes(List<DrawMatch> matches) {
  final byId = {for (final m in matches) m.id: m};
  for (final m in matches.where((m) => m.round == 1 && m.isBye)) {
    final winner = m.a is ByeSlot ? m.b : m.a;
    final next = m.nextMatchId == null ? null : byId[m.nextMatchId];
    if (next == null || winner is ByeSlot) continue;
    byId[next.id] = m.nextSlot == 0
        ? byId[next.id]!.copyWith(a: winner)
        : byId[next.id]!.copyWith(b: winner);
  }
  return [for (final m in matches) byId[m.id]!];
}

// ---------------------------------------------------------------------------
// Grupos + eliminatoria (y relámpago)
// ---------------------------------------------------------------------------

/// Cuántos grupos: del tamaño preferido, sin grupos de menos de 3.
int groupCount(int teams, int preferredSize) {
  var g = (teams / preferredSize).ceil();
  while (g > 1 && teams / g < 3) {
    g--;
  }
  return max(1, g);
}

Draw _groupsKnockout(List<DrawTeam> seeded, DrawConfig c) {
  final g = groupCount(seeded.length, c.groupSize);
  // Serpentina: 1→A, 2→B, …, luego vuelve (B…A) para equilibrar el nivel.
  final groups = List.generate(g, (_) => <DrawTeam>[]);
  for (var i = 0; i < seeded.length; i++) {
    final row = i ~/ g, col = i % g;
    groups[row.isEven ? col : g - 1 - col].add(seeded[i]);
  }

  final warnings = <DrawWarning>[];
  if (c.avoidSameClub) _repairGroups(groups, warnings);

  final matches = <DrawMatch>[];
  final drawGroups = <DrawGroup>[];
  for (var gi = 0; gi < g; gi++) {
    final name = groupLetter(gi);
    drawGroups.add(DrawGroup(name, [for (final t in groups[gi]) t.id]));
    matches.addAll(
      _roundRobin(
        [for (final t in groups[gi]) t.id],
        DrawStage.group,
        'g$name',
        name,
      ),
    );
  }

  // Llave con los clasificados: primero los 1º, después los 2º…
  final q = min(c.qualifiersPerGroup, groups.map((x) => x.length).reduce(min));
  final qualifiers = <({String label, int group, int place})>[
    for (var p = 1; p <= q; p++)
      for (var gi = 0; gi < g; gi++)
        (label: '$pº Grupo ${groupLetter(gi)}', group: gi, place: p),
  ];
  if (qualifiers.length >= 2) {
    final size = bracketSize(qualifiers.length);
    final positions = seedPositions(size);
    final slots = [
      for (final s in positions)
        s <= qualifiers.length ? qualifiers[s - 1] : null,
    ];
    _repairSameGroup(slots, warnings);
    matches.addAll(
      _knockoutMatches([
        for (final s in slots)
          s == null ? const ByeSlot() : PlaceholderSlot(s.label),
      ]),
    );
  }
  return Draw(groups: drawGroups, matches: matches, warnings: warnings);
}

/// Reparte para minimizar parejas del mismo club dentro de un grupo:
/// intercambia parejas del mismo "bombo" (fila de la serpentina) entre grupos
/// mientras el total de cruces baje. Los cabezas de serie (fila 0) no se mueven.
void _repairGroups(List<List<DrawTeam>> groups, List<DrawWarning> warnings) {
  int clashesIn(List<DrawTeam> grp) {
    var n = 0;
    for (var i = 0; i < grp.length; i++) {
      for (var j = i + 1; j < grp.length; j++) {
        if (grp[i].sharesClubWith(grp[j])) n++;
      }
    }
    return n;
  }

  var improved = true;
  var guard = 0;
  while (improved && guard++ < 50) {
    improved = false;
    final rows = groups.map((g) => g.length).reduce(max);
    // De abajo hacia arriba: ante un choque se mueve la pareja de peor siembra.
    for (var row = rows - 1; row >= 1; row--) {
      for (var gi = 0; gi < groups.length; gi++) {
        for (var gj = gi + 1; gj < groups.length; gj++) {
          if (row >= groups[gi].length || row >= groups[gj].length) continue;
          final before = clashesIn(groups[gi]) + clashesIn(groups[gj]);
          if (before == 0) continue;
          final t = groups[gi][row];
          groups[gi][row] = groups[gj][row];
          groups[gj][row] = t;
          final after = clashesIn(groups[gi]) + clashesIn(groups[gj]);
          if (after < before) {
            improved = true;
          } else {
            groups[gj][row] = groups[gi][row];
            groups[gi][row] = t;
          }
        }
      }
    }
  }

  for (var gi = 0; gi < groups.length; gi++) {
    final grp = groups[gi];
    for (var i = 0; i < grp.length; i++) {
      for (var j = i + 1; j < grp.length; j++) {
        if (grp[i].sharesClubWith(grp[j])) {
          warnings.add(
            DrawWarning(
              '${grp[i].label} y ${grp[j].label} son del mismo club y comparten el Grupo ${groupLetter(gi)}.',
            ),
          );
        }
      }
    }
  }
}

/// En la primera ronda de la llave, que no se crucen dos del mismo grupo.
void _repairSameGroup(
  List<({String label, int group, int place})?> slots,
  List<DrawWarning> warnings,
) {
  bool bad(int m) {
    final a = slots[m * 2], b = slots[m * 2 + 1];
    return a != null && b != null && a.group == b.group;
  }

  final n = slots.length ~/ 2;
  for (var m = 0; m < n; m++) {
    if (!bad(m)) continue;
    // Movemos al de peor ubicación (no al primero de grupo).
    final i = slots[m * 2]!.place >= slots[m * 2 + 1]!.place
        ? m * 2
        : m * 2 + 1;
    for (var j = 0; j < slots.length; j++) {
      if (j ~/ 2 == m ||
          slots[j] == null ||
          slots[j]!.place != slots[i]!.place) {
        continue;
      }
      final tmp = slots[i];
      slots[i] = slots[j];
      slots[j] = tmp;
      if (!bad(m) && !bad(j ~/ 2)) break;
      slots[j] = slots[i];
      slots[i] = tmp;
    }
  }
  for (var m = 0; m < n; m++) {
    if (bad(m)) {
      warnings.add(
        DrawWarning(
          '${slots[m * 2]!.label} y ${slots[m * 2 + 1]!.label} se cruzan en la primera ronda.',
        ),
      );
    }
  }
}

/// Todos contra todos (método del círculo). Con número impar, una pareja descansa cada fecha.
List<DrawMatch> _roundRobin(
  List<String> ids,
  DrawStage stage,
  String prefix,
  String? groupName,
) {
  final list = <String?>[...ids];
  if (list.length.isOdd) list.add(null);
  final n = list.length;
  final matches = <DrawMatch>[];
  for (var r = 0; r < n - 1; r++) {
    var order = 0;
    for (var i = 0; i < n ~/ 2; i++) {
      final a = list[i], b = list[n - 1 - i];
      if (a == null || b == null) continue;
      matches.add(
        DrawMatch(
          id: '$prefix-${r + 1}-$order',
          stage: stage,
          round: r + 1,
          order: order++,
          a: TeamSlot(a),
          b: TeamSlot(b),
          groupName: groupName,
        ),
      );
    }
    // Rotación: el primero queda fijo.
    list.insert(1, list.removeLast());
  }
  return matches;
}

// ---------------------------------------------------------------------------
// Americano (por parejas fijas): todos contra todos, gana quien suma más games.
// ---------------------------------------------------------------------------

Draw _americano(List<DrawTeam> seeded) {
  final ids = [for (final t in seeded) t.id];
  return Draw(
    groups: [DrawGroup('Americano', ids)],
    matches: _roundRobin(ids, DrawStage.americano, 'am', 'Americano'),
  );
}

// ---------------------------------------------------------------------------
// Ajuste manual
// ---------------------------------------------------------------------------

/// Intercambia dos parejas en todo el draw (grupos y partidos) y recalcula avisos.
Draw swapTeams(Draw draw, String idA, String idB, Map<String, DrawTeam> teams) {
  DrawSlot sw(DrawSlot s) => switch (s) {
    TeamSlot(:final teamId) when teamId == idA => TeamSlot(idB),
    TeamSlot(:final teamId) when teamId == idB => TeamSlot(idA),
    _ => s,
  };
  String swId(String id) => id == idA ? idB : (id == idB ? idA : id);

  final groups = [
    for (final g in draw.groups)
      DrawGroup(g.name, [for (final id in g.teamIds) swId(id)]),
  ];
  final matches = [
    for (final m in draw.matches) m.copyWith(a: sw(m.a), b: sw(m.b)),
  ];
  return Draw(
    groups: groups,
    matches: matches,
    warnings: clubWarnings(groups, matches, teams),
  );
}

/// Avisos de mismo club (grupos y primera ronda de la llave) para un draw dado.
List<DrawWarning> clubWarnings(
  List<DrawGroup> groups,
  List<DrawMatch> matches,
  Map<String, DrawTeam> teams,
) {
  final out = <DrawWarning>[];
  for (final g in groups) {
    final ts = [for (final id in g.teamIds) teams[id]]
        .whereType<DrawTeam>()
        .toList();
    for (var i = 0; i < ts.length; i++) {
      for (var j = i + 1; j < ts.length; j++) {
        if (ts[i].sharesClubWith(ts[j])) {
          out.add(
            DrawWarning(
              '${ts[i].label} y ${ts[j].label} son del mismo club y comparten el Grupo ${g.name}.',
            ),
          );
        }
      }
    }
  }
  if (groups.isEmpty) {
    for (final m in matches.where(
      (m) => m.stage == DrawStage.knockout && m.round == 1,
    )) {
      final a = m.a is TeamSlot ? teams[(m.a as TeamSlot).teamId] : null;
      final b = m.b is TeamSlot ? teams[(m.b as TeamSlot).teamId] : null;
      if (a != null && b != null && a.sharesClubWith(b)) {
        out.add(
          DrawWarning(
            '${a.label} y ${b.label} son del mismo club y se cruzan en la primera ronda.',
            matchId: m.id,
          ),
        );
      }
    }
  }
  return out;
}
