import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../cloud/auth/cognito_auth_service.dart';
import '../cloud/map_mode.dart';
import '../cloud/models/landmark_models.dart';
import '../cloud/models/shared_viewport_models.dart';
import '../cloud/services/appsync_service.dart';
import '../cloud/services/landmark_upload_service.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/discovery_math.dart';
import '../data/models/achievement.dart';
import '../data/models/cloud_discovery_cell.dart';
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
    required this.authService,
    required this.appsyncService,
    required this.landmarkUploadService,
  });

  final LocalProfileStore localProfileStore;
  final LocationService locationService;
  final ShareService shareService;
  final CognitoAuthService authService;
  final AppSyncService appsyncService;
  final LandmarkUploadService landmarkUploadService;

  final MapController mapController = MapController();
  final Distance _distance = const Distance();

  late PlayerProfile _profile;
  StreamSubscription<Position>? _positionSub;
  Timer? _cloudSyncTimer;
  Timer? _sharedViewportTimer;

  final Map<String, CloudDiscoveryCell> _pendingCloudCells = {};

  bool _initialized = false;
  bool _tracking = false;
  bool _busy = false;
  bool _sharedLoading = false;
  String? _error;
  LatLng? _currentLatLng;
  MapMode _mapMode = MapMode.personal;
  SharedViewportResponse _sharedViewport = SharedViewportResponse.empty();
  List<PendingLandmark> _pendingLandmarks = const [];

  bool get initialized => _initialized;
  bool get tracking => _tracking;
  bool get busy => _busy;
  bool get sharedLoading => _sharedLoading;
  String? get error => _error;
  PlayerProfile get profile => _profile;
  LatLng? get currentLatLng => _currentLatLng;
  MapMode get mapMode => _mapMode;
  SharedViewportResponse get sharedViewport => _sharedViewport;
  List<PendingLandmark> get pendingLandmarks => _pendingLandmarks;

  bool get isSignedIn => authService.isSignedIn;
  bool get isAdminOrModerator =>
      authService.currentSession?.isAdminOrModerator ?? false;
  String? get signedInEmail => authService.currentSession?.email;

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

  List<RevealPoint> get activeFogReveals {
    if (_mapMode == MapMode.personal) return reveals;

    final merged = <String, RevealPoint>{};

    for (final reveal in reveals) {
      final key =
          '${reveal.latitude.toStringAsFixed(6)}:${reveal.longitude.toStringAsFixed(6)}';
      merged[key] = reveal;
    }

    for (final cell in _sharedViewport.cells) {
      final key =
          '${cell.lat.toStringAsFixed(6)}:${cell.lon.toStringAsFixed(6)}';
      merged.putIfAbsent(
        key,
        () => RevealPoint(
          latitude: cell.lat,
          longitude: cell.lon,
          discoveredAtIso: cell.lastDiscoveredAt,
        ),
      );
    }

    return merged.values.toList();
  }

  List<SharedPlayer> get sharedPlayers => _sharedViewport.players;
  List<SharedLandmark> get sharedLandmarks => _sharedViewport.landmarks;

  Future<void> init() async {
    _profile = await localProfileStore.load();
    await authService.init();

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

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await authService.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  Future<void> confirmSignUp({
    required String email,
    required String code,
  }) async {
    await authService.confirmSignUp(email: email, code: code);
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await authService.signIn(email: email, password: password);
    notifyListeners();
  }

  Future<void> signOut() async {
    await authService.signOut();
    _mapMode = MapMode.personal;
    _sharedViewport = SharedViewportResponse.empty();
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

  Future<void> setMapMode(MapMode mode, {MapCamera? camera}) async {
    if (mode == MapMode.shared && !isSignedIn) {
      _error = 'Please sign in to use Shared mode.';
      notifyListeners();
      return;
    }

    _mapMode = mode;
    notifyListeners();

    if (_mapMode == MapMode.shared && camera != null) {
      await refreshSharedViewport(camera);
    }
  }

  Future<void> refreshSharedViewport(MapCamera camera) async {
    if (!isSignedIn || _mapMode != MapMode.shared) return;

    _sharedLoading = true;
    notifyListeners();

    try {
      final bounds = camera.visibleBounds;
      final viewport = await appsyncService.getSharedViewport(
        minLat: bounds.southEast.latitude,
        maxLat: bounds.northWest.latitude,
        minLon: bounds.northWest.longitude,
        maxLon: bounds.southEast.longitude,
        zoom: camera.zoom.round(),
      );
      _sharedViewport = viewport;
    } catch (e) {
      _error = e.toString();
    } finally {
      _sharedLoading = false;
      notifyListeners();
    }
  }

  void scheduleSharedViewportRefresh(MapCamera camera) {
    _sharedViewportTimer?.cancel();
    _sharedViewportTimer = Timer(
      const Duration(seconds: 2),
      () => refreshSharedViewport(camera),
    );
  }

  Future<void> uploadLandmark({
    required String title,
    required String description,
    required String category,
    required int mapZoom,
  }) async {
    final current = _currentLatLng;
    if (current == null) {
      throw Exception('Current location is not available yet.');
    }

    final file = await landmarkUploadService.pickFromCamera();
    if (file == null) return;

    await landmarkUploadService.uploadLandmark(
      file: file,
      title: title,
      description: description,
      category: category,
      lat: current.latitude,
      lon: current.longitude,
      mapZoom: mapZoom,
    );
  }

  Future<void> loadPendingLandmarks() async {
    if (!isAdminOrModerator) return;
    _pendingLandmarks = await appsyncService.listPendingLandmarks();
    notifyListeners();
  }

  Future<String> getPendingLandmarkReviewUrl(String landmarkId) {
    return appsyncService.getPendingLandmarkReviewUrl(landmarkId);
  }

  Future<void> moderateLandmark({
    required String landmarkId,
    required bool approve,
    String moderationNotes = '',
  }) async {
    await appsyncService.moderateLandmark(
      landmarkId: landmarkId,
      approve: approve,
      moderationNotes: moderationNotes,
    );
    await loadPendingLandmarks();
  }

  Future<String> getLandmarkViewUrl(String landmarkId) {
    return appsyncService.getLandmarkViewUrl(landmarkId);
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
      final revealTime = DateTime.now().toUtc().toIso8601String();
      updatedReveals.add(
        RevealPoint(
          latitude: point.latitude,
          longitude: point.longitude,
          discoveredAtIso: revealTime,
        ),
      );

      final cloudCells = DiscoveryMath.cellsForRevealData(
        point: point,
        radiusMeters: AppConstants.discoveryRadiusMeters,
        cellDegrees: AppConstants.statsCellDegrees,
      );

      updatedCells.addAll(cloudCells.map((e) => e.cellId));
      for (final cell in cloudCells) {
        _pendingCloudCells[cell.cellId] = cell;
      }
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
    _scheduleCloudSync();
    notifyListeners();
  }

  void _scheduleCloudSync() {
    if (!isSignedIn || _currentLatLng == null) return;

    _cloudSyncTimer?.cancel();
    _cloudSyncTimer = Timer(const Duration(seconds: 6), () async {
      try {
        final cells = _pendingCloudCells.values.toList();
        _pendingCloudCells.clear();

        await appsyncService.syncDiscoveries(
          cells: cells,
          currentLat: _currentLatLng?.latitude,
          currentLon: _currentLatLng?.longitude,
          mapZoom: 17,
          displayName: _profile.displayName,
        );

        if (_mapMode == MapMode.shared && mapController.camera.visibleBounds != null) {
          await refreshSharedViewport(mapController.camera);
        }
      } catch (e) {
        _error = e.toString();
        notifyListeners();
      }
    });
  }

  bool _shouldCreateReveal(LatLng point) {
    if (_profile.reveals.isEmpty) return true;
    final last = _profile.reveals.last;
    final meters = _distance(point, LatLng(last.latitude, last.longitude));
    return meters >= AppConstants.minDistanceBetweenRevealsMeters;
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _cloudSyncTimer?.cancel();
    _sharedViewportTimer?.cancel();
    super.dispose();
  }
}