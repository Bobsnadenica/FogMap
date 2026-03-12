class AppConstants {
  static const String appName = 'Mist of Atlas';

  static const String userAgentPackageName = 'com.example.world_of_fog';

  static const String tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const double initialZoom = 16.0;
  static const double minZoom = 2.0;
  static const double maxZoom = 18.0;

  static const double discoveryRadiusMeters = 8.0;
  static const double minDistanceBetweenRevealsMeters = 8.0;
  static const double statsCellDegrees = 0.00018;
  static const double averageStepLengthMeters = 0.78;

  static const double maxAcceptedAccuracyMeters = 12.0;
  static const double maxInitialFixAccuracyMeters = 15.0;
  static const double maxPreviewAccuracyMeters = 35.0;
  static const double minAcceptedMovementMeters = 6.0;
  static const double stationaryJitterMeters = 4.0;
  static const double maxAcceptedSpeedMetersPerSecond = 12.0;
  static const double maxReasonableJumpMeters = 60.0;
  static const double discoverySmoothingMinBlend = 0.35;
  static const double discoverySmoothingMaxBlend = 0.82;
  static const double revealPathPointSpacingMeters = 3.0;
  static const int maxAcceptedLocationAgeSeconds = 15;
  static const int maxDistanceCarryForwardGapSeconds = 180;
  static const int initialFixSampleCount = 2;
  static const int initialFixStabilizationWindowSeconds = 12;
  static const double initialFixMaxClusterSpreadMeters = 10.0;
  static const int initialFixBootstrapAttempts = 4;
  static const int initialFixBootstrapDelaySeconds = 2;
  static const int locationStreamDistanceFilterMeters = 3;
  static const int locationStreamIntervalSeconds = 3;
  static const int sharedViewportRefreshSeconds = 8;
  static const int sharedViewportCacheTtlSeconds = 6;
  static const int sharedViewportDebounceMilliseconds = 650;
  static const int sharedViewportCacheMaxEntries = 24;
  static const int sharedViewportPersistedCacheMaxAgeHours = 24;
  static const int sharedViewportPersistedCellLimit = 30000;
  static const int sharedViewportPersistedLandmarkLimit = 2000;
  static const int cloudSyncBatchSize = 200;
  static const int personalBootstrapRefreshHours = 12;

  static const double defaultLat = 20.0;
  static const double defaultLon = 0.0;

  static const String profileFileName = 'player_profile.json';
}
