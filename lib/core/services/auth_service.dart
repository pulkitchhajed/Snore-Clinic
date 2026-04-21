import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

/// Service to handle Firebase Authentication operations.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Stream of user state changes.
  Stream<User?> get userChanges => _auth.userChanges();

  /// Currently logged in user.
  User? get currentUser => _auth.currentUser;

  /// Returns true if the current user is logged in with a permanent account.
  bool get isAuthenticated => currentUser != null && !currentUser!.isAnonymous;

  /// Guest sign in (Anonymous).
  Future<User?> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      return credential.user;
    } catch (e) {
      debugPrint('AuthService: Anonymous Sign-in Error: $e');
      return null;
    }
  }

  /// Google Sign In.
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // If user is already an anonymous guest, we should link the accounts.
      if (currentUser != null && currentUser!.isAnonymous) {
        final result = await currentUser!.linkWithCredential(credential);
        return result.user;
      }

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      debugPrint('AuthService: Google Sign-in Error: $e');
      return null;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('AuthService: Sign-out Error: $e');
    }
  }
}
