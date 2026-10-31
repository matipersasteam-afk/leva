import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/draw/draw.dart';
import '../domain/models/event.dart';
import '../domain/models/registration.dart';
import '../domain/scoring/set_score.dart';

/// Pareja de un partido guardado: con inscripción o "por definir".
class MatchTeam {
  const MatchTeam({
    required this.label,
    this.regId,
    this.playerUids = const [],
  });
  final String label;

  /// null = lugar por definir ("Ganador Cuartos 1", "1º Grupo A").
  final String? regId;
  final List<String> playerUids;

  bool get isDefined => regId != null;
}

/// Partido tal como se guarda en `events/{e}/matches/{id}` (lo que lee el cuadro).
class StoredMatch {
  const StoredMatch({
    required this.id,
    required this.categoryId,
    required this.stage,
    required this.round,
    required this.order,
    required this.status,
    this.groupName,
    this.teamA,
    this.teamB,
    this.nextMatchId,
    this.nextSlot,
    this.sets = const [],
    this.winner,
    this.courtId,
    this.scheduledAt,
  });

  final String id;
  final String categoryId;
  final DrawStage stage;
  final int round;
  final int order;

  /// scheduled | called | live | pending_confirmation | final | walkover
  final String status;
  final String? groupName;
  final MatchTeam? teamA;
  final MatchTeam? teamB;
  final String? nextMatchId;
  final int? nextSlot;
  final List<SetScore> sets;

  /// 'A' | 'B'
  final String? winner;
  final String? courtId;
  final DateTime? scheduledAt;

  bool get isLive => status == 'live';
  bool get isFinal => status == 'final' || status == 'walkover';
  List<String> get playerUids => [...?teamA?.playerUids, ...?teamB?.playerUids];
}

class StoredGroup {
  const StoredGroup({
    required this.id,
    required this.name,
    required this.teams,
  });
  final String id;
  final String name;
  final List<MatchTeam> teams;
}

/// Lo que el admin necesita para generar el draw de una categoría.
class DrawInput {
  const DrawInput({required this.teams, required this.registrations});
  final List<DrawTeam> teams;
  final Map<String, Registration> registrations;
}

class DrawRepository {
  DrawRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, Object?>> _event(String id) =>
      _db.collection('events').doc(id);
  CollectionReference<Map<String, Object?>> _matches(String e) =>
      _event(e).collection('matches');
  CollectionReference<Map<String, Object?>> _groups(String e) =>
      _event(e).collection('groups');

