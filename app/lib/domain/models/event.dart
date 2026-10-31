/// Evento (torneo) de LEVA y sus categorías. Dart puro: las fechas son
/// DateTime y el mapeo a Timestamp vive en `data/`.
library;

import '../scoring/scoring_rules.dart';

enum EventStatus {
  draft('Borrador'),
  open('Inscripciones abiertas'),
  closed('Inscripciones cerradas'),
  live('En juego'),
  finished('Finalizado');

  const EventStatus(this.label);
  final String label;

  /// Visible para jugadores y en rutas públicas.
  bool get isPublic => this != EventStatus.draft;
}

enum DrawFormat {
  groupsKnockout('groups_knockout', 'Grupos + eliminatoria'),
  singleElim('single_elim', 'Eliminación directa'),
  americano('americano', 'Americano'),
  relampago('relampago', 'Relámpago');

  const DrawFormat(this.id, this.label);
  final String id;
  final String label;

  static DrawFormat fromId(String? id) =>
      DrawFormat.values.where((f) => f.id == id).firstOrNull ??
      DrawFormat.groupsKnockout;
}

/// Franja horaria de disponibilidad.
enum DaySlot {
  manana('Mañana', '8–12'),
  tarde('Tarde', '12–17'),
  noche('Noche', '17–23');

  const DaySlot(this.label, this.hours);
  final String label;
  final String hours;
}

class Court {
  const Court(this.id, this.name);
  final String id;
  final String name;

  Map<String, Object?> toJson() => {'id': id, 'name': name};
  factory Court.fromJson(Map<String, Object?> j) =>
      Court(j['id']! as String, j['name']! as String);

  /// Cancha 1..n con ids c1..cn.
  static List<Court> numbered(int n) => [
    for (var i = 1; i <= n; i++) Court('c$i', 'Cancha $i'),
  ];
}

class PadelEvent {
  const PadelEvent({
    required this.id,
    required this.name,
    required this.status,
    required this.venueName,
    required this.startDate,
    required this.endDate,
    required this.registrationDeadline,
    required this.courts,
    this.venueAddress = '',
    this.rules = ScoringRules.leva,
    this.matchMinutes = 60,
    this.minRestMinutes = 60,
    this.checkInMinutesBefore = 20,
    this.paymentMethods = const ['venue'],
  });

  final String id;
  final String name;
  final EventStatus status;
  final String venueName;
  final String venueAddress;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime registrationDeadline;
  final List<Court> courts;
  final ScoringRules rules;
  final int matchMinutes;
  final int minRestMinutes;
  final int checkInMinutesBefore;
  final List<String> paymentMethods;

  /// Slug para el link público del cuadro (/c/{slug}).
  String get slug => slugify(name);

  /// Días del torneo (sin hora), para la grilla de disponibilidad.
  List<DateTime> get days {
    final first = DateTime(startDate.year, startDate.month, startDate.day);
    final last = DateTime(endDate.year, endDate.month, endDate.day);
    return [
      for (
        var d = first;
        !d.isAfter(last);
        d = DateTime(d.year, d.month, d.day + 1)
      )
        d,
    ];
  }

  /// Se puede inscribir ahora.
  bool acceptsRegistrations(DateTime now) =>
      status == EventStatus.open && !now.isAfter(registrationDeadline);

  PadelEvent copyWith({
    String? name,
    EventStatus? status,
    String? venueName,
    String? venueAddress,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? registrationDeadline,
    List<Court>? courts,
    ScoringRules? rules,
    int? matchMinutes,
    int? minRestMinutes,
  }) => PadelEvent(
    id: id,
    name: name ?? this.name,
    status: status ?? this.status,
    venueName: venueName ?? this.venueName,
    venueAddress: venueAddress ?? this.venueAddress,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    registrationDeadline: registrationDeadline ?? this.registrationDeadline,
    courts: courts ?? this.courts,
    rules: rules ?? this.rules,
    matchMinutes: matchMinutes ?? this.matchMinutes,
    minRestMinutes: minRestMinutes ?? this.minRestMinutes,
    checkInMinutesBefore: checkInMinutesBefore,
    paymentMethods: paymentMethods,
  );
}

class EventCategory {
  const EventCategory({
    required this.id,
    required this.name,
    required this.capacity,
    required this.priceCents,
    this.format = DrawFormat.groupsKnockout,
    this.confirmedCount = 0,
    this.waitlistCount = 0,
    this.drawStatus = 'none',
  });

  /// none | draft | published
  final String drawStatus;
  bool get isPublishedDraw => drawStatus == 'published';

  final String id;

  /// "4ta", "Suma 9", "Mixto 5ta"…
  final String name;

  /// Parejas con lugar (no incluye lista de espera).
  final int capacity;

  /// Precio por pareja en centavos MXN.
  final int priceCents;
  final DrawFormat format;

  /// Lugares tomados (parejas con lugar, pagadas o no).
  final int confirmedCount;
  final int waitlistCount;

  bool get isFull => confirmedCount >= capacity;
  int get spotsLeft => (capacity - confirmedCount).clamp(0, capacity);

  /// Dónde cae una inscripción nueva.
  RegistrationSlot get nextSlot =>
      isFull ? RegistrationSlot.waitlist : RegistrationSlot.confirmed;

  EventCategory copyWith({
    String? name,
    int? capacity,
    int? priceCents,
    DrawFormat? format,
  }) => EventCategory(
    id: id,
    name: name ?? this.name,
    capacity: capacity ?? this.capacity,
    priceCents: priceCents ?? this.priceCents,
    format: format ?? this.format,
    confirmedCount: confirmedCount,
    waitlistCount: waitlistCount,
    drawStatus: drawStatus,
  );
}

enum RegistrationSlot { confirmed, waitlist }

/// "LEVA Open Otoño 2026" → "leva-open-otono-2026".
String slugify(String s) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñç';
  const to = 'aaaaeeeeiiiioooouuuunc';
  final lower = s.toLowerCase();
  final buf = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    buf.write(i >= 0 ? to[i] : ch);
  }
  return buf
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Validaciones del formulario de evento (mensajes es-MX). null = válido.
abstract final class EventValidators {
  static String? name(String? v) {
    final t = v?.trim() ?? '';
    if (t.length < 4) return 'Escribe el nombre del torneo.';
    if (t.length > 60) return 'Máximo 60 caracteres.';
    return null;
  }

  static String? venue(String? v) =>
      (v?.trim().isEmpty ?? true) ? 'Escribe la sede.' : null;

  /// Fechas: inicio ≤ fin y cierre de inscripciones ≤ inicio.
  static String? dates(DateTime start, DateTime end, DateTime deadline) {
    if (end.isBefore(DateTime(start.year, start.month, start.day))) {
      return 'El torneo no puede terminar antes de empezar.';
    }
    if (deadline.isAfter(start)) {
      return 'Las inscripciones tienen que cerrar antes de que empiece el torneo.';
    }
    return null;
  }

  static String? capacity(int? v) {
    if (v == null || v < 2) return 'Al menos 2 parejas.';
    if (v > 128) return 'Máximo 128 parejas por categoría.';
    return null;
  }

  static String? priceMxn(int? v) {
    if (v == null || v < 0) return 'Escribe un precio válido (0 si es gratis).';
    if (v > 100000) return 'Revisa el precio.';
    return null;
  }

  static String? courts(int? v) {
    if (v == null || v < 1) return 'Al menos 1 cancha.';
    if (v > 20) return 'Máximo 20 canchas.';
    return null;
  }
}
