import 'scoring_rules.dart';
import 'set_score.dart';

/// Fase del juego en curso.
enum GamePhase { regular, tiebreak, superTiebreak }

/// Qué cerró el último punto, para el log ("Punto de oro: game para…") y la TV.
enum PointEvent { point, game, set, match }

/// Resultado de anotar un punto.
class PointResult {
  const PointResult(this.score, this.event, {this.goldenPoint = false});

  final MatchScore score;
  final PointEvent event;

  /// El punto se jugó como punto de oro (40-40 con regla de oro).
  final bool goldenPoint;
}

/// Estado inmutable de un partido de pádel. Cada punto devuelve un estado nuevo.
///
/// El saque se lleva por pareja: alterna cada game; en tie-break saca primero
/// la pareja a la que le toca, luego cambia cada dos puntos, y el set siguiente
/// lo empieza sacando la pareja que recibió primero en el tie-break.
class MatchScore {
  const MatchScore._({
    required this.rules,
    required this.sets,
    required this.gamesA,
    required this.gamesB,
    required this.pointsA,
    required this.pointsB,
    required this.phase,
    required this.server,
    required this.tiebreakFirstServer,
    required this.winner,
  });

  /// Partido sin empezar.
  factory MatchScore.start(ScoringRules rules, {Side firstServer = Side.a}) =>
      MatchScore._(
        rules: rules,
        sets: const [],
        gamesA: 0,
        gamesB: 0,
        pointsA: 0,
        pointsB: 0,
        phase: GamePhase.regular,
        server: firstServer,
        tiebreakFirstServer: null,
        winner: null,
      );

  final ScoringRules rules;

  /// Sets terminados, en orden.
  final List<SetScore> sets;

  /// Games del set en curso.
  final int gamesA;
  final int gamesB;

  /// Puntos del game en curso (0..4+ en juego regular; puntos de tie-break en tie-break).
  final int pointsA;
  final int pointsB;

  final GamePhase phase;

  /// Pareja que saca el próximo punto.
  final Side server;

  /// Pareja que sacó el primer punto del tie-break en curso (null fuera de tie-break).
  final Side? tiebreakFirstServer;

  /// Ganador del partido; null mientras se juega.
  final Side? winner;

  bool get isFinished => winner != null;

  int games(Side s) => s == Side.a ? gamesA : gamesB;
  int points(Side s) => s == Side.a ? pointsA : pointsB;

  int setsWon(Side s) => sets.where((x) => x.winner == s).length;

  bool get isTiebreak => phase != GamePhase.regular;

  /// 40-40 con punto de oro: el próximo punto define el game.
  bool get isGoldenPoint =>
      !isFinished &&
      phase == GamePhase.regular &&
      rules.goldenPoint &&
      pointsA == 3 &&
      pointsB == 3;

  /// Etiqueta del punto para el marcador: 0/15/30/40/AD o el número en tie-break.
  String pointLabel(Side s) {
    if (isFinished) return '';
    if (isTiebreak) return '${points(s)}';
    final me = points(s), them = points(s.other);
    if (me >= 3 && them >= 3) return me > them ? 'AD' : '40';
    return const ['0', '15', '30', '40'][me];
  }

  /// Anota un punto para [side]. Lanza [StateError] si el partido terminó.
  PointResult play(Side side) {
    if (isFinished) throw StateError('El partido ya terminó');
    return phase == GamePhase.regular
        ? _regularPoint(side)
        : _tiebreakPoint(side);
  }

  /// Atajo de [play] que devuelve solo el estado nuevo.
  MatchScore pointWonBy(Side side) => play(side).score;

  PointResult _regularPoint(Side side) {
    if (isGoldenPoint) {
      return _gameWonBy(side, goldenPoint: true);
    }
    var a = pointsA, b = pointsB;
    side == Side.a ? a++ : b++;
    // Ventaja tradicional: de AD-40 vuelve a iguales (40-40).
    if (a == 4 && b == 4) {
      a = 3;
      b = 3;
    }
    final mine = side == Side.a ? a : b, theirs = side == Side.a ? b : a;
    if (mine >= 4 && mine - theirs >= 2) return _gameWonBy(side);
    return PointResult(_copy(pointsA: a, pointsB: b), PointEvent.point);
  }

