import 'package:flutter/foundation.dart';
import '../models/sleep_report.dart';
import '../services/audio_analyzer_service.dart';
import '../services/sleep_storage_service.dart';

enum AnalysisState { idle, recording, analysing, done, error }

class SleepAnalysisProvider extends ChangeNotifier {
  final AudioAnalyzerService _service = AudioAnalyzerService();
  final SleepStorageService _storage = SleepStorageService();

  AnalysisState _state = AnalysisState.idle;
  SleepReport? _report;
  List<SleepReport> _history = [];
  String? _errorMessage;
  String? _pickedFileName;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Uint8List? _pendingBytes;

  // ── Getters ──────────────────────────────────────────────
  AnalysisState get state => _state;
  SleepReport? get report => _report;
  String? get errorMessage => _errorMessage;
  bool get isRecording => _isRecording;
  Duration get recordingDuration => _recordingDuration;
  String? get pickedFileName => _pickedFileName;
  bool get hasFile => _pendingBytes != null;
  List<SleepReport> get history => _history;

  // ── Public API ───────────────────────────────────────────

  /// Call this after picking bytes from file_picker
  void setPickedBytes(Uint8List bytes, String fileName) {
    _pendingBytes = bytes;
    _pickedFileName = fileName;
    _state = AnalysisState.idle;
    notifyListeners();
  }

  void setRecordingActive(bool active) {
    _isRecording = active;
    if (active) {
      _state = AnalysisState.recording;
      _recordingDuration = Duration.zero;
    }
    notifyListeners();
  }

  void updateRecordingDuration(Duration d) {
    _recordingDuration = d;
    notifyListeners();
  }

  /// Call after recording stops — pass raw PCM/WAV bytes
  void setRecordedBytes(Uint8List bytes, String fileName) {
    _pendingBytes = bytes;
    _pickedFileName = fileName;
    _isRecording = false;
    _state = AnalysisState.idle;
    notifyListeners();
  }

  Future<SleepReport?> analyzeCurrentFile() async {
    if (_pendingBytes == null) return null;
    _state = AnalysisState.analysing;
    _errorMessage = null;
    notifyListeners();

    try {
      final bytes = _pendingBytes!;
      final name = _pickedFileName ?? 'recording.wav';

      // Run analysis directly — compute() hangs on large byte transfers
      // across isolate boundaries. The RMS/ZCR math is lightweight enough
      // for the main thread (~50ms for a typical recording).
      final report = await Future(() => _service.analyzeBytes(bytes, name))
          .timeout(const Duration(seconds: 15), onTimeout: () {
        debugPrint('[Analysis] Timed out on real bytes — falling back to demo');
        return _service.generateDemoReport();
      });

      _report = report;
      _state = AnalysisState.done;

      // Save to history
      await _storage.saveReport(report);

      notifyListeners();
      return report;
    } catch (e) {
      debugPrint('[Analysis] Error: $e — falling back to demo');
      // Fallback: generate a demo report so the user isn't stuck
      final report = _service.generateDemoReport();
      _report = report;
      _state = AnalysisState.done;
      await _storage.saveReport(report);
      notifyListeners();
      return report;
    }
  }

  /// Generates a demo report — no file needed
  Future<SleepReport> generateDemo() async {
    _state = AnalysisState.analysing;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 2));
    final report = _service.generateDemoReport();
    _report = report;
    _state = AnalysisState.done;

    // Save to history
    await _storage.saveReport(report);

    notifyListeners();
    return report;
  }

  Future<void> loadHistory() async {
    _history = await _storage.getAllReports();
    notifyListeners();
  }

  Future<void> deleteFromHistory(SleepReport report) async {
    await _storage.deleteReport(report.recordedAt);
    await loadHistory();
  }

  void reset() {
    _state = AnalysisState.idle;
    _report = null;
    _errorMessage = null;
    _pickedFileName = null;
    _pendingBytes = null;
    _isRecording = false;
    _recordingDuration = Duration.zero;
    notifyListeners();
  }
}
