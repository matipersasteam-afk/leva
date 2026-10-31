import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../data/draw_repository.dart';
import '../../domain/draw/draw.dart';
import '../../domain/models/event.dart';
import '../draw/draw_view.dart';

DrawKind _kindOf(DrawFormat f) => switch (f) {
  DrawFormat.groupsKnockout => DrawKind.groupsKnockout,
  DrawFormat.singleElim => DrawKind.singleElim,
  DrawFormat.americano => DrawKind.americano,
  DrawFormat.relampago => DrawKind.relampago,
};

/// Generar, ajustar y publicar el draw de cada categoría.
class AdminDrawScreen extends ConsumerStatefulWidget {
  const AdminDrawScreen({super.key, required this.eventId});
  final String eventId;

  @override
  ConsumerState<AdminDrawScreen> createState() => _AdminDrawScreenState();
}

class _AdminDrawScreenState extends ConsumerState<AdminDrawScreen> {
  String? _categoryId;
  int _groupSize = 4;
  int _qualifiers = 2;
  bool _byRanking = true;
  bool _avoidClub = true;
  int _seed = 1;

  DrawInput? _input;
  Draw? _draw;
  String? _picked;
  bool _loading = false;
  bool _publishing = false;
  String? _error;

  Map<String, DrawTeam> get _teams => {
    for (final t in _input?.teams ?? const <DrawTeam>[]) t.id: t,
  };
  Map<String, String> get _labels => {
    for (final t in _input?.teams ?? const <DrawTeam>[]) t.id: t.label,
  };

  void _selectCategory(EventCategory c) {
    setState(() {
      _categoryId = c.id;
      _draw = null;
      _input = null;
      _error = null;
      _picked = null;
    });
  }

