import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../data/draw_repository.dart';
import '../../domain/models/event.dart';
import '../../domain/scoring/scoring.dart';

/// Juez de cancha: punto a punto con dos botones grandes. Cada punto se guarda
/// en el partido (el cuadro y la app del público lo ven en vivo).
class JudgeScreen extends ConsumerStatefulWidget {
  const JudgeScreen({super.key, required this.eventId, required this.matchId});
  final String eventId;
  final String matchId;

  @override
  ConsumerState<JudgeScreen> createState() => _JudgeScreenState();
}

class _JudgeScreenState extends ConsumerState<JudgeScreen> {
  ScoreHistory? _history;
  bool _saving = false;
  String? _error;

  void _start(ScoringRules rules, Side firstServer) =>
      _push(ScoreHistory.start(rules, firstServer: firstServer));

  void _push(ScoreHistory h) {
    setState(() {
      _history = h;
      _error = null;
    });
    final uid = ref.read(authStateProvider).value?.uid ?? '';
    ref
        .read(drawRepositoryProvider)
        .saveLiveScore(
          eventId: widget.eventId,
          matchId: widget.matchId,
          score: h.current,
          byUid: uid,
        )
        .catchError((_) {
          if (mounted) {
            setState(
              () => _error = 'Sin conexión: el punto no se guardó. Sigue anotando; se envía con el próximo.',
            );
          }
        });
  }

  void _point(Side side) {
    final h = _history;
    if (h == null || h.current.isFinished) return;
    HapticFeedback.lightImpact();
    _push(h.point(side));
  }

  Future<void> _confirm(StoredMatch m) async {
    final score = _history!.current;
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(drawRepositoryProvider)
          .saveResult(
            eventId: widget.eventId,
            matchId: m.id,
            sets: score.sets,
            winner: score.winner!,
            byUid: uid,
            method: 'juez',
            score: score,
          );
      if (mounted) context.pop();
    } on ResultLockedError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se guardó. Revisa tu conexión.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = ref.watch(eventProvider(widget.eventId)).value;
    final match = ref
        .watch(
          matchProvider((eventId: widget.eventId, matchId: widget.matchId)),
        )
        .value;

    // Retoma el marcador guardado si el juez reabre la pantalla.
    if (_history == null && match?.liveScore != null) {
      try {
        _history = ScoreHistory.resume(MatchScore.fromJson(match!.liveScore!));
      } catch (_) {
        // Marcador ilegible: se empieza de nuevo.
      }
    }

    return Scaffold(
      body: LevaCourtBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  LevaTopBar(
                    title: event?.name ?? '',
                    onBack: () => context.pop(),
                    trailing: const LevaRoleChip('Juez'),
                  ),
                  Expanded(
                    child: event == null || match == null
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: LevaColors.gold500,
                            ),
                          )
                        : _body(event, match),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(PadelEvent event, StoredMatch m) {
    final names = [m.teamA?.label ?? '', m.teamB?.label ?? ''];
    final h = _history;

    if (m.isFinal) {
      return const Padding(
        padding: EdgeInsets.all(LevaSpace.gutter),
        child: LevaEmptyState(
          title: 'Partido terminado',
          message: 'El resultado ya está cargado. Para corregirlo, usa la mesa de control.',
        ),
      );
    }

    if (h == null) {
      return ListView(
        padding: const EdgeInsets.all(LevaSpace.gutter),
        children: [
          Text('¿QUIÉN', style: LevaType.xl),
          GoldText('SACA?', style: LevaType.xl),
          const SizedBox(height: LevaSpace.s2),
          Text(
            event.rules.goldenPoint
                ? 'Punto de oro en 40-40.'
                : 'Ventaja tradicional en 40-40.',
            style: LevaType.meta,
          ),
          const SizedBox(height: LevaSpace.s5),
          for (final side in Side.values) ...[
            LevaButton(
              label: names[side.index],
              variant: side == Side.a
                  ? LevaButtonVariant.gold
                  : LevaButtonVariant.line,
              onPressed: () => _start(event.rules, side),
            ),
            const SizedBox(height: LevaSpace.s3),
          ],
        ],
      );
    }

    final s = h.current;
    List<String> sets(Side side) => [
      for (final x in s.sets) '${x.of(side)}',
      if (!s.isFinished) '${s.games(side)}',
    ];
    List<bool> won(Side side) => [for (final x in s.sets) x.winner == side];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        LevaSpace.gutter,
        0,
        LevaSpace.gutter,
        LevaSpace.s10,
      ),
      children: [
        LevaPanel(
          child: Column(
            children: [
              if (s.isGoldenPoint || s.isTiebreak)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: LevaTag(
                    s.isGoldenPoint
                        ? 'Punto de oro'
                        : (s.phase == GamePhase.superTiebreak
                              ? 'Súper tie-break'
                              : 'Tie-break'),
                    kind: LevaTagKind.gold,
                  ),
                ),
              for (final side in Side.values)
                ScoreRow(
                  name: names[side.index],
                  sets: sets(side),
                  setsWon: won(side),
                  point: s.pointLabel(side),
                  serving: !s.isFinished && s.server == side,
                ),
            ],
          ),
        ),
        const SizedBox(height: LevaSpace.s4),
        if (s.isFinished) ...[
          Text(
            'Gana ${names[s.winner!.index]} · ${s.sets.map((x) => x.label).join(' ')}',
            style: LevaType.body(size: 16, weight: 700, color: LevaColors.ok),
          ),
          const SizedBox(height: LevaSpace.s3),
          LevaButton(
            label: 'Confirmar resultado',
            loading: _saving,
            onPressed: _saving ? null : () => _confirm(m),
          ),
        ] else
          Row(
            children: [
              for (final side in Side.values) ...[
                Expanded(
                  child: LevaPressable(
                    semanticLabel: 'Punto para ${names[side.index]}',
                    onTap: () => _point(side),
                    child: Container(
                      height: 168,
                      padding: const EdgeInsets.all(LevaSpace.s4),
                      decoration: BoxDecoration(
                        gradient: LevaGradients.navyCard,
                        borderRadius: BorderRadius.circular(LevaRadius.md),
                        border: Border.all(color: LevaColors.line2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            names[side.index].toUpperCase(),
                            style: LevaType.display(22),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '+ PUNTO',
                            style: LevaType.support(
                              color: LevaColors.gold200,
                              weight: 700,
                              tracking: 0.14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (side == Side.a) const SizedBox(width: LevaSpace.s3),
              ],
            ],
          ),
        const SizedBox(height: LevaSpace.s3),
        LevaButton(
          label: 'Deshacer último punto',
          icon: Icons.undo,
          small: true,
          variant: LevaButtonVariant.dark,
          onPressed: h.canUndo && !_saving ? () => _push(h.undo()) : null,
        ),
        if (_error != null) ...[
          const SizedBox(height: LevaSpace.s3),
          LevaNotice(_error!),
        ],
      ],
    );
  }
}
