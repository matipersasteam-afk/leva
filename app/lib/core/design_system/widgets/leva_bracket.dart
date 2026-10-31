import 'package:flutter/material.dart';

import '../leva_tokens.dart';
import '../leva_typography.dart';
import 'leva_match.dart';

/// Partido del cuadro, en datos de presentación.
class BracketItem {
  const BracketItem({
    required this.caption,
    this.teamA,
    this.teamB,
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
  final int? winner;
  final bool live;
  final bool mine;
}

/// Llave de eliminación: columnas por ronda con líneas de conexión.
/// [rounds][r] tiene la mitad de partidos que [rounds][r-1].
class LevaBracket extends StatelessWidget {
  const LevaBracket({
    super.key,
    required this.rounds,
    required this.roundNames,
    this.columnWidth = 210,
  });

  final List<List<BracketItem>> rounds;
  final List<String> roundNames;
  final double columnWidth;

  static const _tileHeight = 110.0;
  static const _gap = 14.0;
  static const _hGap = 36.0;
  static const _header = 28.0;

  @override
  Widget build(BuildContext context) {
    if (rounds.isEmpty) return const SizedBox.shrink();
    final slot = _tileHeight + _gap;
    final height = _header + rounds.first.length * slot;
    final width = rounds.length * columnWidth + (rounds.length - 1) * _hGap;

    double top(int r, int i) =>
        _header + (i + 0.5) * slot * (1 << r) - _tileHeight / 2;
    double left(int r) => r * (columnWidth + _hGap);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: LevaSpace.gutter),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _Connectors(
                  rounds: rounds,
                  top: top,
                  left: left,
                  columnWidth: columnWidth,
                  tileHeight: _tileHeight,
                ),
              ),
            ),
            for (var r = 0; r < rounds.length; r++) ...[
              Positioned(
                left: left(r),
                top: 0,
                child: Text(
                  roundNames[r].toUpperCase(),
                  style: LevaType.support(),
                ),
              ),
              for (var i = 0; i < rounds[r].length; i++)
                Positioned(
                  left: left(r),
                  top: top(r, i),
                  width: columnWidth,
                  child: _Tile(item: rounds[r][i]),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item});
  final BracketItem item;

  @override
  Widget build(BuildContext context) => BracketMatchTile(
    caption: item.caption,
    teamA: item.teamA,
    teamB: item.teamB,
    scoreA: item.scoreA,
    scoreB: item.scoreB,
    winner: item.winner,
    live: item.live,
    mine: item.mine,
  );
}

class _Connectors extends CustomPainter {
  _Connectors({
    required this.rounds,
    required this.top,
    required this.left,
    required this.columnWidth,
    required this.tileHeight,
  });

  final List<List<BracketItem>> rounds;
  final double Function(int r, int i) top;
  final double Function(int r) left;
  final double columnWidth;
  final double tileHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = LevaColors.line2;
    final hot = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = LevaColors.gold500;
    for (var r = 0; r < rounds.length - 1; r++) {
      for (var i = 0; i < rounds[r].length; i++) {
        final x1 = left(r) + columnWidth, y1 = top(r, i) + tileHeight / 2;
        final x2 = left(r + 1), y2 = top(r + 1, i ~/ 2) + tileHeight / 2;
        final mx = (x1 + x2) / 2;
        final path = Path()
          ..moveTo(x1, y1)
          ..lineTo(mx, y1)
          ..lineTo(mx, y2)
          ..lineTo(x2, y2);
        canvas.drawPath(path, rounds[r][i].mine ? hot : line);
      }
    }
  }

  @override
  bool shouldRepaint(_Connectors old) => old.rounds != rounds;
}
