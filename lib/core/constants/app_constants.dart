class AppConstants {
  static const String appName = 'FogFrontier';

  // Replace this with your real package id before release.
  static const String userAgentPackageName = 'com.example.fogfrontier';

  static const String tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const double initialZoom = 16.0;
  static const double minZoom = 2.0;
  static const double maxZoom = 18.0;

  // Street-level discovery tuning.
  // Around a small patch of road / sidewalk rather than a huge area.
  static const double discoveryRadiusMeters = 8.0;
  static const double minDistanceBetweenRevealsMeters = 8.0;

  // Much smaller discovery cells so progress matches real movement.
  // Roughly street-scale cells.
  static const double statsCellDegrees = 0.00018;

  static const double defaultLat = 20.0;
  static const double defaultLon = 0.0;

  static const String profileFileName = 'player_profile.json';
}