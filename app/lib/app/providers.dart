import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../data/draw_repository.dart';
import '../data/event_repository.dart';
import '../data/registration_repository.dart';
import '../data/profile_repository.dart';
import '../domain/models/event.dart';
import '../domain/models/player_profile.dart';
import '../domain/models/registration.dart';
import 'session.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(FirebaseAuth.instance),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(FirebaseFirestore.instance),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// Perfil del usuario con sesión (null si no hay sesión o no creó su perfil).
final myProfileProvider = StreamProvider<PlayerProfile?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).watch(user.uid);
});

final myHistoryProvider = StreamProvider<List<HistoryEntry>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(profileRepositoryProvider).history(user.uid);
});

// ---------------- Eventos e inscripciones (M3) ----------------

final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => EventRepository(FirebaseFirestore.instance),
);

final registrationRepositoryProvider = Provider<RegistrationRepository>(
  (ref) => RegistrationRepository(FirebaseFirestore.instance),
);

final publicEventsProvider = StreamProvider<List<PadelEvent>>(
  (ref) => ref.watch(eventRepositoryProvider).watchPublic(),
);

final allEventsProvider = StreamProvider<List<PadelEvent>>(
  (ref) => ref.watch(eventRepositoryProvider).watchAll(),
);

final eventProvider = StreamProvider.family<PadelEvent?, String>(
  (ref, id) => ref.watch(eventRepositoryProvider).watch(id),
);

final categoriesProvider = StreamProvider.family<List<EventCategory>, String>(
  (ref, eventId) => ref.watch(eventRepositoryProvider).watchCategories(eventId),
);

/// Mis inscripciones en un evento (como capitán o como pareja).
final myRegistrationsProvider =
    StreamProvider.family<List<Registration>, String>((ref, eventId) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value(const []);
      return ref
          .watch(registrationRepositoryProvider)
          .watchMine(eventId, user.uid);
    });

final registrationProvider =
    StreamProvider.family<Registration?, ({String eventId, String regId})>(
      (ref, k) => ref
          .watch(registrationRepositoryProvider)
          .watchOne(k.eventId, k.regId),
    );

final allRegistrationsProvider =
    StreamProvider.family<List<Registration>, String>(
      (ref, eventId) =>
          ref.watch(registrationRepositoryProvider).watchAll(eventId),
    );

/// Invitaciones por usuario pendientes de aceptar.
final myInvitesProvider = StreamProvider<List<Invite>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(registrationRepositoryProvider).watchMyInvites(user.uid);
});

// ---------------- Draw (M4) ----------------

final drawRepositoryProvider = Provider<DrawRepository>(
  (ref) => DrawRepository(FirebaseFirestore.instance),
);

typedef CategoryKey = ({String eventId, String categoryId});

final matchesProvider = StreamProvider.family<List<StoredMatch>, CategoryKey>(
  (ref, k) =>
      ref.watch(drawRepositoryProvider).watchMatches(k.eventId, k.categoryId),
);

final groupsProvider = StreamProvider.family<List<StoredGroup>, CategoryKey>(
  (ref, k) =>
      ref.watch(drawRepositoryProvider).watchGroups(k.eventId, k.categoryId),
);

final isAdminProvider = Provider<bool>(
  (ref) => ref.watch(myRoleProvider).value == UserRole.admin,
);

final isStaffProvider = Provider<bool>((ref) {
  final role = ref.watch(myRoleProvider).value;
  return role == UserRole.admin || role == UserRole.staff;
});

final myRoleProvider = FutureProvider<UserRole>((ref) async {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).role();
});

/// El splash se muestra al menos hasta que termina su animación.
class SplashDone extends Notifier<bool> {
  @override
  bool build() => false;
  void done() => state = true;
}

final splashDoneProvider = NotifierProvider<SplashDone, bool>(SplashDone.new);

final sessionStatusProvider = Provider<SessionStatus>((ref) {
  final auth = ref.watch(authStateProvider);
  final splashDone = ref.watch(splashDoneProvider);
  if (!splashDone || auth.isLoading) return SessionStatus.loading;
  final user = auth.value;
  if (user == null) return SessionStatus.signedOut;
  final profile = ref.watch(myProfileProvider);
  if (profile.isLoading && !profile.hasValue) return SessionStatus.loading;
  return profile.value == null
      ? SessionStatus.needsProfile
      : SessionStatus.ready;
});
