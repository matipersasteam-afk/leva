/// Modelos del draw (cuadro). Dart puro.
library;

/// Pareja inscrita, tal como la ve el generador de draw.
class DrawTeam {
  const DrawTeam({
    required this.id,
    required this.label,
    this.clubs = const {},
    this.ranking = 0,
    this.order = 0,
  });

  /// Id de la inscripción.
  final String id;

  /// "Gasparini / De Anda".
  final String label;

  /// Clubes de los dos jugadores (para no cruzarlos en la primera ronda).
  final Set<String> clubs;

  /// Puntos de ranking de la pareja (suma de los dos jugadores).
  final int ranking;

  /// Orden de inscripción: desempata el ranking (primero en inscribirse, mejor sembrado).
  final int order;

  /// Clubes normalizados; "Sin club" y vacíos no cuentan como club.
  Set<String> get realClubs => {
    for (final c in clubs)
      if (normalizeClub(c).isNotEmpty) normalizeClub(c),
  };

  bool sharesClubWith(DrawTeam other) =>
      realClubs.intersection(other.realClubs).isNotEmpty;
}

String normalizeClub(String c) {
  final t = c.trim().toLowerCase();
  return t == 'sin club' || t == 'ninguno' || t == '-' ? '' : t;
}

/// Lugar de un partido: una pareja, un bye o un lugar por definir.
sealed class DrawSlot {
  const DrawSlot();
}

class TeamSlot extends DrawSlot {
  const TeamSlot(this.teamId);
  final String teamId;
  @override
  bool operator ==(Object other) => other is TeamSlot && other.teamId == teamId;
  @override
  int get hashCode => teamId.hashCode;
  @override
  String toString() => teamId;
}

class ByeSlot extends DrawSlot {
  const ByeSlot();
  @override
  bool operator ==(Object other) => other is ByeSlot;
  @override
  int get hashCode => 0;
  @override
  String toString() => 'BYE';
}

/// "1º Grupo A", "Ganador de Cuartos 2".
class PlaceholderSlot extends DrawSlot {
  const PlaceholderSlot(this.label);
  final String label;
  @override
  bool operator ==(Object other) =>
      other is PlaceholderSlot && other.label == label;
  @override
  int get hashCode => label.hashCode;
  @override
  String toString() => label;
}

enum DrawStage { group, knockout, americano }

class DrawMatch {
  const DrawMatch({
    required this.id,
    required this.stage,
    required this.round,
    required this.order,
    required this.a,
    required this.b,
    this.groupName,
    this.nextMatchId,
    this.nextSlot,
  });

  final String id;
  final DrawStage stage;

  /// Ronda (1 = primera). En grupos, la fecha del round-robin.
  final int round;

  /// Orden dentro de la ronda (0-based), de arriba hacia abajo en el cuadro.
  final int order;
  final DrawSlot a;
  final DrawSlot b;
  final String? groupName;

  /// A qué partido avanza el ganador y en qué lugar (0 = a, 1 = b).
  final String? nextMatchId;
  final int? nextSlot;

  bool get isBye => a is ByeSlot || b is ByeSlot;

  DrawMatch copyWith({DrawSlot? a, DrawSlot? b}) => DrawMatch(
    id: id,
    stage: stage,
    round: round,
    order: order,
    a: a ?? this.a,
    b: b ?? this.b,
    groupName: groupName,
    nextMatchId: nextMatchId,
    nextSlot: nextSlot,
  );

  @override
  String toString() => '$id: $a vs $b';
}

class DrawGroup {
  const DrawGroup(this.name, this.teamIds);

  /// "A", "B"…
  final String name;
  final List<String> teamIds;
}

/// Aviso para el admin (no bloquea publicar).
class DrawWarning {
  const DrawWarning(this.message, {this.matchId});
  final String message;
  final String? matchId;
  @override
  String toString() => message;
}

class Draw {
  const Draw({
    required this.groups,
    required this.matches,
    this.warnings = const [],
  });

  final List<DrawGroup> groups;
  final List<DrawMatch> matches;
  final List<DrawWarning> warnings;

  List<DrawMatch> get groupMatches =>
      matches.where((m) => m.stage != DrawStage.knockout).toList();
  List<DrawMatch> get knockoutMatches =>
      matches.where((m) => m.stage == DrawStage.knockout).toList();

  int get knockoutRounds =>
      knockoutMatches.fold(0, (max, m) => m.round > max ? m.round : max);

  DrawMatch? byId(String id) => matches.where((m) => m.id == id).firstOrNull;
}

/// Nombre de la ronda de eliminatoria según cuántas faltan para la final.
String knockoutRoundName(int round, int totalRounds) {
  final fromEnd = totalRounds - round;
  return switch (fromEnd) {
    0 => 'Final',
    1 => 'Semifinal',
    2 => 'Cuartos',
    3 => 'Octavos',
    _ => 'Ronda de ${1 << (fromEnd + 1)}',
  };
}

/// Letra de grupo: 0 → A.
String groupLetter(int i) => String.fromCharCode(65 + i);
