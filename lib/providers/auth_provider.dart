import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Reactive stream of the current Firebase auth state.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Auth service for sign-in / sign-out operations.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Web OAuth client ID from google-services.json (client_type: 3).
// Required by google_sign_in v7.x on Android.
const _kWebClientId =
    '6549990351-6g8j10shnlm983gv15iv5tp874lu9nf7.apps.googleusercontent.com';

/// Call once at app startup after Firebase.initializeApp().
Future<void> initGoogleSignIn() async {
  await GoogleSignIn.instance.initialize(serverClientId: _kWebClientId);
}

class AuthService {
  final _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await GoogleSignIn.instance.authenticate();
    final idToken = googleUser.authentication.idToken;

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      GoogleSignIn.instance.signOut(),
    ]);
  }
}
