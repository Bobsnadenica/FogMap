import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/discovery_math.dart';
import '../data/models/achievement.dart';
import '../data/models/player_profile.dart';
import '../data/models/reveal_point.dart';
import '../services/local_profile_store.dart';
import '../services/location_service.dart';
import '../services/share_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    required this.localProfileStore,
    required this.locationService,
    required this.shareService,
  });

  final LocalProfileStore localProfileStore;
  final LocationService locationService;
  final ShareService shareService;

  final MapController mapController = MapController();
  final Distance _distance = const Distance();

  late PlayerProfile _profile;
  StreamSubscription<Position>? _positionSub;

  bool _initialized = false;
  bool _tracking = false;
  bool _busy = false;
  String? _error;
  LatLng? _currentLatLng;

  bool get initialized => _initialized;
  bool get tracking => _tracking;
  bool get busy => _busy;
  String? get error => _error;
  PlayerProfile get profile => _profile;
  LatLng? get currentLatLng => _currentLatLng;

  List<RevealPoint> get reveals => _profile.reveals;

  List<LatLng> get revealLatLngs =>
      _profile.reveals.map((e) => LatLng(e.latitude, e.longitude)).toList();

  List<Achievement> get achievements => AchievementCatalog.build(_profile);

  double get totalKm => _profile.totalDistanceMeters / 1000.0;

  int get discoveredCellsCount => _profile.discoveredCells.length;

  double get coveragePercent => DiscoveryMath.coveragePercent(
        discoveredCells: discoveredCellsCount,
        cellDegrees: AppConstants.statsCellDegrees,
      );

  Future<void> init() async {
    _profile = await localProfileStore.load();

    if (_profile.lastLatitude != null && _profile.lastLongitude != null) {
      _currentLatLng = LatLng(_profile.lastLatitude!, _profile.lastLongitude!);
    }

    _initialized = true;
    notifyListeners();

    await startTracking();
  }

  Future<void> startTracking() async {
    if (_tracking || _busy) return;

    _busy = true;
    _error = null;
    notifyListeners();

    try {
      await locationService.ensureReady();

      await _positionSub?.cancel();
      _positionSub = locationService.stream().listen(
        _handlePosition,
        onError: (Object err) {
          _error = err.toString();
          _tracking = false;
          notifyListeners();
        },
      );

      _tracking = true;
    } catch (e) {
      _error = e.toString();
      _tracking = false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> stopTracking() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _tracking = false;
    notifyListeners();
  }

  Future<void> setDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    _profile = _profile.copyWith(
      displayName: trimmed,
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
    );

    await localProfileStore.save(_profile);
    notifyListeners();
  }

  Future<void> share() async {
    await shareService.shareProfile(_profile);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _handlePosition(Position position) async {
    final point = LatLng(position.latitude, position.longitude);

    final previous = _currentLatLng;
    _currentLatLng = point;

    double totalMeters = _profile.totalDistanceMeters;
    if (previous != null) {
      totalMeters += _distance(previous, point);
    }

    final shouldReveal = _shouldCreateReveal(point);

    final updatedReveals = List<RevealPoint>.from(_profile.reveals);
    final updatedCells = Set<String>.from(_profile.discoveredCells);

    if (shouldReveal) {
      updatedReveals.add(
        RevealPoint(
          latitude: point.latitude,
          longitude: point.longitude,
          discoveredAtIso: DateTime.now().toUtc().toIso8601String(),
        ),
      );

      updatedCells.addAll(
        DiscoveryMath.cellsForReveal(
          point: point,
          radiusMeters: AppConstants.discoveryRadiusMeters,
          cellDegrees: AppConstants.statsCellDegrees,
        ),
      );
    }

    _profile = _profile.copyWith(
      reveals: updatedReveals,
      discoveredCells: updatedCells,
      totalDistanceMeters: totalMeters,
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
      lastLatitude: point.latitude,
      lastLongitude: point.longitude,
    );

    await localProfileStore.save(_profile);
    notifyListeners();
  }

  bool _shouldCreateReveal(LatLng point) {
    if (_profile.reveals.isEmpty) return true;

    final last = _profile.reveals.last;
    final meters = _distance(
      point,
      LatLng(last.latitude, last.longitude),
    );

    return meters >= AppConstants.minDistanceBetweenRevealsMeters;
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }
}