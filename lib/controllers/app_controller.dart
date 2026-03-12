import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../cloud/auth/cognito_auth_service.dart';
import '../cloud/auth/sign_in_flow.dart';
import '../cloud/backend_config.dart';
import '../cloud/map_mode.dart';
import '../cloud/models/landmark_models.dart';
import '../cloud/models/shared_viewport_models.dart';
import '../cloud/services/appsync_service.dart';
import '../cloud/services/landmark_upload_service.dart';
import '../cloud/services/shared_tile_service.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/profile_icon_catalog.dart';
import '../core/utils/discovery_math.dart';
import '../data/models/achievement.dart';
import '../data/models/cloud_discovery_cell.dart';
import '../data/models/player_profile.dart';
import '../data/models/reveal_point.dart';
import '../services/local_profile_store.dart';
import '../services/location_service.dart';
import '../services/share_service.dart';
import '../services/shared_map_cache_store.dart';

class AppController extends ChangeNotifier {
  AppController({
    required this.localProfileStore,
    required this.locationService,
    required this.shareService,
    required this.sharedMapCacheStore,
    required this.authService,
    required this.appsyncService,
    required this.landmarkUploadService,
    required this.sharedTileService,
  });

  final LocalProfileStore localProfileStore;
  final LocationService locationService;
  final ShareService shareService;
  final SharedMapCacheStore sharedMapCacheStore;
  final CognitoAuthService authService;
  final AppSyncService appsyncService;
  final LandmarkUploadService landmarkUploadService;
  final SharedTileService sharedTileService;

  final MapController mapController = MapController();
  final Distance _distance = const Distance();
  final List<_AcceptedLocation> _initialFixSamples = [];

  late PlayerProfile _profile;
  StreamSubscription<Position>? _positionSub;
  Timer? _cloudSyncTimer;
  Timer? _sharedCachePersistTimer;
  Timer? _sharedViewportDebounceTimer;
  Timer? _sharedViewportPollTimer;
  DateTime? _lastAcceptedFixAt;
  double? _lastAcceptedAccuracyMeters;
  LatLng? _lastDiscoveryLatLng;
  String _activeProfileKey = LocalProfileStore.guestProfileKey;

  final Map<String, CloudDiscoveryCell> _pendingCloudCells = {};
  final Map<String, _SharedViewportCacheEntry> _sharedViewportCache = {};
  final Map<String, SharedCell> _sharedCellStore = {};
  final Map<String, SharedLandmark> _sharedLandmarkStore = {};
  String _sharedStoreGeneratedAt = '';

  bool _initialized = false;
  bool _tracking = false;
  bool _busy = false;
  bool _sharedLoading = false;
  bool _cloudSyncInFlight = false;
  String? _error;
  LatLng? _currentLatLng;
  LatLng? _savedMapCenterLatLng;
  MapMode _mapMode = MapMode.personal;
  SharedViewportResponse _sharedViewport = SharedViewportResponse.empty();
  List<PendingLandmark> _pendingLandmarks = const [];
  bool _sharedViewportRequestInFlight = false;
  MapCamera? _queuedSharedViewportCamera;
  String? _activeSharedViewportCacheKey;

  bool get initialized => _initialized;
  bool get tracking => _tracking;
  bool get busy => _busy;
  bool get sharedLoading => _sharedLoading;
  String? get error => _error;
  PlayerProfile get profile => _profile;
  LatLng? get currentLatLng => _currentLatLng;
  LatLng get mapCenter =>
      _currentLatLng ??
      _savedMapCenterLatLng ??
      const LatLng(AppConstants.defaultLat, AppConstants.defaultLon);
  MapMode get mapMode => _mapMode;
  SharedViewportResponse get sharedViewport => _sharedViewport;
  List<PendingLandmark> get pendingLandmarks => _pendingLandmarks;
  bool get waitingForAccurateLocation =>
      _tracking && !_busy && _currentLatLng == null;

  bool get isSignedIn => authService.isSignedIn;
  bool get isAdminOrModerator =>
      authService.currentSession?.isAdminOrModerator ?? false;
  PendingNewPasswordChallenge? get pendingNewPasswordChallenge =>
      authService.pendingNewPasswordChallenge;
  bool get canChangeDisplayName =>
      !isSignedIn || !authService.isDisplayNameLocked;
  bool get canChangeProfileIcon =>
      !isSignedIn || !authService.isProfileIconLocked;
  String? get signedInEmail => authService.currentSession?.email;

  List<RevealPoint> get reveals => _profile.reveals;
  List<LatLng> get revealLatLngs =>
      _profile.reveals.map((e) => LatLng(e.latitude, e.longitude)).toList();
  List<Achievement> get achievements => AchievementCatalog.build(_profile);
  double get totalKm => _profile.totalDistanceMeters / 1000.0;
  int get estimatedSteps =>
      (_profile.totalDistanceMeters / AppConstants.averageStepLengthMeters)
          .round();
  int get revealCount => _profile.reveals.length;
  int get discoveredCellsCount => _profile.discoveredCells.length;
  double get coveragePercent => DiscoveryMath.coveragePercent(
        discoveredCells: discoveredCellsCount,
        cellDegrees: AppConstants.statsCellDegrees,
      );
  String get adventurerRank {
    if (discoveredCellsCount >= 1000 || totalKm >= 250) return 'Worldbreaker';
    if (discoveredCellsCount >= 250 || totalKm >= 100) return 'Roadwarden';
    if (discoveredCellsCount >= 100 || totalKm >= 50) return 'Cartographer';
    if (discoveredCellsCount >= 25 || totalKm >= 10) return 'Pathfinder';
    if (discoveredCellsCount >= 5 || totalKm >= 1) return 'Scout';
    return 'Initiate';
  }

