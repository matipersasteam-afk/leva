import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/session.dart';
import '../../core/design_system/design_system.dart';
import '../../data/draw_repository.dart';
import '../../domain/draw/draw.dart';
import '../../domain/models/event.dart';
import '../../domain/scoring/scoring.dart';
import '../draw/draw_view.dart';

/// "Grupo A · Fecha 2", "Semifinal 1", "Final".
String matchCaption(StoredMatch m, int koRounds, int inRound) =>
    m.stage == DrawStage.knockout
    ? '${knockoutRoundName(m.round, koRounds)}${inRound > 1 ? ' ${m.order + 1}' : ''}'
    : '${(m.groupName?.length ?? 0) == 1 ? 'Grupo ${m.groupName}' : m.groupName} · Fecha ${m.round}';

String _waitingText(int n, {required bool more}) => n == 1
    ? '1 partido${more ? ' más' : ''} espera a que se definan sus parejas.'
    : '$n partidos${more ? ' más' : ''} esperan a que se definan sus parejas.';

/// Mesa de control: los jugadores dicen el resultado y el staff lo carga.
class AdminResultsScreen extends ConsumerStatefulWidget {
  const AdminResultsScreen({super.key, required this.eventId});
  final String eventId;

  @override
  ConsumerState<AdminResultsScreen> createState() => _AdminResultsScreenState();
}

class _AdminResultsScreenState extends ConsumerState<AdminResultsScreen> {
  String? _categoryId;
  int _view = 0; // 0 por cargar, 1 terminados

  @override
  Widget build(BuildContext context) {
    final event = ref.watch(eventProvider(widget.eventId)).value;
    final categories =
        (ref.watch(categoriesProvider(widget.eventId)).value ??
                const <EventCategory>[])
            .where((c) => c.isPublishedDraw)
            .toList();
    final cat =
        categories.where((c) => c.id == _categoryId).firstOrNull ??
        categories.firstOrNull;
    final matches = cat == null
        ? const <StoredMatch>[]
        : ref
                  .watch(
                    matchesProvider((
                      eventId: widget.eventId,
                      categoryId: cat.id,
                    )),
                  )
                  .value ??
              const <StoredMatch>[];

    final koRounds = matches
        .where((m) => m.stage == DrawStage.knockout)
        .fold(0, (max, m) => m.round > max ? m.round : max);
    int inRound(StoredMatch m) =>
        matches.where((x) => x.stage == m.stage && x.round == m.round).length;
    int rank(StoredMatch m) => m.stage == DrawStage.knockout ? 1 : 0;
    final sorted = [...matches]
      ..sort((a, b) {
        var c = rank(a).compareTo(rank(b));
        if (c != 0) return c;
        c = a.round.compareTo(b.round);
        if (c != 0) return c;
        c = (a.groupName ?? '').compareTo(b.groupName ?? '');
        return c != 0 ? c : a.order.compareTo(b.order);
      });
    final toLoad = sorted.where((m) => !m.isFinal && m.isPlayable).toList();
    final waiting = sorted.where((m) => !m.isFinal && !m.isPlayable).length;
    final done = sorted
        .where((m) => m.isFinal && m.isPlayable)
        .toList()
        .reversed
        .toList();
    final list = _view == 0 ? toLoad : done;

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
                    trailing: const LevaRoleChip('Mesa'),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        LevaSpace.gutter,
                        0,
                        LevaSpace.gutter,
                        LevaSpace.s12,
                      ),
                      children: [
                        Text('CARGAR', style: LevaType.xl),
                        GoldText('RESULTADOS', style: LevaType.xl),
                        const SizedBox(height: LevaSpace.s4),
                        if (cat == null)
                          const LevaEmptyState(
                            title: 'Sin cuadros publicados',
                            message: 'Los resultados se cargan cuando el draw de la categoría está publicado.',
                          )
                        else ...[
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final c in categories) ...[
                                  LevaChip(
                                    label: c.name,
                                    selected: c.id == cat.id,
                                    onTap: () =>
                                        setState(() => _categoryId = c.id),
                                  ),
                                  const SizedBox(width: LevaSpace.s2),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: LevaSpace.s4),
                          LevaSegmented(
                            options: [
                              'Por cargar · ${toLoad.length}',
                              'Terminados · ${done.length}',
                            ],
                            index: _view,
                            onChanged: (v) => setState(() => _view = v),
                          ),
                          const SizedBox(height: LevaSpace.s4),
                          if (list.isEmpty)
                            LevaEmptyState(
                              title: _view == 0
                                  ? 'Nada por cargar'
                                  : 'Todavía no hay resultados',
                              message: _view == 0
                                  ? (waiting > 0
                                        ? _waitingText(waiting, more: false)
                                        : 'La categoría terminó.')
                                  : 'Los partidos aparecen aquí al cargar su resultado.',
                            ),
                          for (final m in list) ...[
                            LevaPressable(
                              semanticLabel:
                                  'Cargar resultado: ${m.teamA?.label} contra ${m.teamB?.label}',
                              onTap: event == null
                                  ? null
                                  : () => _openEntry(event, m),
                              child: BracketMatchTile(
                                caption: matchCaption(m, koRounds, inRound(m)),
                                teamA: m.teamA?.label,
                                teamB: m.teamB?.label,
                                scoreA: storedToItem(
                                  m,
                                  koRounds,
                                  1,
                                  const {},
                                ).scoreA,
                                scoreB: storedToItem(
                                  m,
                                  koRounds,
                                  1,
                                  const {},
                                ).scoreB,
                                winner: m.winner == null
                                    ? null
                                    : (m.winner == 'A' ? 0 : 1),
                                live: m.isLive,
                              ),
                            ),
                            const SizedBox(height: LevaSpace.s3),
                          ],
                          if (_view == 0 && waiting > 0 && list.isNotEmpty)
                            Text(
                              _waitingText(waiting, more: true),
                              style: LevaType.meta,
                            ),
                        ],
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

