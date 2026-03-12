import '../../core/constants/app_constants.dart';
import '../../core/utils/journey_insights.dart';
import 'player_profile.dart';

enum AchievementTier { common, rare, epic, legendary }

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.currentValue,
    required this.targetValue,
    required this.tier,
    required this.isUnlocked,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final int currentValue;
  final int targetValue;
  final AchievementTier tier;
  final bool isUnlocked;

  int get displayedCurrentValue {
    if (currentValue <= 0) return 0;
    if (targetValue <= 0) return currentValue;
    return currentValue > targetValue ? targetValue : currentValue;
  }

  double get progress {
    if (targetValue <= 0) return 1;
    final ratio = displayedCurrentValue / targetValue;
    if (ratio < 0) return 0;
    if (ratio > 1) return 1;
    return ratio;
  }
}

class AchievementCatalog {
  static List<Achievement> build(PlayerProfile profile) {
    final cells = profile.discoveredCells.length;
    final wholeKm = (profile.totalDistanceMeters / 1000.0).floor();
    final steps =
        (profile.totalDistanceMeters / AppConstants.averageStepLengthMeters)
            .round();
    final reveals = profile.reveals.length;
    final journeyInsights = JourneyInsights.fromProfile(profile);
    final expeditions = journeyInsights.expeditions.length;
    final activeDays = journeyInsights.activeDays;

    return [
      _milestone(
        id: 'first_footfall',
        title: 'First Footfall',
        description: 'Reveal your first piece of misted land.',
        category: 'Exploration',
        currentValue: cells,
        targetValue: 1,
        tier: AchievementTier.common,
      ),
      _milestone(
        id: 'trail_scout',
        title: 'Trail Scout',
        description: 'Reveal 25 explored cells.',
        category: 'Exploration',
        currentValue: cells,
        targetValue: 25,
        tier: AchievementTier.common,
      ),
      _milestone(
        id: 'cartographers_oath',
        title: 'Cartographer\'s Oath',
        description: 'Reveal 100 explored cells.',
        category: 'Exploration',
        currentValue: cells,
        targetValue: 100,
        tier: AchievementTier.rare,
      ),
      _milestone(
        id: 'realm_surveyor',
        title: 'Realm Surveyor',
        description: 'Reveal 250 explored cells.',
        category: 'Exploration',
        currentValue: cells,
        targetValue: 250,
        tier: AchievementTier.epic,
      ),
      _milestone(
        id: 'worldbreaker',
        title: 'Worldbreaker',
        description: 'Reveal 1,000 explored cells.',
        category: 'Exploration',
        currentValue: cells,
        targetValue: 1000,
        tier: AchievementTier.legendary,
      ),
      _milestone(
        id: 'road_dust',
        title: 'Road Dust',
        description: 'Log 1,000 steps across the kingdom.',
        category: 'Footfalls',
        currentValue: steps,
        targetValue: 1000,
        tier: AchievementTier.common,
      ),
      _milestone(
        id: 'marching_orders',
        title: 'Marching Orders',
        description: 'Log 5,000 steps beneath the fog.',
        category: 'Footfalls',
        currentValue: steps,
        targetValue: 5000,
        tier: AchievementTier.rare,
      ),
      _milestone(
        id: 'ironstride',
        title: 'Ironstride',
        description: 'Log 25,000 steps on your campaign.',
        category: 'Footfalls',
        currentValue: steps,
        targetValue: 25000,
        tier: AchievementTier.epic,
      ),
      _milestone(
        id: 'endless_march',
        title: 'Endless March',
        description: 'Log 100,000 steps in the world beyond the fog.',
        category: 'Footfalls',
        currentValue: steps,
        targetValue: 100000,
        tier: AchievementTier.legendary,
      ),
      _milestone(
        id: 'ember_trail',
        title: 'Ember Trail',
        description: 'Record 10 reveal points on your war map.',
        category: 'Trail',
        currentValue: reveals,
        targetValue: 10,
        tier: AchievementTier.common,
      ),
      _milestone(
        id: 'pathfinder',
        title: 'Pathfinder',
        description: 'Record 50 reveal points on your war map.',
        category: 'Trail',
        currentValue: reveals,
        targetValue: 50,
        tier: AchievementTier.common,
      ),
      _milestone(
        id: 'chronicler',
        title: 'Chronicler',
        description: 'Record 250 reveal points on your war map.',
        category: 'Trail',
        currentValue: reveals,
        targetValue: 250,
        tier: AchievementTier.rare,
      ),
      _milestone(
        id: 'trailblazer',
        title: 'Trailblazer',
        description: 'Record 500 reveal points on your war map.',
        category: 'Trail',
        currentValue: reveals,
        targetValue: 500,
        tier: AchievementTier.epic,
      ),
      _milestone(
        id: 'first_expedition',
        title: 'First Expedition',
        description: 'Complete your first atlas-worthy expedition.',
        category: 'Expedition',
        currentValue: expeditions,
        targetValue: 1,
        tier: AchievementTier.common,
      ),
      _milestone(
        id: 'road_journal',
        title: 'Road Journal',
        description: 'Log 5 expedition sessions in your atlas.',
        category: 'Expedition',
        currentValue: expeditions,
        targetValue: 5,
        tier: AchievementTier.common,
      ),
      _milestone(
        id: 'atlas_chronicler',
        title: 'Atlas Chronicler',
        description: 'Log 15 expedition sessions in your atlas.',
        category: 'Expedition',
        currentValue: expeditions,
        targetValue: 15,
        tier: AchievementTier.rare,
      ),
      _milestone(
        id: 'seasoned_realmwalker',
        title: 'Seasoned Realmwalker',
        description: 'Log 40 expedition sessions across the realm.',
        category: 'Expedition',
        currentValue: expeditions,
        targetValue: 40,
        tier: AchievementTier.epic,
      ),
      _milestone(
        id: 'many_moons',
        title: 'Many Moons',
        description: 'Explore on 7 distinct days.',
        category: 'Expedition',
        currentValue: activeDays,
        targetValue: 7,
        tier: AchievementTier.common,
      ),
      _milestone(
        id: 'road_calendar',
        title: 'Road Calendar',
        description: 'Explore on 30 distinct days.',
        category: 'Expedition',
        currentValue: activeDays,
        targetValue: 30,
        tier: AchievementTier.rare,
      ),
      _milestone(
        id: 'realm_walker',
        title: 'Realm Walker',
        description: 'Travel 10 kilometers through the wilds.',
        category: 'Distance',
        currentValue: wholeKm,
        targetValue: 10,
        tier: AchievementTier.common,
      ),
      _milestone(
        id: 'voyager',
        title: 'Voyager',
        description: 'Travel 50 kilometers through the wilds.',
        category: 'Distance',
        currentValue: wholeKm,
        targetValue: 50,
        tier: AchievementTier.rare,
      ),
      _milestone(
        id: 'world_roadwarden',
        title: 'World Roadwarden',
        description: 'Travel 100 kilometers through the wilds.',
        category: 'Distance',
        currentValue: wholeKm,
        targetValue: 100,
        tier: AchievementTier.epic,
      ),
      _milestone(
        id: 'mythic_roadwarden',
        title: 'Mythic Roadwarden',
        description: 'Travel 250 kilometers through the wilds.',
        category: 'Distance',
        currentValue: wholeKm,
        targetValue: 250,
        tier: AchievementTier.legendary,
      ),
    ];
  }

  static Achievement _milestone({
    required String id,
    required String title,
    required String description,
    required String category,
    required int currentValue,
    required int targetValue,
    required AchievementTier tier,
  }) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      category: category,
      currentValue: currentValue,
      targetValue: targetValue,
      tier: tier,
      isUnlocked: currentValue >= targetValue,
    );
  }
}
