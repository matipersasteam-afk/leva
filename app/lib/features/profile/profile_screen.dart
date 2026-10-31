import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/session.dart';
import '../../core/design_system/design_system.dart';
import '../../data/profile_repository.dart';
import '../../domain/models/player_profile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    if (profile == null) return const SizedBox.shrink();
    final history = ref.watch(myHistoryProvider);

    return ListView(
      padding: const EdgeInsets.only(bottom: 140),
      children: [
        _Hero(profile: profile),
        _Stats(profile: profile),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: LevaSpace.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LevaSectionHeader('Historial LEVA'),
              switch (history) {
                AsyncData(:final value) when value.isEmpty =>
                  const LevaEmptyState(
                    title: 'Tu historia empieza aquí',
                    message: 'Cuando juegues tu primer torneo LEVA, tus resultados aparecen en esta lista.',
                  ),
                AsyncData(:final value) => Column(
                  children: [for (final h in value) _HistoryRow(entry: h)],
                ),
                AsyncError() => const LevaNotice(
                  'No pudimos cargar tu historial.',
                ),
                _ => const Padding(
                  padding: EdgeInsets.all(LevaSpace.s6),
                  child: Center(
                    child: CircularProgressIndicator(color: LevaColors.gold500),
                  ),
                ),
              },
              const SizedBox(height: LevaSpace.s8),
              LevaButton(
                label: 'Cerrar sesión',
                variant: LevaButtonVariant.dark,
                small: true,
                icon: Icons.logout,
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.profile});
  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: 400 + top,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [LevaColors.navy, LevaColors.ink1],
            stops: [0, .92],
          ),
        ),
        child: Stack(
          children: [
            // Placa tipográfica: se reemplaza por la foto recortada del jugador.
            Positioned(
              right: -18,
              bottom: 0,
              width: 300,
              height: 360,
              child: _Plate(initials: profile.initials),
            ),
            Positioned(
              top: top + LevaSpace.s2,
              left: 0,
              right: 0,
              child: LevaTopBar(
                title: 'Mi perfil',
                trailing: LevaIconButton(
                  icon: Icons.edit_outlined,
                  label: 'Editar perfil',
                  onTap: () => context.push(Routes.editProfile),
                ),
              ),
            ),
            Positioned(
              left: LevaSpace.gutter,
              right: LevaSpace.gutter,
              bottom: LevaSpace.gutter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombres largos se achican en vez de cortarse.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: GoldText(
                      profile.firstName.toUpperCase(),
                      style: LevaType.display(76),
                      maxLines: 1,
                    ),
                  ),
                  if (profile.lastName.isNotEmpty)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        profile.lastName.toUpperCase(),
                        style: LevaType.display(76),
                        maxLines: 1,
                      ),
                    ),
                  const SizedBox(height: LevaSpace.s3),
                  Text(
                    [
                      if (profile.nickname != null) '“${profile.nickname}”',
                      profile.club,
                    ].join(' · '),
                    style: LevaType.body(
                      size: 15,
                      weight: 500,
                      color: LevaColors.gold200,
                    ).copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Plate extends StatelessWidget {
  const _Plate({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0, .55, 1],
      ).createShader(r),
      child: Stack(
        children: [
          Positioned(
            left: 210,
            top: 0,
            bottom: 0,
            child: Transform(
              transform: Matrix4.skewX(-14 * math.pi / 180),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    decoration: const BoxDecoration(
                      gradient: LevaGradients.goldVertical,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Opacity(
                    opacity: .45,
                    child: Container(
                      width: 14,
                      decoration: const BoxDecoration(
                        gradient: LevaGradients.goldVertical,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            top: 40,
            child: Center(
              child: Text(
                initials,
                style: LevaType.display(220).copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 1.5
                    ..color = LevaColors.gold500.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.profile});
  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    Widget cell(
      String value,
      String label, {
      bool gold = false,
      bool last = false,
    }) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: LevaSpace.s4,
          horizontal: 4,
        ),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(right: BorderSide(color: LevaColors.line)),
        ),
        child: Column(
          children: [
            FittedBox(
              child: gold
                  ? GoldText(value.toUpperCase(), style: LevaType.display(26))
                  : Text(value.toUpperCase(), style: LevaType.display(26)),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label.toUpperCase(),
                style: LevaType.support(tracking: 0.08),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
    return Container(
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: LevaColors.line),
        ),
      ),
      child: Row(
        children: [
          cell(profile.category.label, 'Categoría', gold: true),
          cell(profile.position.label, 'Posición'),
          cell(profile.hand.label, 'Mano'),
          cell('${profile.tournaments}', 'Torneos', last: true),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final date = entry.date == null
        ? ''
        : DateFormat('MMM yy', 'es_MX').format(entry.date!).toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LevaColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              date,
              style: LevaType.body(
                size: 12,
                weight: 600,
                color: LevaColors.tx3,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.eventName, style: LevaType.body(weight: 600)),
                Text(
                  [
                    entry.category,
                    if (entry.partnerName != null) 'con ${entry.partnerName}',
                  ].join(' · '),
                  style: LevaType.meta,
                ),
              ],
            ),
          ),
          entry.isTitle
              ? GoldText(
                  entry.resultLabel.toUpperCase(),
                  style: LevaType.display(18),
                )
              : LevaTag(entry.resultLabel),
        ],
      ),
    );
  }
}
