import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leva/app/providers.dart';
import 'package:leva/core/design_system/design_system.dart';
import 'package:leva/data/draw_repository.dart';
import 'package:leva/domain/draw/draw.dart';
import 'package:leva/domain/models/event.dart';
import 'package:leva/domain/scoring/scoring.dart';
import 'package:leva/features/admin/admin_results_screen.dart';
import 'package:leva/features/admin/judge_screen.dart';
import 'package:leva/features/draw/draw_view.dart';

final event = PadelEvent(
  id: 'ev',
  name: 'Mini Torneo LEVA',
  status: EventStatus.open,
  venueName: 'Arena LEVA',
  startDate: DateTime(2026, 11, 21),
  endDate: DateTime(2026, 11, 21),
  registrationDeadline: DateTime(2026, 11, 20),
  courts: const [],
);

StoredMatch match({String status = 'scheduled', Map<String, Object?>? live}) =>
    StoredMatch(
      id: 'cuarta_gA-1-0',
      categoryId: 'cuarta',
      stage: DrawStage.group,
      round: 1,
      order: 0,
      status: status,
      groupName: 'A',
      teamA: const MatchTeam(regId: 'r1', label: 'Ramírez / Lozano'),
      teamB: const MatchTeam(regId: 'r2', label: 'Ortiz / Navarro'),
      liveScore: live,
    );

/// Repositorio falso: guarda en memoria lo que mandaría a Firestore.
class FakeDrawRepository implements DrawRepository {
  final live = <MatchScore>[];

