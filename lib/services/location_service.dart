import 'dart:io';

import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<void> ensureReady({bool requireBackground = true}) async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('Location services are disabled on this device.');
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
        'Location permission is permanently denied. Open app settings and allow location access.',
      );
    }

    if (requireBackground && permission != LocationPermission.always) {
      await Geolocator.openAppSettings();
      throw Exception(
        'Background tracking requires "Always" location permission. I opened app settings so you can enable it.',
      );
    }
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
}