  PointResult _tiebreakPoint(Side side) {
    var a = pointsA, b = pointsB;
    side == Side.a ? a++ : b++;
    final target = phase == GamePhase.superTiebreak
        ? rules.superTiebreakPoints
        : rules.tiebreakPoints;
    final mine = side == Side.a ? a : b, theirs = side == Side.a ? b : a;
    final first = tiebreakFirstServer ?? server;

    if (mine >= target && mine - theirs >= 2) {
      if (phase == GamePhase.superTiebreak) {
        final set = SetScore(a, b, superTiebreak: true);
        return PointResult(
          _copy(
            sets: [...sets, set],
            pointsA: 0,
            pointsB: 0,
            winner: side,
            tiebreakFirstServer: null,
            clearTiebreakServer: true,
          ),
          PointEvent.match,
        );
      }
      // Tie-break de set: el set queda 7-6 con los puntos del tie-break.
      final ga = gamesA + (side == Side.a ? 1 : 0),
          gb = gamesB + (side == Side.b ? 1 : 0);
      final set = SetScore(ga, gb, tiebreakA: a, tiebreakB: b);
      return _closeSet(set, side, nextServer: first.other);
    }

    // Saca uno, después cada dos puntos.
    final nextServer = (a + b).isOdd ? server.other : server;
    return PointResult(
      _copy(
        pointsA: a,
        pointsB: b,
        server: nextServer,
        tiebreakFirstServer: first,
      ),
      PointEvent.point,
    );
  }

  PointResult _gameWonBy(Side side, {bool goldenPoint = false}) {
    final ga = gamesA + (side == Side.a ? 1 : 0),
        gb = gamesB + (side == Side.b ? 1 : 0);
    final mine = side == Side.a ? ga : gb, theirs = side == Side.a ? gb : ga;
    final n = rules.gamesPerSet;
    final nextServer = server.other;

    if (mine >= n && mine - theirs >= 2) {
      return _closeSet(
        SetScore(ga, gb),
        side,
        nextServer: nextServer,
        goldenPoint: goldenPoint,
      );
    }
    if (ga == n && gb == n) {
      return PointResult(
        _copy(
          gamesA: ga,
          gamesB: gb,
          pointsA: 0,
          pointsB: 0,
          phase: GamePhase.tiebreak,
          server: nextServer,
          tiebreakFirstServer: nextServer,
        ),
        PointEvent.game,
        goldenPoint: goldenPoint,
      );
    }
    return PointResult(
      _copy(gamesA: ga, gamesB: gb, pointsA: 0, pointsB: 0, server: nextServer),
      PointEvent.game,
      goldenPoint: goldenPoint,
    );
  }

  PointResult _closeSet(
    SetScore set,
    Side side, {
    required Side nextServer,
    bool goldenPoint = false,
  }) {
    final newSets = [...sets, set];
    final won = newSets.where((x) => x.winner == side).length;
    final lost = newSets.length - won;

    if (won == rules.setsToWin) {
      return PointResult(
        _copy(
          sets: newSets,
          gamesA: 0,
          gamesB: 0,
          pointsA: 0,
          pointsB: 0,
          phase: GamePhase.regular,
          winner: side,
          clearTiebreakServer: true,
        ),
        PointEvent.match,
        goldenPoint: goldenPoint,
      );
    }

    final decider = won == rules.setsToWin - 1 && lost == rules.setsToWin - 1;
    final nextPhase = decider && rules.usesSuperTiebreak
        ? GamePhase.superTiebreak
        : GamePhase.regular;
    return PointResult(
      _copy(
        sets: newSets,
        gamesA: 0,
        gamesB: 0,
        pointsA: 0,
        pointsB: 0,
        phase: nextPhase,
        server: nextServer,
        tiebreakFirstServer: nextPhase == GamePhase.superTiebreak
            ? nextServer
            : null,
        clearTiebreakServer: nextPhase != GamePhase.superTiebreak,
      ),
      PointEvent.set,
      goldenPoint: goldenPoint,
    );
  }

