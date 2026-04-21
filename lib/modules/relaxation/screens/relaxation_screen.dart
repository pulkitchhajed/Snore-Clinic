import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/theme/app_theme.dart';

class RelaxationScreen extends StatefulWidget {
  const RelaxationScreen({super.key});
  @override
  State<RelaxationScreen> createState() => _RelaxationScreenState();
}

class _RelaxationScreenState extends State<RelaxationScreen>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();
  int? _playingIndex;
  bool _isPlaying = false;

  // ─── Breathing ───────────────────────────────────────────────────
  String _breatheMode = '4-7-8'; // '4-7-8' or 'box'
  bool _breatheActive = false;
  String _breathePhase = 'Tap to Start';
  late AnimationController _breatheCtrl;
  late Animation<double> _breatheAnim;

  static const _sounds = [
    {'emoji': '🌧️', 'label': 'Rain', 'color': Color(0xFF4FC3F7)},
    {'emoji': '🌊', 'label': 'Ocean', 'color': Color(0xFF26C6DA)},
    {'emoji': '🌿', 'label': 'Forest', 'color': Color(0xFF66BB6A)},
    {'emoji': '🔥', 'label': 'Campfire', 'color': Color(0xFFFF8A65)},
    {'emoji': '🌬️', 'label': 'White Noise', 'color': Color(0xFF90A4AE)},
    {'emoji': '🎵', 'label': 'Binaural', 'color': Color(0xFF9575CD)},
  ];

  @override
  void initState() {
    super.initState();
    _breatheCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4));
    _breatheAnim = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _player.dispose();
    _breatheCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Relaxation Tools'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ─── Ambient Sounds ───────────────────────────────────────
          Text('🎧 Ambient Sounds',
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 6),
          Text('Choose a sound to play while you drift off.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.9,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: _sounds.length,
            itemBuilder: (_, i) => _soundTile(i),
          ),
          const SizedBox(height: 32),

          // ─── Breathing Exercises ──────────────────────────────────
          Text('🫁 Breathing Exercises',
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 6),
          Text('Guided breathing to reduce stress and ease into sleep.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),

          // Mode selector
          Row(children: [
            _modeChip('4-7-8'),
            const SizedBox(width: 8),
            _modeChip('Box'),
          ]),
          const SizedBox(height: 24),

          // Animated breathing circle
          Center(
            child: GestureDetector(
              onTap: _toggleBreathe,
              child: AnimatedBuilder(
                animation: _breatheAnim,
                builder: (_, __) {
                  final sz = 140 + (_breatheActive ? _breatheAnim.value * 80 : 0.0);
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: sz, height: sz,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.accentTeal.withValues(alpha: 0.6),
                          AppTheme.primaryIndigo.withValues(alpha: 0.15),
                        ],
                      ),
                      boxShadow: _breatheActive
                          ? [BoxShadow(
                              color: AppTheme.accentTeal.withValues(alpha: 0.4),
                              blurRadius: 40, spreadRadius: 10)]
                          : null,
                    ),
                    child: Center(
                      child: Text(_breathePhase,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_breatheMode == '4-7-8')
            _infoCard('4-7-8 Method', 'Inhale 4s → Hold 7s → Exhale 8s. Activates your parasympathetic nervous system, reducing anxiety.', AppTheme.accentTeal)
          else
            _infoCard('Box Breathing', 'Inhale 4s → Hold 4s → Exhale 4s → Hold 4s. Used by Navy SEALs to stay calm under pressure.', AppTheme.primaryIndigo),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _soundTile(int i) {
    final s = _sounds[i];
    final color = s['color'] as Color;
    final playing = _playingIndex == i && _isPlaying;

    return GestureDetector(
      onTap: () => _toggleSound(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: playing ? color.withValues(alpha: 0.25) : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: playing ? color : AppTheme.cardBorder, width: playing ? 1.5 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(s['emoji'] as String, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 8),
          Text(s['label'] as String,
              style: TextStyle(
                  color: playing ? color : AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Icon(
            playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_outline_rounded,
            color: playing ? color : AppTheme.textSecondary,
            size: 18,
          ),
        ]),
      ),
    );
  }

  Widget _modeChip(String mode) {
    final active = _breatheMode == mode;
    return GestureDetector(
      onTap: () {
        if (_breatheActive) _stopBreathe();
        setState(() => _breatheMode = mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.accentTeal.withValues(alpha: 0.2)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? AppTheme.accentTeal : AppTheme.cardBorder),
        ),
        child: Text(mode,
            style: TextStyle(
                color: active ? AppTheme.accentTeal : AppTheme.textSecondary,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _infoCard(String title, String body, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 6),
        Text(body, style: Theme.of(context).textTheme.bodyMedium),
      ]),
    );
  }

  Future<void> _toggleSound(int i) async {
    if (_playingIndex == i && _isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      // NOTE: real ambient audio URLs would be provided here.
      // For demo, we just simulate the playing state.
      await _player.stop();
      setState(() {
        _playingIndex = i;
        _isPlaying = true;
      });
    }
  }

  void _toggleBreathe() {
    if (_breatheActive) {
      _stopBreathe();
    } else {
      _startBreathe();
    }
  }

  void _startBreathe() {
    setState(() => _breatheActive = true);
    if (_breatheMode == '4-7-8') {
      _run478();
    } else {
      _runBox();
    }
  }

  Future<void> _run478() async {
    final phases = [
      ('Inhale', 4), ('Hold', 7), ('Exhale', 8),
    ];
    while (_breatheActive && mounted) {
      for (final (phase, sec) in phases) {
        if (!_breatheActive) break;
        setState(() => _breathePhase = '$phase\n${sec}s');
        if (phase == 'Inhale') {
          _breatheCtrl.duration = Duration(seconds: sec);
          _breatheCtrl.forward(from: 0);
        } else if (phase == 'Exhale') {
          _breatheCtrl.duration = Duration(seconds: sec);
          _breatheCtrl.reverse(from: 1);
        }
        await Future.delayed(Duration(seconds: sec));
      }
    }
  }

  Future<void> _runBox() async {
    final phases = [
      ('Inhale', 4), ('Hold', 4), ('Exhale', 4), ('Hold', 4),
    ];
    while (_breatheActive && mounted) {
      for (final (phase, sec) in phases) {
        if (!_breatheActive) break;
        setState(() => _breathePhase = '$phase\n${sec}s');
        if (phase == 'Inhale') {
          _breatheCtrl.duration = Duration(seconds: sec);
          _breatheCtrl.forward(from: 0);
        } else if (phase == 'Exhale') {
          _breatheCtrl.duration = Duration(seconds: sec);
          _breatheCtrl.reverse(from: 1);
        }
        await Future.delayed(Duration(seconds: sec));
      }
    }
  }

  void _stopBreathe() {
    setState(() {
      _breatheActive = false;
      _breathePhase = 'Tap to Start';
    });
    _breatheCtrl.stop();
  }
}
