import 'package:flutter/material.dart';
import 'package:snore_clinics/core/theme/app_theme.dart';
import 'package:snore_clinics/modules/sleep_analysis/screens/sleep_analysis_screen.dart';
import 'package:snore_clinics/modules/journal/screens/calendarized_journal_screen.dart';
import 'package:snore_clinics/modules/ai/screens/insights_screen.dart';
import 'package:snore_clinics/modules/ai/screens/nidra_chat_screen.dart';
import 'package:snore_clinics/screens/home_screen.dart';

class MainNavScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const SleepAnalysisScreen(),
    const CalendarizedJournalScreen(),
    const InsightsScreen(),
    const NidraChatScreen(),
  ];

  final List<BottomNavigationBarItem> _items = const [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
    BottomNavigationBarItem(icon: Icon(Icons.mic_rounded), label: 'Record'),
    BottomNavigationBarItem(icon: Icon(Icons.book_rounded), label: 'Journal'),
    BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Insights'),
    BottomNavigationBarItem(icon: Icon(Icons.smart_toy_rounded), label: 'Nidra'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.cardBorder, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: _items,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.surface,
          selectedItemColor: AppTheme.primaryIndigo,
          unselectedItemColor: AppTheme.textSecondary,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 0,
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _currentIndex = 4; // Nidra Chat
                });
              },
              backgroundColor: AppTheme.primaryIndigo,
              tooltip: 'Ask Nidra',
              child: const Text('🤖', style: TextStyle(fontSize: 22)),
            )
          : null,
    );
  }
}
