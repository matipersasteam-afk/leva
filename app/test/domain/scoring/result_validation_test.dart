import 'package:flutter_test/flutter_test.dart';
import 'package:leva/domain/scoring/scoring.dart';

const leva = ScoringRules.leva;

Side? winnerOf(List<SetScore> sets, [ScoringRules rules = leva]) {
  final r = validateFinalResult(sets, rules);
  return r is ValidResult ? r.winner : null;
}

String? errorOf(List<SetScore> sets, [ScoringRules rules = leva]) {
  final r = validateFinalResult(sets, rules);
  return r is InvalidResult ? r.message : null;
}

void main() {
  group('resultados válidos', () {
    test('6-4 3-6 10-7 (súper tie-break)', () {
      expect(
        winnerOf(const [
          SetScore(6, 4),
          SetScore(3, 6),
          SetScore(10, 7, superTiebreak: true),
        ]),
        Side.a,
      );
    });

    test('7-6 con puntos de tie-break y 6-3', () {
      expect(
        winnerOf(const [
          SetScore(7, 6, tiebreakA: 7, tiebreakB: 5),
          SetScore(6, 3),
        ]),
        Side.a,
      );
    });

    test('7-6 sin cargar los puntos del tie-break', () {
      expect(winnerOf(const [SetScore(6, 7), SetScore(5, 7)]), Side.b);
    });

    test('súper tie-break largo 12-10', () {
      expect(
        winnerOf(const [
          SetScore(6, 2),
          SetScore(4, 6),
          SetScore(10, 12, superTiebreak: true),
        ]),
        Side.b,
      );
    });

    test('tercer set completo cuando no hay súper tie-break', () {
      const rules = ScoringRules(superTiebreak: false);
      expect(
        winnerOf(const [SetScore(6, 2), SetScore(4, 6), SetScore(7, 5)], rules),
        Side.a,
      );
    });
  });

  group('resultados inválidos con mensaje claro', () {
    test(
      'lista vacía',
      () => expect(errorOf(const []), 'Carga al menos un set.'),
    );

    test('6-5 no es un set terminado', () {
      expect(
        errorOf(const [SetScore(6, 5), SetScore(6, 0)]),
        contains('Set 1'),
      );
    });

    test('8-6 no existe a 6 games', () {
      expect(
        errorOf(const [SetScore(8, 6), SetScore(6, 0)]),
        contains('no es un resultado de set válido'),
      );
    });

    test('set empatado', () {
      expect(
        errorOf(const [SetScore(6, 6), SetScore(6, 0)]),
        contains('empatado'),
      );
    });

    test('6-4 con tie-break no corresponde', () {
      expect(
        errorOf(const [
          SetScore(6, 4, tiebreakA: 7, tiebreakB: 5),
          SetScore(6, 0),
        ]),
        contains('tie-break'),
      );
    });

    test('tie-break 7-6 no se gana por 2', () {
      expect(
        errorOf(const [
          SetScore(7, 6, tiebreakA: 7, tiebreakB: 6),
          SetScore(6, 0),
        ]),
        contains('2 puntos'),
      );
    });

    test('el tie-break lo gana quien pierde el set', () {
      expect(
        errorOf(const [
          SetScore(7, 6, tiebreakA: 5, tiebreakB: 7),
          SetScore(6, 0),
        ]),
        contains('quien gana el set'),
      );
    });

    test('con súper tie-break el set decisivo se carga en puntos', () {
      expect(
        errorOf(const [SetScore(6, 4), SetScore(3, 6), SetScore(6, 3)]),
        startsWith('Súper tie-break'),
      );
    });

    test('súper tie-break 12-9 no termina así', () {
      expect(
        errorOf(const [
          SetScore(6, 4),
          SetScore(3, 6),
          SetScore(12, 9, superTiebreak: true),
        ]),
        contains('exactamente 2'),
      );
    });

    test('súper tie-break en un set que no es decisivo', () {
      expect(
        errorOf(const [SetScore(10, 7, superTiebreak: true), SetScore(6, 0)]),
        contains('no corresponde'),
      );
    });

    test('partido sin definir (un solo set)', () {
      expect(errorOf(const [SetScore(6, 4)]), contains('Falta definir'));
    });

    test('sets de más después de definido', () {
      expect(
        errorOf(const [SetScore(6, 4), SetScore(6, 4), SetScore(6, 1)]),
        contains('ya estaba definido'),
      );
    });
  });
}
