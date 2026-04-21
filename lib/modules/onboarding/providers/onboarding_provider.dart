import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../../../core/services/firestore_service.dart';

class OnboardingProvider extends ChangeNotifier {
  UserProfile _profile = const UserProfile(
    name: '',
    age: 25,
    gender: 'other',
    weightKg: 70,
    heightCm: 170,
    bedtime: '22:30',
    wakeTime: '06:30',
    goalDurationMinutes: 480,
    onboardingComplete: false,
  );

  UserProfile get profile => _profile;
  bool get isComplete => _profile.onboardingComplete;

  Future<void> loadProfile() async {
    final loaded = await FirestoreService.getProfile();
    if (loaded != null) {
      _profile = loaded;
      notifyListeners();
    }
  }

  void updateName(String v) {
    _profile = _profile.copyWith(name: v);
    notifyListeners();
  }

  void updateAge(int v) {
    _profile = _profile.copyWith(age: v);
    notifyListeners();
  }

  void updateGender(String v) {
    _profile = _profile.copyWith(gender: v);
    notifyListeners();
  }

  void updateWeight(double v) {
    _profile = _profile.copyWith(weightKg: v);
    notifyListeners();
  }

  void updateHeight(double v) {
    _profile = _profile.copyWith(heightCm: v);
    notifyListeners();
  }

  void updateBedtime(String v) {
    _profile = _profile.copyWith(bedtime: v);
    notifyListeners();
  }

  void updateWakeTime(String v) {
    _profile = _profile.copyWith(wakeTime: v);
    notifyListeners();
  }

  void updateGoalDuration(int minutes) {
    _profile = _profile.copyWith(goalDurationMinutes: minutes);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _profile = _profile.copyWith(onboardingComplete: true);
    FirestoreService.saveProfile(_profile); // deliberately not awaited to avoid blocking navigation
    notifyListeners();
  }

  Future<void> saveProfile() async {
    await FirestoreService.saveProfile(_profile);
    notifyListeners();
  }

  Future<void> clearProfile() async {
    _profile = const UserProfile(
      name: '', age: 25, gender: 'other',
      weightKg: 70, heightCm: 170,
      bedtime: '22:30', wakeTime: '06:30',
      goalDurationMinutes: 480, onboardingComplete: false,
    );
    // Merge false into Firestore so onboardingComplete resets
    await FirestoreService.saveProfile(_profile);
    notifyListeners();
  }

  /// Reset to initial state (used during logout).
  void reset() {
    _profile = const UserProfile(
      name: '', age: 25, gender: 'other',
      weightKg: 70, heightCm: 170,
      bedtime: '22:30', wakeTime: '06:30',
      goalDurationMinutes: 480, onboardingComplete: false,
    );
    notifyListeners();
  }
}
