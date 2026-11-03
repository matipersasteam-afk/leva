import 'package:flutter_test/flutter_test.dart';
import 'package:leva/data/draw_repository.dart';
import 'package:leva/domain/draw/draw.dart';
import 'package:leva/domain/scoring/set_score.dart';

/// Partidos guardados a partir del draw, como los escribe `publish`.
List<StoredMatch> stored(Draw d) => [
  for (final m in d.matches)
    StoredMatch(
      id: m.id,
      categoryId: 'cat',
      stage: m.stage,
      round: m.round,
      order: m.order,
      status: m.isBye ? 'walkover' : 'scheduled',
      groupName: m.groupName,
      teamA: _team(m.a),
      teamB: _team(m.b),
      nextMatchId: m.nextMatchId,
      nextSlot: m.nextSlot,
    ),
];

MatchTeam? _team(DrawSlot s) => switch (s) {
  TeamSlot(:final teamId) => MatchTeam(
    regId: teamId,
    label: 'L-$teamId',
    playerUids: ['$teamId-1', '$teamId-2'],
  ),
  PlaceholderSlot(:final label) => MatchTeam(label: label),
  ByeSlot() => null,
};

/// Termina el partido: gana la pareja de menor número (t1 le gana a t2…).
StoredMatch played(StoredMatch m) {
  final a = m.teamA!.regId!, b = m.teamB!.regId!;
  final aWins = int.parse(a.substring(1)) < int.parse(b.substring(1));
  return StoredMatch(
    id: m.id,
    categoryId: m.categoryId,
    stage: m.stage,
    round: m.round,
    order: m.order,
    status: 'final',
    groupName: m.groupName,
    teamA: m.teamA,
    teamB: m.teamB,
    sets: aWins
        ? const [SetScore(6, 3), SetScore(6, 4)]
        : const [SetScore(3, 6), SetScore(4, 6)],
    winner: aWins ? 'A' : 'B',
  );
}

void main() {
  final teams = [
    for (var i = 1; i <= 8; i++)
      DrawTeam(id: 't$i', label: 'P$i', ranking: 100 - i, order: i),
  ];
  final draw = generateDraw(
    teams,
    const DrawConfig(kind: DrawKind.groupsKnockout, avoidSameClub: false),
  );
  List<String> ids(String g) =>
      draw.groups.firstWhere((x) => x.name == g).teamIds;

  test('el grupo sin terminar no llena la llave', () {
    final ms = stored(draw);
    final firstA = ms.indexWhere((m) => m.groupName == 'A');
    ms[firstA] = played(ms[firstA]);
    expect(groupFills(ms, 'A', ids('A')), isEmpty);
  });

  test('al terminar el grupo, 1º y 2º entran a su lugar en la llave', () {
    final ms = [
      for (final m in stored(draw)) m.groupName == 'A' ? played(m) : m,
    ];
    final fills = groupFills(ms, 'A', ids('A'));
    expect(fills, hasLength(2));
    // En el grupo A gana siempre el de menor número: el orden es por número.
    final order = [...ids('A')]
      ..sort(
        (x, y) =>
            int.parse(x.substring(1)).compareTo(int.parse(y.substring(1))),
      );
    for (final f in fills) {
      final place = parseGroupPlace(f.from)!;
      expect(place.group, 'A');
      expect(f.team.regId, order[place.place - 1]);
      expect(f.match.stage, DrawStage.knockout);
    }
    // El grupo B todavía no terminó: ningún lugar suyo se toca.
    expect(groupFills(ms, 'B', ids('B')), isEmpty);
  });

  test('no toca un partido de la llave que ya empezó', () {
    final ms = [
      for (final m in stored(draw))
        if (m.groupName == 'A')
          played(m)
        else if (m.stage == DrawStage.knockout && m.round == 1)
          StoredMatch(
            id: m.id,
            categoryId: m.categoryId,
            stage: m.stage,
            round: m.round,
            order: m.order,
            status: 'live',
            teamA: m.teamA,
            teamB: m.teamB,
            nextMatchId: m.nextMatchId,
            nextSlot: m.nextSlot,
          )
        else
          m,
    ];
    expect(groupFills(ms, 'A', ids('A')), isEmpty);
  });

  test('un lugar ya llenado se corrige si cambia la tabla', () {
    final ms = [
      for (final m in stored(draw)) m.groupName == 'A' ? played(m) : m,
    ];
    final f = groupFills(ms, 'A', ids('A')).first;
    // Simula que en el lugar quedó otra pareja (resultado corregido).
    final wrong = ids('A').firstWhere((id) => id != f.team.regId);
    final i = ms.indexWhere((m) => m.id == f.match.id);
    final m = ms[i];
    final placed = MatchTeam(regId: wrong, label: 'L-$wrong', from: f.from);
    ms[i] = StoredMatch(
      id: m.id,
      categoryId: m.categoryId,
      stage: m.stage,
      round: m.round,
      order: m.order,
      status: m.status,
      teamA: f.slot == 0 ? placed : m.teamA,
      teamB: f.slot == 1 ? placed : m.teamB,
      nextMatchId: m.nextMatchId,
      nextSlot: m.nextSlot,
    );
    final again = groupFills(ms, 'A', ids('A'));
    expect(
      again
          .where((x) => x.match.id == m.id && x.slot == f.slot)
          .single
          .team
          .regId,
      f.team.regId,
    );
  });

  test('lee sets guardados como mapas y como listas viejas', () {
    expect(
      setFromJson({'a': 7, 'b': 6, 'tbA': 7, 'tbB': 5}),
      const SetScore(7, 6, tiebreakA: 7, tiebreakB: 5),
    );
    expect(
      setFromJson({'a': 10, 'b': 8, 'stb': true}),
      const SetScore(10, 8, superTiebreak: true),
    );
    expect(setFromJson([6, 4]), const SetScore(6, 4));
    expect(setFromJson('x'), isNull);
  });
}
