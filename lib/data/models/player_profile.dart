import 'reveal_point.dart';

class PlayerProfile {
  PlayerProfile({
    required this.id,
    required this.displayName,
    required this.createdAtIso,
    required this.updatedAtIso,
    required this.reveals,
    required this.discoveredCells,
    required this.totalDistanceMeters,
    this.lastLatitude,
    this.lastLongitude,
  });

  final String id;
  final String displayName;
  final String createdAtIso;
  final String updatedAtIso;
  final List<RevealPoint> reveals;
  final Set<String> discoveredCells;
  final double totalDistanceMeters;
  final double? lastLatitude;
  final double? lastLongitude;

  PlayerProfile copyWith({
    String? id,
    String? displayName,
    String? createdAtIso,
    String? updatedAtIso,
    List<RevealPoint>? reveals,
    Set<String>? discoveredCells,
    double? totalDistanceMeters,
    double? lastLatitude,
    double? lastLongitude,
  }) {
    return PlayerProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      createdAtIso: createdAtIso ?? this.createdAtIso,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
      reveals: reveals ?? this.reveals,
      discoveredCells: discoveredCells ?? this.discoveredCells,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      lastLatitude: lastLatitude ?? this.lastLatitude,
      lastLongitude: lastLongitude ?? this.lastLongitude,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'createdAtIso': createdAtIso,
        'updatedAtIso': updatedAtIso,
        'reveals': reveals.map((e) => e.toJson()).toList(),
        'discoveredCells': discoveredCells.toList(),
        'totalDistanceMeters': totalDistanceMeters,
        'lastLatitude': lastLatitude,
        'lastLongitude': lastLongitude,
      };

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      createdAtIso: json['createdAtIso'] as String,
      updatedAtIso: json['updatedAtIso'] as String,
      reveals: (json['reveals'] as List<dynamic>)
          .map((e) => RevealPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      discoveredCells: (json['discoveredCells'] as List<dynamic>)
          .map((e) => e.toString())
          .toSet(),
      totalDistanceMeters: (json['totalDistanceMeters'] as num).toDouble(),
      lastLatitude: (json['lastLatitude'] as num?)?.toDouble(),
      lastLongitude: (json['lastLongitude'] as num?)?.toDouble(),
    );
  }

  static PlayerProfile createEmpty({
    String id = 'local-player',
    String displayName = 'Adventurer',
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    return PlayerProfile(
      id: id,
      displayName: displayName,
      createdAtIso: now,
      updatedAtIso: now,
      reveals: const [],
      discoveredCells: <String>{},
      totalDistanceMeters: 0,
    );
  }
}