  List<RevealPoint> get personalFogReveals {
    return _profile.discoveredCells.map((cellId) {
      final center = DiscoveryMath.cellCenterFromId(
        cellId,
        AppConstants.statsCellDegrees,
      );
      return RevealPoint(
        latitude: center.latitude,
        longitude: center.longitude,
        discoveredAtIso: _profile.updatedAtIso,
      );
    }).toList(growable: false);
  }

  List<RevealPoint> get activeFogReveals {
    if (_mapMode != MapMode.shared) {
      return _profile.reveals.isNotEmpty
          ? const <RevealPoint>[]
          : personalFogReveals;
    }

    final merged = <RevealPoint>[
      if (_profile.reveals.isEmpty) ...personalFogReveals,
    ];

    merged.addAll(
      _sharedViewport.cells
          .where((cell) => !_profile.discoveredCells.contains(cell.cellId))
          .map(
            (cell) => RevealPoint(
              latitude: cell.lat,
              longitude: cell.lon,
              discoveredAtIso: cell.lastDiscoveredAt,
            ),
          ),
    );

    return merged;
  }

  List<SharedPlayer> get sharedPlayers {
    final currentUserId = authService.currentUserId;
    if (currentUserId == null) return _sharedViewport.players;
    return _sharedViewport.players
        .where((player) => player.userId != currentUserId)
        .toList();
  }

  List<SharedLandmark> get sharedLandmarks => _sharedViewport.landmarks;

  Future<void> init() async {
    await authService.init();
    await _loadProfileForCurrentSession();

    if (isSignedIn) {
      await _loadPersistedSharedCache();
      await _restorePersonalMapFromCloud(silent: true);
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
      await _bootstrapCurrentLocation();

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
    required String profileIcon,
  }) async {
    await authService.signUp(
      email: email,
      password: password,
      displayName: displayName,
      profileIcon: profileIcon,
    );
  }

  Future<void> confirmSignUp({
    required String email,
    required String code,
  }) async {
    await authService.confirmSignUp(email: email, code: code);
  }

  Future<SignInOutcome> signIn({
    required String email,
    required String password,
  }) async {
    final outcome = await authService.signIn(email: email, password: password);
    if (outcome == SignInOutcome.newPasswordRequired) {
      notifyListeners();
      return outcome;
    }

    await _completeSignedInTransition();
    notifyListeners();
    return outcome;
  }

  Future<void> completeNewPasswordChallenge({
    required String newPassword,
    required String displayName,
    required String profileIcon,
  }) async {
    await authService.completeNewPasswordChallenge(
      newPassword: newPassword,
      displayName: displayName,
      profileIcon: profileIcon,
    );
    await _completeSignedInTransition();
    notifyListeners();
  }

  void cancelPendingSignInChallenge() {
    authService.clearPendingSignInChallenge();
    notifyListeners();
  }

  Future<void> _completeSignedInTransition() async {
    _resetSessionScopedState();
    await _switchToCurrentSessionProfile();
    await _loadPersistedSharedCache();
    await _restorePersonalMapFromCloud(silent: false);
    await _bootstrapCurrentLocation();
    _scheduleCloudSync();
    _ensureSharedViewportPolling();
  }

  Future<void> signOut() async {
    await authService.signOut();
    _resetSessionScopedState();
    _mapMode = MapMode.personal;
    await _switchToCurrentSessionProfile();
    await _bootstrapCurrentLocation();
    notifyListeners();
  }

  Future<void> setDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (trimmed == _profile.displayName) return;

    if (isSignedIn) {
      final updatedDisplayName = await authService.updateDisplayNameOnce(
        trimmed,
      );

      _profile = _profile.copyWith(
        displayName: updatedDisplayName,
        updatedAtIso: DateTime.now().toUtc().toIso8601String(),
      );

      await localProfileStore.save(_profile, profileKey: _activeProfileKey);
      _scheduleCloudSync();
      notifyListeners();
      return;
    }

    _profile = _profile.copyWith(
      displayName: trimmed,
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
    );

