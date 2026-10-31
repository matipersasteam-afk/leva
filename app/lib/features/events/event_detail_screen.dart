import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/session.dart';
import '../../core/design_system/design_system.dart';
import '../../domain/models/event.dart';
import '../../domain/models/registration.dart';
import 'event_format.dart';
import 'event_widgets.dart';

/// Detalle del torneo: datos, categorías con cupos, reglas e inscripción.
class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});
  final String eventId;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  String? _categoryId;

  @override
  Widget build(BuildContext context) {
    final event = ref.watch(eventProvider(widget.eventId));
    final categories =
        ref.watch(categoriesProvider(widget.eventId)).value ?? const [];
    final mine =
        ref.watch(myRegistrationsProvider(widget.eventId)).value ?? const [];
    final active = mine
        .where((r) => r.status != RegistrationStatus.cancelled)
        .toList();

    return Scaffold(
      body: switch (event) {
        AsyncData(value: final e?) => _body(context, e, categories, active),
        AsyncData() => _missing(context),
        AsyncError() => _missing(context),
        _ => const Center(
          child: CircularProgressIndicator(color: LevaColors.gold500),
        ),
      },
    );
  }

  Widget _missing(BuildContext context) => SafeArea(
    child: Column(
      children: [
        LevaTopBar(onBack: () => context.pop()),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: LevaSpace.gutter),
          child: LevaEmptyState(
            title: 'Torneo no disponible',
            message: 'Este torneo no existe o todavía no se publicó.',
          ),
        ),
      ],
    ),
  );

  Widget _body(
    BuildContext context,
    PadelEvent e,
    List<EventCategory> categories,
    List<Registration> mine,
  ) {
    final selected = categories.where((c) => c.id == _categoryId).firstOrNull;
    final registeredCats = {for (final r in mine) r.categoryId};
    final canRegister = e.acceptsRegistrations(DateTime.now());

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.only(
            bottom: 160 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            SafeArea(
              bottom: false,
              child: LevaTopBar(
                onBack: () => context.pop(),
                trailing: LevaIconButton(
                  icon: Icons.ios_share,
                  label: 'Compartir torneo',
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: 'leva.app/torneo/${e.slug}'),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link del torneo copiado')),
                    );
                  },
                ),
              ),
            ),
            SizedBox(
              height: 220,
              child: Stack(
                children: [
                  const Positioned(
                    right: -20,
                    top: 0,
                    bottom: 0,
                    child: PosterStripes(width: 60),
                  ),
                  Positioned(
                    left: LevaSpace.gutter,
                    right: 90,
                    bottom: LevaSpace.s5,
                    child: EventTitle(e.name, size: 80),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LevaSpace.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Facts(event: e),
                  for (final r in mine) ...[
                    const SizedBox(height: LevaSpace.s4),
                    _MyRegistration(
                      reg: r,
                      categoryName:
                          categories
                              .where((c) => c.id == r.categoryId)
                              .firstOrNull
                              ?.name ??
                          '',
                      onTap: () =>
                          context.push(Routes.registration(e.id, r.id)),
                    ),
                  ],
                  LevaSectionHeader(
                    'Elige categoría',
                    trailing: Text(
                      'Cupos por pareja',
                      style: LevaType.meta.copyWith(fontSize: 12),
                    ),
                  ),
                  if (categories.isEmpty)
                    Text(
                      'Las categorías se publican pronto.',
                      style: LevaType.body(color: LevaColors.tx2),
                    ),
                  for (final c in categories) ...[
                    LevaChoiceCard(
                      selected: c.id == _categoryId,
                      enabled: canRegister && !registeredCats.contains(c.id),
                      onTap: () => setState(() => _categoryId = c.id),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 92,
                            child: Text(
                              c.name.toUpperCase(),
                              style: LevaType.display(26),
                            ),
                          ),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                text: '${c.confirmedCount} de ${c.capacity}',
                                children: [
                                  if (registeredCats.contains(c.id))
                                    const TextSpan(text: ' · Ya tienes lugar')
                                  else if (c.isFull)
                                    const TextSpan(
                                      text: ' · Lista de espera',
                                      style: TextStyle(
                                        color: LevaColors.pending,
                                      ),
                                    ),
                                ],
                              ),
                              style: LevaType.body(
                                size: 13,
                                color: LevaColors.tx2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: LevaSpace.s2),
                  ],
                  const LevaSectionHeader('Reglas'),
                  ..._rules(e).map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check,
                            size: 18,
                            color: LevaColors.gold500,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              t,
                              style: LevaType.body(
                                size: 14,
                                color: LevaColors.tx2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: LevaStickyBar(
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('POR PAREJA', style: LevaType.support()),
                    Text(
                      selected == null ? '—' : formatMxn(selected.priceCents),
                      style: LevaType.numbers(34),
                    ),
                  ],
                ),
                const SizedBox(width: LevaSpace.s4),
                Expanded(
                  child: LevaButton(
                    label: !canRegister
                        ? (e.status == EventStatus.open
                              ? 'Inscripciones cerradas'
                              : e.status.label)
                        : selected == null
                        ? 'Elige categoría'
                        : selected.isFull
                        ? 'Lista de espera'
                        : 'Inscribirme',
                    onPressed: canRegister && selected != null
                        ? () => context.push(
                            Routes.registerStart(e.id, selected.id),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<String> _rules(PadelEvent e) => [
    e.rules.goldenPoint
        ? 'Punto de oro en todos los games.'
        : 'Games con ventaja tradicional.',
    if (e.rules.usesSuperTiebreak)
      'Súper tie-break a ${e.rules.superTiebreakPoints} en lugar del 3er set.',
    'Check-in con QR ${e.checkInMinutesBefore} min antes de tu primer partido.',
    'Descanso mínimo de ${e.minRestMinutes} min entre partidos.',
  ];
}

class _Facts extends StatelessWidget {
  const _Facts({required this.event});
  final PadelEvent event;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, String value) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: LevaColors.ink2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: LevaType.support()),
          const SizedBox(height: 4),
          Text(value, style: LevaType.body(weight: 600)),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(LevaRadius.md),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: LevaColors.line),
          borderRadius: BorderRadius.circular(LevaRadius.md),
          color: LevaColors.line,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: cell('Fechas', EventFormat.range(event))),
                const SizedBox(width: 1),
                Expanded(child: cell('Sede', event.venueName)),
              ],
            ),
            const SizedBox(height: 1),
            Row(
              children: [
                Expanded(child: cell('Canchas', '${event.courts.length}')),
                const SizedBox(width: 1),
                Expanded(
                  child: cell(
                    'Cierre',
                    EventFormat.deadline(event.registrationDeadline),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MyRegistration extends StatelessWidget {
  const _MyRegistration({
    required this.reg,
    required this.categoryName,
    required this.onTap,
  });
  final Registration reg;
  final String categoryName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LevaPressable(
      onTap: onTap,
      scale: 0.985,
      semanticLabel: 'Mi inscripción en $categoryName',
      child: LevaPanel(
        highlight: true,
        padding: const EdgeInsets.all(LevaSpace.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                LevaTag(categoryName, kind: LevaTagKind.gold),
                const SizedBox(width: LevaSpace.s2),
                registrationTag(reg),
                const Spacer(),
                const Icon(Icons.chevron_right, color: LevaColors.tx2),
              ],
            ),
            const SizedBox(height: LevaSpace.s4),
            LevaDuel(
              a: [reg.captain.lastName],
              b: [reg.partner?.lastName ?? 'Por confirmar'],
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}
