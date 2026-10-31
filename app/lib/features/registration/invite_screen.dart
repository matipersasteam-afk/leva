import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/session.dart';
import '../../core/design_system/design_system.dart';
import '../../data/registration_repository.dart';
import '../../domain/models/event.dart';
import '../../domain/models/registration.dart';
import '../events/event_format.dart';

final _inviteProvider = FutureProvider.autoDispose.family<Invite?, String>(
  (ref, code) => ref.watch(registrationRepositoryProvider).getInvite(code),
);

/// Pantalla del link de invitación: "Julia te invita a jugar LEVA Open · 4ta".
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, required this.code});
  final String code;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _accept(Invite invite) async {
    final me = ref.read(myProfileProvider).value;
    if (me == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(registrationRepositoryProvider).acceptInvite(invite, me);
      if (mounted) {
        context.go(Routes.registration(invite.eventId, invite.regId));
      }
    } on RegistrationFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = ref.watch(_inviteProvider(widget.code));
    final me = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      body: LevaCourtBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  LevaTopBar(
                    onBack: () => context.canPop()
                        ? context.pop()
                        : context.go(Routes.home),
                  ),
                  Expanded(
                    child: switch (invite) {
                      AsyncData(value: final inv?) => _content(inv, me),
                      AsyncData() || AsyncError() => const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: LevaSpace.gutter,
                        ),
                        child: LevaEmptyState(
                          title: 'Invitación no encontrada',
                          message: 'Revisa el link o pídele a tu pareja que te lo mande de nuevo.',
                        ),
                      ),
                      _ => const Center(
                        child: CircularProgressIndicator(
                          color: LevaColors.gold500,
                        ),
                      ),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(Invite inv, String? me) {
    final parts = inv.fromName.trim().split(RegExp(r'\s+'));
    final fromLast = parts.length > 1
        ? parts.sublist(1).join(' ')
        : parts.first;
    final mine = inv.fromUid == me;
    final forOther = inv.invitedUid != null && inv.invitedUid != me;
    final acceptedByMe = inv.used && inv.acceptedBy == me;
    final event = ref.watch(eventProvider(inv.eventId)).value;
    final category =
        (ref.watch(categoriesProvider(inv.eventId)).value ?? const [])
            .where((c) => c.id == inv.categoryId)
            .firstOrNull;

    Widget fact(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: LevaSpace.s2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: LevaColors.gold500),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: LevaType.body(size: 14, color: LevaColors.tx2),
            ),
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        LevaSpace.gutter,
        LevaSpace.s2,
        LevaSpace.gutter,
        LevaSpace.s10,
      ),
      children: [
        Text(
          '${parts.first} te invita a jugar',
          style: LevaType.body(size: 15, color: LevaColors.tx2),
        ),
        const SizedBox(height: LevaSpace.s4),
        LevaDuel(a: [fromLast], b: const ['Tú'], size: 40),
        const SizedBox(height: LevaSpace.s6),
        LevaPanel(
          highlight: true,
          padding: const EdgeInsets.all(LevaSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LevaTag(inv.categoryName, kind: LevaTagKind.gold),
                  const SizedBox(width: LevaSpace.s2),
                  if (inv.slot == RegistrationSlot.waitlist)
                    const LevaTag('Lista de espera'),
                ],
              ),
              const SizedBox(height: LevaSpace.s3),
              Text(inv.eventName.toUpperCase(), style: LevaType.display(30)),
              if (event != null) ...[
                fact(Icons.calendar_today_outlined, EventFormat.range(event)),
                fact(Icons.place_outlined, event.venueName),
              ],
              if (category != null)
                fact(
                  Icons.payments_outlined,
                  '${formatMxn(category.priceCents)} por pareja · pago en sede',
                ),
            ],
          ),
        ),
        const SizedBox(height: LevaSpace.s5),
        if (inv.used) ...[
          LevaNotice(
            acceptedByMe
                ? 'Ya aceptaste esta invitación.'
                : 'Esta invitación ya fue aceptada.',
            kind: LevaNoticeKind.info,
          ),
          const SizedBox(height: LevaSpace.s4),
          LevaButton(
            label: acceptedByMe ? 'Ver inscripción' : 'Ir al inicio',
            variant: acceptedByMe
                ? LevaButtonVariant.gold
                : LevaButtonVariant.dark,
            onPressed: () => context.go(
              acceptedByMe
                  ? Routes.registration(inv.eventId, inv.regId)
                  : Routes.home,
            ),
          ),
        ] else if (mine)
          const LevaNotice(
            'Esta es tu propia invitación. Compártela con tu pareja.',
            kind: LevaNoticeKind.info,
          )
        else if (forOther)
          const LevaNotice('Esta invitación es para otro jugador.')
        else ...[
          if (inv.slot == RegistrationSlot.waitlist) ...[
            const LevaNotice(
              'La categoría está llena: al aceptar entran juntos a la lista de espera.',
              kind: LevaNoticeKind.info,
            ),
            const SizedBox(height: LevaSpace.s4),
          ],
          if (_error != null) ...[
            LevaNotice(_error!),
            const SizedBox(height: LevaSpace.s4),
          ],
          LevaButton(
            label: 'Aceptar y jugar',
            loading: _busy,
            onPressed: () => _accept(inv),
          ),
          const SizedBox(height: LevaSpace.s3),
          LevaButton(
            label: 'Ahora no',
            variant: LevaButtonVariant.dark,
            small: true,
            onPressed: _busy ? null : () => context.go(Routes.home),
          ),
        ],
      ],
    );
  }
}
