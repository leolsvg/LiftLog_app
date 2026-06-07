import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> signIn(String email, String password) async {
    try {
      final res = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return res.user;
    } catch (e) { return null; }
  }

  Future<User?> signUp(String email, String password) async {
    try {
      final res = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return res.user;
    } catch (e) { return null; }
  }
  Future<void> signOut() async {
    // Déconnexion Firebase
    await FirebaseAuth.instance.signOut();
    
    // Déconnexion Google (essentiel pour forcer la sélection de compte la prochaine fois)
    await GoogleSignIn().signOut();
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn(scopes: ['email']).signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return (await _auth.signInWithCredential(credential)).user;
    } catch (e) {
      throw StateError('Google sign-in failed: $e');
    }
  }

  Future<User?> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    );
    final oAuthCredential = OAuthProvider("apple.com").credential(
      idToken: credential.identityToken, accessToken: credential.authorizationCode,
    );
    return (await _auth.signInWithCredential(oAuthCredential)).user;
  }
}