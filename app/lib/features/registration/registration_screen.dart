import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/session.dart';
import '../../core/design_system/design_system.dart';
import '../../domain/models/event.dart';
import '../../domain/models/registration.dart';
import '../events/event_format.dart';
import '../events/event_widgets.dart';

/// Mi inscripción: pareja (invitación), disponibilidad y pago.
class RegistrationScreen extends ConsumerWidget {
  const RegistrationScreen({
    super.key,
    required this.eventId,
    required this.regId,
  });
  final String eventId;
  final String regId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reg = ref.watch(
      registrationProvider((eventId: eventId, regId: regId)),
    );
    final event = ref.watch(eventProvider(eventId)).value;
    final category = (ref.watch(categoriesProvider(eventId)).value ?? const [])
        .where((c) => c.id == reg.value?.categoryId)
        .firstOrNull;
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
                    title: event == null || category == null
                        ? ''
                        : '${event.name} · ${category.name}',
                    onBack: () => context.canPop()
                        ? context.pop()
                        : context.go(Routes.event(eventId)),
                  ),
                  Expanded(
                    child: switch (reg) {
                      AsyncData(value: final r?)
                          when event != null && me != null =>
                        _Body(
                          reg: r,
                          event: event,
                          categoryName: category?.name ?? '',
                          me: me,
                        ),
                      AsyncData() || AsyncError() => const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: LevaSpace.gutter,
                        ),
                        child: LevaEmptyState(
                          title: 'Inscripción no disponible',
                          message: 'No encontramos esta inscripción o no eres parte de ella.',
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
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.reg,
    required this.event,
    required this.categoryName,
    required this.me,
  });
  final Registration reg;
  final PadelEvent event;
  final String categoryName;
  final String me;

  int get _stepsDone {
    var d = 1;
    if (reg.hasPartner) d++;
    if (reg.payment.method != null || reg.payment.isPaid) d++;
    return d;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCaptain = reg.captain.uid == me;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        LevaSpace.gutter,
        0,
        LevaSpace.gutter,
        LevaSpace.s12,
      ),
      children: [
        LevaSteps(total: 3, done: _stepsDone),
        const SizedBox(height: LevaSpace.s6),
        Text('TU', style: LevaType.xl),
        GoldText('INSCRIPCIÓN', style: LevaType.xl),
        const SizedBox(height: LevaSpace.s3),
        Row(children: [registrationTag(reg)]),
        const SizedBox(height: LevaSpace.s5),
        _StatusNotice(reg: reg),
        const LevaSectionHeader('Pareja'),
        _PairCard(reg: reg, isCaptain: isCaptain),
        const LevaSectionHeader('Tu disponibilidad'),
        Text(
          'El generador de horarios la respeta. Toca las franjas en que puedes jugar.',
          style: LevaType.body(size: 13.5, color: LevaColors.tx2),
        ),
        const SizedBox(height: LevaSpace.s3),
        _AvailabilityGrid(reg: reg, event: event, uid: me),
        if (reg.status != RegistrationStatus.waitlist &&
            reg.status != RegistrationStatus.cancelled) ...[
          const LevaSectionHeader('Pago'),
          _PaymentSection(reg: reg),
        ],
      ],
    );
  }
}

class _StatusNotice extends StatelessWidget {
  const _StatusNotice({required this.reg});
  final Registration reg;

  @override
  Widget build(BuildContext context) {
    final amount = formatMxn(reg.payment.amountCents);
    final msg = switch (reg.status) {
      RegistrationStatus.pendingPartner
          when reg.slot == RegistrationSlot.waitlist =>
        'Estás en lista de espera. Invita a tu pareja para que, si se libera un lugar, puedan entrar.',
      RegistrationStatus.pendingPartner =>
        'Tu lugar está apartado. Falta que tu pareja acepte la invitación.',
      RegistrationStatus.pendingPayment
          when reg.payment.method == PaymentMethod.venue =>
        'Lugar apartado. Paguen $amount en la mesa de control antes de su primer partido.',
      RegistrationStatus.pendingPayment =>
        'Lugar apartado. Elige cómo van a pagar los $amount de la inscripción.',
      RegistrationStatus.confirmed =>
        '¡Están dentro! Te avisamos cuando salga el cuadro y sus horarios.',
      RegistrationStatus.waitlist =>
        'Están en lista de espera${reg.waitlistPosition == null ? '' : ' (lugar ${reg.waitlistPosition})'}. Si se libera un lugar, LEVA los pasa y les avisa.',
      RegistrationStatus.cancelled => 'Esta inscripción está cancelada.',
    };
    return LevaNotice(msg, kind: LevaNoticeKind.info);
  }
}

class _PairCard extends StatelessWidget {
  const _PairCard({required this.reg, required this.isCaptain});
  final Registration reg;
  final bool isCaptain;

