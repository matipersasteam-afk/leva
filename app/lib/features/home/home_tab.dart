import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/session.dart';
import '../../core/design_system/design_system.dart';
import '../../data/registration_repository.dart';
import '../events/event_widgets.dart';

/// Inicio del jugador: saludo, invitaciones pendientes y torneos.
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final events = ref.watch(publicEventsProvider);
    final invites = ref.watch(myInvitesProvider).value ?? const [];
    final isAdmin = ref.watch(isAdminProvider);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        LevaSpace.gutter,
        MediaQuery.paddingOf(context).top + LevaSpace.s6,
        LevaSpace.gutter,
        140,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HOLA', style: LevaType.support(size: 13, weight: 300)),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: GoldText(
                      (profile?.firstName ?? '').toUpperCase(),
                      style: LevaType.mega,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            if (profile != null)
              LevaPressable(
                onTap: () => context.go(Routes.profile),
                semanticLabel: 'Mi perfil',
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: LevaColors.navy,
                    border: Border.all(color: LevaColors.gold500, width: 1.5),
                  ),
                  child: Text(
                    profile.initials,
                    style: LevaType.display(18, color: LevaColors.gold200),
                  ),
                ),
              ),
          ],
        ),
        if (isAdmin) ...[
          const SizedBox(height: LevaSpace.s5),
          LevaButton(
            label: 'Panel de LEVA',
            icon: Icons.admin_panel_settings_outlined,
            variant: LevaButtonVariant.line,
            small: true,
            onPressed: () => context.push(Routes.admin),
          ),
        ],
        for (final inv in invites) ...[
          const SizedBox(height: LevaSpace.s4),
          _InviteCard(invite: inv),
        ],
        const LevaSectionHeader('Torneos'),
        switch (events) {
          AsyncData(:final value) when value.isEmpty => const LevaEmptyState(
            title: 'Todavía no hay torneos abiertos',
            message: 'Cuando LEVA abra inscripciones, el torneo aparece aquí y te avisamos.',
          ),
          AsyncData(:final value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EventPosterCard(
                event: value.first,
                onTap: () => context.push(Routes.event(value.first.id)),
              ),
              for (final e in value.skip(1))
                EventRow(
                  event: e,
                  onTap: () => context.push(Routes.event(e.id)),
                ),
            ],
          ),
          AsyncError() => const LevaNotice(
            'No pudimos cargar los torneos. Revisa tu conexión.',
          ),
          _ => const Padding(
            padding: EdgeInsets.all(LevaSpace.s8),
            child: Center(
              child: CircularProgressIndicator(color: LevaColors.gold500),
            ),
          ),
        },
      ],
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.invite});
  final Invite invite;

  @override
  Widget build(BuildContext context) {
    return LevaPressable(
      onTap: () => context.push(Routes.invite(invite.code)),
      scale: 0.985,
      semanticLabel: 'Invitación de ${invite.fromName}',
      child: LevaPanel(
        highlight: true,
        child: Row(
          children: [
            const Icon(Icons.mail_outline, color: LevaColors.gold200),
            const SizedBox(width: LevaSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${invite.fromName} te invitó a jugar',
                    style: LevaType.body(weight: 600),
                  ),
                  Text(
                    '${invite.eventName} · ${invite.categoryName}',
                    style: LevaType.meta,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: LevaColors.tx2),
          ],
        ),
      ),
    );
  }
}
