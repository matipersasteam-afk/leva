import 'package:flutter_test/flutter_test.dart';
import 'package:leva/app/session.dart';

String withFrom(String route, String from) =>
    Uri(path: route, queryParameters: {'desde': from}).toString();

void main() {
  group('redirectFor', () {
    test('mientras carga, todo va al splash recordando el destino', () {
      expect(
        redirectFor(SessionStatus.loading, Routes.home),
        withFrom(Routes.splash, Routes.home),
      );
      expect(redirectFor(SessionStatus.loading, Routes.splash), isNull);
      expect(
        redirectFor(SessionStatus.loading, Routes.login),
        withFrom(Routes.splash, Routes.login),
      );
    });

    test('sin sesión solo se puede estar en login', () {
      expect(redirectFor(SessionStatus.signedOut, Routes.splash), Routes.login);
      expect(
        redirectFor(SessionStatus.signedOut, Routes.profile),
        withFrom(Routes.login, Routes.profile),
      );
      expect(redirectFor(SessionStatus.signedOut, Routes.login), isNull);
      expect(redirectFor(SessionStatus.signedOut, Routes.loginEmail), isNull);
    });

    test('con sesión y sin perfil, siempre a crear perfil', () {
      expect(
        redirectFor(SessionStatus.needsProfile, Routes.login),
        Routes.createProfile,
      );
      expect(
        redirectFor(SessionStatus.needsProfile, Routes.createProfile),
        isNull,
      );
    });

    test('listo: sale de splash/login/alta hacia inicio y deja navegar', () {
      expect(redirectFor(SessionStatus.ready, Routes.splash), Routes.home);
      expect(redirectFor(SessionStatus.ready, Routes.loginEmail), Routes.home);
      expect(
        redirectFor(SessionStatus.ready, Routes.createProfile),
        Routes.home,
      );
      expect(redirectFor(SessionStatus.ready, Routes.profile), isNull);
      expect(redirectFor(SessionStatus.ready, Routes.editProfile), isNull);
    });

    test('un enlace directo sobrevive al splash, al login y al alta', () {
      const invite = '/i/ABC123';
      // 1. La app arranca con el enlace: va al splash recordándolo.
      final s1 = redirectFor(SessionStatus.loading, invite)!;
      expect(s1, withFrom(Routes.splash, invite));
      // 2. Sin sesión: al login, sigue recordándolo.
      final s2 = redirectFor(SessionStatus.signedOut, s1)!;
      expect(s2, withFrom(Routes.login, invite));
      // 3. Inicia sesión pero no tiene perfil: al alta, lo sigue recordando.
      final s3 = redirectFor(SessionStatus.needsProfile, s2)!;
      expect(s3, withFrom(Routes.createProfile, invite));
      // 4. Completa el perfil: llega a la invitación.
      expect(redirectFor(SessionStatus.ready, s3), invite);
    });

    test('un enlace directo a login/correo se respeta tras el splash', () {
      final s1 = redirectFor(SessionStatus.loading, Routes.loginEmail)!;
      expect(s1, withFrom(Routes.splash, Routes.loginEmail));
      expect(redirectFor(SessionStatus.signedOut, s1), Routes.loginEmail);
    });
  });
}
