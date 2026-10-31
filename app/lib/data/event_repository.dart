import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/event.dart';
import '../domain/scoring/scoring_rules.dart';

/// Eventos y categorías (`events/{id}`, `events/{id}/categories/{id}`).
class EventRepository {
  EventRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, Object?>> get _events =>
      _db.collection('events');
  CollectionReference<Map<String, Object?>> _categories(String eventId) =>
      _events.doc(eventId).collection('categories');

  /// Eventos visibles para jugadores, del más próximo al más lejano.
  Stream<List<PadelEvent>> watchPublic() => _events
      .where('status', whereIn: ['open', 'closed', 'live'])
      .orderBy('startDate')
      .snapshots()
      .map((q) => [for (final d in q.docs) eventFromDoc(d.id, d.data())]);

  /// Todos (incluye borradores): solo admin.
  Stream<List<PadelEvent>> watchAll() => _events
      .orderBy('startDate', descending: true)
      .snapshots()
      .map((q) => [for (final d in q.docs) eventFromDoc(d.id, d.data())]);

  Stream<PadelEvent?> watch(String id) => _events
      .doc(id)
      .snapshots()
      .map((s) => s.data() == null ? null : eventFromDoc(s.id, s.data()!));

  Stream<List<EventCategory>> watchCategories(String eventId) =>
      _categories(eventId)
          .orderBy('order')
          .snapshots()
          .map(
            (q) => [for (final d in q.docs) categoryFromDoc(d.id, d.data())],
          );

  String newEventId() => _events.doc().id;

  Future<void> saveEvent(PadelEvent e, {required bool isNew}) {
    final data = {
      ...eventToJson(e),
      'updatedAt': FieldValue.serverTimestamp(),
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      if (isNew) 'schemaVersion': 1,
    };
    return isNew ? _events.doc(e.id).set(data) : _events.doc(e.id).update(data);
  }

  Future<void> saveCategory(
    String eventId,
    EventCategory c, {
    required int order,
    required bool isNew,
  }) {
    final ref = _categories(eventId).doc(c.id);
    final data = {
      'name': c.name,
      'capacity': c.capacity,
      'priceCents': c.priceCents,
      'format': c.format.id,
      'formatConfig': <String, Object?>{},
      'order': order,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    return isNew
        ? ref.set({
            ...data,
            'confirmedCount': 0,
            'waitlistCount': 0,
            'drawStatus': 'none',
            'lastRegId': null,
          })
        : ref.update(data);
  }

  String newCategoryId(String eventId) => _categories(eventId).doc().id;
}

DateTime _date(Object? v) =>
    (v as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);

PadelEvent eventFromDoc(String id, Map<String, Object?> j) {
  final venue = (j['venue'] as Map?)?.cast<String, Object?>() ?? const {};
  return PadelEvent(
    id: id,
    name: j['name'] as String? ?? '',
    status: EventStatus.values.asNameMap()[j['status']] ?? EventStatus.draft,
    venueName: venue['name'] as String? ?? '',
    venueAddress: venue['address'] as String? ?? '',
    startDate: _date(j['startDate']),
    endDate: _date(j['endDate']),
    registrationDeadline: _date(j['registrationDeadline']),
    courts: [
      for (final c in (j['courts'] as List?) ?? const [])
        Court.fromJson((c as Map).cast<String, Object?>()),
    ],
    rules: j['rules'] is Map
        ? ScoringRules.fromJson((j['rules']! as Map).cast<String, Object?>())
        : ScoringRules.leva,
    matchMinutes: (j['matchMinutes'] as num?)?.toInt() ?? 60,
    minRestMinutes: (j['minRestMinutes'] as num?)?.toInt() ?? 60,
    checkInMinutesBefore: (j['checkInMinutesBefore'] as num?)?.toInt() ?? 20,
    paymentMethods: [
      for (final m in (j['paymentMethods'] as List?) ?? const ['venue'])
        m as String,
    ],
  );
}

Map<String, Object?> eventToJson(PadelEvent e) => {
  'name': e.name.trim(),
  'slug': e.slug,
  'status': e.status.name,
  'venue': {'name': e.venueName.trim(), 'address': e.venueAddress.trim()},
  'startDate': Timestamp.fromDate(e.startDate),
  'endDate': Timestamp.fromDate(e.endDate),
  'registrationDeadline': Timestamp.fromDate(e.registrationDeadline),
  'courts': [for (final c in e.courts) c.toJson()],
  'rules': e.rules.toJson(),
  'matchMinutes': e.matchMinutes,
  'minRestMinutes': e.minRestMinutes,
  'checkInMinutesBefore': e.checkInMinutesBefore,
  'paymentMethods': e.paymentMethods,
};

EventCategory categoryFromDoc(String id, Map<String, Object?> j) =>
    EventCategory(
      id: id,
      name: j['name'] as String? ?? '',
      capacity: (j['capacity'] as num?)?.toInt() ?? 0,
      priceCents: (j['priceCents'] as num?)?.toInt() ?? 0,
      format: DrawFormat.fromId(j['format'] as String?),
      confirmedCount: (j['confirmedCount'] as num?)?.toInt() ?? 0,
      waitlistCount: (j['waitlistCount'] as num?)?.toInt() ?? 0,
      drawStatus: j['drawStatus'] as String? ?? 'none',
    );