  @override
  Widget build(BuildContext context) {
    final partner = reg.partner;
    return LevaPanel(
      padding: const EdgeInsets.all(LevaSpace.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (partner != null)
            Row(
              children: [
                Expanded(
                  child: PairName(
                    lines: [reg.captain.lastName],
                    caption: reg.captain.name,
                    size: 28,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: LevaSlash(height: 56),
                ),
                Expanded(
                  child: PairName(
                    lines: [partner.lastName],
                    caption: partner.name,
                    alignEnd: true,
                    size: 28,
                  ),
                ),
              ],
            )
          else ...[
            Text(
              isCaptain
                  ? 'Comparte este link o código con tu pareja:'
                  : 'Esperando que acepte tu pareja.',
              style: LevaType.body(size: 14, color: LevaColors.tx2),
            ),
            const SizedBox(height: LevaSpace.s3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    reg.inviteCode,
                    style: LevaType.numbers(
                      40,
                      color: LevaColors.gold200,
                    ).copyWith(letterSpacing: 6),
                    semanticsLabel:
                        'Código ${reg.inviteCode.split('').join(' ')}',
                  ),
                ),
                LevaButton(
                  label: 'Copiar link',
                  icon: Icons.link,
                  small: true,
                  expand: false,
                  variant: LevaButtonVariant.line,
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: AppLinks.invite(reg.inviteCode)),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Link copiado. Mándaselo por WhatsApp a tu pareja.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            if (reg.invitedUid != null) ...[
              const SizedBox(height: LevaSpace.s2),
              Text(
                'También le aparece la invitación en su app.',
                style: LevaType.meta,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AvailabilityGrid extends ConsumerWidget {
  const _AvailabilityGrid({
    required this.reg,
    required this.event,
    required this.uid,
  });
  final Registration reg;
  final PadelEvent event;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = reg.availability[uid] ?? const <String, Set<DaySlot>>{};

    Future<void> toggle(String day, DaySlot slot) async {
      final next = {
        for (final e in mine.entries) e.key: {...e.value},
      };
      final set = next.putIfAbsent(day, () => <DaySlot>{});
      set.contains(slot) ? set.remove(slot) : set.add(slot);
      try {
        await ref
            .read(registrationRepositoryProvider)
            .setAvailability(reg.eventId, reg.id, uid, next);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se guardó. Revisa tu conexión.')),
          );
        }
      }
    }

    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 64),
            for (final s in DaySlot.values)
              Expanded(
                child: Text(
                  '${s.label}\n${s.hours}',
                  textAlign: TextAlign.center,
                  style: LevaType.support(tracking: 0.06),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (final day in event.days)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        EventFormat.weekday(day).toUpperCase(),
                        style: LevaType.display(20),
                      ),
                      Text(
                        '${day.day} ${EventFormat.month(day)}',
                        style: LevaType.meta.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                for (final s in DaySlot.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _SlotButton(
                        label: s.label,
                        selected: mine[dayKey(day)]?.contains(s) ?? false,
                        onTap: () => toggle(dayKey(day), s),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SlotButton extends StatelessWidget {
  const _SlotButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LevaPressable(
      onTap: onTap,
      scale: 0.95,
      child: Semantics(
        toggled: selected,
        child: AnimatedContainer(
          duration: LevaMotion.fast,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LevaRadius.sm),
            color: selected ? const Color(0xFF221D12) : LevaColors.ink1,
            border: Border.all(
              color: selected ? LevaColors.gold500 : LevaColors.line2,
            ),
          ),
          // La franja ya está en el encabezado: la celda solo marca el estado.
          child: Semantics(
            label: label,
            child: AnimatedOpacity(
              duration: LevaMotion.fast,
              opacity: selected ? 1 : 0,
              child: const Icon(
                Icons.check,
                size: 18,
                color: LevaColors.gold200,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentSection extends ConsumerWidget {
  const _PaymentSection({required this.reg});
  final Registration reg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reg.payment.isPaid) {
      return LevaPanel(
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: LevaColors.ok),
            const SizedBox(width: LevaSpace.s3),
            Expanded(
              child: Text(
                'Pagado: ${formatMxn(reg.payment.paidCents)}',
                style: LevaType.body(weight: 600),
              ),
            ),
          ],
        ),
      );
    }
    Widget method(PaymentMethod m, String detail, {bool soon = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: LevaSpace.s2),
          child: LevaChoiceCard(
            selected: reg.payment.method == m,
            enabled: !soon,
            onTap: () => ref
                .read(registrationRepositoryProvider)
                .choosePayment(reg.eventId, reg.id, m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  soon ? '${m.label} · próximamente' : m.label,
                  style: LevaType.body(weight: 600),
                ),
                Text(detail, style: LevaType.meta.copyWith(fontSize: 12)),
              ],
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('INSCRIPCIÓN POR PAREJA', style: LevaType.support()),
            ),
            Text(
              formatMxn(reg.payment.amountCents),
              style: LevaType.numbers(30, color: LevaColors.gold200),
            ),
          ],
        ),
        const SizedBox(height: LevaSpace.s3),
        method(PaymentMethod.venue, 'Efectivo o tarjeta en la mesa de control'),
        method(PaymentMethod.mercadopago, 'Tarjeta, OXXO o SPEI', soon: true),
        method(PaymentMethod.stripe, 'Visa, Mastercard, Amex', soon: true),
      ],
    );
  }
}
