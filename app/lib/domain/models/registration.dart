/// Inscripción de una pareja a una categoría. Dart puro.
library;

import 'dart:math';

import 'event.dart';

enum RegistrationStatus {
  pendingPartner('pending_partner', 'Esperando a tu pareja'),
  pendingPayment('pending_payment', 'Pago pendiente'),
  confirmed('confirmed', 'Confirmada'),
  waitlist('waitlist', 'Lista de espera'),
  cancelled('cancelled', 'Cancelada');

  const RegistrationStatus(this.id, this.label);
  final String id;
  final String label;

  static RegistrationStatus fromId(String? id) =>
      RegistrationStatus.values.where((s) => s.id == id).firstOrNull ??
      RegistrationStatus.pendingPartner;
}

enum PaymentMethod {
  venue('venue', 'Pago en sede'),
  mercadopago('mercadopago', 'Mercado Pago'),
  stripe('stripe', 'Tarjeta');

  const PaymentMethod(this.id, this.label);
  final String id;
  final String label;

  static PaymentMethod? fromId(String? id) =>
      PaymentMethod.values.where((m) => m.id == id).firstOrNull;
}

enum PaymentStatus { pending, paid, refunded }

class RegistrationPlayer {
  const RegistrationPlayer({
    required this.uid,
    required this.name,
    required this.club,
  });
  final String uid;
  final String name;
  final String club;

  Map<String, Object?> toJson() => {'uid': uid, 'name': name, 'club': club};
  factory RegistrationPlayer.fromJson(Map<String, Object?> j) =>
      RegistrationPlayer(
        uid: j['uid'] as String? ?? '',
        name: j['name'] as String? ?? '',
        club: j['club'] as String? ?? '',
      );

  /// Apellido para etiquetas de pareja: todo lo que sigue al nombre, con
  /// mayúscula inicial. "Julia Gasparini" → "Gasparini",
  /// "César de Anda" → "De Anda", "Marvin" → "Marvin".
  String get lastName {
    final parts = name.trim().split(RegExp(r'\s+'));
    final rest = parts.length > 1 ? parts.sublist(1).join(' ') : parts.first;
    return rest.isEmpty ? rest : rest[0].toUpperCase() + rest.substring(1);
  }
}

class Payment {
  const Payment({
    this.method,
    this.status = PaymentStatus.pending,
    required this.amountCents,
    this.paidCents = 0,
    this.markedByUid,
    this.paidAt,
  });

  final PaymentMethod? method;
  final PaymentStatus status;
  final int amountCents;
  final int paidCents;
  final String? markedByUid;
  final DateTime? paidAt;

  bool get isPaid => status == PaymentStatus.paid;
}

class Registration {
  const Registration({
    required this.id,
    required this.eventId,
    required this.categoryId,
    required this.players,
    required this.status,
    required this.slot,
    required this.inviteCode,
    required this.payment,
    this.invitedUid,
    this.availability = const {},
    this.waitlistPosition,
    this.createdAt,
  });

  final String id;
  final String eventId;
  final String categoryId;
  final List<RegistrationPlayer> players;
  final RegistrationStatus status;

  /// Si al inscribirse tomó lugar o quedó en lista de espera.
  final RegistrationSlot slot;
  final String inviteCode;

  /// Jugador invitado por usuario (si se invitó por link queda null).
  final String? invitedUid;

  /// Disponibilidad por jugador: uid → día (yyyy-MM-dd) → franjas.
  final Map<String, Map<String, Set<DaySlot>>> availability;
  final Payment payment;
  final int? waitlistPosition;
  final DateTime? createdAt;

  List<String> get playerUids => [for (final p in players) p.uid];
  RegistrationPlayer get captain => players.first;
  RegistrationPlayer? get partner => players.length > 1 ? players[1] : null;
  bool get hasPartner => partner != null;

  /// "Gasparini / De Anda" o "Gasparini / (pendiente)".
  String get label =>
      '${captain.lastName} / ${partner?.lastName ?? 'por confirmar'}';

  /// Franjas en que pueden los dos jugadores.
  Map<String, Set<DaySlot>> get sharedAvailability =>
      intersectAvailability(availability.values.toList());
}

/// Intersección de la disponibilidad de varios jugadores.
/// Si alguien todavía no cargó nada, no restringe.
Map<String, Set<DaySlot>> intersectAvailability(
  List<Map<String, Set<DaySlot>>> perPlayer,
) {
  final loaded = perPlayer
      .where((m) => m.values.any((s) => s.isNotEmpty))
      .toList();
  if (loaded.isEmpty) return {};
  final result = <String, Set<DaySlot>>{};
  for (final day in loaded.first.keys) {
    var slots = {...loaded.first[day]!};
    for (final other in loaded.skip(1)) {
      slots = slots.intersection(other[day] ?? const {});
    }
    if (slots.isNotEmpty) result[day] = slots;
  }
  return result;
}

/// Estado al que pasa una inscripción cuando la pareja acepta.
RegistrationStatus statusAfterPartnerAccepts(
  RegistrationSlot slot,
  PaymentStatus payment,
) {
  if (slot == RegistrationSlot.waitlist) return RegistrationStatus.waitlist;
  return payment == PaymentStatus.paid
      ? RegistrationStatus.confirmed
      : RegistrationStatus.pendingPayment;
}

/// Estado al registrar un pago.
RegistrationStatus statusAfterPayment(Registration r) {
  if (r.status == RegistrationStatus.waitlist ||
      r.status == RegistrationStatus.cancelled) {
    return r.status;
  }
  return r.hasPartner
      ? RegistrationStatus.confirmed
      : RegistrationStatus.pendingPartner;
}

/// Código de invitación: 6 caracteres sin ambigüedades (sin 0/O, 1/I/L).
String newInviteCode([Random? random]) {
  const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final r = random ?? Random.secure();
  return List.generate(6, (_) => alphabet[r.nextInt(alphabet.length)]).join();
}

/// Resumen del panel admin.
class RegistrationSummary {
  const RegistrationSummary({
    required this.total,
    required this.paid,
    required this.pending,
    required this.waitlist,
    required this.collectedCents,
  });

  final int total;
  final int paid;
  final int pending;
  final int waitlist;
  final int collectedCents;

  factory RegistrationSummary.of(Iterable<Registration> regs) {
    var total = 0, paid = 0, pending = 0, waitlist = 0, collected = 0;
    for (final r in regs) {
      if (r.status == RegistrationStatus.cancelled) continue;
      if (r.status == RegistrationStatus.waitlist) {
        waitlist++;
        continue;
      }
      total++;
      if (r.payment.isPaid) {
        paid++;
        collected += r.payment.paidCents;
      } else {
        pending++;
      }
    }
    return RegistrationSummary(
      total: total,
      paid: paid,
      pending: pending,
      waitlist: waitlist,
      collectedCents: collected,
    );
  }
}

/// Formato de dinero MXN: 140000 → "$1,400".
String formatMxn(int cents) {
  final pesos = cents ~/ 100;
  final s = pesos.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  final rest = cents % 100;
  return '\$$buf${rest == 0 ? '' : '.${rest.toString().padLeft(2, '0')}'}';
}

/// Clave de día "yyyy-MM-dd".
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
