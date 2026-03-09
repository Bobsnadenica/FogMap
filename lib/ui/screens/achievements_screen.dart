import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../data/models/achievement.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final List<Achievement> achievements = controller.achievements;
        final int unlocked =
            achievements.where((e) => e.isUnlocked).length;

        return Scaffold(
          appBar: AppBar(title: const Text('Achievements')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events, size: 32),
                      const SizedBox(width: 12),
                      Text(
                        '$unlocked / ${achievements.length} unlocked',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...achievements.map(
                (achievement) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                        achievement.isUnlocked
                            ? Icons.auto_awesome
                            : Icons.lock_outline,
                      ),
                      title: Text(achievement.title),
                      subtitle: Text(achievement.description),
                      trailing: achievement.isUnlocked
                          ? const Icon(Icons.check_circle)
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}