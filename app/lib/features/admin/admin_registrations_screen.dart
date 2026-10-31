import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../data/registration_repository.dart';
import '../../domain/models/event.dart';
import '../../domain/models/registration.dart';
import '../events/event_widgets.dart';

enum _Filter { all, paid, pending, waitlist }

/// Inscripciones del torneo: pagado / pendiente / lista de espera.
class AdminRegistrationsScreen extends ConsumerStatefulWidget {
  const AdminRegistrationsScreen({super.key, required this.eventId});
  final String eventId;

  @override
  ConsumerState<AdminRegistrationsScreen> createState() =>
      _AdminRegistrationsScreenState();
}

class _AdminRegistrationsScreenState
    extends ConsumerState<AdminRegistrationsScreen> {
  _Filter _filter = _Filter.all;
  String? _categoryId;
  String? _busyId;

  bool _matches(Registration r) {
    if (_categoryId != null && r.categoryId != _categoryId) return false;
    if (r.status == RegistrationStatus.cancelled) return _filter == _Filter.all;
    return switch (_filter) {
      _Filter.all => true,
      _Filter.paid => r.payment.isPaid && !r.onWaitlist,
      _Filter.pending => !r.payment.isPaid && !r.onWaitlist,
      _Filter.waitlist => r.onWaitlist,
    };
  }

  Future<void> _run(
    Registration r,
    Future<void> Function() action,
    String done,
  ) async {
    setState(() => _busyId = r.id);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(done)));
      }
    } on RegistrationFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo. Revisa tu conexión y tu rol.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _confirmCancel(Registration r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LevaColors.ink3,
        title: Text('¿Cancelar inscripción?', style: LevaType.m),
        content: Text(
          '${r.label} pierde su lugar y se libera para la lista de espera. Esto no se puede deshacer.',
          style: LevaType.body(color: LevaColors.tx2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sí, cancelar',
              style: TextStyle(color: LevaColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run(
        r,
        () => ref.read(registrationRepositoryProvider).cancel(r),
        'Inscripción cancelada',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = ref.watch(eventProvider(widget.eventId)).value;
    final categories =
        ref.watch(categoriesProvider(widget.eventId)).value ?? const [];
    final regs = ref.watch(allRegistrationsProvider(widget.eventId));
    final me = ref.watch(authStateProvider).value?.uid ?? '';
    final all = regs.value ?? const <Registration>[];
    final scoped = _categoryId == null
        ? all
        : all.where((r) => r.categoryId == _categoryId);
    final summary = RegistrationSummary.of(scoped);
    final visible = all.where(_matches).toList();
    String catName(String id) =>
        categories.where((c) => c.id == id).firstOrNull?.name ?? '';
    EventCategory? cat(String id) =>
        categories.where((c) => c.id == id).firstOrNull;

    return Scaffold(
      body: LevaCourtBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  LevaTopBar(
                    title: event?.name ?? '',
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
                        GoldText('INSCRIPCIONES', style: LevaType.xl),
                        const SizedBox(height: LevaSpace.s4),
                        Row(
                          children: [
                            _Kpi(
                              value: '${summary.total}',
                              label: 'Parejas',
                              color: LevaColors.line2,
                            ),
                            _Kpi(
                              value: '${summary.paid}',
                              label: 'Pagadas',
                              color: LevaColors.ok,
                            ),
                            _Kpi(
                              value: '${summary.pending}',
                              label: 'Pendientes',
                              color: LevaColors.pending,
                            ),
                            _Kpi(
                              value: '${summary.waitlist}',
                              label: 'Espera',
                              color: LevaColors.tx3,
                            ),
                          ],
                        ),
                        const SizedBox(height: LevaSpace.s3),
                        LevaPanel(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'COBRADO',
                                  style: LevaType.support(),
                                ),
                              ),
                              GoldText(
                                formatMxn(summary.collectedCents),
                                style: LevaType.numbers(30),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: LevaSpace.s4),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              LevaChip(
                                label: 'Todas',
                                selected: _categoryId == null,
                                onTap: () => setState(() => _categoryId = null),
                              ),
                              for (final c in categories) ...[
                                const SizedBox(width: LevaSpace.s2),
                                LevaChip(
                                  label: c.name,
                                  selected: _categoryId == c.id,
                                  onTap: () =>
                                      setState(() => _categoryId = c.id),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: LevaSpace.s3),
                        LevaSegmented(
                          options: const [
                            'Todas',
                            'Pagado',
                            'Pendiente',
                            'Espera',
                          ],
                          index: _filter.index,
                          onChanged: (i) =>
                              setState(() => _filter = _Filter.values[i]),
                        ),
                        const SizedBox(height: LevaSpace.s2),
                        if (regs.isLoading && !regs.hasValue)
                          const Padding(
                            padding: EdgeInsets.all(LevaSpace.s8),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: LevaColors.gold500,
                              ),
                            ),
                          )
                        else if (regs.hasError)
                          const LevaNotice(
                            'No pudimos cargar las inscripciones. ¿Tu cuenta tiene rol de admin o staff?',
                          )
                        else if (visible.isEmpty)
                          const LevaEmptyState(
                            title: 'Nada por aquí',
                            message: 'No hay inscripciones con este filtro.',
                          )
                        else
                          for (final r in visible)
                            _RegRow(
                              reg: r,
                              categoryName: catName(r.categoryId),
                              busy: _busyId == r.id,
                              canPromote:
                                  r.onWaitlist &&
                                  !(cat(r.categoryId)?.isFull ?? true),
                              onPaid: () => _run(
                                r,
                                () => ref
                                    .read(registrationRepositoryProvider)
                                    .markPaid(r, byUid: me),
                                '${r.label}: pago registrado',
                              ),
                              onPromote: () => _run(
                                r,
                                () => ref
                                    .read(registrationRepositoryProvider)
                                    .promote(r),
                                '${r.label} pasó a tener lugar',
                              ),
                              onCancel: () => _confirmCancel(r),
                            ),
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

class _Kpi extends StatelessWidget {
  const _Kpi({required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: color, width: 2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: LevaType.numbers(30)),
            Text(label, style: LevaType.meta.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _RegRow extends StatelessWidget {
  const _RegRow({
    required this.reg,
    required this.categoryName,
    required this.busy,
    required this.canPromote,
    required this.onPaid,
    required this.onPromote,
    required this.onCancel,
  });

  final Registration reg;
  final String categoryName;
  final bool busy;
  final bool canPromote;
  final VoidCallback onPaid;
  final VoidCallback onPromote;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final active = reg.status != RegistrationStatus.cancelled;
    final detail = switch (reg.status) {
      RegistrationStatus.cancelled => 'Cancelada',
      _ when reg.onWaitlist => [
        'Lista de espera${reg.waitlistPosition == null ? '' : ' · lugar ${reg.waitlistPosition}'}',
        if (!reg.hasPartner) 'falta que acepte la pareja',
      ].join(' · '),
      _ when reg.payment.isPaid =>
        'Pagado ${formatMxn(reg.payment.paidCents)} · ${reg.payment.method?.label ?? ''}',
      _ => [
        reg.payment.method == null
            ? 'Sin método de pago'
            : '${reg.payment.method!.label} · pendiente',
        if (!reg.hasPartner) 'falta que acepte la pareja',
      ].join(' · '),
    };
    final Widget? action = busy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: LevaColors.gold500,
            ),
          )
        : active && canPromote
        ? LevaButton(
            label: 'Dar lugar',
            small: true,
            expand: false,
            variant: LevaButtonVariant.line,
            onPressed: onPromote,
          )
        : active &&
              !reg.payment.isPaid &&
              !reg.onWaitlist
        ? LevaButton(
            label: 'Marcar cobrado',
            small: true,
            expand: false,
            variant: LevaButtonVariant.dark,
            onPressed: onPaid,
          )
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LevaColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                categoryName.toUpperCase(),
                style: LevaType.display(18, color: LevaColors.tx2),
                maxLines: 2,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reg.label,
                        style: LevaType.body(weight: 600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (action == null) registrationTag(reg),
                  ],
                ),
                Text(detail, style: LevaType.meta.copyWith(fontSize: 12)),
                // La acción va debajo: el nombre de la pareja se lee completo.
                if (action != null) ...[
                  const SizedBox(height: LevaSpace.s2),
                  action,
                ],
              ],
            ),
          ),
          if (active)
            PopupMenuButton<String>(
              tooltip: 'Más acciones',
              color: LevaColors.ink3,
              icon: const Icon(Icons.more_vert, color: LevaColors.tx2),
              onSelected: (v) => v == 'cancel' ? onCancel() : null,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'cancel',
                  child: Text('Cancelar inscripción'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
