import 'package:flutter/foundation.dart';
import '../models/sleep_report.dart';
import '../../../core/services/firestore_service.dart';

/// Handles persistence of sleep reports — now backed by Firestore.
class SleepStorageService {
  Future<void> saveReport(SleepReport report) async {
    try {
      await FirestoreService.saveReport(report);
    } catch (e) {
      debugPrint('[SleepStorageService] saveReport error: $e');
    }
  }

  Future<List<SleepReport>> getAllReports() async {
    try {
      return await FirestoreService.getAllReports();
    } catch (e) {
      debugPrint('[SleepStorageService] getAllReports error: $e');
      return [];
    }
  }

  Future<void> deleteReport(DateTime recordedAt) async {
    try {
      await FirestoreService.deleteReport(recordedAt);
    } catch (e) {
      debugPrint('[SleepStorageService] deleteReport error: $e');
    }
  }
}
