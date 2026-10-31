import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design_system/design_system.dart';
import '../../domain/models/event.dart';
import '../../domain/models/registration.dart';
import 'event_format.dart';

/// Título de torneo en dos tonos: las primeras palabras en contorno y la
/// última en dorado ("LEVA OPEN" / "OTOÑO").
class EventTitle extends StatelessWidget {
  const EventTitle(this.name, {super.key, this.size = 64});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final words = name.trim().toUpperCase().split(RegExp(r'\s+'));
    final last = words.removeLast();
    final style = LevaType.display(size);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (words.isNotEmpty)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              words.join(' '),
              maxLines: 1,
              style: style.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.3
                  ..color = LevaColors.gold500,
              ),
            ),
          ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: GoldText(last, style: style, maxLines: 1),
        ),
      ],
    );
  }
}

/// Franjas doradas inclinadas del afiche.
class PosterStripes extends StatelessWidget {
  const PosterStripes({super.key, this.width = 44});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.skewX(-20 * math.pi / 180),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: .85,
            child: Container(
              width: width,
              decoration: const BoxDecoration(
                gradient: LevaGradients.goldVertical,
              ),
            ),
          ),
          SizedBox(width: width * .27),
          Opacity(
            opacity: .45,
            child: Container(
              width: width * .23,
              decoration: const BoxDecoration(
                gradient: LevaGradients.goldVertical,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Afiche del torneo destacado en Inicio.
class EventPosterCard extends StatelessWidget {
  const EventPosterCard({
    super.key,
    required this.event,
    required this.onTap,
    this.spots,
  });
  final PadelEvent event;
  final VoidCallback onTap;
  final String? spots;

  @override
  Widget build(BuildContext context) {
    final open = event.status == EventStatus.open;
    return LevaPressable(
      onTap: onTap,
      scale: 0.985,
      semanticLabel: 'Torneo ${event.name}',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: LevaColors.ink2,
          borderRadius: BorderRadius.circular(LevaRadius.md),
          border: Border.all(color: LevaColors.line),
        ),
        child: Stack(
          children: [
            const Positioned(
              right: -10,
              top: 0,
              bottom: 0,
              child: PosterStripes(),
            ),
            Padding(
              padding: const EdgeInsets.all(LevaSpace.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LevaTag(
                    event.status.label,
                    kind: open ? LevaTagKind.ok : LevaTagKind.mute,
                  ),
                  const SizedBox(height: LevaSpace.s4),
                  Padding(
                    padding: const EdgeInsets.only(right: 70),
                    child: EventTitle(event.name),
                  ),
                  const SizedBox(height: LevaSpace.s5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Fechas y sede en líneas separadas, libres de la franja dorada.
                            Padding(
                              padding: const EdgeInsets.only(right: 96),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    EventFormat.range(event).toUpperCase(),
                                    style: LevaType.support(),
                                    maxLines: 1,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    event.venueName.toUpperCase(),
                                    style: LevaType.support(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (spots != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                spots!,
                                style: LevaType.meta.copyWith(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const LevaIconButton(
                        icon: Icons.chevron_right,
                        label: 'Ver torneo',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila compacta para los demás torneos.
class EventRow extends StatelessWidget {
  const EventRow({super.key, required this.event, required this.onTap});
  final PadelEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LevaPressable(
      onTap: onTap,
      scale: 0.985,
      semanticLabel: 'Torneo ${event.name}',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: LevaSpace.s4),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: LevaColors.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 62,
              decoration: BoxDecoration(
                color: LevaColors.navy,
                borderRadius: BorderRadius.circular(LevaRadius.sm),
                border: Border.all(color: LevaColors.line),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${event.startDate.day}',
                    style: LevaType.display(28, color: LevaColors.gold200),
                  ),
                  Text(
                    EventFormat.month(event.startDate).toUpperCase(),
                    style: LevaType.support(tracking: 0.2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: LevaSpace.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name.toUpperCase(),
                    style: LevaType.display(22),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(event.venueName, style: LevaType.meta),
                ],
              ),
            ),
            LevaTag(
              event.status == EventStatus.open ? 'Abierto' : event.status.label,
            ),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta de estado de una inscripción.
LevaTag registrationTag(Registration r) => switch (r.status) {
  RegistrationStatus.confirmed => const LevaTag(
    'Confirmada',
    kind: LevaTagKind.ok,
  ),
  RegistrationStatus.pendingPayment => const LevaTag(
    'Pago pendiente',
    kind: LevaTagKind.pending,
  ),
  RegistrationStatus.pendingPartner => const LevaTag(
    'Falta tu pareja',
    kind: LevaTagKind.pending,
  ),
  RegistrationStatus.waitlist => LevaTag(
    'Espera${r.waitlistPosition == null ? '' : ' #${r.waitlistPosition}'}',
  ),
  RegistrationStatus.cancelled => const LevaTag('Cancelada'),
};
