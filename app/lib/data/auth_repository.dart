import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Rol del usuario: viene del custom claim `role` (lo asigna una Function de admin).
enum UserRole { player, staff, admin }

/// Error de autenticación ya traducido para mostrar.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Envuelve FirebaseAuth. Google y Apple usan los proveedores nativos de
/// firebase_auth (popup en web, flujo del sistema en el celular).
class AuthRepository {
  AuthRepository(this._auth);
  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signInWithEmail(String email, String password) => _guard(
    () => _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  Future<void> registerWithEmail(String email, String password) => _guard(
    () => _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  Future<void> signInWithGoogle() => _guard(() {
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    return kIsWeb
        ? _auth.signInWithPopup(provider)
        : _auth.signInWithProvider(provider);
  });

  Future<void> signInWithApple() => _guard(() {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    return kIsWeb
        ? _auth.signInWithPopup(provider)
        : _auth.signInWithProvider(provider);
  });

  Future<void> signOut() => _auth.signOut();

  Future<UserRole> role() async {
    final user = _auth.currentUser;
    if (user == null) return UserRole.player;
    final token = await user.getIdTokenResult();
    return switch (token.claims?['role']) {
      'admin' => UserRole.admin,
      'staff' => UserRole.staff,
      _ => UserRole.player,
    };
  }

  Future<void> _guard(Future<Object?> Function() run) async {
    try {
      await run();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(authMessage(e.code));
    }
  }
}

/// Mensajes de error de Firebase Auth en es-MX.
String authMessage(String code) => switch (code) {
  'invalid-email' => 'Ese correo no es válido.',
  'user-disabled' => 'Esta cuenta está desactivada. Escríbele a LEVA.',
  'user-not-found' ||
  'wrong-password' ||
  'invalid-credential' => 'Correo o contraseña incorrectos.',
  'email-already-in-use' =>
    'Ya existe una cuenta con ese correo. Inicia sesión.',
  'weak-password' => 'La contraseña debe tener al menos 6 caracteres.',
  'too-many-requests' =>
    'Demasiados intentos. Espera un momento y vuelve a probar.',
  'network-request-failed' => 'Sin conexión. Revisa tu internet.',
  'popup-closed-by-user' ||
  'cancelled-popup-request' ||
  'web-context-canceled' ||
  'canceled' => 'Se canceló el inicio de sesión.',
  'operation-not-allowed' => 'Este método de acceso todavía no está activado.',
  'account-exists-with-different-credential' =>
    'Ya tienes cuenta con otro método (por ejemplo, Google). Entra con ese.',
  _ => 'No pudimos iniciar sesión. Intenta de nuevo.',
};
