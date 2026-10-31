import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/session.dart';
import '../../core/design_system/design_system.dart';
import '../../domain/models/event.dart';
import '../../domain/models/player_profile.dart';
import '../../domain/models/registration.dart';
import '../../domain/scoring/scoring_rules.dart';
import '../events/event_format.dart';

/// Crear o editar un torneo y sus categorías.
class AdminEventEditorScreen extends ConsumerStatefulWidget {
  const AdminEventEditorScreen({super.key, this.eventId});

  /// null = torneo nuevo.
  final String? eventId;

  @override
  ConsumerState<AdminEventEditorScreen> createState() =>
      _AdminEventEditorScreenState();
}

class _AdminEventEditorScreenState
    extends ConsumerState<AdminEventEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _venue = TextEditingController();
  final _address = TextEditingController();
  late DateTime _start;
  late DateTime _end;
  late DateTime _deadline;
  int _courts = 4;
  bool _golden = true;
  bool _superTb = true;
  int _minRest = 60;
  EventStatus _status = EventStatus.draft;
  PadelEvent? _loaded;
  bool _busy = false;
  String? _error;

  bool get _isNew => widget.eventId == null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, now.day + 21, 8);
    _end = DateTime(now.year, now.month, now.day + 23, 22);
    _deadline = DateTime(now.year, now.month, now.day + 17, 23, 59);
  }

  void _load(PadelEvent e) {
    if (_loaded != null) return;
    _loaded = e;
    _name.text = e.name;
    _venue.text = e.venueName;
    _address.text = e.venueAddress;
    _start = e.startDate;
    _end = e.endDate;
    _deadline = e.registrationDeadline;
    _courts = e.courts.length;
    _golden = e.rules.goldenPoint;
    _superTb = e.rules.superTiebreak;
    _minRest = e.minRestMinutes;
    _status = e.status;
  }

  @override
  void dispose() {
    _name.dispose();
    _venue.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime.now().subtract(const Duration(days: 365)),
    lastDate: DateTime.now().add(const Duration(days: 730)),
    locale: const Locale('es', 'MX'),
  );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final dateError = EventValidators.dates(_start, _end, _deadline);
    if (dateError != null) {
      setState(() => _error = dateError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(eventRepositoryProvider);
    final id = widget.eventId ?? repo.newEventId();
    final base = _loaded;
    final event = PadelEvent(
      id: id,
      name: _name.text.trim(),
      status: _status,
      venueName: _venue.text.trim(),
      venueAddress: _address.text.trim(),
      startDate: _start,
      endDate: _end,
      registrationDeadline: _deadline,
      courts: Court.numbered(_courts),
      rules: (base?.rules ?? ScoringRules.leva).copyWith(
        goldenPoint: _golden,
        superTiebreak: _superTb,
      ),
      matchMinutes: base?.matchMinutes ?? 60,
      minRestMinutes: _minRest,
    );
    try {
      await repo.saveEvent(event, isNew: _isNew);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Torneo guardado')));
      if (_isNew) context.pushReplacement(Routes.adminEvent(id));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo guardar. ¿Tu cuenta tiene rol de admin?',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isNew) {
      final e = ref.watch(eventProvider(widget.eventId!)).value;
      if (e != null) _load(e);
    }
    final categories = _isNew
        ? const <EventCategory>[]
        : ref.watch(categoriesProvider(widget.eventId!)).value ?? const [];

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
                    child: Form(
                      key: _form,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          LevaSpace.gutter,
                          0,
                          LevaSpace.gutter,
                          LevaSpace.s12,
                        ),
                        children: [
                          Text(_isNew ? 'NUEVO' : 'EDITAR', style: LevaType.xl),
                          GoldText('TORNEO', style: LevaType.xl),
                          const SizedBox(height: LevaSpace.s5),
                          LevaField(
                            label: 'Nombre',
                            controller: _name,
                            hint: 'LEVA Open Otoño',
                            textCapitalization: TextCapitalization.words,
                            validator: EventValidators.name,
                          ),
                          const SizedBox(height: LevaSpace.s4),
                          LevaField(
                            label: 'Sede',
                            controller: _venue,
                            hint: 'Nombre del club',
                            textCapitalization: TextCapitalization.words,
                            validator: EventValidators.venue,
                          ),
                          const SizedBox(height: LevaSpace.s4),
                          LevaField(
                            label: 'Dirección (opcional)',
                            controller: _address,
                            hint: 'Calle, colonia, Zapopan',
                          ),
                          const SizedBox(height: LevaSpace.s5),
                          Text('Fechas', style: LevaType.label),
                          const SizedBox(height: LevaSpace.s2),
                          _DateRow(
                            label: 'Empieza',
                            value: _start,
                            onPick: () async {
                              final d = await _pickDate(_start);
                              if (d != null) {
                                setState(
                                  () => _start = DateTime(
                                    d.year,
                                    d.month,
                                    d.day,
                                    8,
                                  ),
                                );
                              }
                            },
                          ),
                          _DateRow(
                            label: 'Termina',
                            value: _end,
                            onPick: () async {
                              final d = await _pickDate(_end);
                              if (d != null) {
                                setState(
                                  () => _end = DateTime(
                                    d.year,
                                    d.month,
                                    d.day,
                                    22,
                                  ),
                                );
                              }
                            },
                          ),
                          _DateRow(
                            label: 'Cierre de inscripciones',
                            value: _deadline,
                            onPick: () async {
                              final d = await _pickDate(_deadline);
                              if (d != null) {
                                setState(
                                  () => _deadline = DateTime(
                                    d.year,
                                    d.month,
                                    d.day,
                                    23,
                                    59,
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: LevaSpace.s5),
                          LevaOptionRow(
                            title: 'Canchas',
                            detail: 'Se numeran desde Cancha 1',
                            trailing: LevaStepper(
                              value: _courts,
                              min: 1,
                              max: 20,
                              label: 'Canchas',
                              onChanged: (v) => setState(() => _courts = v),
                            ),
                          ),
                          LevaOptionRow(
                            title: 'Descanso mínimo',
                            detail: 'Minutos entre partidos de una pareja',
                            trailing: LevaStepper(
                              value: _minRest,
                              min: 0,
                              max: 240,
                              step: 15,
                              label: 'Minutos de descanso',
                              onChanged: (v) => setState(() => _minRest = v),
                            ),
                          ),
                          LevaOptionRow(
                            title: 'Punto de oro',
                            detail: 'Apagado = ventaja tradicional',
                            trailing: LevaSwitch(
                              value: _golden,
                              label: 'Punto de oro',
                              onChanged: (v) => setState(() => _golden = v),
                            ),
                          ),
                          LevaOptionRow(
                            title: 'Súper tie-break',
                            detail: 'A 10 puntos en lugar del 3er set',
                            trailing: LevaSwitch(
                              value: _superTb,
                              label: 'Súper tie-break',
                              onChanged: (v) => setState(() => _superTb = v),
                            ),
                          ),
                          const SizedBox(height: LevaSpace.s5),
                          Text('Estado', style: LevaType.label),
                          const SizedBox(height: LevaSpace.s2),
                          LevaSegmented(
                            options: const ['Borrador', 'Abiertas', 'Cerradas'],
                            index: switch (_status) {
                              EventStatus.draft => 0,
                              EventStatus.open => 1,
                              _ => 2,
                            },
                            onChanged: (i) => setState(
                              () => _status = [
                                EventStatus.draft,
                                EventStatus.open,
                                EventStatus.closed,
                              ][i],
                            ),
                          ),
                          const SizedBox(height: LevaSpace.s2),
                          Text(
                            'Borrador: solo lo ves tú. Abiertas: aparece en la app y se puede inscribir.',
                            style: LevaType.meta.copyWith(fontSize: 12),
                          ),
                          const SizedBox(height: LevaSpace.s6),
                          if (_error != null) ...[
                            LevaNotice(_error!),
                            const SizedBox(height: LevaSpace.s4),
                          ],
                          LevaButton(
                            label: _isNew ? 'Crear torneo' : 'Guardar cambios',
                            loading: _busy,
                            onPressed: _save,
                          ),
                          if (!_isNew) ...[
                            LevaSectionHeader(
                              'Categorías',
                              trailing: TextButton.icon(
                                onPressed: () => _editCategory(
                                  context,
                                  null,
                                  categories.length,
                                ),
                                icon: const Icon(
                                  Icons.add,
                                  size: 18,
                                  color: LevaColors.gold200,
                                ),
                                label: Text(
                                  'Agregar',
                                  style: LevaType.body(
                                    size: 13,
                                    weight: 600,
                                    color: LevaColors.gold200,
                                  ),
                                ),
                              ),
                            ),
                            if (categories.isEmpty)
                              Text(
                                'Agrega al menos una categoría antes de abrir inscripciones.',
                                style: LevaType.body(
                                  size: 14,
                                  color: LevaColors.tx2,
                                ),
                              ),
                            for (final (i, c) in categories.indexed)
                              _CategoryRow(
                                category: c,
                                onEdit: () => _editCategory(context, c, i),
                              ),
                          ],
                        ],
                      ),
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

  Future<void> _editCategory(
    BuildContext context,
    EventCategory? existing,
    int order,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LevaColors.ink2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(LevaRadius.lg),
        ),
      ),
      builder: (_) => _CategorySheet(
        eventId: widget.eventId!,
        existing: existing,
        order: order,
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onPick,
  });
  final String label;
  final DateTime value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => LevaDateField(
    label: label,
    value: EventFormat.longDay(value),
    onTap: onPick,
  );
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.onEdit});
  final EventCategory category;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return LevaPressable(
      onTap: onEdit,
      scale: 0.985,
      semanticLabel: 'Editar ${category.name}',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: LevaColors.line)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                category.name.toUpperCase(),
                style: LevaType.display(24),
              ),
            ),
            Expanded(
              child: Text(
                '${category.confirmedCount}/${category.capacity} parejas · ${formatMxn(category.priceCents)} · ${category.format.label.replaceAll(' ', ' ')}',
                style: LevaType.meta,
              ),
            ),
            const Icon(Icons.edit_outlined, size: 18, color: LevaColors.tx2),
          ],
        ),
      ),
    );
  }
}

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({
    required this.eventId,
    required this.existing,
    required this.order,
  });
  final String eventId;
  final EventCategory? existing;
  final int order;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _price = TextEditingController(
    text: widget.existing == null
        ? '1400'
        : '${widget.existing!.priceCents ~/ 100}',
  );
  late int _capacity = widget.existing?.capacity ?? 16;
  late DrawFormat _format =
      widget.existing?.format ?? DrawFormat.groupsKnockout;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final price = int.tryParse(_price.text.trim());
    final err = name.isEmpty
        ? 'Escribe el nombre de la categoría.'
        : EventValidators.priceMxn(price) ??
              EventValidators.capacity(_capacity);
    if (err == null &&
        widget.existing != null &&
        _capacity < widget.existing!.confirmedCount) {
      setState(
        () => _error =
            'Ya hay ${widget.existing!.confirmedCount} parejas con lugar; el cupo no puede ser menor.',
      );
      return;
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() => _busy = true);
    final repo = ref.read(eventRepositoryProvider);
    final cat = EventCategory(
      id: widget.existing?.id ?? repo.newCategoryId(widget.eventId),
      name: name,
      capacity: _capacity,
      priceCents: price! * 100,
      format: _format,
    );
    try {
      await repo.saveCategory(
        widget.eventId,
        cat,
        order: widget.order,
        isNew: widget.existing == null,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar la categoría.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            LevaSpace.gutter,
            LevaSpace.s6,
            LevaSpace.gutter,
            LevaSpace.s6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null
                    ? 'NUEVA CATEGORÍA'
                    : 'EDITAR CATEGORÍA',
                style: LevaType.l,
              ),
              const SizedBox(height: LevaSpace.s4),
              Wrap(
                spacing: LevaSpace.s2,
                runSpacing: LevaSpace.s2,
                children: [
                  for (final c in PlayerCategory.values)
                    LevaChip(
                      label: c.label,
                      selected: _name.text == c.label,
                      onTap: () => setState(() => _name.text = c.label),
                    ),
                ],
              ),
              const SizedBox(height: LevaSpace.s3),
              LevaField(
                label: 'Nombre',
                controller: _name,
                hint: '4ta, Suma 9, Mixto…',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: LevaSpace.s4),
              LevaField(
                label: r'Precio por pareja (MXN)',
                controller: _price,
                keyboardType: TextInputType.number,
                hint: '1400',
              ),
              const SizedBox(height: LevaSpace.s3),
              LevaOptionRow(
                title: 'Cupo',
                detail: 'Parejas con lugar (después, lista de espera)',
                trailing: LevaStepper(
                  value: _capacity,
                  min: 2,
                  max: 128,
                  label: 'Cupo',
                  onChanged: (v) => setState(() => _capacity = v),
                ),
              ),
              const SizedBox(height: LevaSpace.s4),
              Text('Formato', style: LevaType.label),
              const SizedBox(height: LevaSpace.s2),
              for (final f in DrawFormat.values) ...[
                LevaChoiceCard(
                  selected: _format == f,
                  onTap: () => setState(() => _format = f),
                  child: Text(f.label, style: LevaType.body(weight: 600)),
                ),
                const SizedBox(height: LevaSpace.s2),
              ],
              const SizedBox(height: LevaSpace.s3),
              if (_error != null) ...[
                LevaNotice(_error!),
                const SizedBox(height: LevaSpace.s3),
              ],
              LevaButton(
                label: 'Guardar categoría',
                loading: _busy,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