  @override
  Future<void> saveLiveScore({
    required String eventId,
    required String matchId,
    required MatchScore score,
    required String byUid,
  }) async => live.add(score);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget app(Widget child, {List overrides = const []}) => ProviderScope(
  overrides: [
    authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
    ...overrides,
  ],
  child: MaterialApp(
    theme: buildLevaTheme(),
    home: Scaffold(body: child),
  ),
);

LevaButton buttonNamed(WidgetTester t, String label) => t.widget<LevaButton>(
  find.byWidgetPredicate((w) => w is LevaButton && w.label == label),
);

Future<void> tapNth(WidgetTester t, String text, int n) async {
  final f = find.text(text).at(n);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  setUp(() {});

  testWidgets('mesa de control: 6-4 6-3 habilita guardar y dice quién gana', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      app(
        SingleChildScrollView(
          child: ResultEntrySheet(event: event, match: match()),
        ),
      ),
    );
    expect(buttonNamed(tester, 'Guardar resultado').onPressed, isNull);

    await tapNth(tester, '6', 0); // set 1, pareja 1
    await tapNth(tester, '4', 1); // set 1, pareja 2
    expect(find.text('SET 2'), findsOneWidget);
    await tapNth(tester, '6', 2); // set 2, pareja 1
    await tapNth(tester, '3', 3); // set 2, pareja 2

    expect(find.text('Gana Ramírez / Lozano'), findsOneWidget);
    expect(find.text('SÚPER TIE-BREAK'), findsNothing);
    expect(buttonNamed(tester, 'Guardar resultado').onPressed, isNotNull);
  });

  testWidgets('mesa de control: 1-1 pide el súper tie-break y valida', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      app(
        SingleChildScrollView(
          child: ResultEntrySheet(event: event, match: match()),
        ),
      ),
    );
    await tapNth(tester, '6', 0);
    await tapNth(tester, '4', 1);
    await tapNth(tester, '3', 2);
    await tapNth(tester, '6', 3);
    expect(find.text('SÚPER TIE-BREAK'), findsOneWidget);

    await tapNth(tester, '10', 0);
    await tapNth(tester, '9', 1); // 10-9: no vale (diferencia de 2)
    expect(buttonNamed(tester, 'Guardar resultado').onPressed, isNull);
    expect(find.textContaining('2 puntos de diferencia'), findsOneWidget);

    await tapNth(tester, '8', 1); // 10-8
    expect(find.text('Gana Ramírez / Lozano'), findsOneWidget);
    expect(buttonNamed(tester, 'Guardar resultado').onPressed, isNotNull);
  });

  testWidgets('cuadro: partidos del grupo con resultado, en vivo y W.O.', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final done = StoredMatch(
      id: 'm1',
      categoryId: 'cuarta',
      stage: DrawStage.group,
      round: 1,
      order: 0,
      status: 'final',
      groupName: 'A',
      teamA: const MatchTeam(regId: 'r1', label: 'Ramírez / Lozano'),
      teamB: const MatchTeam(regId: 'r2', label: 'Ortiz / Navarro'),
      sets: const [SetScore(6, 4), SetScore(6, 3)],
      winner: 'A',
    );
    final wo = StoredMatch(
      id: 'm2',
      categoryId: 'cuarta',
      stage: DrawStage.group,
      round: 2,
      order: 0,
      status: 'walkover',
      groupName: 'A',
      teamA: const MatchTeam(regId: 'r1', label: 'Ramírez / Lozano'),
      teamB: const MatchTeam(regId: 'r3', label: 'Herrera / Cárdenas'),
      winner: 'B',
    );
    final live = match(
      status: 'live',
      live: MatchScore.start(ScoringRules.leva).pointWonBy(Side.a).toJson(),
    );
    await tester.pumpWidget(app(GroupMatches(matches: [wo, done, live])));
    expect(find.text('6-4  6-3'), findsOneWidget);
    expect(find.text('W.O.'), findsOneWidget);
    expect(find.text('0-0'), findsOneWidget); // games del set en juego
    expect(find.text('FECHA 1'), findsOneWidget);
  });

  testWidgets('juez: elige saque, anota, deshace y cada punto se guarda', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final repo = FakeDrawRepository();
    await tester.pumpWidget(
      app(
        const JudgeScreen(eventId: 'ev', matchId: 'cuarta_gA-1-0'),
        overrides: [
          eventProvider.overrideWith((ref, id) => Stream.value(event)),
          matchProvider.overrideWith((ref, k) => Stream.value(match())),
          drawRepositoryProvider.overrideWithValue(repo),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SACA?'), findsOneWidget);

    await tester.tap(find.text('RAMÍREZ / LOZANO'));
    await tester.pumpAndSettle();
    expect(repo.live, hasLength(1));

    await tester.tap(find.text('+ PUNTO').first);
    await tester.pumpAndSettle();
    expect(repo.live.last.pointLabel(Side.a), '15');

    await tester.tap(find.text('DESHACER ÚLTIMO PUNTO'));
    await tester.pumpAndSettle();
    expect(repo.live.last.pointLabel(Side.a), '0');
    expect(tester.takeException(), isNull);
  });

  testWidgets('juez: retoma el marcador guardado al reabrir', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    var s = MatchScore.start(ScoringRules.leva);
    for (var i = 0; i < 3; i++) {
      s = s.pointWonBy(Side.b);
    }
    await tester.pumpWidget(
      app(
        const JudgeScreen(eventId: 'ev', matchId: 'cuarta_gA-1-0'),
        overrides: [
          eventProvider.overrideWith((ref, id) => Stream.value(event)),
          matchProvider.overrideWith(
            (ref, k) => Stream.value(match(status: 'live', live: s.toJson())),
          ),
          drawRepositoryProvider.overrideWithValue(FakeDrawRepository()),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SACA?'), findsNothing);
    expect(find.text('40'), findsOneWidget);
  });

  testWidgets('mesa de control: lista por cargar y terminados', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final semi = StoredMatch(
      id: 'cuarta_ko-1-0',
      categoryId: 'cuarta',
      stage: DrawStage.knockout,
      round: 1,
      order: 0,
      status: 'scheduled',
      teamA: const MatchTeam(label: '1º Grupo A'),
      teamB: const MatchTeam(label: '2º Grupo B'),
    );
    final done = StoredMatch(
      id: 'cuarta_gA-2-0',
      categoryId: 'cuarta',
      stage: DrawStage.group,
      round: 2,
      order: 0,
      status: 'final',
      groupName: 'A',
      teamA: const MatchTeam(regId: 'r1', label: 'Ramírez / Lozano'),
      teamB: const MatchTeam(regId: 'r3', label: 'Herrera / Cárdenas'),
      sets: const [SetScore(6, 2), SetScore(6, 1)],
      winner: 'A',
    );
    await tester.pumpWidget(
      app(
        const AdminResultsScreen(eventId: 'ev'),
        overrides: [
          eventProvider.overrideWith((ref, id) => Stream.value(event)),
          categoriesProvider.overrideWith(
            (ref, id) => Stream.value(const [
              EventCategory(
                id: 'cuarta',
                name: '4ta',
                capacity: 8,
                priceCents: 140000,
                drawStatus: 'published',
              ),
            ]),
          ),
          matchesProvider.overrideWith(
            (ref, k) => Stream.value([match(), semi, done]),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Por cargar · 1'), findsOneWidget);
    expect(find.text('Terminados · 1'), findsOneWidget);
    expect(find.text('GRUPO A · FECHA 1'), findsOneWidget);
    expect(find.textContaining('1 partido más espera'), findsOneWidget);

    await tester.tap(find.text('Terminados · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Herrera / Cárdenas'), findsOneWidget);

    await tester.tap(find.text('Herrera / Cárdenas'));
    await tester.pumpAndSettle();
    expect(find.text('RESULTADO FINAL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
