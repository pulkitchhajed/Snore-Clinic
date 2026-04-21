import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../sleep_analysis/models/sleep_report.dart';
import '../../journal/models/journal_entry.dart';

/// Gemini AI service — structured JSON analysis and chat.
class GeminiService {
  static const String _apiKey = 'AIzaSyAvycsLfudcZHZPvoFxBUBRtVlK7iQm3sw';
  static bool get _hasKey => _apiKey != 'YOUR_GEMINI_API_KEY';

  /// Generates a structured JSON analysis from a SleepReport.
  Future<Map<String, dynamic>> analyzeSession(
      SleepReport report, JournalEntry? journalEntry) async {
    if (!_hasKey) return _offlineJsonAnalysis(report, journalEntry);

    try {
      final schema = Schema.object(
        properties: {
          'aiScore': Schema.integer(description: 'AI sleep score 0-100'),
          'recommendation': Schema.string(description: 'Detailed sleep analysis and tips'),
          'lifestyleFactors': Schema.array(
            description: 'Identified lifestyle factors affecting sleep from journal',
            items: Schema.string(),
          ),
        },
        requiredProperties: ['aiScore', 'recommendation', 'lifestyleFactors'],
      );

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: schema,
          temperature: 0.2, // Low temp for analytical consistency
        ),
      );

      final prompt = _buildAnalysisPrompt(report, journalEntry);
      final response = await model.generateContent([Content.text(prompt)]);
      
      return jsonDecode(response.text ?? '{}') as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Gemini Error: $e');
      return _offlineJsonAnalysis(report, journalEntry);
    }
  }

  /// Streams a conversational response from Nidra Chat.
  Stream<String> chat(String userMessage,
      {SleepReport? latestReport, JournalEntry? latestJournal}) async* {
    if (!_hasKey) {
      yield* _offlineChat(userMessage, latestReport);
      return;
    }
    // TODO: real Gemini streaming call
    yield* _offlineChat(userMessage, latestReport);
  }

  // ── Offline / demo responses ────────────────────────────────────

  Map<String, dynamic> _offlineJsonAnalysis(SleepReport r, JournalEntry? j) {
    final quality = r.quality.name;
    final snoreMin = r.snoringDuration.inMinutes;
    final score = r.qualityScore.toInt();
    
    String rec = '**Sleep Quality: ${quality[0].toUpperCase()}${quality.substring(1)}** ($score/100)\n\n';

    if (snoreMin == 0) {
      rec += 'Excellent news — no significant snoring was detected. Your airway remained clear throughout the night.\n\n';
    } else if (snoreMin < 20) {
      rec += 'Mild snoring detected (${snoreMin}m). This is common and not immediately concerning.\n\n';
    } else {
      rec += 'Moderate-to-heavy snoring detected (${snoreMin}m). Consider sleeping on your side and reviewing your evening habits.\n\n';
    }

    final List<String> factors = [];

    if (j != null) {
      if (j.alcoholUnits > 2) {
        factors.add('Alcohol (${j.alcoholUnits} units)');
      }
      if (j.stressLevel >= 7) {
        factors.add('High Stress (${j.stressLevel}/10)');
      }
      if (j.caffeineUnits > 2) {
        factors.add('Caffeine (${j.caffeineUnits} units)');
      }
    }

    rec += '**Recommendation**: ${score >= 80 ? "Keep up this routine!" : score >= 60 ? "A few small changes could improve your sleep significantly." : "Let\'s work together to find the root cause of your poor sleep."}';

    return {
      'aiScore': score,
      'recommendation': rec,
      'lifestyleFactors': factors.isEmpty ? ['None detected'] : factors,
    };
  }

  Stream<String> _offlineChat(String msg, SleepReport? r) async* {
    final responses = _findBestResponse(msg.toLowerCase(), r);
    for (final chunk in responses.split(' ')) {
      yield '$chunk ';
      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  String _findBestResponse(String msg, SleepReport? r) {
    if (msg.contains('snor')) {
      final min = r?.snoringDuration.inMinutes ?? 0;
      return min == 0
          ? 'Great news! Your last recording showed no significant snoring. Keep sleeping on your side and stay hydrated throughout the day.'
          : 'Your last session showed $min minutes of snoring. To reduce it, try sleeping on your side, elevate your head slightly, and avoid alcohol within 3 hours of bedtime.';
    }
    if (msg.contains('apnea') || msg.contains('apnoea')) {
      return 'Sleep apnea is a serious condition where breathing repeatedly stops during sleep. Signs include loud snoring, gasping, and daytime fatigue. If you suspect it, please consult a sleep specialist. I can help you track patterns in the meantime.';
    }
    if (msg.contains('tip') || msg.contains('advice') || msg.contains('improve')) {
      return '**Top 5 sleep tips:**\n1. Maintain a consistent sleep schedule\n2. Keep your room cool (16–20°C)\n3. Avoid screens 1 hour before bed\n4. Limit caffeine after 2pm\n5. Try the 4-7-8 breathing technique';
    }
    if (msg.contains('score') || msg.contains('result')) {
      final score = r?.qualityScore.toInt() ?? 0;
      return r == null
          ? 'I don\'t have any sleep data yet. Record a session tonight and I\'ll give you a detailed breakdown!'
          : 'Your latest sleep quality score is $score/100. ${score >= 75 ? "That\'s excellent! 🌟" : "There\'s room to improve. Let me know what factors you\'d like to work on."}';
    }
    return 'Hey there! I\'m Nidra, your AI sleep assistant. You can ask me about your snoring data, sleep tips, apnea risk, or anything sleep-related. What would you like to know?';
  }

  String _buildAnalysisPrompt(SleepReport r, JournalEntry? j) {
    final sb = StringBuffer();
    sb.writeln('Analyse this sleep session and provide personalised feedback:');
    sb.writeln('- Total sleep duration: ${r.totalDuration.inMinutes} minutes');
    sb.writeln('- Snoring duration: ${r.snoringDuration.inMinutes} minutes');
    sb.writeln('- Snoring events: ${r.snoringEventCount}');
    sb.writeln('- Quality score: ${r.qualityScore}');
    if (j != null) {
      sb.writeln('Evening journal:');
      sb.writeln('  Caffeine: ${j.caffeineUnits} units');
      sb.writeln('  Alcohol: ${j.alcoholUnits} units');
      sb.writeln('  Stress: ${j.stressLevel}/10');
    }
    sb.writeln('Provide a concise 3-paragraph analysis with lifestyle factors and actionable tips. Use markdown formatting.');
    return sb.toString();
  }
}
