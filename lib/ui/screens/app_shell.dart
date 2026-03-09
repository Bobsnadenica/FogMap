import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import 'achievements_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      MapScreen(controller: widget.controller),
      ProfileScreen(controller: widget.controller),
      AchievementsScreen(controller: widget.controller),
    ];

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final error = widget.controller.error;
          if (error != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
            widget.controller.clearError();
          }
        });

        return Scaffold(
          body: IndexedStack(index: _index, children: screens),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _index,
            onTap: (value) => setState(() => _index = value),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.map),
                label: 'Map',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.emoji_events_outlined),
                activeIcon: Icon(Icons.emoji_events),
                label: 'Achievements',
              ),
            ],
          ),
        );
      },
    );
  }
}