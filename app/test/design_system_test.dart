import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leva/core/design_system/design_system.dart';
import 'package:leva/features/showcase/showcase_screen.dart';

void main() {
  testWidgets('la muestra de componentes se construye sin errores', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(theme: buildLevaTheme(), home: const ShowcaseScreen()),
    );
    expect(find.text('LEVA'), findsOneWidget);
    expect(find.byType(LevaTabBar), findsOneWidget);
  });

  testWidgets('un botón sin acción queda deshabilitado y no responde', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLevaTheme(),
        home: Scaffold(
          body: Column(
            children: [
              const LevaButton(label: 'Deshabilitado'),
              LevaButton(label: 'Activo', onPressed: () => taps++),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('DESHABILITADO'));
    await tester.tap(find.text('ACTIVO'));
    expect(taps, 1);
  });

  testWidgets('el control segmentado reporta el índice tocado', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LevaSegmented(
            options: const ['Grupos', 'Eliminatoria'],
            index: 0,
            onChanged: (i) => selected = i,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Eliminatoria'));
    expect(selected, 1);
  });

  test('el degradé dorado nunca es un solo color plano', () {
    expect(LevaGradients.gold.colors.toSet().length, greaterThan(2));
    expect(LevaGradients.gold.colors.first, LevaColors.gold700);
  });
}
