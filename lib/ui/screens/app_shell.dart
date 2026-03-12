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
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final identityKey = widget.controller.profile.id;
        final screens = [
          MapScreen(
            key: ValueKey('map-$identityKey'),
            controller: widget.controller,
          ),
          ProfileScreen(
            key: ValueKey('profile-$identityKey'),
            controller: widget.controller,
          ),
          AchievementsScreen(
            key: ValueKey('achievements-$identityKey'),
            controller: widget.controller,
          ),
        ];

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
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF13100D),
                  Color(0xFF0F1318),
                ],
              ),
              border: Border(
                top: BorderSide(color: Color(0x22D6B36A)),
              ),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map),
                  label: 'Map',
                ),
                NavigationDestination(
                  icon: Icon(Icons.travel_explore_outlined),
                  selectedIcon: Icon(Icons.travel_explore),
                  label: 'Atlas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  selectedIcon: Icon(Icons.auto_awesome),
                  label: 'Deeds',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