  /// Parejas con lugar y pareja completa, con su ranking (suma de los dos).
  Future<DrawInput> loadInput(String eventId, String categoryId) async {
    final snap = await _event(eventId)
        .collection('registrations')
        .where('categoryId', isEqualTo: categoryId)
        .get();
    final regs = <Registration>[];
    for (final d in snap.docs) {
      final r = registrationFromDocLite(eventId, d.id, d.data());
      if (r != null) regs.add(r);
    }
    regs.sort(
      (a, b) =>
          (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)),
    );
    final eligible = regs.where(
      (r) =>
          r.hasPartner &&
          (r.status == RegistrationStatus.confirmed ||
              r.status == RegistrationStatus.pendingPayment),
    );
    // Ranking actual de cada jugador.
    final uids = {for (final r in eligible) ...r.playerUids};
    final ranking = <String, int>{};
    for (final chunk in _chunks(uids.toList(), 10)) {
      final users = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final u in users.docs) {
        ranking[u.id] = (u.data()['rankingPoints'] as num?)?.toInt() ?? 0;
      }
    }
    final teams = <DrawTeam>[
      for (final (i, r) in eligible.indexed)
        DrawTeam(
          id: r.id,
          label: r.label,
          clubs: {for (final p in r.players) p.club},
          ranking: r.playerUids.fold(
            0,
            (total, uid) => total + (ranking[uid] ?? 0),
          ),
          order: i,
        ),
    ];
    return DrawInput(
      teams: teams,
      registrations: {for (final r in eligible) r.id: r},
    );
  }

  /// Publica el draw: reemplaza grupos y partidos de la categoría en una sola escritura.
  Future<void> publish({
    required String eventId,
    required String categoryId,
    required Draw draw,
    required DrawInput input,
    required Map<String, Object?> config,
  }) async {
    final oldMatches = await _matches(eventId)
        .where('categoryId', isEqualTo: categoryId)
        .get();
    final oldGroups = await _groups(eventId)
        .where('categoryId', isEqualTo: categoryId)
        .get();
    final hasResults = oldMatches.docs.any(
      (d) => d.data()['status'] == 'final' || d.data()['status'] == 'live',
    );
    if (hasResults) {
      throw StateError(
        'Ya hay partidos jugados en esta categoría; el draw no se puede reemplazar.',
      );
    }

    final batch = _db.batch();
    for (final d in [...oldMatches.docs, ...oldGroups.docs]) {
      batch.delete(d.reference);
    }

    Map<String, Object?>? team(DrawSlot s) => switch (s) {
      TeamSlot(:final teamId) => {
        'regId': teamId,
        'label': input.registrations[teamId]?.label ?? teamId,
        'playerUids':
            input.registrations[teamId]?.playerUids ?? const <String>[],
      },
      PlaceholderSlot(:final label) => {
        'regId': null,
        'label': label,
        'playerUids': const <String>[],
      },
      ByeSlot() => null,
    };

    for (final g in draw.groups) {
      batch.set(_groups(eventId).doc('${categoryId}_${g.name}'), {
        'categoryId': categoryId,
        'name': g.name,
        'teams': [
          for (final id in g.teamIds)
            {'regId': id, 'label': input.registrations[id]?.label ?? id},
        ],
      });
    }
    for (final m in draw.matches) {
      final a = team(m.a), b = team(m.b);
      batch.set(_matches(eventId).doc('${categoryId}_${m.id}'), {
        'categoryId': categoryId,
        'stage': m.stage.name,
        'groupId': m.groupName == null ? null : '${categoryId}_${m.groupName}',
        'groupName': m.groupName,
        'round': m.round,
        'order': m.order,
        'teamA': a,
        'teamB': b,
        'playerUids': [
          ...?(a?['playerUids'] as List?),
          ...?(b?['playerUids'] as List?),
        ],
        'next': m.nextMatchId == null
            ? null
            : {
                'matchId': '${categoryId}_${m.nextMatchId}',
                'slot': m.nextSlot == 0 ? 'A' : 'B',
              },
        'status': m.isBye ? 'walkover' : 'scheduled',
        'winner': m.isBye ? (m.a is ByeSlot ? 'B' : 'A') : null,
        'courtId': null,
        'scheduledAt': null,
        'score': null,
        'version': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.update(_event(eventId).collection('categories').doc(categoryId), {
      'drawStatus': 'published',
      'formatConfig': config,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Stream<List<StoredMatch>> watchMatches(String eventId, String categoryId) =>
      _matches(eventId)
          .where('categoryId', isEqualTo: categoryId)
          .snapshots()
          .map(
            (q) => [for (final d in q.docs) storedMatchFromDoc(d.id, d.data())],
          );

  Stream<List<StoredGroup>> watchGroups(String eventId, String categoryId) =>
      _groups(eventId)
          .where('categoryId', isEqualTo: categoryId)
          .snapshots()
          .map((q) {
            final list = [
              for (final d in q.docs)
                StoredGroup(
                  id: d.id,
                  name: d.data()['name'] as String? ?? '',
                  teams: [
                    for (final t in (d.data()['teams'] as List?) ?? const [])
                      MatchTeam(
                        regId: (t as Map)['regId'] as String?,
                        label: t['label'] as String? ?? '',
                      ),
                  ],
                ),
            ]..sort((a, b) => a.name.compareTo(b.name));
            return list;
          });

  static Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, i + size > list.length ? list.length : i + size);
    }
  }
}

/// Inscripción mínima para el draw (evita depender de la pantalla de inscripciones).
Registration? registrationFromDocLite(
  String eventId,
  String id,
  Map<String, Object?> j,
) {
  final players = [
    for (final p in (j['players'] as List?) ?? const [])
      RegistrationPlayer.fromJson((p as Map).cast<String, Object?>()),
  ];
  if (players.isEmpty) return null;
  final pay = (j['payment'] as Map?)?.cast<String, Object?>() ?? const {};
  return Registration(
    id: id,
    eventId: eventId,
    categoryId: j['categoryId'] as String? ?? '',
    players: players,
    status: RegistrationStatus.fromId(j['status'] as String?),
    slot: j['slot'] == 'waitlist'
        ? RegistrationSlot.waitlist
        : RegistrationSlot.confirmed,
    inviteCode: '',
    payment: Payment(
      method: PaymentMethod.fromId(pay['method'] as String?),
      status:
          PaymentStatus.values.asNameMap()[pay['status']] ??
          PaymentStatus.pending,
      amountCents: (pay['amountCents'] as num?)?.toInt() ?? 0,
      paidCents: (pay['paidCents'] as num?)?.toInt() ?? 0,
    ),
    createdAt: (j['createdAt'] as Timestamp?)?.toDate(),
  );
}

StoredMatch storedMatchFromDoc(String id, Map<String, Object?> j) {
  MatchTeam? team(Object? v) {
    if (v is! Map) return null;
    return MatchTeam(
      regId: v['regId'] as String?,
      label: v['label'] as String? ?? '',
      playerUids: [
        for (final u in (v['playerUids'] as List?) ?? const []) u as String,
      ],
    );
  }

  final next = j['next'] as Map?;
  final score = (j['score'] as Map?)?.cast<String, Object?>();
  final result = (j['result'] as Map?)?.cast<String, Object?>();
  return StoredMatch(
    id: id,
    categoryId: j['categoryId'] as String? ?? '',
    stage: DrawStage.values.asNameMap()[j['stage']] ?? DrawStage.group,
    round: (j['round'] as num?)?.toInt() ?? 1,
    order: (j['order'] as num?)?.toInt() ?? 0,
    status: j['status'] as String? ?? 'scheduled',
    groupName: j['groupName'] as String?,
    teamA: team(j['teamA']),
    teamB: team(j['teamB']),
    nextMatchId: next?['matchId'] as String?,
    nextSlot: next == null ? null : (next['slot'] == 'A' ? 0 : 1),
    sets: [
      for (final s in (score?['sets'] as List?) ?? const [])
        if (s is List && s.length >= 2)
          SetScore((s[0] as num).toInt(), (s[1] as num).toInt()),
    ],
    winner: (result?['winner'] ?? j['winner']) as String?,
    courtId: j['courtId'] as String?,
    scheduledAt: (j['scheduledAt'] as Timestamp?)?.toDate(),
  );
}
