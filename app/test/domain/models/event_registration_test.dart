import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:leva/domain/models/event.dart';
import 'package:leva/domain/models/registration.dart';

PadelEvent event({EventStatus status = EventStatus.open}) => PadelEvent(
  id: 'e1',
  name: 'LEVA Open Otoño 2026',
  status: status,
  venueName: 'Arena LEVA',
  startDate: DateTime(2026, 11, 14, 8),
  endDate: DateTime(2026, 11, 16, 22),
  registrationDeadline: DateTime(2026, 11, 10, 23, 59),
  courts: Court.numbered(4),
);

const p1 = RegistrationPlayer(
  uid: 'a',
  name: 'Julia Gasparini',
  club: 'Providencia',
);
const p2 = RegistrationPlayer(uid: 'b', name: 'César de Anda', club: 'Zapopan');

Registration reg({
  List<RegistrationPlayer> players = const [p1, p2],
  RegistrationStatus status = RegistrationStatus.pendingPayment,
  RegistrationSlot slot = RegistrationSlot.confirmed,
  PaymentStatus pay = PaymentStatus.pending,
  int paid = 0,
}) => Registration(
  id: 'r',
  eventId: 'e1',
  categoryId: 'c4',
  players: players,
  status: status,
  slot: slot,
  inviteCode: 'ABC234',
  payment: Payment(
    method: PaymentMethod.venue,
    status: pay,
    amountCents: 140000,
    paidCents: paid,
  ),
);

