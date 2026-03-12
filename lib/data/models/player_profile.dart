import '../../core/constants/profile_icon_catalog.dart';
import 'reveal_point.dart';

class PlayerProfile {
  PlayerProfile({
    required this.id,
    required this.displayName,
    required this.profileIcon,
    required this.createdAtIso,
    required this.updatedAtIso,
    required this.reveals,
    required this.discoveredCells,
    required this.totalDistanceMeters,
    required this.hasSeenMapGuide,
    this.lastCloudBootstrapAtIso,
    this.lastLatitude,
    this.lastLongitude,
  });

  final String id;
  final String displayName;
  final String profileIcon;
  final String createdAtIso;
  final String updatedAtIso;
  final List<RevealPoint> reveals;
  final Set<String> discoveredCells;
  final double totalDistanceMeters;
  final bool hasSeenMapGuide;
  final String? lastCloudBootstrapAtIso;
  final double? lastLatitude;
  final double? lastLongitude;

  PlayerProfile copyWith({
    String? id,
    String? displayName,
    String? profileIcon,
    String? createdAtIso,
    String? updatedAtIso,
    List<RevealPoint>? reveals,
    Set<String>? discoveredCells,
    double? totalDistanceMeters,
    bool? hasSeenMapGuide,
    String? lastCloudBootstrapAtIso,
    double? lastLatitude,
    double? lastLongitude,
  }) {
    return PlayerProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      profileIcon: profileIcon ?? this.profileIcon,
      createdAtIso: createdAtIso ?? this.createdAtIso,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
      reveals: reveals ?? this.reveals,
      discoveredCells: discoveredCells ?? this.discoveredCells,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      hasSeenMapGuide: hasSeenMapGuide ?? this.hasSeenMapGuide,
      lastCloudBootstrapAtIso:
          lastCloudBootstrapAtIso ?? this.lastCloudBootstrapAtIso,
      lastLatitude: lastLatitude ?? this.lastLatitude,
      lastLongitude: lastLongitude ?? this.lastLongitude,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'profileIcon': profileIcon,
        'createdAtIso': createdAtIso,
        'updatedAtIso': updatedAtIso,
        'reveals': reveals.map((e) => e.toJson()).toList(),
        'discoveredCells': discoveredCells.toList()..sort(),
        'totalDistanceMeters': totalDistanceMeters,
        'hasSeenMapGuide': hasSeenMapGuide,
        'lastCloudBootstrapAtIso': lastCloudBootstrapAtIso,
        'lastLatitude': lastLatitude,
        'lastLongitude': lastLongitude,
      };

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['id'] as String? ?? 'local-player',
      displayName: json['displayName'] as String? ?? 'Adventurer',
      profileIcon:
          json['profileIcon'] as String? ?? ProfileIconCatalog.defaultIcon,
      createdAtIso: json['createdAtIso'] as String? ??
          DateTime.now().toUtc().toIso8601String(),
      updatedAtIso: json['updatedAtIso'] as String? ??
          DateTime.now().toUtc().toIso8601String(),
      reveals: ((json['reveals'] as List<dynamic>?) ?? const <dynamic>[])
          .map((e) => RevealPoint.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      discoveredCells:
          ((json['discoveredCells'] as List<dynamic>?) ?? const <dynamic>[])
              .map((e) => e.toString())
              .toSet(),
      totalDistanceMeters:
          (json['totalDistanceMeters'] as num?)?.toDouble() ?? 0,
      hasSeenMapGuide: json['hasSeenMapGuide'] as bool? ?? false,
      lastCloudBootstrapAtIso: json['lastCloudBootstrapAtIso'] as String?,
      lastLatitude: (json['lastLatitude'] as num?)?.toDouble(),
      lastLongitude: (json['lastLongitude'] as num?)?.toDouble(),
    );
  }

  static PlayerProfile createEmpty({
    String id = 'local-player',
    String displayName = 'Adventurer',
    String profileIcon = ProfileIconCatalog.defaultIcon,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    return PlayerProfile(
      id: id,
      displayName: displayName,
      profileIcon: profileIcon,
      createdAtIso: now,
      updatedAtIso: now,
      reveals: const [],
      discoveredCells: <String>{},
      totalDistanceMeters: 0,
      hasSeenMapGuide: false,
    );
  }
}
