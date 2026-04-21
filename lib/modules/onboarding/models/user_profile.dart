import 'dart:convert';

/// Represents a user's baseline health profile and sleep goals.
class UserProfile {
  final String name;
  final int age;
  final String gender; // 'male', 'female', 'other'
  final double weightKg;
  final double heightCm;
  final String bedtime;   // "HH:mm" 24h format e.g. "22:30"
  final String wakeTime;  // "HH:mm" 24h format e.g. "06:30"
  final int goalDurationMinutes;
  final bool onboardingComplete;

  const UserProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.weightKg,
    required this.heightCm,
    required this.bedtime,
    required this.wakeTime,
    required this.goalDurationMinutes,
    this.onboardingComplete = false,
  });

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  UserProfile copyWith({
    String? name,
    int? age,
    String? gender,
    double? weightKg,
    double? heightCm,
    String? bedtime,
    String? wakeTime,
    int? goalDurationMinutes,
    bool? onboardingComplete,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      bedtime: bedtime ?? this.bedtime,
      wakeTime: wakeTime ?? this.wakeTime,
      goalDurationMinutes: goalDurationMinutes ?? this.goalDurationMinutes,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'age': age,
    'gender': gender,
    'weightKg': weightKg,
    'heightCm': heightCm,
    'bedtime': bedtime,
    'wakeTime': wakeTime,
    'goalDurationMinutes': goalDurationMinutes,
    'onboardingComplete': onboardingComplete,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String? ?? '',
    age: json['age'] as int? ?? 25,
    gender: json['gender'] as String? ?? 'other',
    weightKg: (json['weightKg'] as num?)?.toDouble() ?? 70,
    heightCm: (json['heightCm'] as num?)?.toDouble() ?? 170,
    bedtime: json['bedtime'] as String? ?? '22:30',
    wakeTime: json['wakeTime'] as String? ?? '06:30',
    goalDurationMinutes: json['goalDurationMinutes'] as int? ?? 480,
    onboardingComplete: json['onboardingComplete'] as bool? ?? false,
  );

  static UserProfile? fromJsonString(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return UserProfile.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  String toJsonString() => jsonEncode(toJson());
}
