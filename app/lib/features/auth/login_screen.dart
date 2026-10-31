import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/session.dart';
import '../../core/design_system/design_system.dart';
import '../../data/auth_repository.dart';

enum _Method { apple, google }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _Method? _busy;
  String? _error;

  /// Conserva el destino pendiente (p. ej. una invitación) al pasar a correo.
  String _emailRoute(BuildContext context) {
    final from = GoRouterState.of(context).uri.queryParameters['desde'];
    return from == null
        ? Routes.loginEmail
        : Uri(
            path: Routes.loginEmail,
            queryParameters: {'desde': from},
          ).toString();
  }

  /// Apple se ofrece en iOS (obligatorio junto a Google) y en web; no en Android.
  bool get _showApple => kIsWeb || defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _run(_Method m) async {
    setState(() {
      _busy = m;
      _error = null;
    });
    final repo = ref.read(authRepositoryProvider);
    try {
      m == _Method.google
          ? await repo.signInWithGoogle()
          : await repo.signInWithApple();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 520,
            child: _LoginArt(),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          LevaSpace.s6,
                          220,
                          LevaSpace.s6,
                          24 + bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GoldText('¡VAMOS A', style: LevaType.mega),
                            Text('ROMPERLA!', style: LevaType.mega),
                            const SizedBox(height: LevaSpace.s3),
                            Text(
                              'GENTE · PÁDEL · EXPERIENCIAS',
                              style: LevaType.support(
                                size: 12,
                                weight: 300,
                                tracking: 0.2,
                              ),
                            ),
                            const SizedBox(height: LevaSpace.s6),
                            if (_error != null) ...[
                              LevaNotice(_error!),
                              const SizedBox(height: LevaSpace.s3),
                            ],
                            if (_showApple) ...[
                              _AuthButton(
                                label: 'Continuar con Apple',
                                icon: Icons.apple,
                                light: true,
                                busy: _busy == _Method.apple,
                                onTap: _busy == null
                                    ? () => _run(_Method.apple)
                                    : null,
                              ),
                              const SizedBox(height: LevaSpace.s3),
                            ],
                            _AuthButton(
                              label: 'Continuar con Google',
                              leading: const _GoogleG(),
                              busy: _busy == _Method.google,
                              onTap: _busy == null
                                  ? () => _run(_Method.google)
                                  : null,
                            ),
                            const SizedBox(height: LevaSpace.s3),
                            _AuthButton(
                              label: 'Entrar con correo',
                              onTap: _busy == null
                                  ? () => context.push(_emailRoute(context))
                                  : null,
                            ),
                            const SizedBox(height: LevaSpace.s4),
                            const _LegalLine(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    this.icon,
    this.leading,
    this.light = false,
    this.busy = false,
    this.onTap,
  });
  final String label;
  final IconData? icon;
  final Widget? leading;
  final bool light;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = light ? Colors.black : LevaColors.tx1;
    return LevaPressable(
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedOpacity(
        duration: LevaMotion.fast,
        opacity: onTap == null && !busy ? .5 : 1,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: light ? LevaColors.tx1 : Colors.transparent,
            borderRadius: BorderRadius.circular(LevaRadius.sm),
            border: light ? null : Border.all(color: LevaColors.line2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
                )
              else if (leading != null)
                leading!
              else if (icon != null)
                Icon(icon, size: 20, color: fg),
              if (busy || leading != null || icon != null)
                const SizedBox(width: 10),
              Text(
                label,
                style: LevaType.body(size: 15, weight: 600, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Al continuar aceptas los Términos y el Aviso de privacidad de LEVA."
/// con los dos documentos como enlaces.
class _LegalLine extends StatelessWidget {
  const _LegalLine();

  @override
  Widget build(BuildContext context) {
    final base = LevaType.meta.copyWith(fontSize: 12);
    Widget link(String label) => Semantics(
      link: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showLegal(context, label),
        child: Padding(
          // Área táctil mínima de 44 px sin cambiar cómo se ve la línea.
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 14),
          child: Text(
            label,
            style: base.copyWith(
              color: LevaColors.tx2,
              decoration: TextDecoration.underline,
              decorationColor: LevaColors.tx3,
            ),
          ),
        ),
      ),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Al continuar aceptas los ', style: base),
        link('Términos'),
        Text(' y el ', style: base),
        link('Aviso de privacidad'),
        Text(' de LEVA.', style: base),
      ],
    );
  }

  /// Los documentos legales los entrega LEVA; mientras tanto, un aviso honesto.
  static void _showLegal(BuildContext context, String title) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: LevaColors.ink2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(LevaRadius.lg),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            LevaSpace.gutter,
            LevaSpace.s6,
            LevaSpace.gutter,
            LevaSpace.s6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.toUpperCase(), style: LevaType.l),
              const SizedBox(height: LevaSpace.s3),
              const LevaNotice(
                'Documento en preparación. LEVA lo publica aquí antes del lanzamiento de la app.',
                kind: LevaNoticeKind.info,
              ),
              const SizedBox(height: LevaSpace.s5),
              LevaButton(
                label: 'Entendido',
                variant: LevaButtonVariant.dark,
                small: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo "G" de Google en sus cuatro colores, dibujado en vector.
class _GoogleG extends StatelessWidget {
  const _GoogleG();
  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: Size.square(20), painter: _GoogleGPainter());
}

class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.2;
    final r = (s - stroke) / 2;
    final c = Offset(s / 2, s / 2);
    final rect = Rect.fromCircle(center: c, radius: r);
    double rad(double deg) => deg * math.pi / 180;
    Paint p(int color) => Paint()
      ..color = Color(color)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    canvas.drawArc(rect, rad(-145), rad(105), false, p(0xFFEA4335)); // rojo
    canvas.drawArc(rect, rad(145), rad(70), false, p(0xFFFBBC05)); // amarillo
    canvas.drawArc(rect, rad(45), rad(100), false, p(0xFF34A853)); // verde
    canvas.drawArc(rect, rad(0), rad(45), false, p(0xFF4285F4)); // azul
    canvas.drawRect(
      Rect.fromLTRB(
        c.dx,
        c.dy - stroke / 2,
        c.dx + r + stroke / 2,
        c.dy + stroke / 2,
      ),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_GoogleGPainter old) => false;
}

/// Arte superior: cancha en perspectiva, corte dorado y escudo.
class _LoginArt extends StatelessWidget {
  const _LoginArt();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0, .45, 1],
      ).createShader(r),
      child: Container(
        color: LevaColors.ink2,
        child: Stack(
          children: [
            Positioned.fill(
              child: Transform(
                transform: Matrix4.skewY(-8 * math.pi / 180),
                child: const CourtLines(opacity: 0.22),
              ),
            ),
            Positioned(
              // Termina antes del titular (que arranca a 220 px como mínimo),
              // para que ninguna letra dorada quede sobre el dorado.
              right: -30,
              top: -40,
              height: 250,
              child: Transform(
                transform: Matrix4.skewX(-18 * math.pi / 180),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      decoration: const BoxDecoration(
                        gradient: LevaGradients.goldVertical,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Opacity(
                      opacity: .5,
                      child: Container(
                        width: 8,
                        decoration: const BoxDecoration(
                          gradient: LevaGradients.goldVertical,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: LevaSpace.s6,
              top: MediaQuery.paddingOf(context).top + 48,
              child: const LevaShield(size: 72),
            ),
          ],
        ),
      ),
    );
  }
}
