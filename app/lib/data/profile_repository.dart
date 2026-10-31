import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/player_profile.dart';

/// Entrada del historial LEVA (`users/{uid}/history/{eventId}`), solo lectura
/// para el jugador; la escribe el servidor al cerrar un torneo.
class HistoryEntry {
  const HistoryEntry({
    required this.eventName,
    required this.category,
    required this.result,
    this.partnerName,
    this.date,
  });

  final String eventName;
  final String category;
  final String result;
  final String? partnerName;
  final DateTime? date;

  bool get isTitle => result == 'campeon';

  /// "campeon" → "Campeón", "semis" → "Semifinal"…
  String get resultLabel => switch (result) {
    'campeon' => 'Campeón',
    'final' => 'Final',
    'semis' => 'Semifinal',
    'cuartos' => 'Cuartos',
    'octavos' => 'Octavos',
    'grupos' => 'Fase de grupos',
    _ => result,
  };
}

class ProfileRepository {
  ProfileRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, Object?>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  Stream<PlayerProfile?> watch(String uid) => _doc(uid).snapshots().map((s) {
    final data = s.data();
    return data == null ? null : PlayerProfile.fromJson(uid, data);
  });

  /// Primer guardado: incluye los contadores en cero que exigen las reglas.
  Future<void> create(PlayerProfile p) => _doc(p.uid).set({
    ...p.editableJson(),
    'rankingPoints': 0,
    'stats': {'tournaments': 0, 'titles': 0},
    'ambassador': false,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'schemaVersion': 1,
  });

  Future<void> update(PlayerProfile p) => _doc(p.uid)
      .update({...p.editableJson(), 'updatedAt': FieldValue.serverTimestamp()});

  /// Lista de jugadores para buscar pareja. Se carga una vez por pantalla y se
  /// filtra en el dispositivo con [matchesPlayerQuery] (sin acentos ni
  /// mayúsculas, también por apellido o apodo). Para el tamaño de la liga LEVA
  /// alcanza; si crece mucho, se cambia por un campo de búsqueda normalizado.
  Future<List<PlayerProfile>> listPlayers({int limit = 500}) async {
    final snap = await _db
        .collection('users')
        .orderBy('displayName')
        .limit(limit)
        .get();
    return [for (final d in snap.docs) PlayerProfile.fromJson(d.id, d.data())];
  }

  Stream<List<HistoryEntry>> history(String uid) =>
      _doc(uid)
          .collection('history')
          .orderBy('date', descending: true)
          .limit(50)
          .snapshots()
          .map(
            (q) => [
              for (final d in q.docs)
                HistoryEntry(
                  eventName: d.data()['eventName'] as String? ?? '',
                  category: d.data()['categoryName'] as String? ?? '',
                  result: d.data()['result'] as String? ?? '',
                  partnerName: d.data()['partnerName'] as String?,
                  date: (d.data()['date'] as Timestamp?)?.toDate(),
                ),
            ],
          );
}
