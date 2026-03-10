import 'dart:io';

import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<void> ensureReady({bool requireBackground = true}) async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      await Geolocator.openLocationSettings();
      throw Exception(
        'Location services are disabled. Please enable location services and reopen the app.',
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission was denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      throw Exception(
        'Location permission is permanently denied. I opened app settings so you can enable it.',
      );
    }

    if (requireBackground && permission == LocationPermission.whileInUse) {
      // Try one more permission request. On some platforms this may upgrade.
      permission = await Geolocator.requestPermission();
    }

    if (requireBackground && permission != LocationPermission.always) {
      if (Platform.isIOS || Platform.isAndroid) {
        await Geolocator.openAppSettings();
      }
      throw Exception(
        'Background tracking requires "Always" location permission. I opened app settings so you can enable it.',
      );
    }
  }

  Future<Position> getCurrentPosition() {
    return Geolocator.getCurrentPosition(
      locationSettings: _platformCurrentSettings(),
    );
  }

  Stream<Position> stream() {
    return Geolocator.getPositionStream(
      locationSettings: _platformSettings(),
    );
  }

  LocationSettings _platformSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
        intervalDuration: const Duration(seconds: 8),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'World Of Fog is tracking location',
          notificationText:
              'Background exploration is active while you move.',
          enableWakeLock: true,
        ),
      );
    }

    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 8,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 8,
    );
  }

  LocationSettings _platformCurrentSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
      );
    }

    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
    );
  }
}