  void _openEntry(PadelEvent event, StoredMatch m) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LevaColors.ink2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(LevaRadius.lg),
        ),
      ),
      builder: (_) => ResultEntrySheet(event: event, match: m),
    );
  }
}

/// Carga del resultado final: games por set (o puntos del súper tie-break) y W.O.
class ResultEntrySheet extends ConsumerStatefulWidget {
  const ResultEntrySheet({super.key, required this.event, required this.match});
  final PadelEvent event;
  final StoredMatch match;

  @override
  ConsumerState<ResultEntrySheet> createState() => _ResultEntrySheetState();
}

class _ResultEntrySheetState extends ConsumerState<ResultEntrySheet> {
  late final ScoringRules _rules = widget.event.rules;
  late final int _maxSets = _rules.setsToWin * 2 - 1;
  late final List<int?> _a = List.filled(_maxSets, null);
  late final List<int?> _b = List.filled(_maxSets, null);
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Corrección: arranca con el resultado ya cargado.
    for (final (i, s) in widget.match.sets.indexed) {
      if (i >= _maxSets || widget.match.status == 'walkover') break;
      _a[i] = s.a;
      _b[i] = s.b;
    }
  }

  /// Sets completos en orden y cuántos se muestran (hasta que alguien gana).
  ({List<SetScore> sets, int visible}) get _entered {
    final sets = <SetScore>[];
    var wonA = 0, wonB = 0, visible = 0;
    for (var i = 0; i < _maxSets; i++) {
      if (wonA == _rules.setsToWin || wonB == _rules.setsToWin) break;
      visible++;
      final a = _a[i], b = _b[i];
      if (a == null || b == null) break;
      final stb = _isSuper(i, wonA, wonB);
      sets.add(SetScore(a, b, superTiebreak: stb));
      if (a > b) wonA++;
      if (b > a) wonB++;
    }
    return (sets: sets, visible: visible);
  }

  bool _isSuper(int i, int wonA, int wonB) =>
      _rules.usesSuperTiebreak &&
      wonA == _rules.setsToWin - 1 &&
      wonB == _rules.setsToWin - 1;

  bool _superAt(int index) {
    var wonA = 0, wonB = 0;
    for (var i = 0; i < index; i++) {
      final a = _a[i] ?? 0, b = _b[i] ?? 0;
      if (a > b) wonA++;
      if (b > a) wonB++;
    }
    return _isSuper(index, wonA, wonB);
  }

  Future<void> _save({Side? walkoverWinner}) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    final List<SetScore> sets;
    final Side winner;
    if (walkoverWinner != null) {
      winner = walkoverWinner;
      sets = walkoverSets(winner, _rules);
    } else {
      final check = validateFinalResult(_entered.sets, _rules);
      if (check is! ValidResult) return;
      winner = check.winner;
      sets = _entered.sets;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(drawRepositoryProvider)
          .saveResult(
            eventId: widget.event.id,
            matchId: widget.match.id,
            sets: sets,
            winner: winner,
            byUid: uid,
            walkover: walkoverWinner != null,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Resultado guardado · gana ${widget.match.team(winner == Side.a ? 0 : 1)?.label}',
          ),
        ),
      );
    } on ResultLockedError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se guardó. Revisa tu conexión y tu rol de staff.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmWalkover(Side absent) async {
    final name = widget.match.team(absent == Side.a ? 0 : 1)?.label ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: LevaColors.ink3,
        title: Text('¿W.O. de $name?', style: LevaType.m),
        content: Text(
          'Pierde el partido por no presentarse. En la tabla cuenta como ${walkoverSets(absent.other, _rules).map((s) => s.label).join(' ')}.',
          style: LevaType.body(size: 14, color: LevaColors.tx2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirmar W.O.'),
          ),
        ],
      ),
    );
    if (ok == true) await _save(walkoverWinner: absent.other);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final entered = _entered;
    final check = validateFinalResult(entered.sets, _rules);
    final complete = entered.sets.length == entered.visible;
    final message = switch (check) {
      ValidResult(:final winner) =>
        'Gana ${m.team(winner == Side.a ? 0 : 1)?.label}',
      InvalidResult(:final message) => complete ? message : null,
    };

    Widget picker(int setIndex, int side) {
      final values = side == 0 ? _a : _b;
      // Súper tie-break: puntos (casi siempre 10-x, 11-9, 12-10); set: games.
      final top = _superAt(setIndex)
          ? _rules.superTiebreakPoints + 10
          : _rules.gamesPerSet + 1;
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var g = 0; g <= top; g++)
            LevaChip(
              label: '$g',
              selected: values[setIndex] == g,
              onTap: () => setState(() => values[setIndex] = g),
            ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            LevaSpace.gutter,
            LevaSpace.s5,
            LevaSpace.gutter,
            LevaSpace.s5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('RESULTADO FINAL', style: LevaType.support()),
              const SizedBox(height: LevaSpace.s3),
              for (var i = 0; i < entered.visible; i++) ...[
                Text(
                  _superAt(i) ? 'SÚPER TIE-BREAK' : 'SET ${i + 1}',
                  style: LevaType.support(color: LevaColors.gold200),
                ),
                const SizedBox(height: LevaSpace.s2),
                for (final side in [0, 1]) ...[
                  Text(
                    m.team(side)?.label ?? '',
                    style: LevaType.body(size: 14, weight: 600),
                  ),
                  const SizedBox(height: 6),
                  picker(i, side),
                  const SizedBox(height: LevaSpace.s3),
                ],
              ],
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: LevaSpace.s3),
                  child: Text(
                    message,
                    style: LevaType.body(
                      size: 14,
                      weight: 600,
                      color: check is ValidResult
                          ? LevaColors.ok
                          : LevaColors.danger,
                    ),
                  ),
                ),
              if (_error != null) ...[
                LevaNotice(_error!),
                const SizedBox(height: LevaSpace.s3),
              ],
              LevaButton(
                label: 'Guardar resultado',
                loading: _saving,
                onPressed: check is ValidResult && !_saving ? _save : null,
              ),
              const SizedBox(height: LevaSpace.s3),
              Row(
                children: [
                  for (final side in Side.values) ...[
                    Expanded(
                      child: LevaButton(
                        label: 'W.O. ${side == Side.a ? '1' : '2'}',
                        small: true,
                        variant: LevaButtonVariant.dark,
                        onPressed: _saving
                            ? null
                            : () => _confirmWalkover(side),
                      ),
                    ),
                    if (side == Side.a) const SizedBox(width: LevaSpace.s2),
                  ],
                ],
              ),
              const SizedBox(height: LevaSpace.s2),
              Text(
                'W.O. 1: no se presentó ${m.teamA?.label}. W.O. 2: no se presentó ${m.teamB?.label}.',
                style: LevaType.meta.copyWith(fontSize: 12),
              ),
              if (!m.isFinal) ...[
                const SizedBox(height: LevaSpace.s4),
                LevaButton(
                  label: m.isLive
                      ? 'Seguir punto a punto'
                      : 'Punto a punto (juez)',
                  icon: Icons.sports_tennis,
                  small: true,
                  variant: LevaButtonVariant.line,
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push(Routes.judge(widget.event.id, m.id));
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
