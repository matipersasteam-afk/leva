import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_draw_screen.dart';
import '../features/admin/admin_event_editor_screen.dart';
import '../features/admin/admin_events_screen.dart';
import '../features/admin/admin_registrations_screen.dart';
import '../features/auth/email_auth_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/draw/draw_tab.dart';
import '../features/events/event_detail_screen.dart';
import '../features/home/home_shell.dart';
import '../features/home/home_tab.dart';
import '../features/home/placeholder_tabs.dart';
import '../features/profile/profile_form_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/registration/invite_screen.dart';
import '../features/registration/register_start_screen.dart';
import '../features/registration/registration_screen.dart';
import '../features/showcase/showcase_screen.dart';
import 'providers.dart';
import 'session.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-evalúa la redirección cada vez que cambia la sesión.
  final refresh = _RouterRefresh();
  ref.listen(sessionStatusProvider, (_, _) => refresh.ping());
  // El rol llega después del token: re-evalúa las rutas de admin al conocerlo.
  ref.listen(myRoleProvider, (_, _) => refresh.ping());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      if (kDebugMode && state.matchedLocation == Routes.showcase) return null;
      final to = redirectFor(
        ref.read(sessionStatusProvider),
        state.uri.toString(),
      );
      if (to != null) return to;
      // Panel de LEVA: solo admin.
      if (state.matchedLocation.startsWith(Routes.admin) &&
          !ref.read(isAdminProvider)) {
        return Routes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: Routes.login,
        pageBuilder: (_, _) => const NoTransitionPage(child: LoginScreen()),
        routes: [
          GoRoute(path: 'correo', builder: (_, _) => const EmailAuthScreen()),
        ],
      ),
      GoRoute(
        path: Routes.createProfile,
        builder: (_, _) => const ProfileFormScreen(),
      ),
      GoRoute(
        path: Routes.editProfile,
        builder: (_, _) => const ProfileFormScreen(editing: true),
      ),
      GoRoute(
        path: '/evento/:id',
        builder: (_, s) => EventDetailScreen(eventId: s.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'inscribirme/:cat',
            builder: (_, s) => RegisterStartScreen(
              eventId: s.pathParameters['id']!,
              categoryId: s.pathParameters['cat']!,
            ),
          ),
          GoRoute(
            path: 'inscripcion/:reg',
            builder: (_, s) => RegistrationScreen(
              eventId: s.pathParameters['id']!,
              regId: s.pathParameters['reg']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/i/:code',
        builder: (_, s) =>
            InviteScreen(code: s.pathParameters['code']!.toUpperCase()),
      ),
      GoRoute(
        path: Routes.admin,
        builder: (_, _) => const AdminEventsScreen(),
        routes: [
          GoRoute(
            path: 'evento/nuevo',
            builder: (_, _) => const AdminEventEditorScreen(),
          ),
          GoRoute(
            path: 'evento/:id',
            builder: (_, s) =>
                AdminEventEditorScreen(eventId: s.pathParameters['id']),
            routes: [
              GoRoute(
                path: 'draw',
                builder: (_, s) =>
                    AdminDrawScreen(eventId: s.pathParameters['id']!),
              ),
              GoRoute(
                path: 'inscripciones',
                builder: (_, s) =>
                    AdminRegistrationsScreen(eventId: s.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),
      if (kDebugMode)
        GoRoute(
          path: Routes.showcase,
          builder: (_, _) => const ShowcaseScreen(),
        ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.home, builder: (_, _) => const HomeTab()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.draw, builder: (_, _) => const DrawTab()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.schedule,
                builder: (_, _) => const ScheduleTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Avisa a GoRouter que vuelva a evaluar la redirección.
class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}