  MatchScore _copy({
    List<SetScore>? sets,
    int? gamesA,
    int? gamesB,
    int? pointsA,
    int? pointsB,
    GamePhase? phase,
    Side? server,
    Side? tiebreakFirstServer,
    bool clearTiebreakServer = false,
    Side? winner,
  }) => MatchScore._(
    rules: rules,
    sets: sets ?? this.sets,
    gamesA: gamesA ?? this.gamesA,
    gamesB: gamesB ?? this.gamesB,
    pointsA: pointsA ?? this.pointsA,
    pointsB: pointsB ?? this.pointsB,
    phase: phase ?? this.phase,
    server: server ?? this.server,
    tiebreakFirstServer: clearTiebreakServer
        ? null
        : (tiebreakFirstServer ?? this.tiebreakFirstServer),
    winner: winner ?? this.winner,
  );

  /// Para guardar en Firestore (`matches/{id}.score`).
  Map<String, Object?> toJson() => {
    'rules': rules.toJson(),
    'sets': [for (final s in sets) s.toJson()],
    'games': [gamesA, gamesB],
    'points': [pointsA, pointsB],
    'phase': phase.name,
    'server': server.name,
    'tbServer': tiebreakFirstServer?.name,
    'winner': winner?.name,
  };

  factory MatchScore.fromJson(Map<String, Object?> json) {
    final games = (json['games']! as List).cast<int>();
    final points = (json['points']! as List).cast<int>();
    return MatchScore._(
      rules: ScoringRules.fromJson(
        (json['rules']! as Map).cast<String, Object?>(),
      ),
      sets: [
        for (final s in json['sets']! as List)
          SetScore.fromJson((s as Map).cast<String, Object?>()),
      ],
      gamesA: games[0],
      gamesB: games[1],
      pointsA: points[0],
      pointsB: points[1],
      phase: GamePhase.values.byName(json['phase']! as String),
      server: Side.values.byName(json['server']! as String),
      tiebreakFirstServer: json['tbServer'] == null
          ? null
          : Side.values.byName(json['tbServer']! as String),
      winner: json['winner'] == null
          ? null
          : Side.values.byName(json['winner']! as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MatchScore &&
      other.rules == rules &&
      _listEq(other.sets, sets) &&
      other.gamesA == gamesA &&
      other.gamesB == gamesB &&
      other.pointsA == pointsA &&
      other.pointsB == pointsB &&
      other.phase == phase &&
      other.server == server &&
      other.tiebreakFirstServer == tiebreakFirstServer &&
      other.winner == winner;

  @override
  int get hashCode => Object.hash(
    rules,
    Object.hashAll(sets),
    gamesA,
    gamesB,
    pointsA,
    pointsB,
    phase,
    server,
    tiebreakFirstServer,
    winner,
  );

  @override
  String toString() =>
      '${sets.join(' ')} | ${phase.name} $gamesA-$gamesB · ${pointLabel(Side.a)}-${pointLabel(Side.b)}${isFinished ? ' · gana ${winner!.name}' : ''}';
}

bool _listEq(List<SetScore> x, List<SetScore> y) {
  if (x.length != y.length) return false;
  for (var i = 0; i < x.length; i++) {
    if (x[i] != y[i]) return false;
  }
  return true;
}

/// Historial para deshacer: pila de estados. Inmutable.
class ScoreHistory {
  const ScoreHistory._(this._states);

  factory ScoreHistory.start(ScoringRules rules, {Side firstServer = Side.a}) =>
      ScoreHistory._([MatchScore.start(rules, firstServer: firstServer)]);

  final List<MatchScore> _states;

  MatchScore get current => _states.last;
  bool get canUndo => _states.length > 1;
  int get pointsPlayed => _states.length - 1;

  ScoreHistory point(Side side) =>
      ScoreHistory._([..._states, current.pointWonBy(side)]);

  ScoreHistory undo() =>
      canUndo ? ScoreHistory._(_states.sublist(0, _states.length - 1)) : this;
}
