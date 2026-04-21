import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../modules/onboarding/models/user_profile.dart';
import '../../modules/journal/models/journal_entry.dart';
import '../../modules/sleep_analysis/models/sleep_report.dart';

/// Central Firestore service for all SnoreClinics AI cloud data operations.
/// Uses a device-level UID (no login required) scoped under /users/{uid}/.
class FirestoreService {
  static const _uidKey = 'device_uid';
  static final _db = FirebaseFirestore.instance;

  static String? _cachedUid;

  /// Returns the current active UID. 
  /// Prioritizes authenticated user ID, falls back to device-level ID.
  static Future<String> get uid async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) return authUser.uid;
    
    if (_cachedUid != null) return _cachedUid!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_uidKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_uidKey, id);
    }
    _cachedUid = id;
    return id;
  }

  /// Returns only the local device-level UID, regardless of auth state.
  static Future<String> get deviceUid async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_uidKey) ?? await uid;
  }

  // ─── Collection References ────────────────────────────────────────────────

  static Future<DocumentReference<Map<String, dynamic>>> _userDoc() async {
    return _db.collection('users').doc(await uid);
  }

  static Future<CollectionReference<Map<String, dynamic>>>
      _sleepReportsCol() async {
    return (await _userDoc()).collection('sleep_reports');
  }

  static Future<CollectionReference<Map<String, dynamic>>>
      _journalCol() async {
    return (await _userDoc()).collection('journal_entries');
  }

  // ─── User Profile ─────────────────────────────────────────────────────────

  /// Saves or updates the user profile document.
  static Future<void> saveProfile(UserProfile profile) async {
    try {
      final doc = await _userDoc();
      await doc.set({
        ...profile.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Firestore] saveProfile error: $e');
    }
  }

  /// Loads the user profile from Firestore. Returns null if not found.
  static Future<UserProfile?> getProfile() async {
    try {
      final doc = await _userDoc();
      final snap = await doc.get();
      if (!snap.exists || snap.data() == null) return null;
      return UserProfile.fromJson(snap.data()!);
    } catch (e) {
      debugPrint('[Firestore] getProfile error: $e');
      return null;
    }
  }

  // ─── Sleep Reports ────────────────────────────────────────────────────────

  /// Saves a sleep report to Firestore. Uses recordedAt timestamp as document ID.
  static Future<void> saveReport(SleepReport report) async {
    try {
      final col = await _sleepReportsCol();
      final docId = report.recordedAt.millisecondsSinceEpoch.toString();

      // Limit amplitudeTimeline to 300 points to stay under Firestore 1 MB doc limit
      final timelinePoints = report.amplitudeTimeline.length > 300
          ? report.amplitudeTimeline
              .sublist(0, 300)
              .map((s) => {
                    'timeSeconds': s.timeSeconds,
                    'amplitude': s.amplitude,
                    'isSnoring': s.isSnoring,
                  })
              .toList()
          : report.amplitudeTimeline
              .map((s) => {
                    'timeSeconds': s.timeSeconds,
                    'amplitude': s.amplitude,
                    'isSnoring': s.isSnoring,
                  })
              .toList();

      await col.doc(docId).set({
        'fileName': report.fileName,
        'recordedAt': Timestamp.fromDate(report.recordedAt),
        'totalDurationMs': report.totalDuration.inMilliseconds,
        'snoringDurationMs': report.snoringDuration.inMilliseconds,
        'snoringEventCount': report.snoringEventCount,
        'qualityScore': report.qualityScore,
        'quality': report.quality.name,
        'snoringEvents': report.snoringEvents
            .map((e) => {
                  'timestampMs': e.timestamp.inMilliseconds,
                  'amplitude': e.amplitude,
                  'durationMs': e.duration.inMilliseconds,
                })
            .toList(),
        'amplitudeTimeline': timelinePoints,
        'insights': report.insights
            .map((i) => {
                  'title': i.title,
                  'description': i.description,
                  'emoji': i.emoji,
                })
            .toList(),
        'sleepDebtHours': report.sleepDebtHours,
        'lightSleepPercent': report.lightSleepPercent,
        'deepSleepPercent': report.deepSleepPercent,
        'remSleepPercent': report.remSleepPercent,
        'apneaRiskLevel': report.apneaRiskLevel,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[Firestore] saveReport error: $e');
    }
  }

  /// Saves AI analysis results onto an existing sleep report document.
  static Future<void> saveAiAnalysis({
    required DateTime reportedAt,
    required int aiScore,
    required String aiRecommendation,
    required List<String> aiLifestyleFactors,
  }) async {
    try {
      final col = await _sleepReportsCol();
      final docId = reportedAt.millisecondsSinceEpoch.toString();
      await col.doc(docId).update({
        'aiScore': aiScore,
        'aiRecommendation': aiRecommendation,
        'aiLifestyleFactors': aiLifestyleFactors,
      });
    } catch (e) {
      debugPrint('[Firestore] saveAiAnalysis error: $e');
    }
  }

  /// Returns all sleep reports, sorted by date (newest first).
  static Future<List<SleepReport>> getAllReports() async {
    try {
      final col = await _sleepReportsCol();
      final snap = await col
          .orderBy('recordedAt', descending: true)
          .limit(50)
          .get();
      return snap.docs.map((d) => _mapToReport(d.data())).toList();
    } catch (e) {
      debugPrint('[Firestore] getAllReports error: $e');
      return [];
    }
  }

  /// Deletes a single sleep report by timestamp.
  static Future<void> deleteReport(DateTime recordedAt) async {
    try {
      final col = await _sleepReportsCol();
      await col.doc(recordedAt.millisecondsSinceEpoch.toString()).delete();
    } catch (e) {
      debugPrint('[Firestore] deleteReport error: $e');
    }
  }

  // ─── Journal Entries ──────────────────────────────────────────────────────

  /// Saves a new journal entry.
  static Future<void> saveJournalEntry(JournalEntry entry) async {
    try {
      final col = await _journalCol();
      await col.doc(entry.id).set({
        ...entry.toJson(),
        'date': Timestamp.fromDate(entry.date),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[Firestore] saveJournalEntry error: $e');
    }
  }

  /// Returns all journal entries, sorted newest first.
  static Future<List<JournalEntry>> getJournalEntries() async {
    try {
      final col = await _journalCol();
      final snap = await col
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      return snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        // Convert Firestore Timestamp → ISO string for fromJson
        if (data['date'] is Timestamp) {
          data['date'] = (data['date'] as Timestamp).toDate().toIso8601String();
        }
        return JournalEntry.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('[Firestore] getJournalEntries error: $e');
      return [];
    }
  }

  /// Deletes a journal entry by its ID.
  static Future<void> deleteJournalEntry(String id) async {
    try {
      final col = await _journalCol();
      await col.doc(id).delete();
    } catch (e) {
      debugPrint('[Firestore] deleteJournalEntry error: $e');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static SleepReport _mapToReport(Map<String, dynamic> data) {
    final recordedAt = data['recordedAt'] is Timestamp
        ? (data['recordedAt'] as Timestamp).toDate()
        : DateTime.parse(data['recordedAt'] as String);

    return SleepReport(
      fileName: data['fileName'] as String? ?? '',
      recordedAt: recordedAt,
      totalDuration: Duration(milliseconds: (data['totalDurationMs'] as num).toInt()),
      snoringDuration: Duration(milliseconds: (data['snoringDurationMs'] as num).toInt()),
      snoringEventCount: (data['snoringEventCount'] as num).toInt(),
      qualityScore: (data['qualityScore'] as num).toDouble(),
      quality: SleepQuality.values.firstWhere(
        (q) => q.name == data['quality'],
        orElse: () => SleepQuality.good,
      ),
      snoringEvents: ((data['snoringEvents'] as List?) ?? [])
          .map((e) => SnoringEvent(
                timestamp: Duration(milliseconds: (e['timestampMs'] as num).toInt()),
                amplitude: (e['amplitude'] as num).toDouble(),
                duration: Duration(milliseconds: (e['durationMs'] as num).toInt()),
              ))
          .toList(),
      amplitudeTimeline: ((data['amplitudeTimeline'] as List?) ?? [])
          .map((s) => AmplitudeSample(
                timeSeconds: (s['timeSeconds'] as num).toDouble(),
                amplitude: (s['amplitude'] as num).toDouble(),
                isSnoring: s['isSnoring'] as bool? ?? false,
              ))
          .toList(),
      insights: ((data['insights'] as List?) ?? [])
          .map((i) => SleepInsight(
                title: i['title'] as String? ?? '',
                description: i['description'] as String? ?? '',
                emoji: i['emoji'] as String? ?? '💤',
              ))
          .toList(),
      sleepDebtHours: (data['sleepDebtHours'] as num?)?.toDouble() ?? 0.0,
      lightSleepPercent: (data['lightSleepPercent'] as num?)?.toDouble() ?? 0.50,
      deepSleepPercent: (data['deepSleepPercent'] as num?)?.toDouble() ?? 0.25,
      remSleepPercent: (data['remSleepPercent'] as num?)?.toDouble() ?? 0.25,
      apneaRiskLevel: data['apneaRiskLevel'] as String? ?? 'Low',
    );
  }
  /// Migrates all data from a guest UID to an authenticated UID.
  static Future<void> migrateGuestData(String guestUid, String authUid) async {
    try {
      final guestDoc = _db.collection('users').doc(guestUid);
      final authDoc = _db.collection('users').doc(authUid);

      // 1. Migrate Profile
      final profileSnap = await guestDoc.get();
      if (profileSnap.exists && profileSnap.data() != null) {
        await authDoc.set(profileSnap.data()!, SetOptions(merge: true));
      }

      // 2. Migrate Sleep Reports
      final reportsSnap = await guestDoc.collection('sleep_reports').get();
      for (var doc in reportsSnap.docs) {
        await authDoc.collection('sleep_reports').doc(doc.id).set(doc.data());
      }

      // 3. Migrate Journal Entries
      final journalSnap = await guestDoc.collection('journal_entries').get();
      for (var doc in journalSnap.docs) {
        await authDoc.collection('journal_entries').doc(doc.id).set(doc.data());
      }

      debugPrint('[Firestore] Migration from $guestUid to $authUid complete.');
    } catch (e) {
      debugPrint('[Firestore] Migration error: $e');
    }
  }
}