  Future<void> _generate(EventCategory c, {bool reshuffle = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      _picked = null;
      if (reshuffle) _seed++;
    });
    try {
      _input ??= await ref
          .read(drawRepositoryProvider)
          .loadInput(widget.eventId, c.id);
      final draw = generateDraw(
        _input!.teams,
        DrawConfig(
          kind: _kindOf(c.format),
          groupSize: _groupSize,
          qualifiersPerGroup: _qualifiers,
          seedByRanking: _byRanking,
          avoidSameClub: _avoidClub,
          seed: _seed,
        ),
      );
      setState(() => _draw = draw);
    } on DrawError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
        () => _error = 'No pudimos cargar las parejas. Revisa tu conexión.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _tapPair(String id) {
    if (_picked == null) {
      setState(() => _picked = id);
    } else if (_picked == id) {
      setState(() => _picked = null);
    } else {
      setState(() {
        _draw = swapTeams(_draw!, _picked!, id, _teams);
        _picked = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Parejas intercambiadas')));
    }
  }

  Future<void> _publish(EventCategory c) async {
    if (c.isPublishedDraw) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: LevaColors.ink3,
          title: Text('¿Reemplazar el draw?', style: LevaType.m),
          content: Text(
            '${c.name} ya tiene un draw publicado. Los jugadores van a ver el nuevo.',
            style: LevaType.body(color: LevaColors.tx2),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reemplazar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _publishing = true);
    try {
      await ref
          .read(drawRepositoryProvider)
          .publish(
            eventId: widget.eventId,
            categoryId: c.id,
            draw: _draw!,
            input: _input!,
            config: {
              'groupSize': _groupSize,
              'qualifiersPerGroup': _qualifiers,
              'seedByRanking': _byRanking,
              'avoidSameClub': _avoidClub,
              'seed': _seed,
            },
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Draw de ${c.name} publicado')));
      }
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo publicar. Revisa tu conexión y tu rol de admin.',
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = ref.watch(eventProvider(widget.eventId)).value;
    final categories =
        ref.watch(categoriesProvider(widget.eventId)).value ?? const [];
    final cat = categories.where((c) => c.id == _categoryId).firstOrNull;
    final usesGroups = cat != null && (cat.format == DrawFormat.groupsKnockout);

    return Scaffold(
      body: LevaCourtBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  LevaTopBar(
                    title: event?.name ?? '',
                    onBack: () => context.pop(),
                    trailing: const LevaRoleChip('Admin'),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: LevaSpace.s12),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: LevaSpace.gutter,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('GENERAR', style: LevaType.xl),
                              GoldText('DRAW', style: LevaType.xl),
                              const SizedBox(height: LevaSpace.s4),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final c in categories) ...[
                                      LevaChip(
                                        label: c.isPublishedDraw
                                            ? '${c.name} ✓'
                                            : c.name,
                                        selected: c.id == _categoryId,
                                        onTap: () => _selectCategory(c),
                                      ),
                                      const SizedBox(width: LevaSpace.s2),
                                    ],
                                  ],
                                ),
                              ),
                              if (cat == null)
                                const LevaEmptyState(
                                  title: 'Elige una categoría',
                                  message: 'El draw se arma con las parejas que tienen lugar y pareja confirmada.',
                                )
                              else ...[
                                const SizedBox(height: LevaSpace.s4),
                                LevaPanel(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cat.format.label,
                                              style: LevaType.body(weight: 600),
                                            ),
                                            Text(
                                              '${cat.confirmedCount} parejas con lugar · el formato se cambia en la categoría',
                                              style: LevaType.meta.copyWith(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (cat.isPublishedDraw)
                                        const LevaTag(
                                          'Publicado',
                                          kind: LevaTagKind.ok,
                                        ),
                                    ],
                                  ),
                                ),
                                if (usesGroups) ...[
                                  LevaOptionRow(
                                    title: 'Parejas por grupo',
                                    trailing: LevaStepper(
                                      value: _groupSize,
                                      min: 3,
                                      max: 5,
                                      label: 'Parejas por grupo',
                                      onChanged: (v) =>
                                          setState(() => _groupSize = v),
                                    ),
                                  ),
                                  LevaOptionRow(
                                    title: 'Pasan por grupo',
                                    trailing: LevaStepper(
                                      value: _qualifiers,
                                      min: 1,
                                      max: 2,
                                      label: 'Clasificados por grupo',
                                      onChanged: (v) =>
                                          setState(() => _qualifiers = v),
                                    ),
                                  ),
                                ],
                                LevaOptionRow(
                                  title: 'Sembrar por ranking',
                                  detail: 'Si no, por orden de inscripción',
                                  trailing: LevaSwitch(
                                    value: _byRanking,
                                    label: 'Sembrar por ranking',
                                    onChanged: (v) =>
                                        setState(() => _byRanking = v),
                                  ),
                                ),
                                LevaOptionRow(
                                  title: 'Evitar mismo club',
                                  detail: 'En la primera ronda y en los grupos',
                                  trailing: LevaSwitch(
                                    value: _avoidClub,
                                    label: 'Evitar mismo club',
                                    onChanged: (v) =>
                                        setState(() => _avoidClub = v),
                                  ),
                                ),
                                const SizedBox(height: LevaSpace.s5),
                                Row(
                                  children: [
                                    Expanded(
                                      child: LevaButton(
                                        label: _draw == null
                                            ? 'Generar draw'
                                            : 'Volver a generar',
                                        variant: _draw == null
                                            ? LevaButtonVariant.gold
                                            : LevaButtonVariant.dark,
                                        loading: _loading,
                                        onPressed: () => _generate(
                                          cat,
                                          reshuffle: _draw != null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: LevaSpace.s4),
                                  LevaNotice(_error!),
                                ],
                              ],
                            ],
                          ),
                        ),
                        if (cat != null && _draw != null) ..._preview(cat),
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

  List<Widget> _preview(EventCategory cat) {
    final d = _draw!;
    final bracket = bracketFromDraw(d, _labels);
    final pad = const EdgeInsets.symmetric(horizontal: LevaSpace.gutter);
    return [
      Padding(
        padding: pad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: LevaSpace.s5),
            if (d.warnings.isEmpty)
              LevaNotice(
                _avoidClub ? 'Sin cruces del mismo club.' : 'Draw generado.',
                kind: LevaNoticeKind.info,
              )
            else
              _WarningsSummary(
                warnings: d.warnings,
                groups: d.groups.isNotEmpty,
              ),
            const SizedBox(height: LevaSpace.s3),
            Text(
              d.groups.isNotEmpty
                  ? 'Ajuste manual: toca una pareja y luego otra para intercambiarlas.'
                  : 'Ajuste manual: toca una pareja de la primera ronda y luego otra.',
              style: LevaType.meta,
            ),
          ],
        ),
      ),
      if (d.groups.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: LevaSpace.gutter),
          child: LevaSectionHeader('Grupos'),
        ),
        for (final g in d.groups)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LevaSpace.gutter,
              0,
              LevaSpace.gutter,
              LevaSpace.s3,
            ),
            child: LevaPanel(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    g.name.length == 1
                        ? 'GRUPO ${g.name}'
                        : g.name.toUpperCase(),
                    style: LevaType.display(22),
                  ),
                  const SizedBox(height: 6),
                  for (final id in g.teamIds)
                    _PairButton(
                      team: _teams[id]!,
                      picked: _picked == id,
                      onTap: () => _tapPair(id),
                    ),
                ],
              ),
            ),
          ),
      ] else if (d.knockoutMatches.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: LevaSpace.gutter),
          child: LevaSectionHeader('Primera ronda'),
        ),
        Padding(
          padding: pad,
          child: Column(
            children: [
              for (final m in d.knockoutMatches.where(
                (m) => m.round == 1 && !m.isBye,
              ))
                LevaPanel(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      for (final s in [m.a, m.b])
                        if (s is TeamSlot)
                          _PairButton(
                            team: _teams[s.teamId]!,
                            picked: _picked == s.teamId,
                            onTap: () => _tapPair(s.teamId),
                          ),
                    ],
                  ),
                ),
            ].expand((w) => [w, const SizedBox(height: LevaSpace.s2)]).toList(),
          ),
        ),
      ],
      if (d.knockoutMatches.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: LevaSpace.gutter),
          child: LevaSectionHeader('Llave'),
        ),
        LevaBracket(rounds: bracket.rounds, roundNames: bracket.names),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(
          LevaSpace.gutter,
          LevaSpace.s6,
          LevaSpace.gutter,
          0,
        ),
        child: LevaButton(
          label: cat.isPublishedDraw
              ? 'Reemplazar draw publicado'
              : 'Publicar draw',
          loading: _publishing,
          onPressed: () => _publish(cat),
        ),
      ),
    ];
  }
}

