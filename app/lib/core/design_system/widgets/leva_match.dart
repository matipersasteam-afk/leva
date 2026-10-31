import 'package:flutter/material.dart';

import '../leva_tokens.dart';
import '../leva_typography.dart';
import 'leva_controls.dart';
import 'leva_primitives.dart';

/// Nombre de pareja en display, apilado ("GASPARINI / DE ANDA" → dos líneas).
class PairName extends StatelessWidget {
  const PairName({
    super.key,
    required this.lines,
    this.caption,
    this.alignEnd = false,
    this.size = 30,
    this.winner = false,
  });
  final List<String> lines;
  final String? caption;
  final bool alignEnd;
  final double size;
  final bool winner;

  @override
  Widget build(BuildContext context) {
    final style = LevaType.display(
      size,
      color: winner ? LevaColors.gold200 : LevaColors.tx1,
    );
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Apellidos largos se achican en vez de cortarse ("GASPARINI").
        for (final l in lines)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              l.toUpperCase(),
              style: style,
              textAlign: alignEnd ? TextAlign.right : TextAlign.left,
              maxLines: 1,
            ),
          ),
        if (caption != null) ...[
          const SizedBox(height: 6),
          Text(
            caption!,
            style: LevaType.meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// Firma visual de LEVA: dos parejas separadas por el corte dorado.
class LevaDuel extends StatelessWidget {
  const LevaDuel({
    super.key,
    required this.a,
    required this.b,
    this.captionA,
    this.captionB,
    this.size = 30,
  });
  final List<String> a;
  final List<String> b;
  final String? captionA;
  final String? captionB;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PairName(lines: a, caption: captionA, size: size),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: LevaSpace.s3),
          // El corte acompaña la altura de los nombres (1 o 2 líneas).
          child: LevaSlash(
            width: size * 0.7,
            height:
                size * (a.length > b.length ? a.length : b.length) * 1.05 +
                size * 0.5,
          ),
        ),
        Expanded(
          child: PairName(
            lines: b,
            caption: captionB,
            alignEnd: true,
            size: size,
          ),
        ),
      ],
    );
  }
}

/// Dato del pie de una tarjeta: CANCHA 3 · HORA 17:30.
class LevaStat extends StatelessWidget {
  const LevaStat({
    super.key,
    required this.label,
    required this.value,
    this.gold = false,
  });
  final String label;
  final String value;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final style = LevaType.numbers(30);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: LevaType.support()),
        const SizedBox(height: 4),
        gold
            ? GoldText(value.toUpperCase(), style: style)
            : Text(value.toUpperCase(), style: style),
      ],
    );
  }
}

/// Tarjeta "Próximo partido": duelo + cancha, hora y cuenta regresiva.
class NextMatchCard extends StatelessWidget {
  const NextMatchCard({
    super.key,
    required this.a,
    required this.b,
    required this.court,
    required this.time,
    required this.countdown,
    this.round,
    this.captionA,
    this.captionB,
    this.onTap,
  });

