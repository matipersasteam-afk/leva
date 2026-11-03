import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/draw/draw.dart';
import '../domain/models/event.dart';
import '../domain/models/registration.dart';
import '../domain/scoring/scoring.dart';

/// Pareja de un partido guardado: con inscripción o "por definir".
class MatchTeam {
  const MatchTeam({
    required this.label,
    this.regId,
    this.playerUids = const [],
    this.from,
  });
  final String label;

  /// null = lugar por definir ("Ganador Cuartos 1", "1º Grupo A").
  final String? regId;
  final List<String> playerUids;

  /// Lugar original del cuadro ("1º Grupo A") una vez que se definió la pareja.
  final String? from;

  /// De dónde sale esta pareja: el lugar original o, si nunca se definió, su etiqueta.
  String get source => from ?? label;

  Map<String, Object?> toJson() => {
    'regId': regId,
    'label': label,
    'playerUids': playerUids,
    'from': from,
  };

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
    this.liveScore,
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

  /// Marcador punto a punto del juez (`MatchScore.toJson`), si lo hay.
  final Map<String, Object?>? liveScore;

  /// Las dos parejas ya están definidas: se puede cargar el resultado.
  bool get isPlayable => teamA?.isDefined == true && teamB?.isDefined == true;

  MatchTeam? team(int slot) => slot == 0 ? teamA : teamB;

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

  Stream<StoredMatch?> watchMatch(String eventId, String matchId) =>
      _matches(eventId)
          .doc(matchId)
          .snapshots()
          .map((d) => d.exists ? storedMatchFromDoc(d.id, d.data()!) : null);

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

  // ---------------- Resultados (M6) ----------------

