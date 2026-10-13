import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/progress_provider.dart';
import '../widgets/common.dart';
import 'home_tab.dart';
import 'practice_tab.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';

/// The bottom-navigation shell: Home, Practice, Progress and Settings.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const List<String> _titles = [
    'LinguaCoach AI',
    'Practice',
    'Your Progress',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    final pages = <Widget>[
      const HomeTab(),
      const PracticeTab(),
      const ProgressScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          PillBadge(
            icon: Icons.local_fire_department,
            label: '${progress.streak}',
            color: Colors.deepOrange,
          ),
          const SizedBox(width: 8),
          PillBadge(
            icon: Icons.bolt,
            label: '${progress.totalXp} XP',
            color: Colors.amber.shade800,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic_none),
            selectedIcon: Icon(Icons.mic),
            label: 'Practice',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
