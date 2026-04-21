import 'package:flutter/foundation.dart';
import '../models/journal_entry.dart';
import '../../../core/services/firestore_service.dart';

class JournalProvider extends ChangeNotifier {
  List<JournalEntry> _entries = [];
  JournalEntry? _draftEvening;
  JournalEntry? _draftMorning;

  List<JournalEntry> get entries => List.unmodifiable(_entries);
  JournalEntry get eveningDraft => _draftEvening ?? JournalEntry.newEvening();
  JournalEntry get morningDraft => _draftMorning ?? JournalEntry.newMorning();

  Future<void> loadEntries() async {
    _entries = await FirestoreService.getJournalEntries();
    notifyListeners();
  }

  void updateEveningDraft(JournalEntry e) {
    _draftEvening = e;
    notifyListeners();
  }

  void updateMorningDraft(JournalEntry e) {
    _draftMorning = e;
    notifyListeners();
  }

  Future<void> saveEvening() async {
    if (_draftEvening == null) return;
    await FirestoreService.saveJournalEntry(_draftEvening!);
    _entries.insert(0, _draftEvening!);
    _draftEvening = null;
    notifyListeners();
  }

  Future<void> saveMorning() async {
    if (_draftMorning == null) return;
    await FirestoreService.saveJournalEntry(_draftMorning!);
    _entries.insert(0, _draftMorning!);
    _draftMorning = null;
    notifyListeners();
  }

  Future<void> deleteEntry(String id) async {
    await FirestoreService.deleteJournalEntry(id);
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  /// Clears in-memory entries (used during logout).
  void clear() {
    _entries = [];
    _draftEvening = null;
    _draftMorning = null;
    notifyListeners();
  }
}
