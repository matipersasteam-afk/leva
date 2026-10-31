/// Pareja A o B de un partido.
enum Side {
  a,
  b;

  Side get other => this == Side.a ? Side.b : Side.a;
}

/// Set terminado. Si se definió por tie-break guarda los puntos del tie-break.
/// Un súper tie-break se guarda como set con `superTiebreak = true` y los
/// puntos en `a`/`b` (p. ej. 10-7).
class SetScore {
  const SetScore(
    this.a,
    this.b, {
    this.tiebreakA,
    this.tiebreakB,
    this.superTiebreak = false,
  }) : assert(a >= 0 && b >= 0),
       assert((tiebreakA == null) == (tiebreakB == null));

  final int a;
  final int b;
  final int? tiebreakA;
  final int? tiebreakB;
  final bool superTiebreak;

  int of(Side side) => side == Side.a ? a : b;

  bool get hasTiebreak => tiebreakA != null;

  /// Ganador del set (los empates no son sets válidos; ver `validateFinalResult`).
  Side? get winner => a == b ? null : (a > b ? Side.a : Side.b);

  /// "6-4", "7-6 (7-5)", "10-8".
  String get label => hasTiebreak ? '$a-$b ($tiebreakA-$tiebreakB)' : '$a-$b';

  Map<String, Object?> toJson() => {
    'a': a,
    'b': b,
    if (tiebreakA != null) 'tbA': tiebreakA,
    if (tiebreakB != null) 'tbB': tiebreakB,
    if (superTiebreak) 'stb': true,
  };

  factory SetScore.fromJson(Map<String, Object?> json) => SetScore(
    json['a']! as int,
    json['b']! as int,
    tiebreakA: json['tbA'] as int?,
    tiebreakB: json['tbB'] as int?,
    superTiebreak: json['stb'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is SetScore &&
      other.a == a &&
      other.b == b &&
      other.tiebreakA == tiebreakA &&
      other.tiebreakB == tiebreakB &&
      other.superTiebreak == superTiebreak;

  @override
  int get hashCode => Object.hash(a, b, tiebreakA, tiebreakB, superTiebreak);

  @override
  String toString() => superTiebreak ? 'STB $label' : label;
}
