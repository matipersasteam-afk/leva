import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/session.dart';
import '../../core/design_system/design_system.dart';
import '../../data/registration_repository.dart';
import '../../domain/models/event.dart';
import '../../domain/models/player_profile.dart';

/// Paso 1: elegir pareja (buscar jugador o invitar por link). Al elegir se
/// aparta el lugar (o la lista de espera) y se crea la invitación.
class RegisterStartScreen extends ConsumerStatefulWidget {
  const RegisterStartScreen({
    super.key,
    required this.eventId,
    required this.categoryId,
  });
  final String eventId;
  final String categoryId;

  @override
  ConsumerState<RegisterStartScreen> createState() =>
      _RegisterStartScreenState();
}

class _RegisterStartScreenState extends ConsumerState<RegisterStartScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<PlayerProfile> _results = const [];
  bool _searching = false;
  String? _busyFor; // uid elegido, o 'link'
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  /// Jugadores cargados una vez; el filtro corre en el dispositivo.
  Future<List<PlayerProfile>>? _players;

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      if (q.trim().length < 2) {
        setState(() => _results = const []);
        return;
      }
      setState(() => _searching = true);
      final me = ref.read(authRepositoryProvider).currentUser?.uid;
      try {
        _players ??= ref.read(profileRepositoryProvider).listPlayers();
        final all = await _players!;
        if (mounted) {
          setState(
            () => _results = all
                .where((p) => p.uid != me && matchesPlayerQuery(p, q))
                .take(8)
                .toList(),
          );
        }
      } catch (_) {
        _players = null;
        if (mounted) {
          setState(
            () => _error = 'No pudimos buscar jugadores. Revisa tu conexión.',
          );
        }
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _reserve(
    PadelEvent event,
    EventCategory category, {
    PlayerProfile? partner,
  }) async {
    final me = ref.read(myProfileProvider).value;
    if (me == null) return;
    setState(() {
      _busyFor = partner?.uid ?? 'link';
      _error = null;
    });
    try {
      final r = await ref
          .read(registrationRepositoryProvider)
          .reserve(event: event, category: category, me: me, partner: partner);
      if (mounted) {
        context.pushReplacement(Routes.registration(event.id, r.regId));
      }
    } on RegistrationFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No pudimos apartar tu lugar. Puede que las inscripciones hayan cerrado. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyFor = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = ref.watch(eventProvider(widget.eventId)).value;
    final category =
        (ref.watch(categoriesProvider(widget.eventId)).value ?? const [])
            .where((c) => c.id == widget.categoryId)
            .firstOrNull;

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
                    onBack: () => context.pop(),
                  ),
                  Expanded(
                    child: event == null || category == null
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: LevaColors.gold500,
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(
                              LevaSpace.gutter,
                              0,
                              LevaSpace.gutter,
                              LevaSpace.s10,
                            ),
                            children: [
                              const LevaSteps(total: 3, done: 1),
                              const SizedBox(height: LevaSpace.s6),
                              Text('ARMA TU', style: LevaType.xl),
                              GoldText('PAREJA', style: LevaType.xl),
                              const SizedBox(height: LevaSpace.s2),
                              Text(
                                'Tu pareja recibe la invitación y la acepta desde su app.',
                                style: LevaType.body(
                                  size: 14,
                                  color: LevaColors.tx2,
                                ),
                              ),
                              if (category.isFull) ...[
                                const SizedBox(height: LevaSpace.s4),
                                LevaNotice(
                                  '${category.name} está llena: entras a la lista de espera y te avisamos si se libera un lugar.',
                                  kind: LevaNoticeKind.info,
                                ),
                              ],
                              const SizedBox(height: LevaSpace.s5),
                              LevaField(
                                label: 'Buscar jugador',
                                controller: _query,
                                hint: 'Nombre y apellido',
                                textCapitalization: TextCapitalization.words,
                                onChanged: _onQuery,
                                suffix: _searching
                                    ? const Padding(
                                        padding: EdgeInsets.all(14),
                                        child: SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: LevaColors.gold500,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.search,
                                        color: LevaColors.tx3,
                                      ),
                              ),
                              if (_query.text.trim().length < 2)
                                _Suggestions(
                                  players: _players ??= ref
                                      .read(profileRepositoryProvider)
                                      .listPlayers(),
                                  categoryName: category.name,
                                  me: ref
                                      .read(authRepositoryProvider)
                                      .currentUser
                                      ?.uid,
                                  busyFor: _busyFor,
                                  onInvite: (p) =>
                                      _reserve(event, category, partner: p),
                                ),
                              for (final p in _results)
                                _PlayerResult(
                                  player: p,
                                  busy: _busyFor == p.uid,
                                  onInvite: _busyFor == null
                                      ? () => _reserve(
                                          event,
                                          category,
                                          partner: p,
                                        )
                                      : null,
                                ),
                              if (_query.text.trim().length >= 2 &&
                                  !_searching &&
                                  _results.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: LevaSpace.s4,
                                  ),
                                  child: Text(
                                    'No encontramos a nadie con ese nombre. Invítalo por link y se registra al abrirlo.',
                                    style: LevaType.meta,
                                  ),
                                ),
                              const SizedBox(height: LevaSpace.s5),
                              LevaButton(
                                label: 'Invitar por link',
                                icon: Icons.link,
                                variant: LevaButtonVariant.line,
                                small: true,
                                loading: _busyFor == 'link',
                                onPressed: _busyFor == null
                                    ? () => _reserve(event, category)
                                    : null,
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: LevaSpace.s4),
                                LevaNotice(_error!),
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
}

class _PlayerResult extends StatelessWidget {
  const _PlayerResult({
    required this.player,
    required this.onInvite,
    this.busy = false,
  });
  final PlayerProfile player;
  final VoidCallback? onInvite;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LevaColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LevaColors.navy,
              border: Border.all(color: LevaColors.line2),
            ),
            child: Text(player.initials, style: LevaType.display(16)),
          ),
          const SizedBox(width: LevaSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.nickname == null
                      ? player.displayName
                      : '${player.displayName} “${player.nickname}”',
                  style: LevaType.body(weight: 600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${player.category.label} · ${player.club}',
                  style: LevaType.meta,
                ),
              ],
            ),
          ),
          LevaButton(
            label: 'Invitar',
            small: true,
            expand: false,
            variant: LevaButtonVariant.dark,
            loading: busy,
            onPressed: onInvite,
          ),
        ],
      ),
    );
  }
}

/// Sugerencias con la búsqueda vacía: jugadores de la misma categoría.
class _Suggestions extends StatelessWidget {
  const _Suggestions({
    required this.players,
    required this.categoryName,
    required this.me,
    required this.busyFor,
    required this.onInvite,
  });

  final Future<List<PlayerProfile>> players;
  final String categoryName;
  final String? me;
  final String? busyFor;
  final ValueChanged<PlayerProfile> onInvite;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PlayerProfile>>(
      future: players,
      builder: (context, snap) {
        final list = (snap.data ?? const <PlayerProfile>[])
            .where((p) => p.uid != me && p.category.label == categoryName)
            .take(5)
            .toList();
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: LevaSpace.s4),
            Text('Jugadores de $categoryName', style: LevaType.label),
            for (final p in list)
              _PlayerResult(
                player: p,
                busy: busyFor == p.uid,
                onInvite: busyFor == null ? () => onInvite(p) : null,
              ),
          ],
        );
      },
    );
  }
}
