/// Reglas de puntuación configurables por evento o categoría.
///
/// Por defecto (`ScoringRules.leva`): al mejor de 3 sets a 6 games, tie-break
/// a 7 en 6-6, punto de oro y súper tie-break a 10 en lugar del 3er set.
class ScoringRules {
  const ScoringRules({
    this.goldenPoint = true,
    this.superTiebreak = true,
    this.setsToWin = 2,
    this.gamesPerSet = 6,
    this.tiebreakPoints = 7,
    this.superTiebreakPoints = 10,
  }) : assert(setsToWin >= 1),
       assert(gamesPerSet >= 1),
       assert(tiebreakPoints >= 1),
       assert(superTiebreakPoints >= 1);

  /// En 40-40 se juega un solo punto decisivo. Si es `false`, ventaja tradicional.
  final bool goldenPoint;

  /// El set decisivo se reemplaza por un súper tie-break.
  final bool superTiebreak;

  /// Sets necesarios para ganar (2 = al mejor de 3; 1 = set único, p. ej. relámpago).
  final int setsToWin;

  /// Games para ganar un set (6 normal; 4 en sets cortos).
  final int gamesPerSet;

  final int tiebreakPoints;
  final int superTiebreakPoints;

  static const leva = ScoringRules();

  /// El súper tie-break solo aplica si hay set decisivo (más de un set a ganar).
  bool get usesSuperTiebreak => superTiebreak && setsToWin > 1;

  ScoringRules copyWith({
    bool? goldenPoint,
    bool? superTiebreak,
    int? setsToWin,
    int? gamesPerSet,
    int? tiebreakPoints,
    int? superTiebreakPoints,
  }) => ScoringRules(
    goldenPoint: goldenPoint ?? this.goldenPoint,
    superTiebreak: superTiebreak ?? this.superTiebreak,
    setsToWin: setsToWin ?? this.setsToWin,
    gamesPerSet: gamesPerSet ?? this.gamesPerSet,
    tiebreakPoints: tiebreakPoints ?? this.tiebreakPoints,
    superTiebreakPoints: superTiebreakPoints ?? this.superTiebreakPoints,
  );

  Map<String, Object?> toJson() => {
    'goldenPoint': goldenPoint,
    'superTiebreak': superTiebreak,
    'setsToWin': setsToWin,
    'gamesPerSet': gamesPerSet,
    'tiebreakPoints': tiebreakPoints,
    'superTiebreakPoints': superTiebreakPoints,
  };

  factory ScoringRules.fromJson(Map<String, Object?> json) => ScoringRules(
    goldenPoint: json['goldenPoint'] as bool? ?? true,
    superTiebreak: json['superTiebreak'] as bool? ?? true,
    setsToWin: json['setsToWin'] as int? ?? 2,
    gamesPerSet: json['gamesPerSet'] as int? ?? 6,
    tiebreakPoints: json['tiebreakPoints'] as int? ?? 7,
    superTiebreakPoints: json['superTiebreakPoints'] as int? ?? 10,
  );

  @override
  bool operator ==(Object other) =>
      other is ScoringRules &&
      other.goldenPoint == goldenPoint &&
      other.superTiebreak == superTiebreak &&
      other.setsToWin == setsToWin &&
      other.gamesPerSet == gamesPerSet &&
      other.tiebreakPoints == tiebreakPoints &&
      other.superTiebreakPoints == superTiebreakPoints;

  @override
  int get hashCode => Object.hash(
    goldenPoint,
    superTiebreak,
    setsToWin,
    gamesPerSet,
    tiebreakPoints,
    superTiebreakPoints,
  );
}
