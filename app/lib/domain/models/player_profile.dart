/// Perfil de jugador LEVA. Dart puro: el mapeo a Firestore vive en `data/`.
library;

/// Categorías del circuito. El id es lo que se guarda; el label lo que se muestra.
enum PlayerCategory {
  tercera('3ra'),
  cuarta('4ta'),
  quinta('5ta'),
  sexta('6ta'),
  suma9('Suma 9');

  const PlayerCategory(this.label);
  final String label;

  static PlayerCategory? fromId(String? id) =>
      PlayerCategory.values.where((c) => c.name == id).firstOrNull;
}

enum Hand {
  diestra('Diestra'),
  zurda('Zurda');

  const Hand(this.label);
  final String label;
}

enum CourtPosition {
  drive('Drive'),
  reves('Revés'),
  ambas('Ambas');

  const CourtPosition(this.label);
  final String label;
}

class PlayerProfile {
  const PlayerProfile({
    required this.uid,
    required this.displayName,
    required this.category,
    required this.club,
    required this.hand,
    required this.position,
    this.nickname,
    this.photoUrl,
    this.rankingPoints = 0,
    this.tournaments = 0,
    this.titles = 0,
    this.ambassador = false,
  });

  final String uid;
  final String displayName;
  final String? nickname;
  final PlayerCategory category;
  final String club;
  final Hand hand;
  final CourtPosition position;
  final String? photoUrl;

  // Campos que solo escribe el servidor (circuito, insignias: fase 2).
  final int rankingPoints;
  final int tournaments;
  final int titles;
  final bool ambassador;

  /// Iniciales para avatar y placa tipográfica: "Julia Gasparini" → "JG".
  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  String get firstName => displayName.trim().split(RegExp(r'\s+')).first;

  String get lastName {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  PlayerProfile copyWith({
    String? displayName,
    String? nickname,
    PlayerCategory? category,
    String? club,
    Hand? hand,
    CourtPosition? position,
    String? photoUrl,
  }) => PlayerProfile(
    uid: uid,
    displayName: displayName ?? this.displayName,
    nickname: nickname ?? this.nickname,
    category: category ?? this.category,
    club: club ?? this.club,
    hand: hand ?? this.hand,
    position: position ?? this.position,
    photoUrl: photoUrl ?? this.photoUrl,
    rankingPoints: rankingPoints,
    tournaments: tournaments,
    titles: titles,
    ambassador: ambassador,
  );

  /// Solo los campos que el jugador puede editar (las reglas de Firestore
  /// rechazan cualquier otro).
  Map<String, Object?> editableJson() => {
    'displayName': displayName.trim(),
    'nickname': (nickname?.trim().isEmpty ?? true) ? null : nickname!.trim(),
    'category': category.name,
    'club': club.trim(),
    'hand': hand.name,
    'position': position.name,
    'photoUrl': photoUrl,
  };

  factory PlayerProfile.fromJson(String uid, Map<String, Object?> json) {
    final stats = (json['stats'] as Map?)?.cast<String, Object?>() ?? const {};
    return PlayerProfile(
      uid: uid,
      displayName: json['displayName'] as String? ?? '',
      nickname: json['nickname'] as String?,
      category:
          PlayerCategory.fromId(json['category'] as String?) ??
          PlayerCategory.sexta,
      club: json['club'] as String? ?? '',
      hand: Hand.values.asNameMap()[json['hand']] ?? Hand.diestra,
      position:
          CourtPosition.values.asNameMap()[json['position']] ??
          CourtPosition.ambas,
      photoUrl: json['photoUrl'] as String?,
      rankingPoints: (json['rankingPoints'] as num?)?.toInt() ?? 0,
      tournaments: (stats['tournaments'] as num?)?.toInt() ?? 0,
      titles: (stats['titles'] as num?)?.toInt() ?? 0,
      ambassador: json['ambassador'] as bool? ?? false,
    );
  }
}

/// Validaciones de formulario (mensajes en es-MX). Devuelven null si es válido.
abstract final class ProfileValidators {
  static String? displayName(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Escribe tu nombre.';
    if (t.length < 3) return 'Tu nombre es muy corto.';
    if (t.length > 40) return 'Máximo 40 caracteres.';
    if (!t.contains(' ')) return 'Escribe nombre y apellido.';
    return null;
  }

  static String? nickname(String? v) {
    final t = v?.trim() ?? '';
    if (t.length > 20) return 'El apodo puede tener hasta 20 caracteres.';
    return null;
  }

  static String? club(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Escribe tu club. Si no tienes, pon "Sin club".';
    if (t.length > 40) return 'Máximo 40 caracteres.';
    return null;
  }
}

/// Quita acentos y pasa a minúsculas: "César De Anda" → "cesar de anda".
String normalizeForSearch(String s) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  final lower = s.toLowerCase();
  final buf = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    buf.write(i >= 0 ? to[i] : ch);
  }
  return buf.toString().trim();
}

/// ¿El jugador coincide con lo que se escribió? Cada palabra buscada tiene que
/// ser el inicio de alguna palabra del nombre o del apodo, sin importar acentos
/// ni mayúsculas: "cesar", "anda", "ces de an" y "chispita" encuentran a
/// César “Chispita” de Anda.
bool matchesPlayerQuery(PlayerProfile p, String query) {
  final q = normalizeForSearch(query)
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (q.isEmpty) return false;
  final words = normalizeForSearch('${p.displayName} ${p.nickname ?? ''}')
      .split(RegExp(r'\s+'));
  return q.every((term) => words.any((w) => w.startsWith(term)));
}
