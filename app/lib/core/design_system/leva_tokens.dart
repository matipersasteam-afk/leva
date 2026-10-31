// Tokens de marca LEVA: única fuente de verdad del look.
// Traducidos 1:1 de prototipo/leva-app.html (:root) y DESIGN.md.
// Valores aproximados: reemplazar aquí cuando LEVA entregue los oficiales.
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Paleta.
abstract final class LevaColors {
  // Fondo
  static const ink0 = Color(0xFF06080D);
  static const ink1 = Color(0xFF0A0D14);
  static const ink2 = Color(0xFF0E1626);
  static const ink3 = Color(0xFF132037);
  static const navy = Color(0xFF1B2A4A);
  static const navyHi = Color(0xFF24375F);

  // Oro metálico (usar siempre como degradé, nunca plano en superficies)
  static const gold700 = Color(0xFF8C6A2E);
  static const gold500 = Color(0xFFD4AF5A);
  static const gold200 = Color(0xFFF3DC9A);
  static const goldLine = Color(0x47D4AF5A); // 28 %
  static const goldWash = Color(0x14D4AF5A); // 8 %

  // Texto
  static const tx1 = Color(0xFFF6F4EF);
  static const tx2 = Color(0xFFBAC1CF);
  static const tx3 = Color(0xFF97A0B2);

  // Líneas
  static const line = Color(0x14FFFFFF); // 8 %
  static const line2 = Color(0x24FFFFFF); // 14 %

  // Estados
  static const live = Color(0xFFF0484F);
  static const ok = Color(0xFF43C08F);
  static const pending = Color(0xFFF09A4A);
  static const danger = live;
}

/// Degradés dorados.
abstract final class LevaGradients {
  /// Horizontal (100° en CSS): textos, botones, chips activos.
  static const gold = LinearGradient(
    begin: Alignment(-1, -0.18),
    end: Alignment(1, 0.18),
    colors: [
      Color(0xFF8C6A2E),
      Color(0xFFB88F42),
      Color(0xFFD4AF5A),
      Color(0xFFF3DC9A),
      Color(0xFFD4AF5A),
      Color(0xFFA07B36),
      Color(0xFF8C6A2E),
    ],
    stops: [0, .22, .40, .52, .64, .84, 1],
  );

  /// Vertical: el corte dorado del duelo y barras.
  static const goldVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [LevaColors.gold200, LevaColors.gold500, LevaColors.gold700],
    stops: [0, .45, 1],
  );

  static const panel = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [LevaColors.ink3, LevaColors.ink2],
  );

  static const navyCard = LinearGradient(
    begin: Alignment(-0.6, -1),
    end: Alignment(0.6, 1),
    colors: [LevaColors.navy, LevaColors.ink2],
    stops: [0, .7],
  );
}

/// Espaciado (base 4).
abstract final class LevaSpace {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s10 = 40.0;
  static const s12 = 48.0;

  /// Margen lateral de pantalla.
  static const gutter = s5;
}

/// Radios: anguloso, de afiche.
abstract final class LevaRadius {
  static const xs = 4.0;
  static const sm = 6.0;
  static const md = 10.0;
  static const lg = 16.0;

  /// Corte en esquinas superior-derecha e inferior-izquierda.
  static const chamfer = 12.0;
  static const chamferSmall = 10.0;
}

/// Sombras: neutras y con offset (nunca halos de color).
abstract final class LevaShadows {
  static const s1 = [
    BoxShadow(
      color: Color(0xB3000000),
      offset: Offset(0, 10),
      blurRadius: 28,
      spreadRadius: -14,
    ),
  ];
  static const s2 = [
    BoxShadow(
      color: Color(0xD9000000),
      offset: Offset(0, 22),
      blurRadius: 48,
      spreadRadius: -20,
    ),
  ];
  static const slash = [
    BoxShadow(
      color: Color(0xB3000000),
      offset: Offset(6, 10),
      blurRadius: 18,
      spreadRadius: -8,
    ),
  ];
}

/// Movimiento (skill de Emil Kowalski): curvas fuertes, UI por debajo de 300 ms.
abstract final class LevaMotion {
  /// Entradas, salidas y feedback.
  static const easeOut = Cubic(0.23, 1, 0.32, 1);

  /// Movimiento en pantalla (indicadores, intercambios).
  static const easeInOut = Cubic(0.77, 0, 0.175, 1);

  /// Pantallas y cajones estilo iOS.
  static const drawer = Cubic(0.32, 0.72, 0, 1);

  static const press = Duration(milliseconds: 140);
  static const fast = Duration(milliseconds: 180);
  static const base = Duration(milliseconds: 240);
  static const indicator = Duration(milliseconds: 220);
  static const screen = Duration(milliseconds: 400);
  static const hero = Duration(milliseconds: 700);

  /// Escala al presionar cualquier control.
  static const pressScale = 0.97;

  /// Separación entre elementos que entran escalonados.
  static const stagger = Duration(milliseconds: 45);
}
