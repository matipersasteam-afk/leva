// Configuración pública de Firebase para leva-padel-app (equivalente a la que
// genera `flutterfire configure`). Estos valores identifican el proyecto; no son
// secretos. La protección real está en las reglas de seguridad y en App Check.
// ignore_for_file: lines_longer_than_80_chars
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError(
        'LEVA solo está configurada para Android, iOS y web.',
      ),
    };
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyDMoSAwaM_vDTI-QwiCRgiuHbVjEukRQQ0',
    appId: '1:453238712077:web:f63ef7b69eb98e539c3244',
    messagingSenderId: '453238712077',
    projectId: 'leva-padel-app',
    authDomain: 'leva-padel-app.firebaseapp.com',
    storageBucket: 'leva-padel-app.firebasestorage.app',
  );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyDZBgZOfNTWGYYGqHhltK3e5Jxc3-xsDSU',
    appId: '1:453238712077:android:03709b648ab6f8b29c3244',
    messagingSenderId: '453238712077',
    projectId: 'leva-padel-app',
    storageBucket: 'leva-padel-app.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyB2HrgHxGwGsX-yw66R_Dr_lv4dka3jbn0',
    appId: '1:453238712077:ios:63fa5a0fa33685ca9c3244',
    messagingSenderId: '453238712077',
    projectId: 'leva-padel-app',
    storageBucket: 'leva-padel-app.firebasestorage.app',
    iosBundleId: 'mx.leva.app',
  );
}
