import 'package:flutter/material.dart';

import 'leva_tokens.dart';
import 'leva_typography.dart';

/// Tema global. La app es siempre oscura: es la identidad de LEVA.
ThemeData buildLevaTheme() {
  const scheme = ColorScheme.dark(
    primary: LevaColors.gold500,
    onPrimary: LevaColors.ink1,
    secondary: LevaColors.navy,
    onSecondary: LevaColors.tx1,
    surface: LevaColors.ink1,
    onSurface: LevaColors.tx1,
    surfaceContainerHighest: LevaColors.ink3,
    error: LevaColors.danger,
    onError: LevaColors.tx1,
    outline: LevaColors.line2,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: LevaColors.ink1,
    fontFamily: LevaType.family,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: TextTheme(
      displayLarge: LevaType.mega,
      displayMedium: LevaType.xl,
      displaySmall: LevaType.l,
      headlineMedium: LevaType.m,
      bodyLarge: LevaType.body(),
      bodyMedium: LevaType.body(size: 14),
      bodySmall: LevaType.meta,
      labelLarge: LevaType.label,
      labelSmall: LevaType.support(),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: LevaColors.gold500,
      selectionColor: Color(0x66D4AF5A),
      selectionHandleColor: LevaColors.gold500,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: LevaColors.ink3,
      contentTextStyle: LevaType.body(size: 14, weight: 500),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LevaRadius.md),
        side: const BorderSide(color: LevaColors.goldLine),
      ),
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(
      color: LevaColors.line,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LevaColors.ink2,
      hintStyle: LevaType.body(color: LevaColors.tx3, size: 16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LevaRadius.sm),
        borderSide: const BorderSide(color: LevaColors.line2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LevaRadius.sm),
        borderSide: const BorderSide(color: LevaColors.gold500),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: LevaPageTransitionsBuilder(),
        TargetPlatform.iOS: LevaPageTransitionsBuilder(),
        TargetPlatform.windows: LevaPageTransitionsBuilder(),
      },
    ),
  );
}

/// Transición de pantalla: entra desde la derecha con curva de cajón iOS,
/// la anterior se desplaza 28 % y se oscurece. Igual en iOS y Android.
class LevaPageTransitionsBuilder extends PageTransitionsBuilder {
  const LevaPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    final enter = CurvedAnimation(
      parent: animation,
      curve: LevaMotion.drawer,
      reverseCurve: LevaMotion.drawer.flipped,
    );
    final under = CurvedAnimation(
      parent: secondaryAnimation,
      curve: LevaMotion.drawer,
    );
    return SlideTransition(
      position: Tween(
        begin: const Offset(-0.28, 0),
        end: Offset.zero,
      ).animate(ReverseAnimation(under)),
      child: SlideTransition(
        position: Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(enter),
        child: child,
      ),
    );
  }
}
