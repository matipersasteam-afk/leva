import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../leva_tokens.dart';

/// Envuelve cualquier control: escala a 0.97 al presionar (140 ms, ease-out fuerte)
/// y expone semántica de botón.
class LevaPressable extends StatefulWidget {
  const LevaPressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = LevaMotion.pressScale,
    this.semanticLabel,
    this.haptic = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final String? semanticLabel;
  final bool haptic;

  @override
  State<LevaPressable> createState() => _LevaPressableState();
}

class _LevaPressableState extends State<LevaPressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => _set(true) : null,
          onTapUp: enabled ? (_) => _set(false) : null,
          onTapCancel: () => _set(false),
          onTap: enabled
              ? () {
                  if (widget.haptic) HapticFeedback.selectionClick();
                  widget.onTap!();
                }
              : null,
          child: AnimatedScale(
            scale: _down ? widget.scale : 1,
            duration: LevaMotion.press,
            curve: LevaMotion.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Trazado con corte a 45° en esquina superior-derecha e inferior-izquierda.
Path chamferPath(Size s, double cut) => Path()
  ..moveTo(0, 0)
  ..lineTo(s.width - cut, 0)
  ..lineTo(s.width, cut)
  ..lineTo(s.width, s.height)
  ..lineTo(cut, s.height)
  ..lineTo(0, s.height - cut)
  ..close();

class _ChamferClipper extends CustomClipper<Path> {
  const _ChamferClipper(this.cut);
  final double cut;
  @override
  Path getClip(Size size) => chamferPath(size, cut);
  @override
  bool shouldReclip(_ChamferClipper old) => old.cut != cut;
}

class _ChamferBorderPainter extends CustomPainter {
  const _ChamferBorderPainter(this.cut, this.color);
  final double cut;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1);
    final p = chamferPath(r.size, cut).shift(r.topLeft);
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ChamferBorderPainter old) =>
      old.cut != cut || old.color != color;
}

/// Superficie con esquinas cortadas. El borde se dibuja siguiendo el corte
/// (no se pierde en las diagonales).
class Chamfered extends StatelessWidget {
  const Chamfered({
    super.key,
    required this.child,
    this.cut = LevaRadius.chamfer,
    this.color,
    this.gradient,
    this.borderColor,
  });

  final Widget child;
  final double cut;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _ChamferClipper(cut),
      child: CustomPaint(
        foregroundPainter: borderColor == null
            ? null
            : _ChamferBorderPainter(cut, borderColor!),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, gradient: gradient),
          child: child,
        ),
      ),
    );
  }
}

/// Texto pintado con el degradé dorado. Deja aire para la inclinación de la
/// itálica y los acentos (Ñ, Á) para que el degradé no los recorte.
class GoldText extends StatelessWidget {
  const GoldText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign,
    this.maxLines,
  });

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? 14;
    final left = size * 0.14;
    // El margen izquierdo extra se compensa corriendo el bloque, así el texto
    // queda alineado igual que un Text normal.
    return Transform.translate(
      offset: Offset(-left, 0),
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LevaGradients.gold.createShader(bounds),
        child: Padding(
          padding: EdgeInsets.only(
            left: left,
            right: size * 0.12,
            top: size * 0.08,
            // Los signos que bajan de la línea base (¡ ¿ ,) en itálica.
            bottom: size * 0.08,
          ),
          child: Text(
            text,
            style: style,
            textAlign: textAlign,
            maxLines: maxLines,
          ),
        ),
      ),
    );
  }
}

/// El corte dorado del duelo: barra inclinada -18°.
class LevaSlash extends StatelessWidget {
  const LevaSlash({super.key, this.width = 22, this.height = 64});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.skewX(-18 * math.pi / 180),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LevaGradients.goldVertical,
          borderRadius: BorderRadius.circular(1),
          boxShadow: LevaShadows.slash,
        ),
      ),
    );
  }
}

/// Escudo LEVA — PROVISORIO hasta recibir el logo oficial (se reemplaza por un asset).
class LevaShield extends StatelessWidget {
  const LevaShield({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Escudo LEVA',
      image: true,
      child: CustomPaint(
        size: Size(size, size * 1.1),
        painter: const _ShieldPainter(),
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  const _ShieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 100, sy = size.height / 110;
    canvas.save();
    canvas.scale(sx, sy);
    final shield = Path()
      ..moveTo(50, 3)
      ..lineTo(93, 15)
      ..lineTo(93, 52)
      ..cubicTo(93, 79, 73, 96, 50, 106)
      ..cubicTo(27, 96, 7, 79, 7, 52)
      ..lineTo(7, 15)
      ..close();
    const box = Rect.fromLTWH(0, 0, 100, 110);
    canvas.drawPath(
      shield,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [LevaColors.navyHi, Color(0xFF121D35)],
        ).createShader(box),
    );
    canvas.drawPath(
      shield,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round
        ..shader = LevaGradients.goldVertical.createShader(box),
    );
    // Órbita
    canvas.save();
    canvas.translate(50, 52);
    canvas.rotate(-24 * math.pi / 180);
    canvas.drawOval(
      const Rect.fromLTRB(-31, -11, 31, 11),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = LevaColors.gold500.withValues(alpha: 0.7),
    );
    canvas.restore();
    // Pala
    canvas.save();
    canvas.translate(50, 54);
    canvas.rotate(-30 * math.pi / 180);
    final head = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-12, -30, 24, 31),
      const Radius.circular(12),
    );
    canvas.drawRRect(head, Paint()..color = LevaColors.ink1);
    canvas.drawRRect(
      head,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..color = LevaColors.gold500,
    );
    final dot = Paint()..color = LevaColors.gold500;
    for (final o in const [
      Offset(-5, -20),
      Offset(5, -20),
      Offset(0, -13),
      Offset(-5, -7),
      Offset(5, -7),
    ]) {
      canvas.drawCircle(o, 1.5, dot);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3.5, 1, 7, 20),
        const Radius.circular(2.5),
      ),
      Paint()
        ..shader = LevaGradients.goldVertical.createShader(
          const Rect.fromLTWH(-3.5, 1, 7, 20),
        ),
    );
    canvas.restore();
    // Pelota
    canvas.drawCircle(
      const Offset(78, 42),
      5.5,
      Paint()..color = LevaColors.gold200,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShieldPainter old) => false;
}

/// Líneas de cancha tenues para fondos (splash, TV).
class CourtLines extends StatelessWidget {
  const CourtLines({super.key, this.opacity = 0.1});
  final double opacity;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _CourtPainter(opacity), size: Size.infinite);
}

class _CourtPainter extends CustomPainter {
  const _CourtPainter(this.opacity);
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = LevaColors.gold500.withValues(alpha: opacity);
    final r = Rect.fromLTWH(
      size.width * .1,
      size.height * .1,
      size.width * .8,
      size.height * .8,
    );
    canvas.drawRect(r, p);
    canvas.drawLine(
      Offset(r.left, r.center.dy),
      Offset(r.right, r.center.dy),
      p,
    );
    final sv = r.height * .17;
    canvas.drawLine(Offset(r.left, r.top + sv), Offset(r.right, r.top + sv), p);
    canvas.drawLine(
      Offset(r.left, r.bottom - sv),
      Offset(r.right, r.bottom - sv),
      p,
    );
    canvas.drawLine(
      Offset(r.center.dx, r.top + sv),
      Offset(r.center.dx, r.bottom - sv),
      p,
    );
  }

  @override
  bool shouldRepaint(_CourtPainter old) => old.opacity != opacity;
}
