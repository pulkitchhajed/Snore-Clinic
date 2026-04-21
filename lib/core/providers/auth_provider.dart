import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Provider to manage Authentication state across the app.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;

  AuthProvider() {
    // Listen to auth changes on initialization.
    _authService.userChanges.listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null && !_user!.isAnonymous;
  String? get uid => _user?.uid;

  /// Guest Login.
  Future<void> signInAnonymously() async {
    _setLoading(true);
    final guestUid = await FirestoreService.deviceUid;
    final user = await _authService.signInAnonymously();
    
    // Migrate data from old system device ID to the new anonymous UID
    if (user != null && guestUid != user.uid) {
      await FirestoreService.migrateGuestData(guestUid, user.uid);
    }
    
    _setLoading(false);
  }

  /// Google Login.
  Future<void> signInWithGoogle() async {
    _setLoading(true);
    final guestUid = await FirestoreService.deviceUid;
    final user = await _authService.signInWithGoogle();
    
    // Migrate data if we transition from guest to a permanent UID
    if (user != null && guestUid != user.uid) {
      await FirestoreService.migrateGuestData(guestUid, user.uid);
    }
    
    _setLoading(false);
  }

  /// Sign out.
  Future<void> signOut() async {
    _setLoading(true);
    await _authService.signOut();
    _setLoading(false);
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }
}