class _PairButton extends StatelessWidget {
  const _PairButton({
    required this.team,
    required this.picked,
    required this.onTap,
  });
  final DrawTeam team;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LevaPressable(
      onTap: onTap,
      scale: 0.98,
      semanticLabel: 'Pareja ${team.label}',
      child: AnimatedContainer(
        duration: LevaMotion.fast,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(LevaRadius.xs),
          color: picked ? LevaColors.goldWash : null,
          border: Border.all(
            color: picked ? LevaColors.gold500 : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                team.label,
                style: LevaType.body(size: 14, weight: 500),
              ),
            ),
            Text(
              team.realClubs.join(', '),
              style: LevaType.meta.copyWith(fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avisos del draw en un solo bloque, con el detalle desplegable.
class _WarningsSummary extends StatefulWidget {
  const _WarningsSummary({required this.warnings, required this.groups});
  final List<DrawWarning> warnings;
  final bool groups;

  @override
  State<_WarningsSummary> createState() => _WarningsSummaryState();
}

class _WarningsSummaryState extends State<_WarningsSummary> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.warnings.length;
    final title = widget.groups
        ? '$n ${n == 1 ? 'cruce' : 'cruces'} de mismo club en grupos. Es el mínimo posible con estos clubes; puedes ajustarlo a mano.'
        : '$n ${n == 1 ? 'cruce' : 'cruces'} de mismo club en la primera ronda que no se pudieron evitar.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LevaNotice(
          title,
          kind: widget.groups ? LevaNoticeKind.info : LevaNoticeKind.error,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _open = !_open),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 44),
            ),
            child: Text(
              _open ? 'Ocultar detalle' : 'Ver detalle',
              style: LevaType.body(
                size: 13,
                weight: 600,
                color: LevaColors.gold200,
              ),
            ),
          ),
        ),
        if (_open)
          for (final w in widget.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('· ${w.message}', style: LevaType.meta),
            ),
      ],
    );
  }
}