    await localProfileStore.save(_profile, profileKey: _activeProfileKey);
    notifyListeners();
  }

  Future<void> setProfileIcon(String icon) async {
    final normalized = icon.trim();
    if (!ProfileIconCatalog.isAllowed(normalized)) return;
    if (normalized == _profile.profileIcon) return;

    if (isSignedIn) {
      final updatedProfileIcon = await authService.updateProfileIconOnce(
        normalized,
      );

      _profile = _profile.copyWith(
        profileIcon: updatedProfileIcon,
        updatedAtIso: DateTime.now().toUtc().toIso8601String(),
      );

      await localProfileStore.save(_profile, profileKey: _activeProfileKey);
      _scheduleCloudSync();
      notifyListeners();
      return;
    }

    _profile = _profile.copyWith(
      profileIcon: normalized,
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
    );

    await localProfileStore.save(_profile, profileKey: _activeProfileKey);
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
    if (_mapMode != MapMode.shared) {
      _stopSharedViewportPolling();
      _sharedLoading = false;
    } else {
      _ensureSharedViewportPolling();
      if (camera != null) {
        _applyStoredSharedViewportFor(camera);
      }
    }
    notifyListeners();

    if (_mapMode == MapMode.shared && camera != null) {
      await refreshSharedViewport(camera);
    }
  }

  Future<void> refreshSharedViewport(
    MapCamera camera, {
    bool force = false,
  }) async {
    if (!isSignedIn || _mapMode != MapMode.shared) return;

    _ensureSharedViewportPolling();
    final cacheKey = _sharedViewportCacheKeyFor(camera);
    final cachedEntry = _sharedViewportCache[cacheKey];
    final storedViewport = _storedSharedViewportFor(camera);
    final now = DateTime.now().toUtc();
    final hasFreshCache = cachedEntry != null &&
        now.difference(cachedEntry.fetchedAt).inSeconds <
            AppConstants.sharedViewportCacheTtlSeconds;
    final hasAppliedCache = cachedEntry != null &&
        _applySharedViewportSnapshot(
          cacheKey: cacheKey,
          viewport: cachedEntry.viewport,
        );
    final hasAppliedStoredViewport = storedViewport != null &&
        _applySharedViewportSnapshot(
          cacheKey: cacheKey,
          viewport: storedViewport,
        );

    if (!force && hasFreshCache) {
      if (hasAppliedCache || hasAppliedStoredViewport) {
        notifyListeners();
      }
      return;
    }

    if (_sharedViewportRequestInFlight) {
      _queuedSharedViewportCamera = camera;
      if (hasAppliedCache || hasAppliedStoredViewport) {
        notifyListeners();
      }
      return;
    }

    final shouldShowLoading = cachedEntry == null &&
        storedViewport == null &&
        (_activeSharedViewportCacheKey != cacheKey ||
            _sharedViewport.cells.isEmpty);
    if (shouldShowLoading) {
      _sharedLoading = true;
      notifyListeners();
    } else if (hasAppliedCache || hasAppliedStoredViewport) {
      notifyListeners();
    }

    _sharedViewportRequestInFlight = true;

    try {
      final bounds = camera.visibleBounds;
      final minLat = bounds.southEast.latitude;
      final maxLat = bounds.northWest.latitude;
      final minLon = bounds.northWest.longitude;
      final maxLon = bounds.southEast.longitude;
      final zoom = camera.zoom.round();

      final viewport = await _fetchSharedViewport(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
        zoom: zoom,
      );
      _mergeSharedViewportStore(viewport);
      _cacheSharedViewport(
        cacheKey: cacheKey,
        viewport: viewport,
        fetchedAt: DateTime.now().toUtc(),
      );

      _applySharedViewportSnapshot(
        cacheKey: cacheKey,
        viewport: viewport,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _sharedViewportRequestInFlight = false;
      _sharedLoading = false;
      notifyListeners();

      final queuedCamera = _queuedSharedViewportCamera;
      _queuedSharedViewportCamera = null;
      if (queuedCamera != null && isSignedIn && _mapMode == MapMode.shared) {
        Future<void>(() => refreshSharedViewport(queuedCamera));
      }
    }
  }

  void scheduleSharedViewportRefresh(MapCamera camera) {
    final appliedStoredViewport = _applyStoredSharedViewportFor(camera);
    if (appliedStoredViewport) {
      notifyListeners();
    }
    _sharedViewportDebounceTimer?.cancel();
    _sharedViewportDebounceTimer = Timer(
      const Duration(
          milliseconds: AppConstants.sharedViewportDebounceMilliseconds),
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

  Future<void> _restorePersonalMapFromCloud({required bool silent}) async {
    if (_canUseWarmPersonalBootstrapCache(silent: silent)) {
      return;
    }

    try {
      final remoteCells = await appsyncService.getMyDiscoveryBootstrap();
      final remoteCellIds = remoteCells.map((cell) => cell.cellId).toSet();
      await _backfillLocalDiscoveriesToCloud(remoteCellIds);

      final bootstrapTimestamp = DateTime.now().toUtc().toIso8601String();

      if (remoteCells.isEmpty) {
        _profile =
            _profile.copyWith(lastCloudBootstrapAtIso: bootstrapTimestamp);
        await localProfileStore.save(_profile, profileKey: _activeProfileKey);
        return;
      }

      final mergedCells = Set<String>.from(_profile.discoveredCells);

      for (final cell in remoteCells) {
        mergedCells.add(cell.cellId);
      }

      _profile = _profile.copyWith(
        discoveredCells: mergedCells,
        lastCloudBootstrapAtIso: bootstrapTimestamp,
        updatedAtIso: DateTime.now().toUtc().toIso8601String(),
      );

      await localProfileStore.save(_profile, profileKey: _activeProfileKey);
    } catch (e) {
      if (!silent) rethrow;
      // If backend bootstrap is not deployed yet, do not block app startup.
    }
  }

  bool _canUseWarmPersonalBootstrapCache({required bool silent}) {
    if (!silent) return false;
    if (_profile.discoveredCells.isEmpty) return false;

    final rawTimestamp = _profile.lastCloudBootstrapAtIso;
    if (rawTimestamp == null || rawTimestamp.isEmpty) return false;

    final timestamp = DateTime.tryParse(rawTimestamp)?.toUtc();
    if (timestamp == null) return false;

    return DateTime.now().toUtc().difference(timestamp).inHours <
        AppConstants.personalBootstrapRefreshHours;
  }

  Future<void> _backfillLocalDiscoveriesToCloud(
      Set<String> remoteCellIds) async {
    final missingIds = _profile.discoveredCells
        .where((cellId) => !remoteCellIds.contains(cellId))
        .toList(growable: false);

    if (missingIds.isEmpty) return;

    for (var start = 0;
        start < missingIds.length;
        start += AppConstants.cloudSyncBatchSize) {
      final end = (start + AppConstants.cloudSyncBatchSize) > missingIds.length
          ? missingIds.length
          : start + AppConstants.cloudSyncBatchSize;
      final batchIds = missingIds.sublist(start, end);
      final batchCells = batchIds.map((cellId) {
        final center = DiscoveryMath.cellCenterFromId(
          cellId,
          AppConstants.statsCellDegrees,
        );
        return CloudDiscoveryCell(
          cellId: cellId,
          latitude: center.latitude,
          longitude: center.longitude,
        );
      }).toList(growable: false);

      await appsyncService.syncDiscoveries(
        cells: batchCells,
        currentLat: null,
        currentLon: null,
        mapZoom: 17,
        displayName: _syncDisplayName,
        profileIcon: _syncProfileIcon,
      );

      for (final cellId in batchIds) {
        _pendingCloudCells.remove(cellId);
      }
    }
  }

  Future<void> _handlePosition(Position position) async {
    final preview = _previewLocationFor(position);
    final previewUpdated =
        preview != null ? _updateCurrentLocationPreview(preview.latLng) : false;

    final accepted = _acceptedLocationFor(position);
    if (accepted == null) {
      if (previewUpdated) {
        _scheduleCloudSync();
        notifyListeners();
      }
      return;
    }

    final previousAccepted = _lastDiscoveryLatLng;
    final point = _smoothedDiscoveryPoint(accepted);
    if (previousAccepted != null &&
        _distance(previousAccepted, point) <
            AppConstants.stationaryJitterMeters) {
      if (previewUpdated) {
        _scheduleCloudSync();
        notifyListeners();
      }
      return;
    }

    _currentLatLng = point;
    _lastDiscoveryLatLng = point;

    double totalMeters = _profile.totalDistanceMeters;
    if (previousAccepted != null) {
      final movedMeters = _distance(previousAccepted, point);
      final fixTimestamp = accepted.timestamp;
      final gapSeconds = _lastAcceptedFixAt == null
          ? 0
          : fixTimestamp.difference(_lastAcceptedFixAt!).inSeconds;
      if (movedMeters >= AppConstants.minAcceptedMovementMeters &&
          gapSeconds <= AppConstants.maxDistanceCarryForwardGapSeconds) {
        totalMeters += movedMeters;
      }
    }

    final updatedReveals = List<RevealPoint>.from(_profile.reveals);
    final updatedCells = Set<String>.from(_profile.discoveredCells);
    final revealTime = DateTime.now().toUtc().toIso8601String();

    final lastRevealPoint = updatedReveals.isEmpty
        ? null
        : LatLng(
            updatedReveals.last.latitude,
            updatedReveals.last.longitude,
          );
    final shouldAppendRevealPoint = lastRevealPoint == null ||
        _distance(lastRevealPoint, point) >=
            AppConstants.revealPathPointSpacingMeters;

    if (shouldAppendRevealPoint) {
      updatedReveals.add(
        RevealPoint(
          latitude: point.latitude,
          longitude: point.longitude,
          discoveredAtIso: revealTime,
        ),
      );
    }

    final cloudCells = previousAccepted == null
        ? DiscoveryMath.cellsForRevealData(
            point: point,
            radiusMeters: AppConstants.discoveryRadiusMeters,
            cellDegrees: AppConstants.statsCellDegrees,
          )
        : DiscoveryMath.cellsForPathSegmentData(
            start: previousAccepted,
            end: point,
            radiusMeters: AppConstants.discoveryRadiusMeters,
            cellDegrees: AppConstants.statsCellDegrees,
          );

    final newCloudCells = cloudCells
        .where((cell) => !updatedCells.contains(cell.cellId))
        .toList();

    if (newCloudCells.isNotEmpty) {
      updatedCells.addAll(newCloudCells.map((e) => e.cellId));
      for (final cell in newCloudCells) {
        _pendingCloudCells[cell.cellId] = cell;
      }
    }

    _lastAcceptedFixAt = accepted.timestamp;
    _lastAcceptedAccuracyMeters = accepted.accuracy;
    _savedMapCenterLatLng = point;

    _profile = _profile.copyWith(
      reveals: updatedReveals,
      discoveredCells: updatedCells,
      totalDistanceMeters: totalMeters,
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
      lastLatitude: point.latitude,
      lastLongitude: point.longitude,
    );

    await localProfileStore.save(_profile, profileKey: _activeProfileKey);
    _scheduleCloudSync();
    notifyListeners();
  }

  _AcceptedLocation? _acceptedLocationFor(Position position) {
    if (position.isMocked) {
      _error = 'Mock location detected. Discovery update ignored.';
      notifyListeners();
      return null;
    }

    final candidate = _AcceptedLocation(
      latLng: LatLng(position.latitude, position.longitude),
      timestamp: _positionTimestamp(position),
      accuracy: position.accuracy,
    );

    if (!_isFreshTimestamp(candidate.timestamp)) {
      return null;
    }

    if (position.speed > AppConstants.maxAcceptedSpeedMetersPerSecond) {
      return null;
    }

    if (_lastDiscoveryLatLng == null) {
      return _stabilizedInitialFix(candidate);
    }

    _initialFixSamples.clear();

    if (candidate.accuracy <= 0 ||
        candidate.accuracy > AppConstants.maxAcceptedAccuracyMeters) {
      return null;
    }

    final distanceFromLastAccepted = _distance(
      _lastDiscoveryLatLng!,
      candidate.latLng,
    );

    if (distanceFromLastAccepted < AppConstants.minAcceptedMovementMeters) {
      return null;
    }

    if (!_isReasonableJump(candidate, distanceFromLastAccepted)) {
      return null;
    }

    return candidate;
  }

  _AcceptedLocation? _previewLocationFor(Position position) {
    if (position.isMocked) {
      return null;
    }

    final candidate = _AcceptedLocation(
      latLng: LatLng(position.latitude, position.longitude),
      timestamp: _positionTimestamp(position),
      accuracy: position.accuracy,
    );

    if (!_isFreshTimestamp(candidate.timestamp)) {
      return null;
    }

    if (candidate.accuracy <= 0 ||
        candidate.accuracy > AppConstants.maxPreviewAccuracyMeters) {
      return null;
    }

    if (position.speed > AppConstants.maxAcceptedSpeedMetersPerSecond) {
      return null;
    }

    return candidate;
  }

  _AcceptedLocation? _stabilizedInitialFix(_AcceptedLocation candidate) {
    if (candidate.accuracy <= 0 ||
        candidate.accuracy > AppConstants.maxInitialFixAccuracyMeters) {
      return null;
    }

    final cutoff = candidate.timestamp.subtract(
      const Duration(
        seconds: AppConstants.initialFixStabilizationWindowSeconds,
      ),
    );
    _initialFixSamples.removeWhere(
      (sample) => sample.timestamp.isBefore(cutoff),
    );
    _initialFixSamples.add(candidate);

    final sampleCount = AppConstants.initialFixSampleCount;
    if (_initialFixSamples.length < sampleCount) {
      return null;
    }

    final cluster = _initialFixSamples.sublist(
      _initialFixSamples.length - sampleCount,
    );
    final averagedLatLng = _averageLatLng(cluster);

    var maxSpreadMeters = 0.0;
    var worstAccuracyMeters = 0.0;
    for (final sample in cluster) {
      final spreadMeters = _distance(sample.latLng, averagedLatLng);
      if (spreadMeters > maxSpreadMeters) {
        maxSpreadMeters = spreadMeters;
      }
      if (sample.accuracy > worstAccuracyMeters) {
        worstAccuracyMeters = sample.accuracy;
      }
    }

    if (maxSpreadMeters > AppConstants.initialFixMaxClusterSpreadMeters) {
      _initialFixSamples.removeAt(0);
      return null;
    }

    _initialFixSamples.clear();
    return _AcceptedLocation(
      latLng: averagedLatLng,
      timestamp: candidate.timestamp,
      accuracy: worstAccuracyMeters,
    );
  }

  bool _isFreshTimestamp(DateTime timestamp) {
    final ageSeconds = DateTime.now().toUtc().difference(timestamp).inSeconds;
    return ageSeconds <= AppConstants.maxAcceptedLocationAgeSeconds;
  }

  bool _isReasonableJump(_AcceptedLocation candidate, double distanceMeters) {
    if (_lastAcceptedFixAt == null) return true;

    final elapsedSeconds =
        candidate.timestamp.difference(_lastAcceptedFixAt!).inSeconds;
    if (elapsedSeconds <= 0) return true;

    final allowedDistance = AppConstants.maxReasonableJumpMeters +
        (elapsedSeconds * AppConstants.maxAcceptedSpeedMetersPerSecond) +
        (_lastAcceptedAccuracyMeters ?? 0) +
        candidate.accuracy;

    return distanceMeters <= allowedDistance;
  }

  DateTime _positionTimestamp(Position position) => position.timestamp.toUtc();

  void _scheduleCloudSync() {
    if (!isSignedIn || _currentLatLng == null || !_tracking) return;

    if (_cloudSyncTimer?.isActive == true || _cloudSyncInFlight) {
      return;
    }

    _cloudSyncTimer = Timer(const Duration(seconds: 6), () async {
      _cloudSyncTimer = null;
      _cloudSyncInFlight = true;
      final pendingSnapshot = Map<String, CloudDiscoveryCell>.from(
        _pendingCloudCells,
      );
      final cells = pendingSnapshot.values.toList();

      try {
        await appsyncService.syncDiscoveries(
          cells: cells,
          currentLat: _currentLatLng?.latitude,
          currentLon: _currentLatLng?.longitude,
          mapZoom: 17,
          displayName: _syncDisplayName,
          profileIcon: _syncProfileIcon,
        );

        // Keep discoveries queued until sync succeeds to avoid silent data loss.
        for (final cellId in pendingSnapshot.keys) {
          _pendingCloudCells.remove(cellId);
        }
      } catch (e) {
        _error = e.toString();
        notifyListeners();
      } finally {
        _cloudSyncInFlight = false;
        if (isSignedIn && _currentLatLng != null && _tracking) {
          _scheduleCloudSync();
        }
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _cloudSyncTimer?.cancel();
    _sharedCachePersistTimer?.cancel();
    _sharedViewportDebounceTimer?.cancel();
    _sharedViewportPollTimer?.cancel();
    appsyncService.dispose();
    sharedTileService.dispose();
    super.dispose();
  }

  Future<SharedViewportResponse> _fetchSharedViewport({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    required int zoom,
  }) async {
    if (!sharedTileService.isConfigured) {
      return appsyncService.getSharedViewport(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
        zoom: zoom,
      );
    }

    try {
      final results = await Future.wait([
        sharedTileService.getViewport(
          worldId: BackendConfig.defaultWorldId,
          minLat: minLat,
          maxLat: maxLat,
          minLon: minLon,
          maxLon: maxLon,
          zoom: zoom,
        ),
        appsyncService.getSharedPresence(
          minLat: minLat,
          maxLat: maxLat,
          minLon: minLon,
          maxLon: maxLon,
          zoom: zoom,
        ),
      ]);

      final tileViewport = results[0] as SharedViewportResponse;
      final players = results[1] as List<SharedPlayer>;

      if (!tileViewport.hasTilePayload) {
        return appsyncService.getSharedViewport(
          minLat: minLat,
          maxLat: maxLat,
          minLon: minLon,
          maxLon: maxLon,
          zoom: zoom,
        );
      }

      return SharedViewportResponse(
        worldId: tileViewport.worldId,
        cells: tileViewport.cells,
        players: players,
        landmarks: tileViewport.landmarks,
        generatedAt: tileViewport.generatedAt,
      );
    } catch (_) {
      return appsyncService.getSharedViewport(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
        zoom: zoom,
      );
    }
  }

  String get _syncDisplayName =>
      authService.currentDisplayName?.trim().isNotEmpty == true
          ? authService.currentDisplayName!.trim()
          : _profile.displayName;

  String get _syncProfileIcon {
    if (!isSignedIn) return _profile.profileIcon;
    return authService.currentProfileIcon;
  }

  Future<void> _loadProfileForCurrentSession() async {
    final userId = authService.currentUserId;
    final defaultDisplayName = userId == null
        ? 'Adventurer'
        : (authService.currentDisplayName ?? 'Adventurer');

    _activeProfileKey = _profileStorageKeyFor(userId);
    _profile = await localProfileStore.load(
      profileKey: _activeProfileKey,
      profileId: userId ?? 'local-player',
      defaultDisplayName: defaultDisplayName,
    );

    await _syncProfileIdentityMetadata();

    if (_profile.lastLatitude != null && _profile.lastLongitude != null) {
      _savedMapCenterLatLng = LatLng(
        _profile.lastLatitude!,
        _profile.lastLongitude!,
      );
    } else {
      _savedMapCenterLatLng = null;
    }
  }

  Future<void> _switchToCurrentSessionProfile() async {
    final previousLivePoint = _currentLatLng;
    _resetLiveLocationState();
    await _loadProfileForCurrentSession();
    _savedMapCenterLatLng ??= previousLivePoint;
  }

  Future<void> _syncProfileIdentityMetadata() async {
    final userId = authService.currentUserId;
    if (userId == null) return;

    var updatedProfile = _profile;
    var changed = false;

    if (updatedProfile.id != userId) {
      updatedProfile = updatedProfile.copyWith(id: userId);
      changed = true;
    }

    final authDisplayName = authService.currentDisplayName?.trim();
    if (authDisplayName != null &&
        authDisplayName.isNotEmpty &&
        (updatedProfile.displayName.trim().isEmpty ||
            updatedProfile.displayName == 'Adventurer')) {
      updatedProfile = updatedProfile.copyWith(displayName: authDisplayName);
      changed = true;
    }

    final authProfileIcon = authService.currentProfileIcon.trim();
    if (authProfileIcon.isNotEmpty &&
        ProfileIconCatalog.isAllowed(authProfileIcon) &&
        (updatedProfile.profileIcon.trim().isEmpty ||
            updatedProfile.profileIcon == ProfileIconCatalog.defaultIcon)) {
      updatedProfile = updatedProfile.copyWith(profileIcon: authProfileIcon);
      changed = true;
    }

    if (!changed) return;

    _profile = updatedProfile.copyWith(
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
    );
    await localProfileStore.save(_profile, profileKey: _activeProfileKey);
  }

  String _profileStorageKeyFor(String? userId) {
    if (userId == null || userId.isEmpty) {
      return LocalProfileStore.guestProfileKey;
    }
    return 'user_$userId';
  }

  void _resetLiveLocationState() {
    _currentLatLng = null;
    _lastDiscoveryLatLng = null;
    _lastAcceptedFixAt = null;
    _lastAcceptedAccuracyMeters = null;
    _initialFixSamples.clear();
  }

  void _resetSessionScopedState() {
    _pendingCloudCells.clear();
    _cloudSyncTimer?.cancel();
    _cloudSyncTimer = null;
    _error = null;
    _pendingLandmarks = const [];
    _resetSharedViewportState();
  }

  Future<void> _bootstrapCurrentLocation() async {
    for (var attempt = 0;
        attempt < AppConstants.initialFixBootstrapAttempts;
        attempt++) {
      try {
        final bootstrapPosition = await locationService
            .getCurrentPosition()
            .timeout(const Duration(seconds: 8));
        await _handlePosition(bootstrapPosition);
        if (_currentLatLng != null) {
          return;
        }
      } catch (_) {
        // Keep trying within the bootstrap window before falling back to stream.
      }

      if (attempt < AppConstants.initialFixBootstrapAttempts - 1) {
        await Future<void>.delayed(
          const Duration(seconds: AppConstants.initialFixBootstrapDelaySeconds),
        );
      }
    }
  }

  String _sharedViewportCacheKeyFor(MapCamera camera) {
    final bounds = camera.visibleBounds;
    return DiscoveryMath.sharedViewportCacheKey(
      minLat: bounds.southEast.latitude,
      maxLat: bounds.northWest.latitude,
      minLon: bounds.northWest.longitude,
      maxLon: bounds.southEast.longitude,
      mapZoom: camera.zoom.round(),
    );
  }

  bool _applySharedViewportSnapshot({
    required String cacheKey,
    required SharedViewportResponse viewport,
  }) {
    if (_mapMode != MapMode.shared) return false;

    final currentKey = _sharedViewportCacheKeyFor(mapController.camera);
    if (cacheKey != currentKey) {
      return false;
    }

    final changed = _activeSharedViewportCacheKey != cacheKey ||
        _sharedViewport.generatedAt != viewport.generatedAt;
    _sharedViewport = viewport;
    _activeSharedViewportCacheKey = cacheKey;
    return changed;
  }

  void _cacheSharedViewport({
    required String cacheKey,
    required SharedViewportResponse viewport,
    required DateTime fetchedAt,
  }) {
    _sharedViewportCache[cacheKey] = _SharedViewportCacheEntry(
      viewport: viewport,
      fetchedAt: fetchedAt,
    );

    if (_sharedViewportCache.length <=
        AppConstants.sharedViewportCacheMaxEntries) {
      return;
    }

    final oldestKey = _sharedViewportCache.entries
        .reduce(
          (a, b) => a.value.fetchedAt.isBefore(b.value.fetchedAt) ? a : b,
        )
        .key;
    _sharedViewportCache.remove(oldestKey);
  }

  bool _applyStoredSharedViewportFor(MapCamera camera) {
    final cacheKey = _sharedViewportCacheKeyFor(camera);
    final storedViewport = _storedSharedViewportFor(camera);
    if (storedViewport == null) {
      return false;
    }
    return _applySharedViewportSnapshot(
      cacheKey: cacheKey,
      viewport: storedViewport,
    );
  }

  void _mergeSharedViewportStore(SharedViewportResponse viewport) {
    var changed = false;

    for (final cell in viewport.cells) {
      final existing = _sharedCellStore[cell.cellId];
      if (existing == null ||
          cell.lastDiscoveredAt.compareTo(existing.lastDiscoveredAt) >= 0) {
        if (existing != cell) {
          _sharedCellStore[cell.cellId] = cell;
          changed = true;
        }
      }
    }
    for (final landmark in viewport.landmarks) {
      final existing = _sharedLandmarkStore[landmark.landmarkId];
      final existingCreatedAt = existing?.createdAt ?? '';
      final incomingCreatedAt = landmark.createdAt ?? '';
      if (existing == null ||
          incomingCreatedAt.compareTo(existingCreatedAt) >= 0) {
        if (existing != landmark) {
          _sharedLandmarkStore[landmark.landmarkId] = landmark;
          changed = true;
        }
      }
    }

    if (viewport.generatedAt.isNotEmpty &&
        viewport.generatedAt.compareTo(_sharedStoreGeneratedAt) >= 0) {
      _sharedStoreGeneratedAt = viewport.generatedAt;
    }

    if (changed) {
      _scheduleSharedCachePersist(worldId: viewport.worldId);
    }
  }

  SharedViewportResponse? _storedSharedViewportFor(MapCamera camera) {
    if (_sharedCellStore.isEmpty && _sharedLandmarkStore.isEmpty) {
      return null;
    }
    final cells = _sharedCellStore.values
        .where(
          (cell) => _isInViewport(
            lat: cell.lat,
            lon: cell.lon,
            camera: camera,
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => b.lastDiscoveredAt.compareTo(a.lastDiscoveredAt));

    final landmarks = _sharedLandmarkStore.values
        .where(
          (landmark) => _isInViewport(
            lat: landmark.lat,
            lon: landmark.lon,
            camera: camera,
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));

    if (cells.isEmpty && landmarks.isEmpty) {
      return null;
    }

    return SharedViewportResponse(
      worldId: _sharedViewport.worldId.isEmpty
          ? BackendConfig.defaultWorldId
          : _sharedViewport.worldId,
      cells: cells,
      players: const [],
      landmarks: landmarks,
      generatedAt: _sharedStoreGeneratedAt,
    );
  }

  bool _isInViewport({
    required double lat,
    required double lon,
    required MapCamera camera,
  }) {
    final bounds = camera.visibleBounds;
    return lat >= bounds.southEast.latitude &&
        lat <= bounds.northWest.latitude &&
        lon >= bounds.northWest.longitude &&
        lon <= bounds.southEast.longitude;
  }

  void _resetSharedViewportState({bool clearCache = true}) {
    _sharedCachePersistTimer?.cancel();
    _sharedViewportDebounceTimer?.cancel();
    _stopSharedViewportPolling();
    _sharedViewport = SharedViewportResponse.empty();
    _sharedLoading = false;
    _sharedViewportRequestInFlight = false;
    _queuedSharedViewportCamera = null;
    _activeSharedViewportCacheKey = null;
    _sharedStoreGeneratedAt = '';
    if (clearCache) {
      _sharedViewportCache.clear();
      _sharedCellStore.clear();
      _sharedLandmarkStore.clear();
    }
  }

  Future<void> _loadPersistedSharedCache() async {
    final snapshot = await sharedMapCacheStore.load(
      worldId: BackendConfig.defaultWorldId,
      maxAge: const Duration(
        hours: AppConstants.sharedViewportPersistedCacheMaxAgeHours,
      ),
    );
    if (snapshot == null) {
      return;
    }

    _sharedCellStore
      ..clear()
      ..addEntries(
        snapshot.cells.map(
          (cell) => MapEntry(cell.cellId, cell),
        ),
      );
    _sharedLandmarkStore
      ..clear()
      ..addEntries(
        snapshot.landmarks.map(
          (landmark) => MapEntry(landmark.landmarkId, landmark),
        ),
      );
    _sharedStoreGeneratedAt = snapshot.generatedAt;
  }

  void _scheduleSharedCachePersist({required String worldId}) {
    _sharedCachePersistTimer?.cancel();
    _sharedCachePersistTimer = Timer(const Duration(seconds: 2), () async {
      final sortedCells = _sharedCellStore.values.toList(growable: false)
        ..sort((a, b) => b.lastDiscoveredAt.compareTo(a.lastDiscoveredAt));
      final sortedLandmarks = _sharedLandmarkStore.values
          .toList(growable: false)
        ..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));

      final snapshot = SharedViewportCacheSnapshot(
        worldId: worldId,
        savedAtIso: DateTime.now().toUtc().toIso8601String(),
        generatedAt: _sharedStoreGeneratedAt,
        cells: sortedCells
            .take(AppConstants.sharedViewportPersistedCellLimit)
            .toList(growable: false),
        landmarks: sortedLandmarks
            .take(AppConstants.sharedViewportPersistedLandmarkLimit)
            .toList(growable: false),
      );

      await sharedMapCacheStore.save(snapshot);
    });
  }

  void _ensureSharedViewportPolling() {
    if (!isSignedIn || _mapMode != MapMode.shared) {
      _stopSharedViewportPolling();
      return;
    }
    if (_sharedViewportPollTimer != null) return;

    _sharedViewportPollTimer = Timer.periodic(
      const Duration(seconds: AppConstants.sharedViewportRefreshSeconds),
      (_) {
        if (!isSignedIn || _mapMode != MapMode.shared) {
          _stopSharedViewportPolling();
          return;
        }
        refreshSharedViewport(mapController.camera);
      },
    );
  }

  void _stopSharedViewportPolling() {
    _sharedViewportPollTimer?.cancel();
    _sharedViewportPollTimer = null;
  }

  LatLng _averageLatLng(List<_AcceptedLocation> samples) {
    var latTotal = 0.0;
    var lonTotal = 0.0;
    for (final sample in samples) {
      latTotal += sample.latLng.latitude;
      lonTotal += sample.latLng.longitude;
    }
    return LatLng(latTotal / samples.length, lonTotal / samples.length);
  }

  LatLng _smoothedDiscoveryPoint(_AcceptedLocation candidate) {
    final previous = _lastDiscoveryLatLng;
    if (previous == null) return candidate.latLng;

    final distanceMeters = _distance(previous, candidate.latLng);
    if (distanceMeters <= AppConstants.stationaryJitterMeters) {
      return previous;
    }

    final blend = (distanceMeters / (distanceMeters + candidate.accuracy))
        .clamp(
          AppConstants.discoverySmoothingMinBlend,
          AppConstants.discoverySmoothingMaxBlend,
        )
        .toDouble();

    return LatLng(
      previous.latitude +
          ((candidate.latLng.latitude - previous.latitude) * blend),
      previous.longitude +
          ((candidate.latLng.longitude - previous.longitude) * blend),
    );
  }

  bool _updateCurrentLocationPreview(LatLng point) {
    final previous = _currentLatLng;
    if (previous != null && _distance(previous, point) < 1.0) {
      return false;
    }

    _currentLatLng = point;
    _savedMapCenterLatLng = point;
    return true;
  }
}

class _AcceptedLocation {
  const _AcceptedLocation({
    required this.latLng,
    required this.timestamp,
    required this.accuracy,
  });

  final LatLng latLng;
  final DateTime timestamp;
  final double accuracy;
}

class _SharedViewportCacheEntry {
  const _SharedViewportCacheEntry({
    required this.viewport,
    required this.fetchedAt,
  });

  final SharedViewportResponse viewport;
  final DateTime fetchedAt;
}
