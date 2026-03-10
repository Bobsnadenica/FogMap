class AppConstants {
  static const String appName = 'FogFrontier';

  static const String userAgentPackageName = 'com.example.world_of_fog';

  static const String tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const double initialZoom = 16.0;
  static const double minZoom = 2.0;
  static const double maxZoom = 18.0;

  static const double discoveryRadiusMeters = 8.0;
  static const double minDistanceBetweenRevealsMeters = 8.0;
  static const double statsCellDegrees = 0.00018;

  static const double maxAcceptedAccuracyMeters = 12.0;
  static const double maxInitialFixAccuracyMeters = 15.0;
  static const double maxPreviewAccuracyMeters = 35.0;
  static const double minAcceptedMovementMeters = 6.0;
  static const double maxAcceptedSpeedMetersPerSecond = 12.0;
  static const double maxReasonableJumpMeters = 60.0;
  static const int maxAcceptedLocationAgeSeconds = 15;
  static const int maxDistanceCarryForwardGapSeconds = 180;
  static const int initialFixSampleCount = 2;
  static const int initialFixStabilizationWindowSeconds = 12;
  static const double initialFixMaxClusterSpreadMeters = 10.0;
  static const int initialFixBootstrapAttempts = 4;
  static const int initialFixBootstrapDelaySeconds = 2;
  static const int sharedViewportRefreshSeconds = 15;
  static const int sharedViewportCacheTtlSeconds = 15;
  static const int sharedViewportDebounceMilliseconds = 650;
  static const int sharedViewportCacheMaxEntries = 24;
  static const int cloudSyncBatchSize = 200;

  static const double defaultLat = 20.0;
  static const double defaultLon = 0.0;

  static const String profileFileName = 'player_profile.json';
}
