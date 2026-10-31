import 'package:flutter/material.dart';

import '../../core/design_system/design_system.dart';
import '../../data/draw_repository.dart';
import '../../domain/draw/draw.dart';
import '../../domain/scoring/set_score.dart';

/// Tabla de un grupo: posición, pareja, PJ, PG, sets y games.
class GroupTable extends StatelessWidget {
  const GroupTable({
    super.key,
    required this.name,
    required this.rows,
    required this.labels,
    this.qualifiers = 2,
    this.highlightIds = const {},
    this.byGames = false,
  });

  final String name;
  final List<StandingRow> rows;
  final Map<String, String> labels;
  final int qualifiers;
  final Set<String> highlightIds;
  final bool byGames;

  @override
  Widget build(BuildContext context) {
    TextStyle head = LevaType.support(tracking: 0.12);
    Widget cell(
      String t, {
      TextStyle? style,
      TextAlign align = TextAlign.center,
      double w = 34,
    }) => SizedBox(
      width: w,
      child: Text(
        t,
        textAlign: align,
        style: style ?? LevaType.body(size: 13.5),
      ),
    );

    return LevaPanel(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name.length == 1 ? 'GRUPO $name' : name.toUpperCase(),
                  style: LevaType.display(24),
                ),
              ),
              if (!byGames)
                Text('PASAN $qualifiers', style: LevaType.support()),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              cell('', w: 26),
              Expanded(child: Text('PAREJA', style: head)),
              cell('PJ', style: head),
              cell('PG', style: head),
              cell(byGames ? 'GAMES' : 'SETS', style: head, w: 48),
            ],
          ),
          const Divider(),
          for (final (i, r) in rows.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: LevaColors.line)),
              ),
              child: Row(
                children: [
                  cell(
                    '${i + 1}',
                    w: 26,
                    style: LevaType.display(
                      18,
                      color: !byGames && i < qualifiers
                          ? LevaColors.gold500
                          : LevaColors.tx3,
                    ),
                    align: TextAlign.left,
                  ),
                  Expanded(
                    child: Text(
                      labels[r.teamId] ?? r.teamId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LevaType.body(
                        size: 13.5,
                        weight: 500,
                        color: highlightIds.contains(r.teamId)
                            ? LevaColors.gold200
                            : LevaColors.tx1,
                      ),
                    ),
                  ),
                  cell('${r.played}'),
                  cell('${r.won}'),
                  cell(
                    byGames ? '${r.gamesFor}' : '${r.setsFor}-${r.setsAgainst}',
                    w: 48,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Conversión a datos de presentación
// ---------------------------------------------------------------------------

String _slotLabel(DrawSlot s, Map<String, String> labels) => switch (s) {
  TeamSlot(:final teamId) => labels[teamId] ?? teamId,
  PlaceholderSlot(:final label) => label,
  ByeSlot() => 'Bye',
};

/// Llave a partir de un draw en memoria (vista previa del admin).
({List<List<BracketItem>> rounds, List<String> names}) bracketFromDraw(
  Draw d,
  Map<String, String> labels,
) {
  final total = d.knockoutRounds;
  final rounds = <List<BracketItem>>[];
  for (var r = 1; r <= total; r++) {
    final ms = d.knockoutMatches.where((m) => m.round == r).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    rounds.add([
      for (final m in ms)
        BracketItem(
          caption: m.isBye
              ? 'Pasa directo'
              : '${knockoutRoundName(r, total)}${ms.length > 1 ? ' ${m.order + 1}' : ''}',
          teamA: m.a is ByeSlot ? 'Bye' : _slotLabel(m.a, labels),
          teamB: m.b is ByeSlot ? 'Bye' : _slotLabel(m.b, labels),
        ),
    ]);
  }
  return (
    rounds: rounds,
    names: [for (var r = 1; r <= total; r++) knockoutRoundName(r, total)],
  );
}

/// Llave a partir de los partidos guardados (cuadro del jugador y TV).
({List<List<BracketItem>> rounds, List<String> names}) bracketFromStored(
  List<StoredMatch> matches, {
  Set<String> mineUids = const {},
}) {
  final ko = matches.where((m) => m.stage == DrawStage.knockout).toList();
  final total = ko.fold(0, (max, m) => m.round > max ? m.round : max);
  final rounds = <List<BracketItem>>[];
  for (var r = 1; r <= total; r++) {
    final ms = ko.where((m) => m.round == r).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    rounds.add([
      for (final m in ms) storedToItem(m, total, ms.length, mineUids),
    ]);
  }
  return (
    rounds: rounds,
    names: [for (var r = 1; r <= total; r++) knockoutRoundName(r, total)],
  );
}

BracketItem storedToItem(
  StoredMatch m,
  int totalRounds,
  int inRound,
  Set<String> mineUids,
) {
  final walkover = m.status == 'walkover';
  String caption;
  if (m.isLive) {
    caption = m.courtId == null
        ? 'En juego'
        : 'C${m.courtId!.replaceAll('c', '')}';
  } else if (m.isFinal) {
    caption = walkover ? 'Pasa directo' : 'Finalizado';
  } else {
    caption =
        '${knockoutRoundName(m.round, totalRounds)}${inRound > 1 ? ' ${m.order + 1}' : ''}';
  }
  List<int> games(int side) => [for (final s in m.sets) side == 0 ? s.a : s.b];
  return BracketItem(
    caption: caption,
    teamA: m.teamA?.label ?? (walkover ? 'Bye' : null),
    teamB: m.teamB?.label ?? (walkover ? 'Bye' : null),
    scoreA: games(0),
    scoreB: games(1),
    winner: m.winner == null ? null : (m.winner == 'A' ? 0 : 1),
    live: m.isLive,
    mine: m.playerUids.any(mineUids.contains),
  );
}

/// Resultados terminados de un grupo, para la tabla.
List<PlayedMatch> groupResults(List<StoredMatch> matches, String groupName) => [
  for (final m in matches)
    if (m.groupName == groupName &&
        m.status == 'final' &&
        m.teamA?.regId != null &&
        m.teamB?.regId != null)
      PlayedMatch(
        teamA: m.teamA!.regId!,
        teamB: m.teamB!.regId!,
        sets: List<SetScore>.from(m.sets),
      ),
];
