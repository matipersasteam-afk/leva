import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:leva/domain/draw/draw.dart';
import 'package:leva/domain/scoring/set_score.dart';

/// n parejas t1..tn con ranking descendente y clubes rotando entre [clubs].
List<DrawTeam> teams(
  int n, {
  List<String> clubs = const ['A', 'B', 'C', 'D'],
  bool sameRanking = false,
}) => [
  for (var i = 1; i <= n; i++)
    DrawTeam(
      id: 't$i',
      label: 'Pareja $i',
      clubs: {clubs[(i - 1) % clubs.length]},
      ranking: sameRanking ? 0 : 1000 - i,
      order: i,
    ),
];

Map<String, DrawTeam> byId(List<DrawTeam> ts) => {for (final t in ts) t.id: t};

Set<String> teamIdsIn(Draw d) => {
  for (final m in d.matches)
    for (final s in [m.a, m.b])
      if (s is TeamSlot) s.teamId,
};

void main() {
  group('siembra', () {
    test('por ranking, y a igual ranking el primero en inscribirse', () {
      final ts = [
        const DrawTeam(id: 'x', label: 'X', ranking: 10, order: 3),
        const DrawTeam(id: 'y', label: 'Y', ranking: 50, order: 2),
        const DrawTeam(id: 'z', label: 'Z', ranking: 10, order: 1),
      ];
      expect(seedTeams(ts).map((t) => t.id), ['y', 'z', 'x']);
      expect(seedTeams(ts, byRanking: false).map((t) => t.id), ['z', 'y', 'x']);
    });

    test('posiciones estándar: los mejores solo se cruzan al final', () {
      expect(seedPositions(8), [1, 8, 4, 5, 2, 7, 3, 6]);
      expect(seedPositions(4), [1, 4, 2, 3]);
      expect(bracketSize(5), 8);
      expect(bracketSize(16), 16);
    });

    test('"Sin club" no cuenta como club compartido', () {
      const a = DrawTeam(id: 'a', label: 'a', clubs: {'Sin club'});
      const b = DrawTeam(id: 'b', label: 'b', clubs: {' sin club '});
      const c = DrawTeam(id: 'c', label: 'c', clubs: {'Zapopan Pádel'});
      const d = DrawTeam(
        id: 'd',
        label: 'd',
        clubs: {'zapopan pádel ', 'Andares'},
      );
      expect(a.sharesClubWith(b), isFalse);
      expect(c.sharesClubWith(d), isTrue);
    });
  });

  group('eliminación directa', () {
    test('16 parejas: 15 partidos, 4 rondas, final sin siguiente', () {
      final d = generateDraw(
        teams(16),
        const DrawConfig(kind: DrawKind.singleElim),
      );
      expect(d.matches, hasLength(15));
      expect(d.knockoutRounds, 4);
      expect(d.matches.where((m) => m.nextMatchId == null).single.round, 4);
      expect(teamIdsIn(d), hasLength(16));
    });

    test(
      '6 parejas: los 2 mejores sembrados tienen bye y pasan solos a semis',
      () {
        final d = generateDraw(
          teams(6),
          const DrawConfig(kind: DrawKind.singleElim),
        );
        final first = d.matches.where((m) => m.round == 1).toList();
        final byes = first.where((m) => m.isBye).toList();
        expect(byes, hasLength(2));
        final byeTeams = {
          for (final m in byes) (m.a is TeamSlot ? m.a : m.b) as TeamSlot,
        };
        expect(byeTeams.map((s) => s.teamId), unorderedEquals(['t1', 't2']));
        // Avanzaron a la ronda 2.
        final r2 = d.matches.where((m) => m.round == 2);
        final inR2 = {
          for (final m in r2) ...[m.a, m.b],
        }.whereType<TeamSlot>().map((s) => s.teamId);
        expect(inR2, containsAll(['t1', 't2']));
      },
    );

    test('1 y 2 de siembra quedan en mitades opuestas del cuadro', () {
      final d = generateDraw(
        teams(8),
        const DrawConfig(kind: DrawKind.singleElim),
      );
      final first = d.matches.where((m) => m.round == 1).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      int half(String id) =>
          first.indexWhere((m) => m.a == TeamSlot(id) || m.b == TeamSlot(id)) <
              2
          ? 0
          : 1;
      expect(half('t1'), isNot(half('t2')));
    });

    test('evita cruzar parejas del mismo club en la primera ronda', () {
      // 8 parejas de solo 2 clubes alternados: hay solución sin cruces.
      for (var seed = 1; seed <= 50; seed++) {
        final ts = teams(8, clubs: ['Andares', 'Zapopan']);
        final d = generateDraw(
          ts,
          DrawConfig(kind: DrawKind.singleElim, seed: seed),
        );
        expect(d.warnings, isEmpty, reason: 'semilla $seed');
        final map = byId(ts);
        for (final m in d.matches.where((m) => m.round == 1)) {
          final a = map[(m.a as TeamSlot).teamId]!,
              b = map[(m.b as TeamSlot).teamId]!;
          expect(
            a.sharesClubWith(b),
            isFalse,
            reason: 'semilla $seed: ${m.id}',
          );
        }
      }
    });

    test('si es imposible evitarlo, avisa en lugar de fallar', () {
      final ts = teams(4, clubs: ['Andares']);
      final d = generateDraw(ts, const DrawConfig(kind: DrawKind.singleElim));
      expect(d.warnings, isNotEmpty);
      expect(d.warnings.first.message, contains('mismo club'));
    });

    test('misma semilla, mismo draw; otra semilla puede sortear distinto', () {
      final a = generateDraw(
        teams(12),
        const DrawConfig(kind: DrawKind.singleElim, seed: 7),
      );
      final b = generateDraw(
        teams(12),
        const DrawConfig(kind: DrawKind.singleElim, seed: 7),
      );
      expect(a.matches.map((m) => '$m'), b.matches.map((m) => '$m'));
    });
  });

  group('grupos + eliminatoria', () {
    test('cantidad de grupos sin grupos de menos de 3', () {
      expect(groupCount(16, 4), 4);
      expect(groupCount(10, 4), 3); // 4, 3, 3
      expect(groupCount(5, 4), 1);
      expect(groupCount(7, 3), 2); // 4 y 3
    });

    test('16 parejas en 4 grupos de 4 con serpentina', () {
      final d = generateDraw(
        teams(16, clubs: ['']),
        const DrawConfig(kind: DrawKind.groupsKnockout),
      );
      expect(d.groups.map((g) => g.name), ['A', 'B', 'C', 'D']);
      expect(d.groups.every((g) => g.teamIds.length == 4), isTrue);
      // Cabezas de serie 1..4 cada uno en un grupo distinto, y 5..8 al revés.
      expect(d.groups.map((g) => g.teamIds.first), ['t1', 't2', 't3', 't4']);
      expect(d.groups.map((g) => g.teamIds[1]), ['t8', 't7', 't6', 't5']);
    });

    test('todos contra todos dentro del grupo: 6 partidos por grupo de 4, sin repetir', () {
      final d = generateDraw(
        teams(16),
        const DrawConfig(kind: DrawKind.groupsKnockout),
      );
      final ga = d.groupMatches.where((m) => m.groupName == 'A').toList();
      expect(ga, hasLength(6));
      final pairs = {
        for (final m in ga)
          {(m.a as TeamSlot).teamId, (m.b as TeamSlot).teamId}.join('|'),
      };
      expect(pairs, hasLength(6));
      // Nadie juega dos veces en la misma fecha.
      for (var r = 1; r <= 3; r++) {
        final playing = ga
            .where((m) => m.round == r)
            .expand((m) => [m.a, m.b])
            .toList();
        expect(playing.toSet().length, playing.length);
      }
    });

    test('grupo de 3: cada pareja descansa una fecha', () {
      final d = generateDraw(
        teams(9),
        const DrawConfig(kind: DrawKind.groupsKnockout, groupSize: 3),
      );
      expect(d.groups.every((g) => g.teamIds.length == 3), isTrue);
      expect(d.groupMatches.where((m) => m.groupName == 'A'), hasLength(3));
    });

    test('llave de clasificados: 4 grupos × 2 = cuartos; nadie repite grupo en la primera ronda', () {
      final d = generateDraw(
        teams(16),
        const DrawConfig(kind: DrawKind.groupsKnockout),
      );
      final ko = d.knockoutMatches.where((m) => m.round == 1).toList();
      expect(ko, hasLength(4));
      for (final m in ko) {
        final a = (m.a as PlaceholderSlot).label,
            b = (m.b as PlaceholderSlot).label;
        expect(
          a.substring(a.length - 1),
          isNot(b.substring(b.length - 1)),
          reason: '$a vs $b',
        );
        expect(
          a.startsWith('1º') || b.startsWith('1º'),
          isTrue,
          reason: 'cada 1º juega contra un 2º',
        );
      }
      expect(knockoutRoundName(1, d.knockoutRounds), 'Cuartos');
      expect(
        d.knockoutMatches.last.b,
        const PlaceholderSlot('Ganador Semifinal 2'),
      );
    });

    test('3 grupos × 2 = 6 clasificados: los 1º mejores tienen bye', () {
      final d = generateDraw(
        teams(12),
        const DrawConfig(kind: DrawKind.groupsKnockout),
      );
      final first = d.knockoutMatches.where((m) => m.round == 1).toList();
      expect(first, hasLength(4));
      expect(first.where((m) => m.isBye), hasLength(2));
    });

    test(
      'reparte parejas del mismo club en grupos distintos cuando se puede',
      () {
        // 8 parejas, 2 grupos; 2 clubes con 4 parejas cada uno → cada grupo 2 y 2 (inevitable).
        // Con 4 clubes de 2 parejas: se puede separar a todos.
        final ts = teams(8, clubs: ['A', 'B', 'C', 'D']);
        final d = generateDraw(
          ts,
          const DrawConfig(kind: DrawKind.groupsKnockout),
        );
        expect(d.warnings, isEmpty);
      },
    );
  });

  group('americano y relámpago', () {
    test('americano: todos contra todos en un solo grupo', () {
      final d = generateDraw(
        teams(6),
        const DrawConfig(kind: DrawKind.americano),
      );
      expect(d.groups.single.teamIds, hasLength(6));
      expect(d.matches, hasLength(15)); // 6*5/2
      expect(d.knockoutMatches, isEmpty);
      expect(d.matches.map((m) => m.round).toSet(), hasLength(5));
    });

    test('relámpago: grupos de 3 y pasa solo el primero', () {
      final d = generateDraw(
        teams(12),
        const DrawConfig(kind: DrawKind.relampago),
      );
      expect(d.groups, hasLength(4));
      expect(d.groups.every((g) => g.teamIds.length == 3), isTrue);
      final ko = d.knockoutMatches.where((m) => m.round == 1);
      expect(ko, hasLength(2)); // 4 primeros → semis
      expect(
        ko.every((m) => (m.a as PlaceholderSlot).label.startsWith('1º')),
        isTrue,
      );
    });

    test('pocas parejas: error claro', () {
      expect(
        () => generateDraw(
          teams(2),
          const DrawConfig(kind: DrawKind.groupsKnockout),
        ),
        throwsA(
          isA<DrawError>().having(
            (e) => e.message,
            'mensaje',
            contains('al menos 3'),
          ),
        ),
      );
      expect(
        () => generateDraw([
          ...teams(3),
          teams(1).first,
        ], const DrawConfig(kind: DrawKind.americano)),
        throwsA(isA<DrawError>()),
      );
    });
  });

  group('ajuste manual', () {
    test('intercambiar dos parejas las mueve en grupos y partidos', () {
      final ts = teams(8);
      final d = generateDraw(
        ts,
        const DrawConfig(kind: DrawKind.groupsKnockout),
      );
      final a = d.groups[0].teamIds.first, b = d.groups[1].teamIds.first;
      final s = swapTeams(d, a, b, byId(ts));
      expect(s.groups[0].teamIds.first, b);
      expect(s.groups[1].teamIds.first, a);
      final inA = s.groupMatches
          .where((m) => m.groupName == 'A')
          .expand((m) => [m.a, m.b]);
      expect(inA, contains(TeamSlot(b)));
      expect(inA, isNot(contains(TeamSlot(a))));
    });

    test('si el cambio junta dos del mismo club, avisa', () {
      final ts = [
        for (var i = 1; i <= 8; i++)
          DrawTeam(
            id: 't$i',
            label: 'P$i',
            clubs: {i <= 2 ? 'Andares' : 'Club $i'},
            ranking: 100 - i,
          ),
      ];
      final d = generateDraw(
        ts,
        const DrawConfig(kind: DrawKind.groupsKnockout),
      );
      expect(d.warnings, isEmpty);
      final gOfT1 = d.groups.indexWhere((g) => g.teamIds.contains('t1'));
      final other = d.groups[gOfT1].teamIds.firstWhere((id) => id != 't1');
      final s = swapTeams(d, other, 't2', byId(ts));
      expect(s.warnings.single.message, contains('mismo club'));
    });
  });

  group('tabla de posiciones', () {
    const ids = ['a', 'b', 'c'];
    PlayedMatch m(String x, String y, List<List<int>> sets) => PlayedMatch(
      teamA: x,
      teamB: y,
      sets: [for (final s in sets) SetScore(s[0], s[1])],
    );

    test('ordena por ganados, luego diferencia de sets y de games', () {
      final rows = computeStandings(ids, [
        m('a', 'b', [
          [6, 0],
          [6, 0],
        ]),
        m('b', 'c', [
          [6, 4],
          [6, 4],
        ]),
        m('c', 'a', [
          [6, 4],
          [6, 4],
        ]),
      ]);
      // Todos 1 ganado; a: sets 2-2 games 20-12 (+8); b: 2-2, 12-20 (-8)... (b: 12-20 vs a, +4 vs c)
      expect(rows.map((r) => r.teamId), ['a', 'c', 'b']);
      expect(rows.first.won, 1);
    });

    test('resultado directo desempata a dos', () {
      final rows = computeStandings(
        ['a', 'b', 'c'],
        [
          m('a', 'b', [
            [6, 4],
            [4, 6],
            [6, 4],
          ]),
          m('b', 'c', [
            [6, 4],
            [4, 6],
            [6, 4],
          ]),
          m('c', 'a', [
            [0, 6],
            [0, 6],
          ]),
        ],
      );
      expect(rows.first.teamId, 'a');
    });

    test('súper tie-break cuenta como set pero no suma games', () {
      final rows = computeStandings(
        ['a', 'b'],
        [
          PlayedMatch(
            teamA: 'a',
            teamB: 'b',
            sets: const [
              SetScore(6, 4),
              SetScore(3, 6),
              SetScore(10, 8, superTiebreak: true),
            ],
          ),
        ],
      );
      final a = rows.firstWhere((r) => r.teamId == 'a');
      expect(
        [a.won, a.setsFor, a.setsAgainst, a.gamesFor, a.gamesAgainst],
        [1, 2, 1, 9, 10],
      );
    });

    test('americano: manda el total de games', () {
      final rows = computeStandings(
        ['a', 'b', 'c'],
        [
          m('a', 'b', [
            [6, 5],
          ]),
          m('b', 'c', [
            [6, 0],
          ]),
          m('a', 'c', [
            [6, 5],
          ]),
        ],
        byGames: true,
      );
      expect(rows.first.teamId, 'a'); // 12 games
      expect(rows[1].teamId, 'b'); // 11 games
    });
  });

  test('propiedades en 300 draws aleatorios: cada pareja aparece una vez en primera ronda o grupo', () {
    final rng = Random(3);
    for (var i = 0; i < 300; i++) {
      final n = 3 + rng.nextInt(30);
      final kind = DrawKind.values[i % DrawKind.values.length];
      final ts = teams(
        n,
        clubs: ['A', 'B', 'C', 'D', 'E'].sublist(0, 1 + rng.nextInt(5)),
      );
      final d = generateDraw(
        ts,
        DrawConfig(kind: kind, seed: i, groupSize: 3 + rng.nextInt(2)),
      );
      if (kind == DrawKind.singleElim) {
        final first = d.matches
            .where((m) => m.round == 1)
            .expand((m) => [m.a, m.b])
            .whereType<TeamSlot>();
        expect(first.length, n, reason: 'n=$n');
        expect(first.toSet().length, n);
      } else {
        final all = d.groups.expand((g) => g.teamIds).toList();
        expect(all.length, n);
        expect(all.toSet().length, n);
        expect(
          d.groups.every((g) => g.teamIds.length >= 3),
          isTrue,
          reason: 'n=$n ${d.groups.map((g) => g.teamIds.length)}',
        );
      }
      // La llave siempre termina en una única final.
      if (d.knockoutMatches.isNotEmpty) {
        expect(
          d.knockoutMatches.where((m) => m.nextMatchId == null),
          hasLength(1),
        );
      }
    }
  });

  test('grupos: el reparto nunca empeora los cruces de club respecto a la serpentina pura', () {
    final rng = Random(11);
    for (var i = 0; i < 200; i++) {
      final n = 6 + rng.nextInt(20);
      final clubs = ['A', 'B', 'C', 'D', 'E', 'F'];
      final ts = [
        for (var k = 1; k <= n; k++)
          DrawTeam(
            id: 't$k',
            label: 'P$k',
            clubs: {
              clubs[rng.nextInt(clubs.length)],
              clubs[rng.nextInt(clubs.length)],
            },
            ranking: 1000 - k,
            order: k,
          ),
      ];
      final repaired = generateDraw(
        ts,
        DrawConfig(kind: DrawKind.groupsKnockout, seed: i),
      );
      final raw = generateDraw(
        ts,
        DrawConfig(
          kind: DrawKind.groupsKnockout,
          seed: i,
          avoidSameClub: false,
        ),
      );
      final rawClashes = clubWarnings(raw.groups, raw.matches, byId(ts)).length;
      expect(
        repaired.warnings.length,
        lessThanOrEqualTo(rawClashes),
        reason: 'n=$n',
      );
      // Los cabezas de serie siguen en su grupo.
      expect(
        repaired.groups.map((g) => g.teamIds.first),
        raw.groups.map((g) => g.teamIds.first),
      );
    }
  });
}
