import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  // Minimal placeholder options so the app can initialize in dev.
  // Replace with values from `flutterfire configure` for production.
  static FirebaseOptions get currentPlatform => const FirebaseOptions(
        apiKey: 'REPLACE_ME',
        appId: '1:000:android:000000000000000',
        messagingSenderId: '000000000000',
        projectId: 'your-project-id',
      );
}
