import 'package:flutter/painting.dart';

import 'leva_tokens.dart';

/// Tipografía LEVA, toda en Archivo variable.
/// - Display: ancho 62 %, peso 900, itálica, mayúsculas (nombres, títulos).
/// - Apoyo: ancho 125 %, fina, mayúsculas con tracking amplio.
/// - Cuerpo: ancho 100 %.
abstract final class LevaType {
  static const family = 'Archivo';

  static List<FontVariation> _axes(double width, double weight) => [
    FontVariation('wdth', width),
    FontVariation('wght', weight),
  ];

  static FontWeight _w(double weight) =>
      FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)];

  /// Display condensada, extra bold, itálica. Usar con texto en MAYÚSCULAS.
  static TextStyle display(
    double size, {
    Color color = LevaColors.tx1,
    double weight = 900,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    fontStyle: FontStyle.italic,
    fontWeight: _w(weight),
    fontVariations: _axes(62, weight),
    height: 0.92,
    letterSpacing: -0.005 * size,
    color: color,
  );

  /// Línea de apoyo: ancha, con tracking de 0.3 em. Usar con texto en MAYÚSCULAS.
  static TextStyle support({
    double size = 11,
    Color color = LevaColors.tx2,
    double weight = 400,
    double tracking = 0.3,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: _w(weight),
    fontVariations: _axes(125, weight),
    letterSpacing: tracking * size,
    height: 1.3,
    color: color,
  );

  static TextStyle body({
    double size = 15,
    Color color = LevaColors.tx1,
    double weight = 400,
    double height = 1.45,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: _w(weight),
    fontVariations: _axes(100, weight),
    height: height,
    color: color,
  );

  /// Números de marcador, horas y montos: cifras tabulares.
  static TextStyle numbers(double size, {Color color = LevaColors.tx1}) =>
      display(
        size,
        color: color,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  // Escala con nombre
  static TextStyle get mega => display(76);
  static TextStyle get xl => display(52);
  static TextStyle get l => display(34);
  static TextStyle get m => display(24);
  static TextStyle get button => display(21);
  static TextStyle get buttonSmall => display(16);
  static TextStyle get label =>
      body(size: 13, weight: 600, color: LevaColors.tx2);
  static TextStyle get meta => body(size: 13, color: LevaColors.tx3);
  static TextStyle get tag =>
      body(size: 11, weight: 600).copyWith(letterSpacing: 0.66);
}
