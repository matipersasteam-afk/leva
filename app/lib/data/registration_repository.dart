import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/event.dart';
import '../domain/models/player_profile.dart';
import '../domain/models/registration.dart';

/// Invitación de pareja (`invites/{code}`), lo que ve quien abre el link.
class Invite {
  const Invite({
    required this.code,
    required this.eventId,
    required this.regId,
    required this.categoryId,
    required this.fromUid,
    required this.fromName,
    required this.eventName,
    required this.categoryName,
    required this.slot,
    required this.used,
    this.invitedUid,
    this.acceptedBy,
  });

  final String code;
  final String eventId;
  final String regId;
  final String categoryId;
  final String fromUid;
  final String fromName;
  final String eventName;
  final String categoryName;
  final RegistrationSlot slot;
  final bool used;
  final String? invitedUid;
  final String? acceptedBy;
}

/// Error de negocio ya traducido para mostrar.
class RegistrationFailure implements Exception {
  const RegistrationFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class RegistrationRepository {
  RegistrationRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, Object?>> _event(String id) =>
      _db.collection('events').doc(id);
  CollectionReference<Map<String, Object?>> _regs(String eventId) =>
      _event(eventId).collection('registrations');
  DocumentReference<Map<String, Object?>> _cat(String eventId, String catId) =>
      _event(eventId).collection('categories').doc(catId);
  DocumentReference<Map<String, Object?>> _invite(String code) =>
      _db.collection('invites').doc(code);

  Stream<List<Registration>> watchMine(String eventId, String uid) =>
      _regs(eventId)
          .where('playerUids', arrayContains: uid)
          .snapshots()
          .map(
            (q) => [
              for (final d in q.docs)
                registrationFromDoc(eventId, d.id, d.data()),
            ],
          );

  Stream<List<Registration>> watchAll(String eventId) => _regs(eventId)
      .orderBy('createdAt')
      .snapshots()
      .map(
        (q) => [
          for (final d in q.docs) registrationFromDoc(eventId, d.id, d.data()),
        ],
      );

  Stream<Registration?> watchOne(String eventId, String regId) => _regs(eventId)
      .doc(regId)
      .snapshots()
      .map(
        (s) => s.data() == null
            ? null
            : registrationFromDoc(eventId, s.id, s.data()!),
      );

  /// Invitaciones por usuario que me llegaron y no acepté.
  Stream<List<Invite>> watchMyInvites(String uid) => _db
      .collection('invites')
      .where('invitedUid', isEqualTo: uid)
      .where('used', isEqualTo: false)
      .snapshots()
      .map((q) => [for (final d in q.docs) _inviteFromDoc(d.id, d.data())]);

  Future<Invite?> getInvite(String code) async {
    final s = await _invite(code.toUpperCase()).get();
    return s.data() == null ? null : _inviteFromDoc(s.id, s.data()!);
  }

  /// Aparta lugar (o lista de espera) y crea la invitación para la pareja.
  /// Transacción: el contador de la categoría y la inscripción se escriben juntos.
  Future<({String regId, String code})> reserve({
    required PadelEvent event,
    required EventCategory category,
    required PlayerProfile me,
    PlayerProfile? partner,
  }) async {
    final regRef = _regs(event.id).doc();
    final code = newInviteCode();
    await _db.runTransaction((tx) async {
      final catSnap = await tx.get(_cat(event.id, category.id));
      final cat = categoryFromDocLite(catSnap.data() ?? const {});
      final slot = cat.confirmed < cat.capacity
          ? RegistrationSlot.confirmed
          : RegistrationSlot.waitlist;
      tx.set(regRef, {
        'categoryId': category.id,
        'playerUids': [me.uid],
        'players': [_player(me).toJson()],
        'status': RegistrationStatus.pendingPartner.id,
        'slot': slot.name,
        'invite': {
          'code': code,
          'invitedUid': partner?.uid,
          'acceptedAt': null,
        },
        'availability': <String, Object?>{},
        'payment': {
          'method': null,
          'split': 'full',
          'status': 'pending',
          'amountCents': cat.priceCents,
          'paidCents': 0,
          'markedByUid': null,
          'paidAt': null,
        },
        if (slot == RegistrationSlot.waitlist)
          'waitlistPosition': cat.waitlist + 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(_cat(event.id, category.id), {
        if (slot == RegistrationSlot.confirmed)
          'confirmedCount': cat.confirmed + 1,
        if (slot == RegistrationSlot.waitlist)
          'waitlistCount': cat.waitlist + 1,
        'lastRegId': regRef.id,
      });
      tx.set(_invite(code), {
        'eventId': event.id,
        'regId': regRef.id,
        'categoryId': category.id,
        'fromUid': me.uid,
        'fromName': me.displayName,
        'eventName': event.name,
        'categoryName': category.name,
        'slot': slot.name,
        'invitedUid': partner?.uid,
        'used': false,
        'acceptedBy': null,
        'acceptedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return (regId: regRef.id, code: code);
  }

  /// La pareja acepta: entra a la inscripción y la invitación queda usada.
  Future<void> acceptInvite(Invite invite, PlayerProfile me) async {
    if (invite.used) {
      throw const RegistrationFailure('Esta invitación ya fue aceptada.');
    }
    if (invite.fromUid == me.uid) {
      throw const RegistrationFailure(
        'No puedes aceptar tu propia invitación.',
      );
    }
    if (invite.invitedUid != null && invite.invitedUid != me.uid) {
      throw const RegistrationFailure('Esta invitación es para otro jugador.');
    }
    final batch = _db.batch();
    batch.update(_regs(invite.eventId).doc(invite.regId), {
      'playerUids': [invite.fromUid, me.uid],
      'players': FieldValue.arrayUnion([_player(me).toJson()]),
      'status': statusAfterPartnerAccepts(
        invite.slot,
        PaymentStatus.pending,
      ).id,
      'invite.acceptedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_invite(invite.code), {
      'used': true,
      'acceptedBy': me.uid,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      throw RegistrationFailure(
        e.code == 'permission-denied'
            ? 'No pudimos aceptar la invitación. Puede que ya la haya aceptado alguien más.'
            : 'No pudimos aceptar la invitación. Revisa tu conexión.',
      );
    }
  }

  Future<void> setAvailability(
    String eventId,
    String regId,
    String uid,
    Map<String, Set<DaySlot>> availability,
  ) => _regs(eventId).doc(regId).update({
    'availability.$uid': {
      for (final e in availability.entries)
        if (e.value.isNotEmpty) e.key: [for (final s in e.value) s.name],
    },
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> choosePayment(
    String eventId,
    String regId,
    PaymentMethod method,
  ) => _regs(eventId).doc(regId).update({
    'payment.method': method.id,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  // ---------- Admin / staff ----------

  Future<void> markPaid(
    Registration r, {
    required String byUid,
    PaymentMethod? method,
  }) => _regs(r.eventId).doc(r.id).update({
    'payment.status': 'paid',
    'payment.paidCents': r.payment.amountCents,
    'payment.method': (method ?? r.payment.method ?? PaymentMethod.venue).id,
    'payment.markedByUid': byUid,
    'payment.paidAt': FieldValue.serverTimestamp(),
    'status': statusAfterPayment(r).id,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  /// Cancela y libera el lugar (o el puesto en la lista de espera).
  Future<void> cancel(Registration r) => _db.runTransaction((tx) async {
    final catRef = _cat(r.eventId, r.categoryId);
    final cat = categoryFromDocLite((await tx.get(catRef)).data() ?? const {});
    final wasWaitlist = r.onWaitlist;
    tx.update(_regs(r.eventId).doc(r.id), {
      'status': RegistrationStatus.cancelled.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    tx.update(catRef, {
      if (wasWaitlist) 'waitlistCount': (cat.waitlist - 1).clamp(0, 1 << 30),
      if (!wasWaitlist) 'confirmedCount': (cat.confirmed - 1).clamp(0, 1 << 30),
    });
  });

  /// Pasa una pareja de la lista de espera a tener lugar, si hay cupo.
  Future<void> promote(Registration r) => _db.runTransaction((tx) async {
    final catRef = _cat(r.eventId, r.categoryId);
    final cat = categoryFromDocLite((await tx.get(catRef)).data() ?? const {});
    if (cat.confirmed >= cat.capacity) {
      throw const RegistrationFailure('No hay lugar libre en esta categoría.');
    }
    final status = !r.hasPartner
        ? RegistrationStatus.pendingPartner
        : (r.payment.isPaid
              ? RegistrationStatus.confirmed
              : RegistrationStatus.pendingPayment);
    tx.update(_regs(r.eventId).doc(r.id), {
      'status': status.id,
      'slot': RegistrationSlot.confirmed.name,
      'waitlistPosition': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    tx.update(catRef, {
      'confirmedCount': cat.confirmed + 1,
      'waitlistCount': (cat.waitlist - 1).clamp(0, 1 << 30),
    });
  });

  static RegistrationPlayer _player(PlayerProfile p) =>
      RegistrationPlayer(uid: p.uid, name: p.displayName, club: p.club);
}

/// Lo mínimo de una categoría que necesitan las transacciones.
({int confirmed, int waitlist, int capacity, int priceCents})
categoryFromDocLite(Map<String, Object?> j) => (
  confirmed: (j['confirmedCount'] as num?)?.toInt() ?? 0,
  waitlist: (j['waitlistCount'] as num?)?.toInt() ?? 0,
  capacity: (j['capacity'] as num?)?.toInt() ?? 0,
  priceCents: (j['priceCents'] as num?)?.toInt() ?? 0,
);

Invite _inviteFromDoc(String code, Map<String, Object?> j) => Invite(
  code: code,
  eventId: j['eventId'] as String? ?? '',
  regId: j['regId'] as String? ?? '',
  categoryId: j['categoryId'] as String? ?? '',
  fromUid: j['fromUid'] as String? ?? '',
  fromName: j['fromName'] as String? ?? '',
  eventName: j['eventName'] as String? ?? '',
  categoryName: j['categoryName'] as String? ?? '',
  slot: j['slot'] == 'waitlist'
      ? RegistrationSlot.waitlist
      : RegistrationSlot.confirmed,
  used: j['used'] as bool? ?? false,
  invitedUid: j['invitedUid'] as String?,
  acceptedBy: j['acceptedBy'] as String?,
);

Registration registrationFromDoc(
  String eventId,
  String id,
  Map<String, Object?> j,
) {
  final invite = (j['invite'] as Map?)?.cast<String, Object?>() ?? const {};
  final pay = (j['payment'] as Map?)?.cast<String, Object?>() ?? const {};
  final avail =
      (j['availability'] as Map?)?.cast<String, Object?>() ?? const {};
  return Registration(
    id: id,
    eventId: eventId,
    categoryId: j['categoryId'] as String? ?? '',
    players: [
      for (final p in (j['players'] as List?) ?? const [])
        RegistrationPlayer.fromJson((p as Map).cast<String, Object?>()),
    ],
    status: RegistrationStatus.fromId(j['status'] as String?),
    slot: j['slot'] == 'waitlist'
        ? RegistrationSlot.waitlist
        : RegistrationSlot.confirmed,
    inviteCode: invite['code'] as String? ?? '',
    invitedUid: invite['invitedUid'] as String?,
    availability: {
      for (final e in avail.entries)
        e.key: {
          for (final d
              in ((e.value as Map?)?.cast<String, Object?>() ?? const {})
                  .entries)
            d.key: {
              for (final s in (d.value as List?) ?? const [])
                if (DaySlot.values.asNameMap()[s] != null)
                  DaySlot.values.asNameMap()[s]!,
            },
        },
    },
    payment: Payment(
      method: PaymentMethod.fromId(pay['method'] as String?),
      status:
          PaymentStatus.values.asNameMap()[pay['status']] ??
          PaymentStatus.pending,
      amountCents: (pay['amountCents'] as num?)?.toInt() ?? 0,
      paidCents: (pay['paidCents'] as num?)?.toInt() ?? 0,
      markedByUid: pay['markedByUid'] as String?,
      paidAt: (pay['paidAt'] as Timestamp?)?.toDate(),
    ),
    waitlistPosition: (j['waitlistPosition'] as num?)?.toInt(),
    createdAt: (j['createdAt'] as Timestamp?)?.toDate(),
  );
}
