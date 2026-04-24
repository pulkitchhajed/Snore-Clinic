import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:just_audio/just_audio.dart';

import '../providers/sleep_analysis_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/file_reader.dart';

class SleepAnalysisScreen extends StatefulWidget {
  const SleepAnalysisScreen({super.key});

  @override
  State<SleepAnalysisScreen> createState() => _SleepAnalysisScreenState();
}

class _SleepAnalysisScreenState extends State<SleepAnalysisScreen>
    with TickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _timer;

  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late Animation<double> _pulseAnim;
  late Animation<double> _rippleAnim;

  double _wakeUpProgress = 0.0;
  Timer? _wakeUpTimer;
  bool _isStopping = false;

  final AudioPlayer _soundsPlayer = AudioPlayer();
  final AudioPlayer _alarmPlayer = AudioPlayer();
  TimeOfDay? _alarmTime;
  String? _activeSoundName;
  bool _isAlarmRinging = false;
  
  final List<Map<String, String>> _sleepSounds = [
    {'name': 'White Noise', 'url': 'https://upload.wikimedia.org/wikipedia/commons/d/d9/White_noise.ogg'},
    {'name': 'Heavy Rain', 'url': 'https://upload.wikimedia.org/wikipedia/commons/1/15/Rain_on_a_tin_roof.ogg'},
    {'name': 'Ocean Waves', 'url': 'https://upload.wikimedia.org/wikipedia/commons/c/c5/Ocean_waves.ogg'},
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rippleAnim = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
    
    _checkAndShowPopups();
  }

  Future<void> _checkAndShowPopups() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTips = prefs.getBool('hasSeenTipsPopup') ?? false;
    
    if (!hasSeenTips && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTipsPopup();
      });
    }
  }

  void _showTipsPopup() {
    bool dontShowAgain = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Recording Tips'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('• Place your phone face down beside your pillow.\n• Ensure the device is plugged in if battery is low.\n• Silence notifications for uninterrupted sleep.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: dontShowAgain,
                    onChanged: (val) {
                      setState(() => dontShowAgain = val ?? false);
                    },
                  ),
                  const Text("Don't remind me anymore"),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (dontShowAgain) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('hasSeenTipsPopup', true);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }

  void _showInterferencePopup(VoidCallback onContinue) {
    bool dontShowAgain = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Background Audio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Background noise like TVs, fans, or audiobooks can interfere with snoring detection. Try to minimize background audio if possible.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: dontShowAgain,
                    onChanged: (val) {
                      setState(() => dontShowAgain = val ?? false);
                    },
                  ),
                  const Text("Don't remind me anymore", style: TextStyle(fontSize: 13)),
                ],
              ),
            ],
          ),
          actions: [
             TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (dontShowAgain) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('hasSeenInterferencePopup', true);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  onContinue();
                }
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    _timer?.cancel();
    _wakeUpTimer?.cancel();
    _recorder.dispose();
    _soundsPlayer.dispose();
    _alarmPlayer.dispose();
    super.dispose();
  }

  // ── Recording ─────────────────────────────────────────────────────

  Future<void> _startRecording(SleepAnalysisProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenInterference = prefs.getBool('hasSeenInterferencePopup') ?? false;

    if (!hasSeenInterference) {
      _showInterferencePopup(() {
        _doStartRecording(provider);
      });
    } else {
      _doStartRecording(provider);
    }
  }

  Future<void> _doStartRecording(SleepAnalysisProvider provider) async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showPermissionSnack();
      return;
    }

    if (!kIsWeb) {
      final isIgnoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (!isIgnoring) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }

    String path;
    if (kIsWeb) {
      // On web, record package uses a temp path
      path = 'sleep_recording.wav';
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = '${dir.path}/sleep_${DateTime.now().millisecondsSinceEpoch}.wav';
    }

    // ── Start foreground service to keep recording alive overnight ──
    if (!kIsWeb) {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'sleep_recording',
          channelName: 'Sleep Recording',
          channelDescription: 'Keeps the app running while recording your sleep.',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          autoRunOnBoot: false,
          autoRunOnMyPackageReplaced: false,
          allowWakeLock: true,
          allowWifiLock: false,
          eventAction: ForegroundTaskEventAction.nothing(),
        ),
      );
      await FlutterForegroundTask.startService(
        notificationTitle: 'Recording Sleep...',
        notificationText: 'SnoreClinics AI is listening for snoring.',
      );
      debugPrint('[Recording] Foreground service started');
    }

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1, // mono is enough for sleep analysis
        bitRate: 32000,
      ),
      path: path,
    );

    provider.setRecordingActive(true);
    _rippleController.repeat(reverse: false);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      provider.updateRecordingDuration(
        provider.recordingDuration + const Duration(seconds: 1),
      );
      _checkAlarm();
    });
  }

  Future<void> _stopAndAnalyse(SleepAnalysisProvider provider) async {
    _timer?.cancel();
    _rippleController.stop();
    _rippleController.reset();
    _soundsPlayer.stop();
    _alarmPlayer.stop();
    _isAlarmRinging = false;

    final stoppedPath = await _recorder.stop();

    // ── Stop foreground service ──
    if (!kIsWeb) {
      await FlutterForegroundTask.stopService();
      debugPrint('[Recording] Foreground service stopped');
    }

    // Mark recording done AFTER we have the path
    provider.setRecordingActive(false);

    if (stoppedPath == null) {
      _showError('Recording stopped but no file was saved.');
      return;
    }

    // Check minimum duration (30 seconds)
    if (provider.recordingDuration.inSeconds < 30) {
      if (mounted) {
        _showMinimumDurationWarning();
      }
      return;
    }

    if (provider.recordingDuration.inMinutes < 10) {
      if (mounted) {
        final bool? shouldSave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Short Recording'),
            content: const Text('This recording is under 10 minutes. A full sleep cycle usually takes over an hour. Do you still want to save and analyze it?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Discard'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Analyze Anyway'),
              ),
            ],
          ),
        );
        if (shouldSave != true) return;
      }
    }

    // Read bytes and kick off analysis — the analysing view will show during this
    Uint8List? bytes;
    final name = stoppedPath.split('/').last.split('\\').last;

    try {
      if (kIsWeb) {
        bytes = await _fetchWebBytes(stoppedPath);
      } else {
        bytes = await _readNativeBytes(stoppedPath);
      }
    } catch (e) {
      bytes = null;
    }

    if (bytes != null && bytes.isNotEmpty) {
      // setPickedBytes will set state→idle, then analyzeCurrentFile sets it to analysing
      provider.setPickedBytes(bytes, name);
      final report = await provider.analyzeCurrentFile();
      if (report != null && mounted) {
        Navigator.pushNamed(context, AppRouter.sleepReport, arguments: report);
      } else if (provider.state == AnalysisState.error && mounted) {
        _showError('Analysis failed: ${provider.errorMessage ?? 'Unknown error'}');
      }
    } else {
      // Fallback: run a demo with the recorded duration
      _showError('Could not read recording bytes. Running analysis...');
      final report = await provider.generateDemo();
      if (mounted) {
        Navigator.pushNamed(context, AppRouter.sleepReport, arguments: report);
      }
    }
  }

  Future<Uint8List?> _fetchWebBytes(String url) async {
    if (!kIsWeb) return null;
    try {
      final response = await http.get(Uri.parse(url));
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _readNativeBytes(String path) async {
    return await PlatformFileReader.readAsBytes(path);
  }

  // ── File picker ───────────────────────────────────────────────────

  Future<void> _pickFile(SleepAnalysisProvider provider) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'm4a', 'mp3', 'aac', 'ogg'],
        withData: true,
      );
      if (result != null) {
        final f = result.files.single;
        final bytes = f.bytes;
        if (bytes != null) {
          provider.setPickedBytes(bytes, f.name);
        }
      }
    } catch (e) {
      _showError('Could not open file: $e');
    }
  }

  Future<void> _navigate(SleepAnalysisProvider provider) async {
    final report = await provider.analyzeCurrentFile();
    if (report != null && mounted) {
      Navigator.pushNamed(context, AppRouter.sleepReport, arguments: report);
    } else if (provider.state == AnalysisState.error && mounted) {
      _showError('Analysis failed: ${provider.errorMessage ?? 'Unknown error'}');
    }
  }

  Future<void> _runDemo(SleepAnalysisProvider provider) async {
    final report = await provider.generateDemo();
    if (mounted) {
      Navigator.pushNamed(context, AppRouter.sleepReport, arguments: report);
    }
  }

  void _showPermissionSnack() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Microphone permission is required to record sleep audio.'),
      backgroundColor: AppTheme.error,
    ));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.error,
    ));
  }

  void _showMinimumDurationWarning() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🥱', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Recording too short',
              style: Theme.of(context).textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Recording should be more than 30s to provide accurate analysis. Please go back to sleep and try again later!',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryIndigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Back to Sleep', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<SleepAnalysisProvider>(
      builder: (context, provider, _) {
        if (provider.isRecording) {
          return _buildRecordingView(provider);
        }
        if (provider.state == AnalysisState.analysing) {
          return _buildAnalysingView();
        }
        return _buildIdleView(provider);
      },
    );
  }

  Widget _buildAnalysingView() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing brain icon
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        AppTheme.primaryIndigo.withValues(alpha: 0.4),
                        AppTheme.primaryIndigo.withValues(alpha: 0.05),
                      ]),
                      border: Border.all(
                          color: AppTheme.primaryIndigo.withValues(alpha: 0.6),
                          width: 1.5),
                    ),
                    child: const Center(
                        child: Text('🧠', style: TextStyle(fontSize: 52))),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Analysing Your Sleep',
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Our AI is processing your recording.\nThis usually takes a few seconds…',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                    height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: AppTheme.primaryIndigo,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Recording (active) view ───────────────────────────────────────

  Widget _buildRecordingView(SleepAnalysisProvider provider) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      _alarmTime == null ? Icons.alarm_rounded : Icons.alarm_on_rounded, 
                      color: _alarmTime == null ? AppTheme.textPrimary : AppTheme.accentTeal,
                    ),
                    onPressed: _showAlarmSheet,
                  ),
                  Row(
                    children: [
                      const Icon(Icons.mic, color: AppTheme.error, size: 20),
                      const SizedBox(width: 6),
                      Text('REC', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.error)),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.music_note_rounded, 
                      color: _activeSoundName == null ? AppTheme.textPrimary : AppTheme.accentTeal,
                    ),
                    onPressed: _showSoundsSheet,
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              'Recording Sleep...',
              style: Theme.of(context).textTheme.displayMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Keep your phone nearby and go to sleep 😴',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 56),
            _buildPulsingMic(provider),
            const SizedBox(height: 40),
            Text(
              _formatDuration(provider.recordingDuration),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Recording in progress',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: StatefulBuilder(
                builder: (context, setState) {
                  return GestureDetector(
                    onForcePressStart: (_) {},
                    onLongPressStart: (_) {
                      _isStopping = true;
                      _wakeUpProgress = 0.0;
                      _wakeUpTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
                        setState(() {
                          _wakeUpProgress += 50 / 2000; // 2 seconds to fill
                          if (_wakeUpProgress >= 1.0) {
                            _wakeUpProgress = 1.0;
                            timer.cancel();
                            _isStopping = false;
                            _stopAndAnalyse(provider);
                          }
                        });
                      });
                    },
                    onLongPressEnd: (_) {
                      _isStopping = false;
                      _wakeUpTimer?.cancel();
                      setState(() {
                        _wakeUpProgress = 0.0;
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      height: 70,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(35),
                        border: Border.all(color: AppTheme.primaryIndigo),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(35),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 50),
                                width: MediaQuery.of(context).size.width * _wakeUpProgress,
                                color: AppTheme.primaryIndigo.withValues(alpha: 0.8),
                              ),
                            ),
                            Text(
                              'Hold To Wake Up',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: _wakeUpProgress > 0.5 ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulsingMic(SleepAnalysisProvider provider) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _rippleController]),
      builder: (_, __) {
        return SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ripple
              Transform.scale(
                scale: _rippleAnim.value,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.error.withValues(
                          alpha: (1 - _rippleController.value) * 0.6),
                      width: 2,
                    ),
                  ),
                ),
              ),
              // Pulse base
              Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.error.withValues(alpha: 0.15),
                    border: Border.all(
                        color: AppTheme.error.withValues(alpha: 0.7), width: 2),
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: AppTheme.error,
                    size: 52,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Idle view ─────────────────────────────────────────────────────

  Widget _buildIdleView(SleepAnalysisProvider provider) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Analysis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroCard(),
              const SizedBox(height: 28),
              Text('Record Tonight', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 12),
              _buildStartRecordingButton(provider),
              const SizedBox(height: 28),
              Row(children: [
                const Expanded(child: Divider(color: AppTheme.cardBorder)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or', style: Theme.of(context).textTheme.bodyMedium),
                ),
                const Expanded(child: Divider(color: AppTheme.cardBorder)),
              ]),
              const SizedBox(height: 24),
              Text('Upload Existing Recording',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 12),
              _buildUploadTile(provider),
              if (provider.hasFile) ...[
                const SizedBox(height: 16),
                _buildSelectedFileCard(provider),
                const SizedBox(height: 16),
                _buildAnalyseButton(provider),
              ],
              const SizedBox(height: 20),
              _buildDemoButton(provider),
              const SizedBox(height: 32),
              _buildHowItWorksSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1D3A), Color(0xFF0F1120)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.primaryIndigo.withValues(alpha: 0.3),
                  AppTheme.primaryIndigo.withValues(alpha: 0.05),
                ]),
                border: Border.all(
                    color: AppTheme.primaryIndigo.withValues(alpha: 0.5), width: 1.5),
              ),
              child: const Center(child: Text('🌙', style: TextStyle(fontSize: 40))),
            ),
          ),
          const SizedBox(height: 18),
          Text('Sleep Sound Analyser',
              style: Theme.of(context).textTheme.headlineLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Start recording before you sleep. Stop when you wake up — we\'ll generate a full sleep quality report.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStartRecordingButton(SleepAnalysisProvider provider) {
    return GestureDetector(
      onTap: () => _startRecording(provider),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryIndigo.withValues(alpha: 0.2),
              AppTheme.primaryIndigo.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppTheme.primaryIndigo.withValues(alpha: 0.5), width: 1.5),
        ),
        child: const Column(
          children: [
            Icon(Icons.mic_rounded, color: AppTheme.primaryIndigo, size: 48),
            SizedBox(height: 12),
            Text(
              'Start Sleep Recording',
              style: TextStyle(
                  color: AppTheme.primaryIndigo,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 4),
            Text(
              'Tap before sleeping • Stop when you wake up',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadTile(SleepAnalysisProvider provider) {
    return GestureDetector(
      onTap: () => _pickFile(provider),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.accentTeal.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.4), width: 1.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_file_rounded, color: AppTheme.accentTeal, size: 32),
            SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pick Audio File',
                    style: TextStyle(color: AppTheme.accentTeal, fontSize: 16, fontWeight: FontWeight.w600)),
                Text('.wav  .m4a  .mp3  .aac  .ogg',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFileCard(SleepAnalysisProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.audio_file_rounded, color: AppTheme.success, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ready to Analyse',
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(color: AppTheme.success)),
                Text(provider.pickedFileName ?? '',
                    style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
            onPressed: provider.reset,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyseButton(SleepAnalysisProvider provider) {
    final busy = provider.state == AnalysisState.analysing;
    return ElevatedButton.icon(
      onPressed: busy ? null : () => _navigate(provider),
      icon: busy
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.analytics_rounded),
      label: Text(busy ? 'Analysing...' : 'Analyse Sleep'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryIndigo,
        disabledBackgroundColor: AppTheme.cardBorder,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildDemoButton(SleepAnalysisProvider provider) {
    return OutlinedButton.icon(
      onPressed: provider.state == AnalysisState.analysing ? null : () => _runDemo(provider),
      icon: const Icon(Icons.play_circle_outline_rounded),
      label: const Text('Try Demo Report (No recording needed)'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryGold,
        side: const BorderSide(color: AppTheme.primaryGold, width: 1.5),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildHowItWorksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How It Works', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        ...[
          ('🌙', 'Tap "Start Recording"', 'Place phone face-down beside your pillow and sleep'),
          ('⏰', 'Wake Up & Tap Stop', 'In the morning open the app and press "Stop & Analyse"'),
          ('📊', 'Get Your Report', 'See your snoring score, spikes, sleep quality & tips'),
        ].map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.$1, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$2, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 2),
                    Text(item.$3, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
  // ── Audio Feature Modals ──────────────────────────────────────────

  void _checkAlarm() {
    if (_alarmTime == null || _isAlarmRinging) return;
    final now = TimeOfDay.now();
    if (now.hour == _alarmTime!.hour && now.minute == _alarmTime!.minute) {
      _triggerAlarm();
    }
  }

  void _triggerAlarm() async {
    setState(() => _isAlarmRinging = true);
    try {
      await _alarmPlayer.setUrl('https://upload.wikimedia.org/wikipedia/commons/4/4b/Bicycle_bell_1.ogg');
      _alarmPlayer.setVolume(1.0);
      _alarmPlayer.setLoopMode(LoopMode.one);
      _alarmPlayer.play();
    } catch (e) {
      debugPrint('Alarm error: $e');
    }
    
    if (mounted) {
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        pageBuilder: (context, anim1, anim2) {
          return Scaffold(
            backgroundColor: AppTheme.primaryIndigo.withValues(alpha: 0.95),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('⏰', style: TextStyle(fontSize: 80)),
                  const SizedBox(height: 24),
                  Text(
                    'Good Morning!',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () {
                      _alarmPlayer.stop();
                      setState(() {
                         _isAlarmRinging = false;
                         _alarmTime = null;
                      });
                      Navigator.pop(context); // dismiss dialog
                      // Stop recording and analyze
                      final provider = Provider.of<SleepAnalysisProvider>(context, listen: false);
                      _stopAndAnalyse(provider);
                    },
                    child: const Text('Wake Up & Analyze Sleep', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        }
      );
    }
  }

  void _showAlarmSheet() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _alarmTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accentTeal,
              surface: AppTheme.surfaceElevated,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null && mounted) {
      setState(() => _alarmTime = time);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Smart Alarm set for ${time.format(context)}'),
        backgroundColor: AppTheme.success,
      ));
    }
  }

  void _showSoundsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.cardBorder, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text('Sleep Sounds', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              ..._sleepSounds.map((snd) {
                final isPlaying = _activeSoundName == snd['name'];
                return ListTile(
                  title: Text(snd['name']!, style: const TextStyle(color: AppTheme.textPrimary)),
                  trailing: isPlaying ? const Icon(Icons.stop_circle, color: AppTheme.accentTeal) : const Icon(Icons.play_circle_outline, color: AppTheme.textSecondary),
                  onTap: () async {
                    if (isPlaying) {
                      await _soundsPlayer.stop();
                      setState(() => _activeSoundName = null);
                      setSheetState(() => _activeSoundName = null);
                    } else {
                      setState(() => _activeSoundName = snd['name']);
                      setSheetState(() => _activeSoundName = snd['name']);
                      try {
                        await _soundsPlayer.setUrl(snd['url']!);
                        _soundsPlayer.setLoopMode(LoopMode.one); // loop infinitely
                        _soundsPlayer.setVolume(1.0);
                        _soundsPlayer.play();
                      } catch (e) {
                         debugPrint('Sound error: $e');
                      }
                    }
                  },
                );
              }),
              const SizedBox(height: 24),
              if (_activeSoundName != null)
                TextButton.icon(
                  onPressed: () async {
                    await _soundsPlayer.stop();
                    setState(() => _activeSoundName = null);
                    setSheetState(() => _activeSoundName = null);
                    if (mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.stop, color: AppTheme.error),
                  label: const Text('Turn Off Sound', style: TextStyle(color: AppTheme.error)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
