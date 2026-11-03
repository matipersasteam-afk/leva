/// Avance del cuadro al cargar resultados. Dart puro.
library;

import '../scoring/scoring_rules.dart';
import '../scoring/set_score.dart';
import 'standings.dart';

/// "1º Grupo A" → (place: 1, group: 'A'). null si no es un lugar de grupo.
({int place, String group})? parseGroupPlace(String label) {
  final m = RegExp(r'^(\d+)º Grupo (.+)$').firstMatch(label.trim());
  if (m == null) return null;
  return (place: int.parse(m.group(1)!), group: m.group(2)!);
}

/// Orden final de un grupo, o null mientras falten partidos por jugar.
/// [teamIds] va en orden de siembra (desempata igual que la tabla).
List<String>? finalGroupOrder({
  required List<String> teamIds,
  required int totalMatches,
  required List<PlayedMatch> results,
}) {
  if (totalMatches == 0 || results.length < totalMatches) return null;
  return [for (final r in computeStandings(teamIds, results)) r.teamId];
}

/// Sets de un W.O. (la pareja que no se presentó pierde 6-0 cada set que hace falta),
/// para que la tabla del grupo lo cuente como un partido ganado.
List<SetScore> walkoverSets(Side winner, ScoringRules rules) => [
  for (var i = 0; i < rules.setsToWin; i++)
    winner == Side.a
        ? SetScore(rules.gamesPerSet, 0)
        : SetScore(0, rules.gamesPerSet),
];
