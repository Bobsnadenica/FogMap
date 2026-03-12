import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/utils/discovery_math.dart';
import '../backend_config.dart';
import '../models/shared_viewport_models.dart';

class SharedTileService {
  SharedTileService({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  bool _disposed = false;

  bool get isConfigured =>
      BackendConfig.cloudFrontSharedTilesDomain.trim().isNotEmpty;

  Future<SharedViewportResponse> getViewport({
    required String worldId,
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    required int zoom,
  }) async {
    if (!isConfigured) {
      throw StateError('Shared tile CDN is not configured.');
    }

    final tileIds = DiscoveryMath.sharedTileIdsForBounds(
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
      mapZoom: zoom,
    ).take(150);

    final cellsById = <String, SharedCell>{};
    final landmarksById = <String, SharedLandmark>{};
    var generatedAt = '';

    final results = await Future.wait(
      tileIds.map((tileId) => _fetchTile(worldId: worldId, tileId: tileId)),
    );
    var hadTilePayload = false;

    for (final viewport in results.whereType<SharedViewportResponse>()) {
      hadTilePayload = true;
      if (viewport.generatedAt.compareTo(generatedAt) > 0) {
        generatedAt = viewport.generatedAt;
      }

      for (final cell in viewport.cells) {
        final existing = cellsById[cell.cellId];
        if (existing == null ||
            cell.lastDiscoveredAt.compareTo(existing.lastDiscoveredAt) >= 0) {
          cellsById[cell.cellId] = cell;
        }
      }

      for (final landmark in viewport.landmarks) {
        final existing = landmarksById[landmark.landmarkId];
        final incomingCreatedAt = landmark.createdAt ?? '';
        final existingCreatedAt = existing?.createdAt ?? '';
        if (existing == null ||
            incomingCreatedAt.compareTo(existingCreatedAt) >= 0) {
          landmarksById[landmark.landmarkId] = landmark;
        }
      }
    }

    return SharedViewportResponse(
      worldId: worldId,
      cells: cellsById.values.toList(growable: false)
        ..sort((a, b) => b.lastDiscoveredAt.compareTo(a.lastDiscoveredAt)),
      players: const [],
      landmarks: landmarksById.values.toList(growable: false)
        ..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? '')),
      generatedAt: generatedAt,
    ).copyWithMetadata(hasTilePayload: hadTilePayload);
  }

  Future<SharedViewportResponse?> _fetchTile({
    required String worldId,
    required String tileId,
  }) async {
    if (_disposed) {
      throw StateError('SharedTileService has been disposed.');
    }

    final uri = Uri.https(
      BackendConfig.cloudFrontSharedTilesDomain,
      '/shared-tiles/v1/$worldId/$tileId.json',
    );

    final response =
        await _client.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Shared tile request failed (${response.statusCode}) for $tileId.',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return SharedViewportResponse.fromJson(decoded);
  }

  void dispose() {
    if (_disposed) return;
    if (_ownsClient) {
      _client.close();
    }
    _disposed = true;
  }
}
