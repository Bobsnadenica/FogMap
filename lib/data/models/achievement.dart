import 'player_profile.dart';

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.isUnlocked,
  });

  final String id;
  final String title;
  final String description;
  final bool isUnlocked;
}

class AchievementCatalog {
  static List<Achievement> build(PlayerProfile profile) {
    final cells = profile.discoveredCells.length;
    final km = profile.totalDistanceMeters / 1000.0;

    return [
      Achievement(
        id: 'first_step',
        title: 'First Step',
        description: 'Reveal your first piece of the world.',
        isUnlocked: cells >= 1,
      ),
      Achievement(
        id: 'trail_scout',
        title: 'Trail Scout',
        description: 'Reveal 25 cells.',
        isUnlocked: cells >= 25,
      ),
      Achievement(
        id: 'cartographer',
        title: 'Cartographer',
        description: 'Reveal 250 cells.',
        isUnlocked: cells >= 250,
      ),
      Achievement(
        id: 'realm_walker',
        title: 'Realm Walker',
        description: 'Walk 10 km.',
        isUnlocked: km >= 10,
      ),
      Achievement(
        id: 'voyager',
        title: 'Voyager',
        description: 'Walk 100 km.',
        isUnlocked: km >= 100,
      ),
      Achievement(
        id: 'worldbreaker',
        title: 'Worldbreaker',
        description: 'Reveal 1000 cells.',
        isUnlocked: cells >= 1000,
      ),
    ];
  }
}