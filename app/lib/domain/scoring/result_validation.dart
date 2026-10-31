import 'scoring_rules.dart';
import 'set_score.dart';

/// Resultado de validar un marcador final cargado a mano.
sealed class ResultCheck {
  const ResultCheck();
}

class ValidResult extends ResultCheck {
  const ValidResult(this.winner);
  final Side winner;
}

class InvalidResult extends ResultCheck {
  const InvalidResult(this.message, {this.setIndex});

  /// Mensaje listo para mostrar (es-MX).
  final String message;

  /// Set con el problema (0-based), si aplica.
  final int? setIndex;
}

/// Valida un resultado final (p. ej. 6-4, 3-6, 10-7) según [rules].
ResultCheck validateFinalResult(List<SetScore> sets, ScoringRules rules) {
  if (sets.isEmpty) return const InvalidResult('Carga al menos un set.');

  final won = {Side.a: 0, Side.b: 0};
  for (var i = 0; i < sets.length; i++) {
    final s = sets[i];
    if (won[Side.a] == rules.setsToWin || won[Side.b] == rules.setsToWin) {
      return InvalidResult(
        'El partido ya estaba definido antes del set ${i + 1}.',
        setIndex: i,
      );
    }
    final decider =
        won[Side.a] == rules.setsToWin - 1 &&
        won[Side.b] == rules.setsToWin - 1;
    final mustBeSuper = decider && rules.usesSuperTiebreak;

    final error = mustBeSuper
        ? _checkSuperTiebreak(s, rules)
        : _checkSet(s, rules);
    if (error != null) {
      return InvalidResult('${_name(i, mustBeSuper)}: $error', setIndex: i);
    }

    won[s.winner!] = won[s.winner!]! + 1;
  }

  for (final side in Side.values) {
    if (won[side] == rules.setsToWin) return ValidResult(side);
  }
  return InvalidResult(
    'Falta definir el partido: nadie llegó a ${rules.setsToWin} ${rules.setsToWin == 1 ? 'set' : 'sets'}.',
  );
}

String _name(int i, bool superTb) =>
    superTb ? 'Súper tie-break' : 'Set ${i + 1}';

String? _checkSet(SetScore s, ScoringRules rules) {
  if (s.superTiebreak) return 'no corresponde súper tie-break en este set.';
  final n = rules.gamesPerSet;
  final hi = s.a > s.b ? s.a : s.b, lo = s.a > s.b ? s.b : s.a;
  if (hi == lo) return 'un set no puede quedar empatado ($hi-$lo).';

  if (hi == n && lo <= n - 2) {
    return s.hasTiebreak ? 'solo un ${n + 1}-$n lleva tie-break.' : null;
  }
  if (hi == n + 1 && lo == n - 1) {
    return s.hasTiebreak ? 'solo un ${n + 1}-$n lleva tie-break.' : null;
  }
  if (hi == n + 1 && lo == n) {
    if (!s.hasTiebreak) return null; // los puntos del tie-break son opcionales
    final err = _checkTiebreakPoints(
      s.tiebreakA!,
      s.tiebreakB!,
      rules.tiebreakPoints,
    );
    if (err != null) return 'tie-break $err';
    final tbWinner = s.tiebreakA! > s.tiebreakB! ? Side.a : Side.b;
    return tbWinner == s.winner
        ? null
        : 'el tie-break lo tiene que ganar quien gana el set.';
  }
  return '$hi-$lo no es un resultado de set válido (a $n games).';
}

String? _checkSuperTiebreak(SetScore s, ScoringRules rules) {
  if (s.hasTiebreak) return 'carga solo los puntos (p. ej. 10-7).';
  return _checkTiebreakPoints(s.a, s.b, rules.superTiebreakPoints);
}

String? _checkTiebreakPoints(int a, int b, int target) {
  final hi = a > b ? a : b, lo = a > b ? b : a;
  if (hi < target) return 'se gana con al menos $target puntos.';
  if (hi - lo < 2) return 'se gana por 2 puntos de diferencia.';
  if (hi > target && hi - lo != 2) {
    return 'pasando de $target, termina con exactamente 2 de diferencia.';
  }
  return null;
}
