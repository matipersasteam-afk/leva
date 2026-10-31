import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:leva/domain/scoring/scoring.dart';

/// Juega una secuencia de puntos: 'a' / 'b' (se ignoran espacios).
MatchScore play(MatchScore s, String seq) {
  for (final c in seq.replaceAll(' ', '').split('')) {
    s = s.pointWonBy(c == 'a' ? Side.a : Side.b);
  }
  return s;
}

String games(Side side, int n) => (side == Side.a ? 'aaaa' : 'bbbb') * n;

/// Games alternados empezando por A: a, b, a, b…
String alternate(int n) =>
    List.generate(n, (i) => i.isEven ? 'aaaa' : 'bbbb').join();

const leva = ScoringRules.leva;
const ventaja = ScoringRules(goldenPoint: false);

void main() {
  group('puntos dentro de un game', () {
    test('arranca 0-0 y suma 15, 30, 40', () {
      var s = MatchScore.start(leva);
      expect([s.pointLabel(Side.a), s.pointLabel(Side.b)], ['0', '0']);
      s = play(s, 'a');
      expect(s.pointLabel(Side.a), '15');
      s = play(s, 'a');
      expect(s.pointLabel(Side.a), '30');
      s = play(s, 'ab');
      expect([s.pointLabel(Side.a), s.pointLabel(Side.b)], ['40', '15']);
    });

    test('40-0 y un punto más gana el game', () {
      final r = play(MatchScore.start(leva), 'aaa').play(Side.a);
      expect(r.event, PointEvent.game);
      expect(r.goldenPoint, isFalse);
      expect(r.score.gamesA, 1);
      expect(r.score.pointLabel(Side.a), '0');
    });

    test('punto de oro: en 40-40 el siguiente punto define el game', () {
      final s = play(MatchScore.start(leva), 'aaabbb');
      expect(s.isGoldenPoint, isTrue);
      expect([s.pointLabel(Side.a), s.pointLabel(Side.b)], ['40', '40']);
      final r = s.play(Side.b);
      expect(r.event, PointEvent.game);
      expect(r.goldenPoint, isTrue);
      expect(r.score.gamesB, 1);
      expect(r.score.isGoldenPoint, isFalse);
    });

    test('ventaja: AD, vuelve a iguales y se gana por 2', () {
      var s = play(MatchScore.start(ventaja), 'aaabbb');
      expect(s.isGoldenPoint, isFalse);
      s = play(s, 'a');
      expect([s.pointLabel(Side.a), s.pointLabel(Side.b)], ['AD', '40']);
      s = play(s, 'b');
      expect([s.pointLabel(Side.a), s.pointLabel(Side.b)], ['40', '40']);
      s = play(s, 'b');
      expect([s.pointLabel(Side.a), s.pointLabel(Side.b)], ['40', 'AD']);
      final r = s.play(Side.b);
      expect(r.event, PointEvent.game);
      expect(r.goldenPoint, isFalse);
      expect(r.score.gamesB, 1);
    });

    test('ventaja: muchos iguales seguidos no desbordan el contador', () {
      var s = play(MatchScore.start(ventaja), 'aaabbb');
      for (var i = 0; i < 50; i++) {
        s = play(s, 'ab');
      }
      expect([s.pointsA, s.pointsB], [3, 3]);
      expect(s.gamesA + s.gamesB, 0);
    });
  });

  group('games y sets', () {
    test('6-0 cierra el set', () {
      final s = play(MatchScore.start(leva), games(Side.a, 6));
      expect(s.sets, [const SetScore(6, 0)]);
      expect([s.gamesA, s.gamesB], [0, 0]);
    });

    test('6-4 cierra el set; 6-5 no', () {
      var s = play(MatchScore.start(leva), alternate(10)); // 5-5
      expect([s.gamesA, s.gamesB], [5, 5]);
      s = play(s, games(Side.a, 1));
      expect(s.sets, isEmpty, reason: '6-5 no cierra');
      final r = s.play(Side.a);
      expect(r.event, PointEvent.point);
      s = play(s, games(Side.a, 1));
      expect(s.sets, [const SetScore(7, 5)]);
    });

    test('6-6 va a tie-break a 7 y el set queda 7-6 con los puntos', () {
      var s = play(MatchScore.start(leva), alternate(12));
      expect(s.phase, GamePhase.tiebreak);
      s = play(s, 'aaaaaa bbbbb');
      expect([s.pointLabel(Side.a), s.pointLabel(Side.b)], ['6', '5']);
      final r = s.play(Side.a);
      expect(r.event, PointEvent.set);
      expect(
        r.score.sets.single,
        const SetScore(7, 6, tiebreakA: 7, tiebreakB: 5),
      );
      expect(r.score.phase, GamePhase.regular);
    });

    test('el tie-break se gana por 2: 7-6 sigue, 9-7 cierra', () {
      var s = play(MatchScore.start(leva), alternate(12));
      s = play(s, 'abababababab a'); // 7-6
      expect(s.sets, isEmpty);
      s = play(s, 'b a a'); // 7-7 → 8-7 → 9-7
      expect(s.sets.single, const SetScore(7, 6, tiebreakA: 9, tiebreakB: 7));
    });
  });

  group('saque', () {
    test('alterna cada game', () {
      var s = MatchScore.start(leva, firstServer: Side.b);
      expect(s.server, Side.b);
      s = play(s, games(Side.a, 1));
      expect(s.server, Side.a);
      s = play(s, games(Side.a, 1));
      expect(s.server, Side.b);
    });

    test('tie-break: 1 punto y luego cada 2; el set siguiente arranca sacando quien recibió primero', () {
      var s = play(
        MatchScore.start(leva),
        alternate(12),
      ); // 12 games → le toca a A
      expect(s.server, Side.a);
      final servers = <Side>[];
      for (var i = 0; i < 6; i++) {
        servers.add(s.server);
        s = s.pointWonBy(i.isEven ? Side.a : Side.b);
      }
      expect(servers, [Side.a, Side.b, Side.b, Side.a, Side.a, Side.b]);
      s = play(s, 'aaaa'); // 7-3
      expect(s.sets.length, 1);
      expect(s.server, Side.b);
    });
  });

  group('partido', () {
    test('2 sets a 0 termina el partido', () {
      final s0 = play(
        MatchScore.start(leva),
        '${games(Side.a, 6)}${games(Side.a, 5)}aaa',
      );
      final r = s0.play(Side.a);
      expect(r.event, PointEvent.match);
      expect(r.score.isFinished, isTrue);
      expect(r.score.winner, Side.a);
      expect(r.score.sets, [const SetScore(6, 0), const SetScore(6, 0)]);
      expect(r.score.pointLabel(Side.a), '');
      expect(() => r.score.play(Side.b), throwsStateError);
    });

    test('1-1 en sets va a súper tie-break a 10', () {
      var s = play(MatchScore.start(leva), games(Side.a, 6) + games(Side.b, 6));
      expect(s.phase, GamePhase.superTiebreak);
      s = play(s, 'a' * 9 + 'b' * 9); // 9-9
      expect(s.isFinished, isFalse);
      s = play(s, 'a'); // 10-9: no alcanza
      expect(s.isFinished, isFalse);
      s = play(s, 'a'); // 11-9
      expect(s.winner, Side.a);
      expect(s.sets.last, const SetScore(11, 9, superTiebreak: true));
    });

    test('sin súper tie-break el tercer set se juega completo', () {
      const rules = ScoringRules(superTiebreak: false);
      var s = play(
        MatchScore.start(rules),
        games(Side.a, 6) + games(Side.b, 6),
      );
      expect(s.phase, GamePhase.regular);
      s = play(s, games(Side.b, 6));
      expect(s.winner, Side.b);
      expect(s.sets.length, 3);
    });

    test(
      'set único (relámpago): un set define y nunca hay súper tie-break',
      () {
        const rules = ScoringRules(setsToWin: 1);
        final s = play(MatchScore.start(rules), games(Side.b, 6));
        expect(s.winner, Side.b);
        expect(rules.usesSuperTiebreak, isFalse);
      },
    );

    test('sets cortos a 4 games: tie-break en 4-4', () {
      const rules = ScoringRules(gamesPerSet: 4);
      var s = play(MatchScore.start(rules), games(Side.a, 4));
      expect(s.sets.single, const SetScore(4, 0));
      s = play(s, alternate(8));
      expect(s.phase, GamePhase.tiebreak);
    });
  });

  group('persistencia y deshacer', () {
    test(
      'toJson/fromJson conserva el estado exacto (a mitad de tie-break)',
      () {
        final s = play(
          MatchScore.start(ventaja, firstServer: Side.b),
          '${games(Side.a, 6)}${alternate(12)}aab',
        );
        expect(s.phase, GamePhase.tiebreak);
        final back = MatchScore.fromJson(s.toJson());
        expect(back, s);
        expect(back.pointWonBy(Side.a), s.pointWonBy(Side.a));
      },
    );

    test('deshacer vuelve exactamente al estado anterior', () {
      var h = ScoreHistory.start(leva);
      expect(h.canUndo, isFalse);
      expect(h.undo().current, h.current);
      h = h.point(Side.a).point(Side.a).point(Side.b);
      final before = h.current;
      h = h.point(Side.a);
      expect(h.current, isNot(before));
      h = h.undo();
      expect(h.current, before);
      expect(h.pointsPlayed, 3);
    });
  });

  test('10 000 partidos aleatorios: siempre terminan y el resultado pasa el validador', () {
    final rnd = Random(42);
    final ruleSets = [
      leva,
      ventaja,
      const ScoringRules(superTiebreak: false),
      const ScoringRules(setsToWin: 1, gamesPerSet: 4),
      const ScoringRules(setsToWin: 3, goldenPoint: false),
    ];
    for (var i = 0; i < 10000; i++) {
      final rules = ruleSets[i % ruleSets.length];
      final bias = 0.3 + rnd.nextDouble() * 0.4;
      var s = MatchScore.start(
        rules,
        firstServer: rnd.nextBool() ? Side.a : Side.b,
      );
      var guard = 0;
      while (!s.isFinished) {
        s = s.pointWonBy(rnd.nextDouble() < bias ? Side.a : Side.b);
        expect(++guard, lessThan(2000), reason: 'el partido no termina');
      }
      expect(s.setsWon(s.winner!), rules.setsToWin);
      final check = validateFinalResult(s.sets, rules);
      expect(
        check,
        isA<ValidResult>(),
        reason:
            '${s.sets} con $rules: ${check is InvalidResult ? check.message : ''}',
      );
      expect((check as ValidResult).winner, s.winner);
    }
  });
}
