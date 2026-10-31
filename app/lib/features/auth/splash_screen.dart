import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';

/// Splash animado: escudo, palabra LEVA revelada y lema con tracking que se cierra.
/// Momento de primera vez: aquí sí hay presupuesto de "delight".
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  Animation<double> _seg(double from, double to) => CurvedAnimation(
    parent: _c,
    curve: Interval(from, to, curve: LevaMotion.easeOut),
  );

  late final _shield = _seg(0, .45);
  late final _word = _seg(.2, .65);
  late final _tag = _seg(.45, 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
      Future<void>.delayed(const Duration(milliseconds: 400), _finish);
    } else {
      _c.forward().whenComplete(
        () => Future<void>.delayed(const Duration(milliseconds: 500), _finish),
      );
    }
  }

  void _finish() {
    if (mounted) ref.read(splashDoneProvider.notifier).done();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.15),
            radius: 0.9,
            colors: [Color(0xBF1B2A4A), LevaColors.ink1],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: CourtLines(opacity: 0.1)),
            Center(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: _shield.value,
                      child: Transform.translate(
                        offset: Offset(0, 8 * (1 - _shield.value)),
                        child: Transform.scale(
                          scale: .92 + .08 * _shield.value,
                          child: const LevaShield(size: 120),
                        ),
                      ),
                    ),
                    const SizedBox(height: LevaSpace.s5),
                    ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: _word.value,
                        child: GoldText('LEVA', style: LevaType.display(92)),
                      ),
                    ),
                    const SizedBox(height: LevaSpace.s3),
                    Opacity(
                      opacity: _tag.value,
                      child: Text(
                        'GENTE · PÁDEL · EXPERIENCIAS',
                        style: LevaType.support(
                          size: 12,
                          weight: 300,
                          tracking: 0.42 + 0.3 * (1 - _tag.value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 40,
              child: FadeTransition(
                opacity: _tag,
                child: Text(
                  'TALENTO | DISCIPLINA | FUTURO',
                  textAlign: TextAlign.center,
                  style: LevaType.support(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
