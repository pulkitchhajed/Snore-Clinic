import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../sleep_analysis/services/sleep_storage_service.dart';
import '../../sleep_analysis/models/sleep_report.dart';
import '../services/gemini_service.dart';

class _Message {
  final String text;
  final bool isUser;
  final bool isLoading;
  _Message(this.text, {this.isUser = false, this.isLoading = false});
}

class NidraChatScreen extends StatefulWidget {
  const NidraChatScreen({super.key});
  @override
  State<NidraChatScreen> createState() => _NidraChatScreenState();
}

class _NidraChatScreenState extends State<NidraChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _gemini = GeminiService();
  final List<_Message> _messages = [];
  SleepReport? _latestReport;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final reports = await SleepStorageService().getAllReports();
    setState(() {
      _latestReport = reports.isEmpty ? null : reports.first;
      _messages.add(_Message(
        _latestReport == null
            ? 'Hi! I\'m **Nidra**, your AI sleep assistant 🌙\nRecord your first sleep session and I\'ll give you personalised insights. Or ask me anything about sleep!'
            : 'Hi! I\'m **Nidra** 🌙\nYour last session scored **${_latestReport!.qualityScore.toInt()}/100**. Ask me anything about your sleep!',
      ));
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryIndigo,
                  AppTheme.accentTeal.withValues(alpha: 0.8),
                ],
              ),
            ),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nidra', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text('AI Sleep Assistant', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ]),
        ]),
      ),
      body: Column(children: [
        // Suggestion chips
        _suggestionsRow(),
        // Messages
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (_, i) => _bubble(_messages[i]),
          ),
        ),
        // Input
        _inputBar(),
      ]),
    );
  }

  Widget _suggestionsRow() {
    final chips = [
      'My sleep score?',
      'Why do I snore?',
      'Sleep tips',
      'Apnea risk',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: chips.map((c) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => _sendMessage(c),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.primaryIndigo.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.primaryIndigo.withValues(alpha: 0.4)),
              ),
              child: Text(c,
                  style: const TextStyle(
                      color: AppTheme.primaryIndigo,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _bubble(_Message m) {
    if (m.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 48),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryIndigo,
              borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: const Radius.circular(4)),
            ),
            child: Text(m.text,
                style: const TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 48),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [
              AppTheme.primaryIndigo,
              AppTheme.accentTeal.withValues(alpha: 0.8),
            ]),
          ),
          child: const Center(child: Text('🤖', style: TextStyle(fontSize: 14))),
        ),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: const Radius.circular(4)),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: m.isLoading
                ? const _TypingIndicator()
                : Text(m.text,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 15, height: 1.5)),
          ),
        ),
      ]),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.cardBorder, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Ask Nidra anything...',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppTheme.cardBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppTheme.cardBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        const BorderSide(color: AppTheme.primaryIndigo)),
              ),
              onSubmitted: _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(_ctrl.text),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _sending ? AppTheme.cardBorder : AppTheme.primaryIndigo,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _sendMessage(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() {
      _sending = true;
      _messages.add(_Message(msg, isUser: true));
      _messages.add(_Message('', isLoading: true));
    });
    _scrollDown();

    final buffer = StringBuffer();
    final idx = _messages.length - 1;

    await for (final chunk in _gemini.chat(msg, latestReport: _latestReport)) {
      buffer.write(chunk);
      if (mounted) {
        setState(() {
          _messages[idx] = _Message(buffer.toString());
        });
      }
    }
    if (mounted) setState(() => _sending = false);
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Opacity(
              opacity: (((_ctrl.value * 3) - i).clamp(0.0, 1.0)),
              child: const CircleAvatar(
                  radius: 4, backgroundColor: AppTheme.primaryIndigo),
            ),
          ),
        );
      }),
    );
  }
}
