class SharedCell {
  const SharedCell({
    required this.cellId,
    required this.lat,
    required this.lon,
    required this.discovererCount,
    required this.tileId,
    required this.lastDiscoveredAt,
  });

  final String cellId;
  final double lat;
  final double lon;
  final int discovererCount;
  final String tileId;
  final String lastDiscoveredAt;

  factory SharedCell.fromJson(Map<String, dynamic> json) {
    return SharedCell(
      cellId: json['cellId'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      discovererCount: json['discovererCount'] as int? ?? 1,
      tileId: json['tileId'] as String? ?? '',
      lastDiscoveredAt: json['lastDiscoveredAt'] as String? ?? '',
    );
  }
}

class SharedPlayer {
  const SharedPlayer({
    required this.userId,
    required this.displayName,
    required this.lat,
    required this.lon,
    required this.lastSeenAt,
  });

  final String userId;
  final String displayName;
  final double lat;
  final double lon;
  final String lastSeenAt;

  factory SharedPlayer.fromJson(Map<String, dynamic> json) {
    return SharedPlayer(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String? ?? 'Explorer',
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      lastSeenAt: json['lastSeenAt'] as String? ?? '',
    );
  }
}

class SharedLandmark {
  const SharedLandmark({
    required this.landmarkId,
    required this.title,
    required this.description,
    required this.category,
    required this.lat,
    required this.lon,
    required this.status,
    this.approvedObjectKey,
    this.createdAt,
  });

  final String landmarkId;
  final String title;
  final String description;
  final String category;
  final double lat;
  final double lon;
  final String status;
  final String? approvedObjectKey;
  final String? createdAt;

  factory SharedLandmark.fromJson(Map<String, dynamic> json) {
    return SharedLandmark(
      landmarkId: json['landmarkId'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      status: json['status'] as String? ?? 'UNKNOWN',
      approvedObjectKey: json['approvedObjectKey'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}

class SharedViewportResponse {
  const SharedViewportResponse({
    required this.worldId,
    required this.cells,
    required this.players,
    required this.landmarks,
    required this.generatedAt,
  });

  final String worldId;
  final List<SharedCell> cells;
  final List<SharedPlayer> players;
  final List<SharedLandmark> landmarks;
  final String generatedAt;

  factory SharedViewportResponse.empty() {
    return const SharedViewportResponse(
      worldId: 'global',
      cells: <SharedCell>[],
      players: <SharedPlayer>[],
      landmarks: <SharedLandmark>[],
      generatedAt: '',
    );
  }

  factory SharedViewportResponse.fromJson(Map<String, dynamic> json) {
    return SharedViewportResponse(
      worldId: json['worldId'] as String? ?? 'global',
      cells: ((json['cells'] as List?) ?? const [])
          .map((e) => SharedCell.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      players: ((json['players'] as List?) ?? const [])
          .map((e) => SharedPlayer.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      landmarks: ((json['landmarks'] as List?) ?? const [])
          .map((e) => SharedLandmark.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      generatedAt: json['generatedAt'] as String? ?? '',
    );
  }
}