  /// Marcador punto a punto del juez: el partido queda en juego.
  Future<void> saveLiveScore({
    required String eventId,
    required String matchId,
    required MatchScore score,
    required String byUid,
  }) => _matches(eventId).doc(matchId).update({
    'status': 'live',
    'score': score.toJson(),
    'liveBy': byUid,
    'version': FieldValue.increment(1),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  /// Resultado final (mesa de control o juez). El ganador pasa al partido
  /// siguiente y, si se cerró un grupo, los clasificados entran a la llave.
  ///
  /// Corregir un resultado se permite mientras el partido siguiente no haya
  /// empezado con otra pareja ([ResultLockedError]).
  Future<void> saveResult({
    required String eventId,
    required String matchId,
    required List<SetScore> sets,
    required Side winner,
    required String byUid,
    String method = 'mesa',
    bool walkover = false,
    MatchScore? score,
  }) async {
    final ref = _matches(eventId).doc(matchId);
    final match = await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final m = storedMatchFromDoc(snap.id, snap.data()!);
      if (!m.isPlayable) {
        throw const ResultLockedError('Falta definir una de las parejas.');
      }
      final slot = winner == Side.a ? 0 : 1;
      final winnerTeam = m.team(slot)!;

      DocumentReference<Map<String, Object?>>? nextRef;
      StoredMatch? next;
      if (m.nextMatchId != null) {
        nextRef = _matches(eventId).doc(m.nextMatchId);
        final n = await tx.get(nextRef);
        if (n.exists) next = storedMatchFromDoc(n.id, n.data()!);
      }
      if (next != null && (next.isLive || next.isFinal)) {
        final there = next.team(m.nextSlot!)?.regId;
        if (there != winnerTeam.regId) {
          throw const ResultLockedError(
            'El partido siguiente ya empezó con la otra pareja. Corrige ese primero.',
          );
        }
      }

      tx.update(ref, {
        'status': walkover ? 'walkover' : 'final',
        'score': {
          ...?score?.toJson(),
          'sets': [for (final s in sets) s.toJson()],
        },
        'winner': winner == Side.a ? 'A' : 'B',
        'result': {
          'winner': winner == Side.a ? 'A' : 'B',
          'method': walkover ? 'wo' : method,
          'submittedBy': byUid,
          'submittedAt': FieldValue.serverTimestamp(),
        },
        'version': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (next != null && !(next.isLive || next.isFinal)) {
        tx.update(nextRef!, _fillSlot(next, m.nextSlot!, winnerTeam));
      }
      return m;
    });

    if (match.stage == DrawStage.group && match.groupName != null) {
      // Se pasa el resultado recién guardado: la lectura de después de la
      // transacción puede llegar sin él y el grupo parecería sin terminar.
      await _fillFromGroup(
        eventId,
        match.categoryId,
        match.groupName!,
        saved: StoredMatch(
          id: match.id,
          categoryId: match.categoryId,
          stage: match.stage,
          round: match.round,
          order: match.order,
          status: walkover ? 'walkover' : 'final',
          groupName: match.groupName,
          teamA: match.teamA,
          teamB: match.teamB,
          nextMatchId: match.nextMatchId,
          nextSlot: match.nextSlot,
          sets: sets,
          winner: winner == Side.a ? 'A' : 'B',
        ),
      );
    }
  }

  /// Si el grupo terminó, pone a sus clasificados en los lugares de la llave
  /// ("1º Grupo A"). No toca partidos de la llave que ya empezaron.
  Future<void> _fillFromGroup(
    String eventId,
    String categoryId,
    String groupName, {
    required StoredMatch saved,
  }) async {
    const server = GetOptions(source: Source.server);
    final all = await _matches(eventId)
        .where('categoryId', isEqualTo: categoryId)
        .get(server);
    final matches = [
      for (final d in all.docs)
        d.id == saved.id ? saved : storedMatchFromDoc(d.id, d.data()),
    ];
    final group = await _groups(eventId)
        .doc('${categoryId}_$groupName')
        .get(server);
    final teamIds = [
      for (final t in (group.data()?['teams'] as List?) ?? const [])
        (t as Map)['regId'] as String,
    ];
    final fills = groupFills(matches, groupName, teamIds);
    if (fills.isEmpty) return;
    final batch = _db.batch();
    // Varios lugares del mismo partido van en una sola escritura.
    final byMatch = <String, StoredMatch>{};
    for (final f in fills) {
      final m = byMatch[f.match.id] ?? f.match;
      final updated = _fillSlot(m, f.slot, f.team, from: f.from);
      byMatch[m.id] = _withSlot(m, f.slot, f.team, f.from);
      batch.update(_matches(eventId).doc(m.id), updated);
    }
    await batch.commit();
  }

  /// Escritura que pone [team] en el lugar [slot] de [m].
  Map<String, Object?> _fillSlot(
    StoredMatch m,
    int slot,
    MatchTeam team, {
    String? from,
  }) {
    final placed = MatchTeam(
      regId: team.regId,
      label: team.label,
      playerUids: team.playerUids,
      from: from ?? m.team(slot)?.source,
    );
    final other = m.team(1 - slot);
    return {
      slot == 0 ? 'teamA' : 'teamB': placed.toJson(),
      'playerUids': slot == 0
          ? [...placed.playerUids, ...?other?.playerUids]
          : [...?other?.playerUids, ...placed.playerUids],
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  StoredMatch _withSlot(StoredMatch m, int slot, MatchTeam t, String from) {
    final placed = MatchTeam(
      regId: t.regId,
      label: t.label,
      playerUids: t.playerUids,
      from: from,
    );
    return StoredMatch(
      id: m.id,
      categoryId: m.categoryId,
      stage: m.stage,
      round: m.round,
      order: m.order,
      status: m.status,
      groupName: m.groupName,
      teamA: slot == 0 ? placed : m.teamA,
      teamB: slot == 1 ? placed : m.teamB,
      nextMatchId: m.nextMatchId,
      nextSlot: m.nextSlot,
      sets: m.sets,
      winner: m.winner,
    );
  }

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
      from: v['from'] as String?,
    );
  }

  final next = j['next'] as Map?;
  final score = (j['score'] as Map?)?.cast<String, Object?>();
  final result = (j['result'] as Map?)?.cast<String, Object?>();
  final status = j['status'] as String? ?? 'scheduled';
  return StoredMatch(
    id: id,
    categoryId: j['categoryId'] as String? ?? '',
    stage: DrawStage.values.asNameMap()[j['stage']] ?? DrawStage.group,
    round: (j['round'] as num?)?.toInt() ?? 1,
    order: (j['order'] as num?)?.toInt() ?? 0,
    status: status,
    groupName: j['groupName'] as String?,
    teamA: team(j['teamA']),
    teamB: team(j['teamB']),
    nextMatchId: next?['matchId'] as String?,
    nextSlot: next == null ? null : (next['slot'] == 'A' ? 0 : 1),
    sets: [
      for (final s in (score?['sets'] as List?) ?? const []) ?setFromJson(s),
    ],
    winner: (result?['winner'] ?? j['winner']) as String?,
    courtId: j['courtId'] as String?,
    scheduledAt: (j['scheduledAt'] as Timestamp?)?.toDate(),
    liveScore: score != null && score['phase'] != null ? score : null,
  );
}

/// Set guardado como `SetScore.toJson` (o `[a, b]` de versiones viejas).
SetScore? setFromJson(Object? s) {
  int n(Object? v) => (v as num).toInt();
  if (s is List && s.length >= 2) return SetScore(n(s[0]), n(s[1]));
  if (s is! Map) return null;
  final tbA = s['tbA'], tbB = s['tbB'];
  return SetScore(
    n(s['a']),
    n(s['b']),
    tiebreakA: tbA == null || tbB == null ? null : n(tbA),
    tiebreakB: tbA == null || tbB == null ? null : n(tbB),
    superTiebreak: s['stb'] == true,
  );
}

/// No se puede cambiar el ganador: el partido siguiente ya empezó con la otra pareja.
class ResultLockedError implements Exception {
  const ResultLockedError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Lugares de la llave ("1º Grupo A") que hay que llenar cuando [groupName]
/// terminó, con [teamIds] en orden de siembra. Vacío si el grupo no terminó.
/// No toca partidos de la llave que ya empezaron ni lugares ya correctos.
List<({StoredMatch match, int slot, MatchTeam team, String from})> groupFills(
  List<StoredMatch> matches,
  String groupName,
  List<String> teamIds,
) {
  final inGroup = matches.where((m) => m.groupName == groupName).toList();
  final order = finalGroupOrder(
    teamIds: teamIds,
    totalMatches: inGroup.length,
    results: [
      for (final m in inGroup)
        if (m.isFinal && m.isPlayable)
          PlayedMatch(
            teamA: m.teamA!.regId!,
            teamB: m.teamB!.regId!,
            sets: m.sets,
          ),
    ],
  );
  if (order == null) return const [];

  final teams = <String, MatchTeam>{
    for (final m in inGroup)
      for (final t in [?m.teamA, ?m.teamB])
        if (t.regId != null) t.regId!: t,
  };
  return [
    for (final m in matches.where((m) => m.stage == DrawStage.knockout))
      if (!m.isLive && !m.isFinal)
        for (final slot in [0, 1])
          if (m.team(slot) case final current?)
            if (parseGroupPlace(current.source) case final place?)
              if (place.group == groupName && place.place <= order.length)
                if (teams[order[place.place - 1]] case final team?)
                  if (team.regId != current.regId)
                    (match: m, slot: slot, team: team, from: current.source),
  ];
}
