import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../core/utils/stat_formatters.dart';
import '../../data/models/achievement.dart';
import '../widgets/fantasy_panel.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final achievements = controller.achievements;
        final unlocked = achievements.where((e) => e.isUnlocked).length;
        final completion =
            achievements.isEmpty ? 0.0 : unlocked / achievements.length;
        final grouped = _groupAchievements(achievements);

        return Scaffold(
          appBar: AppBar(title: const Text('Deeds & Achievements')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FantasyPanel(
                background: const [
                  Color(0xEE2A180E),
                  Color(0xEE1B120C),
                  Color(0xEE11161B),
                ],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hall of Triumphs',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Track the campaign milestones of your wandering across the world map.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _OverviewStat(
                          label: 'Unlocked',
                          value: '$unlocked / ${achievements.length}',
                          icon: Icons.emoji_events,
                        ),
                        _OverviewStat(
                          label: 'Rank',
                          value: controller.adventurerRank,
                          icon: Icons.shield,
                        ),
                        _OverviewStat(
                          label: 'Steps',
                          value: StatFormatters.compactCount(
                            controller.estimatedSteps,
                          ),
                          icon: Icons.directions_walk,
                        ),
                        _OverviewStat(
                          label: 'World',
                          value: StatFormatters.percent(
                            controller.coveragePercent,
                            fractionDigits: 6,
                          ),
                          icon: Icons.public,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FantasyProgressBar(
                            value: completion,
                            height: 12,
                            fill: const [
                              Color(0xFF8A5A1F),
                              Color(0xFFE7C36F),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(completion * 100).toStringAsFixed(0)}%',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFE2C58F),
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ...grouped.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _AchievementSection(
                    category: entry.key,
                    achievements: entry.value,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, List<Achievement>> _groupAchievements(
      List<Achievement> achievements) {
    const categoryOrder = [
      'Exploration',
      'Expedition',
      'Trail',
      'Footfalls',
      'Distance',
    ];

    final grouped = <String, List<Achievement>>{};
    for (final achievement in achievements) {
      grouped
          .putIfAbsent(achievement.category, () => <Achievement>[])
          .add(achievement);
    }

    final ordered = <String, List<Achievement>>{};
    for (final category in categoryOrder) {
      final items = grouped.remove(category);
      if (items != null) {
        ordered[category] = items;
      }
    }
    ordered.addAll(grouped);
    return ordered;
  }
}

class _AchievementSection extends StatelessWidget {
  const _AchievementSection({
    required this.category,
    required this.achievements,
  });

  final String category;
  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievements.where((e) => e.isUnlocked).length;

    return FantasyPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0x33281710),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _categoryIcon(category),
                  color: const Color(0xFFE2C58F),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      '$unlocked / ${achievements.length} completed',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...achievements.map(
            (achievement) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AchievementTile(achievement: achievement),
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Exploration':
        return Icons.explore;
      case 'Expedition':
        return Icons.map_outlined;
      case 'Trail':
        return Icons.alt_route;
      case 'Footfalls':
        return Icons.hiking;
      case 'Distance':
        return Icons.public;
      default:
        return Icons.emoji_events;
    }
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final tierColor = _tierColor(achievement.tier);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: achievement.isUnlocked
            ? const Color(0x2A2D1E0D)
            : const Color(0x18120E0A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: achievement.isUnlocked
              ? tierColor.withValues(alpha: 0.55)
              : const Color(0x1FD6B36A),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  tierColor.withValues(alpha: 0.28),
                  const Color(0xFF15110D),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              achievement.isUnlocked
                  ? Icons.workspace_premium
                  : Icons.lock_outline,
              color:
                  achievement.isUnlocked ? tierColor : const Color(0xFF9EA5AC),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _TierBadge(
                      label: achievement.tier.name,
                      color: tierColor,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                FantasyProgressBar(
                  value: achievement.progress,
                  height: 10,
                  fill: [tierColor.withValues(alpha: 0.78), tierColor],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${StatFormatters.wholeNumber(achievement.currentValue)} / ${StatFormatters.wholeNumber(achievement.targetValue)}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: const Color(0xFFBCA587),
                          ),
                    ),
                    const Spacer(),
                    Text(
                      achievement.isUnlocked ? 'Unlocked' : 'In progress',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: achievement.isUnlocked
                                ? tierColor
                                : const Color(0xFFBCA587),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _tierColor(AchievementTier tier) {
    switch (tier) {
      case AchievementTier.common:
        return const Color(0xFFB4B9BF);
      case AchievementTier.rare:
        return const Color(0xFF5DA7FF);
      case AchievementTier.epic:
        return const Color(0xFFC36BFF);
      case AchievementTier.legendary:
        return const Color(0xFFFFC857);
    }
  }
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x22150F0B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22D6B36A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFE2C58F), size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFFBCA587),
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}