  final List<String> a;
  final List<String> b;
  final String court;
  final String time;
  final String countdown;
  final String? round;
  final String? captionA;
  final String? captionB;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LevaPressable(
      onTap: onTap,
      scale: 0.985,
      semanticLabel: 'Próximo partido en cancha $court a las $time',
      child: LevaPanel(
        highlight: true,
        padding: const EdgeInsets.fromLTRB(
          LevaSpace.s5,
          LevaSpace.s5,
          LevaSpace.s5,
          LevaSpace.s4,
        ),
        child: Stack(
          children: [
            const Positioned(
              right: -40,
              top: -30,
              child: Opacity(opacity: 0.12, child: LevaShield(size: 200)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('PRÓXIMO PARTIDO', style: LevaType.support()),
                    ),
                    if (round != null) LevaTag(round!, kind: LevaTagKind.gold),
                  ],
                ),
                const SizedBox(height: LevaSpace.s4),
                LevaDuel(a: a, b: b, captionA: captionA, captionB: captionB),
                const SizedBox(height: LevaSpace.s5),
                const Divider(),
                const SizedBox(height: LevaSpace.s4),
                Row(
                  children: [
                    Expanded(
                      child: LevaStat(
                        label: 'Cancha',
                        value: court,
                        gold: true,
                      ),
                    ),
                    Expanded(
                      child: LevaStat(label: 'Hora', value: time),
                    ),
                    Expanded(
                      child: LevaStat(label: 'Faltan', value: countdown),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Casilla de punto del marcador. El valor nuevo entra desde abajo (220 ms).
class ScoreBox extends StatelessWidget {
  const ScoreBox({super.key, required this.value, this.size = 56});
  final String value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Container(
      width: size * 1.15,
      height: size,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: LevaColors.ink1,
        borderRadius: BorderRadius.circular(LevaRadius.sm),
        border: Border.all(color: LevaColors.line),
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: reduce ? Duration.zero : LevaMotion.indicator,
        switchInCurve: LevaMotion.easeOut,
        switchOutCurve: LevaMotion.easeOut,
        transitionBuilder: (child, anim) {
          final incoming = child.key == ValueKey(value);
          final offset = Tween(
            begin: Offset(0, incoming ? 0.55 : -0.55),
            end: Offset.zero,
          ).animate(anim);
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(position: offset, child: child),
          );
        },
        child: Text(
          value,
          key: ValueKey(value),
          style: LevaType.numbers(size * 0.64),
        ),
      ),
    );
  }
}

/// Fila de marcador: nombre · sets · punto actual.
class ScoreRow extends StatelessWidget {
  const ScoreRow({
    super.key,
    required this.name,
    required this.sets,
    required this.point,
    this.serving = false,
    this.setsWon = const [],
  });
  final String name;
  final List<String> sets;
  final List<bool> setsWon;
  final String point;
  final bool serving;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          AnimatedOpacity(
            opacity: serving ? 1 : 0,
            duration: LevaMotion.base,
            child: Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: LevaColors.gold500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              name.toUpperCase(),
              style: LevaType.display(21),
              maxLines: 2,
            ),
          ),
          for (var i = 0; i < sets.length; i++)
            SizedBox(
              width: 34,
              child: Text(
                sets[i],
                textAlign: TextAlign.center,
                style: LevaType.body(
                  size: 20,
                  weight: 700,
                  color: i < setsWon.length && setsWon[i]
                      ? LevaColors.gold200
                      : LevaColors.tx1,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          const SizedBox(width: 6),
          ScoreBox(value: point),
        ],
      ),
    );
  }
}

/// Partido en el cuadro.
class BracketMatchTile extends StatelessWidget {
  const BracketMatchTile({
    super.key,
    required this.caption,
    required this.teamA,
    required this.teamB,
    this.scoreA = const [],
    this.scoreB = const [],
    this.winner,
    this.live = false,
    this.mine = false,
  });

  final String caption;
  final String? teamA;
  final String? teamB;
  final List<int> scoreA;
  final List<int> scoreB;
  final int? winner; // 0 = A, 1 = B
  final bool live;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    Widget row(String? name, List<int> score, int side) {
      final tbd = name == null;
      final won = winner == side;
      final lost = winner != null && !won;
      return Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name ?? 'Por definir',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LevaType.body(
                  size: 13,
                  weight: won ? 700 : 500,
                  color: won
                      ? LevaColors.gold200
                      : (lost || tbd ? LevaColors.tx3 : LevaColors.tx1),
                ).copyWith(fontStyle: tbd ? FontStyle.italic : null),
              ),
            ),
            for (final s in score)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  '$s',
                  style: LevaType.body(
                    size: 13,
                    weight: 700,
                    color: won ? LevaColors.tx1 : LevaColors.tx2,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: LevaColors.ink2,
        borderRadius: BorderRadius.circular(LevaRadius.sm),
        border: Border.all(
          color: live
              ? const Color(0x80F0484F)
              : (mine ? LevaColors.goldLine : LevaColors.line),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: const Color(0x2E000000),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              children: [
                if (live)
                  const Padding(
                    padding: EdgeInsets.only(right: 5),
                    child: LiveDot(size: 5),
                  ),
                Expanded(
                  child: Text(
                    (live ? 'En vivo · $caption' : caption).toUpperCase(),
                    style: LevaType.tag.copyWith(
                      color: live ? const Color(0xFFFF8A8F) : LevaColors.tx3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (mine)
                  Text(
                    'TU PARTIDO',
                    style: LevaType.tag.copyWith(
                      color: LevaColors.tx3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          row(teamA, scoreA, 0),
          const Divider(),
          row(teamB, scoreB, 1),
        ],
      ),
    );
  }
}