void main() {
  group('evento', () {
    test('días del torneo para la disponibilidad', () {
      expect(event().days, [
        DateTime(2026, 11, 14),
        DateTime(2026, 11, 15),
        DateTime(2026, 11, 16),
      ]);
    });

    test('acepta inscripciones solo abierto y antes del cierre', () {
      expect(event().acceptsRegistrations(DateTime(2026, 11, 1)), isTrue);
      expect(event().acceptsRegistrations(DateTime(2026, 11, 11)), isFalse);
      expect(
        event(status: EventStatus.draft)
            .acceptsRegistrations(DateTime(2026, 11, 1)),
        isFalse,
      );
      expect(EventStatus.draft.isPublic, isFalse);
    });

    test('slug sin acentos para el link público', () {
      expect(event().slug, 'leva-open-otono-2026');
      expect(slugify('  Copa Navidad — LEVA!! '), 'copa-navidad-leva');
    });

    test('canchas numeradas', () {
      expect(Court.numbered(2).map((c) => '${c.id}:${c.name}'), [
        'c1:Cancha 1',
        'c2:Cancha 2',
      ]);
    });

    test('validaciones', () {
      final s = DateTime(2026, 11, 14);
      expect(
        EventValidators.dates(
          s,
          DateTime(2026, 11, 13),
          DateTime(2026, 11, 10),
        ),
        contains('terminar antes'),
      );
      expect(
        EventValidators.dates(
          s,
          DateTime(2026, 11, 16),
          DateTime(2026, 11, 15),
        ),
        contains('cerrar antes'),
      );
      expect(
        EventValidators.dates(
          s,
          DateTime(2026, 11, 14),
          DateTime(2026, 11, 10),
        ),
        isNull,
      );
      expect(EventValidators.capacity(1), isNotNull);
      expect(EventValidators.capacity(16), isNull);
      expect(EventValidators.priceMxn(0), isNull);
      expect(EventValidators.courts(0), isNotNull);
    });
  });

  group('cupos y lista de espera', () {
    test('con lugar libre toma lugar; lleno va a lista de espera', () {
      const c = EventCategory(
        id: 'c4',
        name: '4ta',
        capacity: 16,
        priceCents: 140000,
        confirmedCount: 15,
      );
      expect(c.nextSlot, RegistrationSlot.confirmed);
      expect(c.spotsLeft, 1);
      const lleno = EventCategory(
        id: 'c5',
        name: '5ta',
        capacity: 16,
        priceCents: 140000,
        confirmedCount: 16,
      );
      expect(lleno.isFull, isTrue);
      expect(lleno.nextSlot, RegistrationSlot.waitlist);
      expect(lleno.spotsLeft, 0);
    });

    test('cuando acepta la pareja: con lugar → pago pendiente o confirmada; en espera sigue en espera', () {
      expect(
        statusAfterPartnerAccepts(
          RegistrationSlot.confirmed,
          PaymentStatus.pending,
        ),
        RegistrationStatus.pendingPayment,
      );
      expect(
        statusAfterPartnerAccepts(
          RegistrationSlot.confirmed,
          PaymentStatus.paid,
        ),
        RegistrationStatus.confirmed,
      );
      expect(
        statusAfterPartnerAccepts(
          RegistrationSlot.waitlist,
          PaymentStatus.pending,
        ),
        RegistrationStatus.waitlist,
      );
    });

    test(
      'al pagar: confirma si ya hay pareja; si no, sigue esperando pareja',
      () {
        expect(statusAfterPayment(reg()), RegistrationStatus.confirmed);
        expect(
          statusAfterPayment(
            reg(players: const [p1], status: RegistrationStatus.pendingPartner),
          ),
          RegistrationStatus.pendingPartner,
        );
        expect(
          statusAfterPayment(reg(status: RegistrationStatus.waitlist)),
          RegistrationStatus.waitlist,
        );
      },
    );
  });

  group('pareja y disponibilidad', () {
    test('etiqueta con apellidos', () {
      expect(reg().label, 'Gasparini / De Anda');
      expect(reg(players: const [p1]).label, 'Gasparini / por confirmar');
    });

    test('la disponibilidad compartida es la intersección', () {
      final a = {
        '2026-11-14': {DaySlot.tarde, DaySlot.noche},
        '2026-11-15': {DaySlot.manana},
      };
      final b = {
        '2026-11-14': {DaySlot.noche},
        '2026-11-15': {DaySlot.tarde},
      };
      expect(intersectAvailability([a, b]), {
        '2026-11-14': {DaySlot.noche},
      });
    });

    test('quien no cargó disponibilidad no restringe', () {
      final a = {
        '2026-11-14': {DaySlot.tarde},
      };
      expect(intersectAvailability([a, {}]), a);
      expect(intersectAvailability([{}, {}]), isEmpty);
    });

    test('código de invitación: 6 caracteres sin ambiguos', () {
      final r = Random(1);
      for (var i = 0; i < 500; i++) {
        final c = newInviteCode(r);
        expect(c, hasLength(6));
        expect(c, isNot(matches(RegExp('[01OIL]'))));
      }
    });
  });

  group('panel admin', () {
    test(
      'resumen: parejas con lugar, pagadas, pendientes, espera y cobrado',
      () {
        final s = RegistrationSummary.of([
          reg(
            pay: PaymentStatus.paid,
            paid: 140000,
            status: RegistrationStatus.confirmed,
          ),
          reg(),
          reg(
            status: RegistrationStatus.waitlist,
            slot: RegistrationSlot.waitlist,
          ),
          reg(status: RegistrationStatus.cancelled),
        ]);
        expect(
          [s.total, s.paid, s.pending, s.waitlist, s.collectedCents],
          [2, 1, 1, 1, 140000],
        );
      },
    );

    test(
      'quien entró en espera sin pareja cuenta como espera, no como pendiente',
      () {
        final solo = reg(
          players: const [p1],
          status: RegistrationStatus.pendingPartner,
          slot: RegistrationSlot.waitlist,
        );
        expect(solo.onWaitlist, isTrue);
        expect(
          reg(status: RegistrationStatus.pendingPartner).onWaitlist,
          isFalse,
        );
        expect(
          reg(
            status: RegistrationStatus.cancelled,
            slot: RegistrationSlot.waitlist,
          ).onWaitlist,
          isFalse,
        );
        final s = RegistrationSummary.of([solo, reg()]);
        expect([s.total, s.pending, s.waitlist], [1, 1, 1]);
      },
    );

    test('formato de dinero MXN', () {
      expect(formatMxn(140000), r'$1,400');
      expect(formatMxn(5320000), r'$53,200');
      expect(formatMxn(70050), r'$700.50');
      expect(formatMxn(0), r'$0');
    });

    test(
      'clave de día',
      () => expect(dayKey(DateTime(2026, 1, 5)), '2026-01-05'),
    );
  });
}
