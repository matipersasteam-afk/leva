/// Estado de sesión que decide a dónde puede ir el usuario. Dart puro.
enum SessionStatus {
  /// Todavía no sabemos si hay sesión (o el splash no terminó).
  loading,

  /// Sin sesión.
  signedOut,

  /// Con sesión pero sin perfil de jugador: debe completarlo.
  needsProfile,

  /// Con sesión y perfil.
  ready,
}

abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const loginEmail = '/login/correo';
  static const createProfile = '/perfil/crear';
  static const home = '/inicio';
  static const draw = '/cuadro';
  static const schedule = '/horarios';
  static const profile = '/perfil';
  static const editProfile = '/perfil/editar';
  static const showcase = '/muestra';
  static const admin = '/admin';
  static const adminNewEvent = '/admin/evento/nuevo';

  static String event(String id) => '/evento/$id';
  static String registerStart(String eventId, String categoryId) =>
      '/evento/$eventId/inscribirme/$categoryId';
  static String registration(String eventId, String regId) =>
      '/evento/$eventId/inscripcion/$regId';
  static String invite(String code) => '/i/$code';
  static String adminEvent(String id) => '/admin/evento/$id';
  static String adminRegistrations(String id) =>
      '/admin/evento/$id/inscripciones';
  static String adminDraw(String id) => '/admin/evento/$id/draw';
}

/// Links que se comparten fuera de la app (la web pública vive en Firebase Hosting).
abstract final class AppLinks {
  static const base = 'https://leva-padel-app.web.app';
  static String invite(String code) => '$base/#${Routes.invite(code)}';
}

/// Rutas de "puerta de entrada": no tiene sentido volver a ellas como destino.
bool _isGate(String path) =>
    path == Routes.splash ||
    path.startsWith(Routes.login) ||
    path == Routes.createProfile;

/// Devuelve la ruta a la que hay que redirigir, o null para quedarse.
///
/// [location] es la ruta actual con su query. Si alguien abre un enlace directo
/// (p. ej. una invitación) mientras la app arranca o sin sesión, el destino se
/// guarda en `?desde=` y se respeta al terminar el splash, el login o el alta.
String? redirectFor(SessionStatus status, String location) {
  final uri = Uri.parse(location);
  final path = uri.path.isEmpty ? Routes.splash : uri.path;
  final from = uri.queryParameters['desde'];
  // Destino pendiente: el guardado, o la ruta actual. Las puertas de entrada
  // (login, alta) solo se recuerdan mientras la app arranca.
  final rememberCurrent = status == SessionStatus.loading
      ? path != Routes.splash
      : !_isGate(path);
  final pending = from ?? (rememberCurrent ? location : null);

  String withFrom(String route) => pending == null
      ? route
      : Uri(path: route, queryParameters: {'desde': pending}).toString();

  switch (status) {
    case SessionStatus.loading:
      return path == Routes.splash ? null : withFrom(Routes.splash);

    case SessionStatus.signedOut:
      if (path.startsWith(Routes.login)) return null;
      // Un enlace directo a /login/... se respeta tal cual.
      if (from != null && Uri.parse(from).path.startsWith(Routes.login)) {
        return from;
      }
      return withFrom(Routes.login);

    case SessionStatus.needsProfile:
      return path == Routes.createProfile
          ? null
          : withFrom(Routes.createProfile);

    case SessionStatus.ready:
      if (!_isGate(path)) return null;
      if (from != null && !_isGate(Uri.parse(from).path)) return from;
      return Routes.home;
  }
}
