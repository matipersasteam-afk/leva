import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/session.dart';
import '../../core/design_system/design_system.dart';
import '../../domain/models/event.dart';
import '../events/event_format.dart';

/// Panel de LEVA: lista de torneos (incluye borradores).
class AdminEventsScreen extends ConsumerWidget {
  const AdminEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(allEventsProvider);
    return Scaffold(
      body: LevaCourtBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  LevaTopBar(
                    onBack: () => context.pop(),
                    trailing: const LevaRoleChip('Admin'),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        LevaSpace.gutter,
                        0,
                        LevaSpace.gutter,
                        LevaSpace.s10,
                      ),
                      children: [
                        Text('PANEL DE', style: LevaType.xl),
                        GoldText('LEVA', style: LevaType.xl),
                        const SizedBox(height: LevaSpace.s5),
                        LevaButton(
                          label: 'Crear torneo',
                          icon: Icons.add,
                          onPressed: () => context.push(Routes.adminNewEvent),
                        ),
                        const LevaSectionHeader('Torneos'),
                        switch (events) {
                          AsyncData(:final value) when value.isEmpty =>
                            const LevaEmptyState(
                              title: 'Sin torneos',
                              message: 'Crea el primero. Queda como borrador hasta que abras inscripciones.',
                            ),
                          AsyncData(:final value) => Column(
                            children: [
                              for (final e in value) _AdminEventRow(event: e),
                            ],
                          ),
                          AsyncError() => const LevaNotice(
                            'No pudimos cargar los torneos. ¿Tu cuenta tiene rol de admin?',
                          ),
                          _ => const Padding(
                            padding: EdgeInsets.all(LevaSpace.s8),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: LevaColors.gold500,
                              ),
                            ),
                          ),
                        },
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminEventRow extends StatelessWidget {
  const _AdminEventRow({required this.event});
  final PadelEvent event;

  @override
  Widget build(BuildContext context) {
    final kind = switch (event.status) {
      EventStatus.open => LevaTagKind.ok,
      EventStatus.live => LevaTagKind.live,
      EventStatus.draft => LevaTagKind.pending,
      _ => LevaTagKind.mute,
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: LevaSpace.s4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LevaColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LevaTag(event.status.label, kind: kind),
          const SizedBox(height: LevaSpace.s2),
          Text(
            event.name.toUpperCase(),
            style: LevaType.display(24),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${EventFormat.range(event)} · ${event.venueName}',
            style: LevaType.meta,
          ),
          const SizedBox(height: LevaSpace.s3),
          Row(
            children: [
              Expanded(
                child: LevaButton(
                  label: 'Editar',
                  icon: Icons.edit_outlined,
                  small: true,
                  variant: LevaButtonVariant.dark,
                  onPressed: () => context.push(Routes.adminEvent(event.id)),
                ),
              ),
              const SizedBox(width: LevaSpace.s2),
              Expanded(
                child: LevaButton(
                  label: 'Inscripciones',
                  icon: Icons.groups_outlined,
                  small: true,
                  variant: LevaButtonVariant.line,
                  onPressed: () =>
                      context.push(Routes.adminRegistrations(event.id)),
                ),
              ),
            ],
          ),
          const SizedBox(height: LevaSpace.s2),
          LevaButton(
            label: 'Draw',
            icon: Icons.account_tree_outlined,
            small: true,
            variant: LevaButtonVariant.line,
            onPressed: () => context.push(Routes.adminDraw(event.id)),
          ),
        ],
      ),
    );
  }
}
