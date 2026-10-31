/// Tabla de posiciones de un grupo o americano. Dart puro.
library;

import '../scoring/set_score.dart';

/// Resultado de un partido terminado entre dos parejas.
class PlayedMatch {
  const PlayedMatch({
    required this.teamA,
    required this.teamB,
    required this.sets,
  });
  final String teamA;
  final String teamB;
  final List<SetScore> sets;

  /// Ganador por sets (null si no hay sets cargados).
  String? get winner {
    var a = 0, b = 0;
    for (final s in sets) {
      if (s.a > s.b) a++;
      if (s.b > s.a) b++;
    }
    if (a == b) return null;
    return a > b ? teamA : teamB;
  }
}

class StandingRow {
  StandingRow(this.teamId);
  final String teamId;
  int played = 0;
  int won = 0;
  int setsFor = 0;
  int setsAgainst = 0;
  int gamesFor = 0;
  int gamesAgainst = 0;

  int get lost => played - won;
  int get setDiff => setsFor - setsAgainst;
  int get gameDiff => gamesFor - gamesAgainst;
}

/// Ordena: partidos ganados, diferencia de sets, diferencia de games,
/// resultado directo (si empatan exactamente dos) y orden de siembra.
/// En [byGames] (americano) manda el total de games ganados.
List<StandingRow> computeStandings(
  List<String> teamIds,
  List<PlayedMatch> results, {
  bool byGames = false,
}) {
  final rows = {for (final id in teamIds) id: StandingRow(id)};
  for (final m in results) {
    final a = rows[m.teamA], b = rows[m.teamB];
    if (a == null || b == null || m.winner == null) continue;
    a.played++;
    b.played++;
    rows[m.winner]!.won++;
    for (final s in m.sets) {
      // Un súper tie-break cuenta como set pero no suma games.
      if (s.a > s.b) {
        a.setsFor++;
        b.setsAgainst++;
      } else {
        b.setsFor++;
        a.setsAgainst++;
      }
      if (!s.superTiebreak) {
        a.gamesFor += s.a;
        a.gamesAgainst += s.b;
        b.gamesFor += s.b;
        b.gamesAgainst += s.a;
      }
    }
  }

  int headToHead(String x, String y) {
    final m = results
        .where((r) => {r.teamA, r.teamB}.containsAll([x, y]))
        .firstOrNull;
    if (m?.winner == x) return -1;
    if (m?.winner == y) return 1;
    return 0;
  }

  final list = rows.values.toList();
  final seedOrder = {for (var i = 0; i < teamIds.length; i++) teamIds[i]: i};
  int primary(StandingRow r) => byGames ? r.gamesFor : r.won;

  list.sort((x, y) {
    var c = primary(y).compareTo(primary(x));
    if (c != 0) return c;
    if (!byGames) {
      c = y.setDiff.compareTo(x.setDiff);
      if (c != 0) return c;
    }
    c = y.gameDiff.compareTo(x.gameDiff);
    if (c != 0) return c;
    // Resultado directo solo si este empate es exactamente entre dos.
    final tied = list.where(
      (r) =>
          primary(r) == primary(x) &&
          r.setDiff == x.setDiff &&
          r.gameDiff == x.gameDiff,
    );
    if (tied.length == 2) {
      c = headToHead(x.teamId, y.teamId);
      if (c != 0) return c;
    }
    return seedOrder[x.teamId]!.compareTo(seedOrder[y.teamId]!);
  });
  return list;
}
