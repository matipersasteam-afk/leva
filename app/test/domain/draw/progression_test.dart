import 'package:flutter_test/flutter_test.dart';
import 'package:leva/domain/draw/draw.dart';
import 'package:leva/domain/scoring/result_validation.dart';
import 'package:leva/domain/scoring/scoring_rules.dart';
import 'package:leva/domain/scoring/set_score.dart';

void main() {
  group('parseGroupPlace', () {
    test('lee los lugares que genera el motor de draw', () {
      final teams = [
        for (var i = 1; i <= 8; i++)
          DrawTeam(id: 't$i', label: 'P$i', ranking: 100 - i, order: i),
      ];
      final d = generateDraw(
        teams,
        const DrawConfig(kind: DrawKind.groupsKnockout),
      );
      final labels = [
        for (final m in d.knockoutMatches.where((m) => m.round == 1))
          for (final s in [m.a, m.b])
            if (s is PlaceholderSlot) s.label,
      ];
      expect(labels, hasLength(4));
      final places = labels.map(parseGroupPlace).toList();
      expect(places.every((p) => p != null), isTrue);
      expect(
        {for (final p in places) '${p!.place}${p.group}'},
        {'1A', '2A', '1B', '2B'},
      );
    });

    test('ignora otros textos', () {
      expect(parseGroupPlace('Ganador Cuartos 1'), isNull);
      expect(parseGroupPlace('Gasparini / De Anda'), isNull);
      expect(parseGroupPlace('2º Grupo C'), (place: 2, group: 'C'));
    });
  });

  group('finalGroupOrder', () {
    const ids = ['a', 'b', 'c'];
    PlayedMatch m(String x, String y, int gx, int gy) => PlayedMatch(
      teamA: x,
      teamB: y,
      sets: [SetScore(gx, gy), SetScore(gx, gy)],
    );

    test('null mientras falten partidos', () {
      expect(
        finalGroupOrder(
          teamIds: ids,
          totalMatches: 3,
          results: [m('a', 'b', 6, 2)],
        ),
        isNull,
      );
    });

    test('orden de la tabla cuando el grupo terminó', () {
      expect(
        finalGroupOrder(
          teamIds: ids,
          totalMatches: 3,
          results: [m('c', 'a', 6, 2), m('c', 'b', 6, 3), m('b', 'a', 6, 4)],
        ),
        ['c', 'b', 'a'],
      );
    });
  });

  test('un W.O. es un resultado válido para la tabla y el validador', () {
    for (final rules in [
      ScoringRules.leva,
      const ScoringRules(setsToWin: 1, gamesPerSet: 4),
    ]) {
      final sets = walkoverSets(Side.b, rules);
      final check = validateFinalResult(sets, rules);
      expect(check, isA<ValidResult>());
      expect((check as ValidResult).winner, Side.b);
    }
  });
}
