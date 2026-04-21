import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/journal_provider.dart';
import '../models/journal_entry.dart';

class MorningJournalScreen extends StatefulWidget {
  const MorningJournalScreen({super.key});
  @override
  State<MorningJournalScreen> createState() => _MorningJournalScreenState();
}

class _MorningJournalScreenState extends State<MorningJournalScreen> {
  int _mood = 7;
  String _position = 'side';
  bool _congestion = false;
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Morning Journal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(DateFormat('EEEE, MMMM d').format(DateTime.now()),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.primaryGold)),
          const SizedBox(height: 6),
          Text('Good morning!', style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 28),

          _sectionHeader('😊 How do you feel right now?'),
          Row(children: [
            const Text('😫', style: TextStyle(fontSize: 22)),
            Expanded(
              child: Slider(
                value: _mood.toDouble(),
                min: 1, max: 10, divisions: 9,
                activeColor: _moodColor(_mood),
                onChanged: (v) => setState(() => _mood = v.round()),
              ),
            ),
            const Text('😄', style: TextStyle(fontSize: 22)),
          ]),
          Center(
              child: Text('${_moodEmoji(_mood)}  $_mood / 10',
                  style: TextStyle(
                      color: _moodColor(_mood),
                      fontWeight: FontWeight.w700,
                      fontSize: 18))),
          const SizedBox(height: 28),

          _sectionHeader('🛏️ How did you sleep?'),
          Row(
            children: ['back', 'side', 'stomach'].map((pos) {
              final labels = {'back': '🫸 Back', 'side': '↔️ Side', 'stomach': '🔻 Stomach'};
              final sel = _position == pos;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _position = pos),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppTheme.accentTeal.withValues(alpha: 0.2)
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: sel ? AppTheme.accentTeal : AppTheme.cardBorder),
                    ),
                    child: Text(labels[pos]!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: sel ? AppTheme.accentTeal : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          _sectionHeader('🤧 Nasal Congestion'),
          GestureDetector(
            onTap: () => setState(() => _congestion = !_congestion),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _congestion
                    ? AppTheme.error.withValues(alpha: 0.1)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _congestion ? AppTheme.error : AppTheme.cardBorder),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Did you wake up with a blocked nose?',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                Switch(
                  value: _congestion,
                  onChanged: (v) => setState(() => _congestion = v),
                  activeThumbColor: AppTheme.error,
                ),
              ]),
            ),
          ),
          const SizedBox(height: 24),

          _sectionHeader('📝 Notes'),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'How did you sleep? Any dreams?',
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.cardBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.cardBorder)),
            ),
          ),
          const SizedBox(height: 36),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Save Morning Entry',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    final p = context.read<JournalProvider>();
    p.updateMorningDraft(JournalEntry.newMorning().copyWith(
      moodScore: _mood,
      sleepPosition: _position,
      hadCongestion: _congestion,
      notes: _notesCtrl.text.trim(),
    ));
    await p.saveMorning();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Morning journal saved! Have a great day ☀️'),
        backgroundColor: AppTheme.success,
      ));
      Navigator.pop(context);
    }
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
      );

  Color _moodColor(int m) {
    if (m <= 3) return AppTheme.error;
    if (m <= 6) return AppTheme.primaryGold;
    return AppTheme.success;
  }

  String _moodEmoji(int m) {
    if (m <= 2) return '😫';
    if (m <= 4) return '😕';
    if (m <= 6) return '😐';
    if (m <= 8) return '😊';
    return '😄';
  }
}
