import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../data/models/cloud_discovery_cell.dart';

class DiscoveryMath {
  static const Distance _distance = Distance();

  static int aggregateSharedTileZoom(int mapZoom) {
    if (mapZoom <= 5) return 5;
    if (mapZoom <= 8) return 8;
    if (mapZoom <= 11) return 11;
    if (mapZoom <= 14) return 13;
    return 14;
  }

  static String cellIdFromLatLng(LatLng point, double cellDegrees) {
    final latIndex = ((point.latitude + 90.0) / cellDegrees).floor();
    final lonIndex = ((point.longitude + 180.0) / cellDegrees).floor();
    return '$latIndex:$lonIndex';
  }

  static LatLng cellCenterFromId(String cellId, double cellDegrees) {
    final parts = cellId.split(':');
    final latIndex = int.parse(parts[0]);
    final lonIndex = int.parse(parts[1]);
    return LatLng(
      (latIndex * cellDegrees) - 90.0 + (cellDegrees / 2),
      (lonIndex * cellDegrees) - 180.0 + (cellDegrees / 2),
    );
  }

  static Set<String> cellsForReveal({
    required LatLng point,
    required double radiusMeters,
    required double cellDegrees,
  }) {
    return cellsForRevealData(
      point: point,
      radiusMeters: radiusMeters,
      cellDegrees: cellDegrees,
    ).map((e) => e.cellId).toSet();
  }

  static Set<CloudDiscoveryCell> cellsForRevealData({
    required LatLng point,
    required double radiusMeters,
    required double cellDegrees,
  }) {
    final latDelta = radiusMeters / 111320.0;
    var cosLat = math.cos(point.latitude * math.pi / 180.0).abs();
    if (cosLat < 0.15) cosLat = 0.15;
    final lonDelta = radiusMeters / (111320.0 * cosLat);

    final minLat = point.latitude - latDelta;
    final maxLat = point.latitude + latDelta;
    final minLon = point.longitude - lonDelta;
    final maxLon = point.longitude + lonDelta;

    final latStart =
        (((minLat + 90.0) / cellDegrees).floor() * cellDegrees) - 90.0;
    final lonStart =
        (((minLon + 180.0) / cellDegrees).floor() * cellDegrees) - 180.0;

    final cells = <CloudDiscoveryCell>{};
    final containingCellId = cellIdFromLatLng(point, cellDegrees);
    final containingCellCenter =
        cellCenterFromId(containingCellId, cellDegrees);

    // Always reveal the cell the player is physically inside, even when a
    // small discovery radius would miss that cell's center point.
    cells.add(
      CloudDiscoveryCell(
        cellId: containingCellId,
        latitude: containingCellCenter.latitude,
        longitude: containingCellCenter.longitude,
      ),
    );

    for (double lat = latStart; lat <= maxLat; lat += cellDegrees) {
      for (double lon = lonStart; lon <= maxLon; lon += cellDegrees) {
        final center = LatLng(lat + cellDegrees / 2, lon + cellDegrees / 2);
        final meters = _distance(point, center);
        if (meters <= radiusMeters) {
          cells.add(
            CloudDiscoveryCell(
              cellId: cellIdFromLatLng(center, cellDegrees),
              latitude: center.latitude,
              longitude: center.longitude,
            ),
          );
        }
      }
    }

    return cells;
  }

  static CloudDiscoveryCell cellForPointData({
    required LatLng point,
    required double cellDegrees,
  }) {
    final cellId = cellIdFromLatLng(point, cellDegrees);
    final center = cellCenterFromId(cellId, cellDegrees);
    return CloudDiscoveryCell(
      cellId: cellId,
      latitude: center.latitude,
      longitude: center.longitude,
    );
  }

  static Set<CloudDiscoveryCell> cellsForPathSegmentData({
    required LatLng start,
    required LatLng end,
    required double radiusMeters,
    required double cellDegrees,
  }) {
    final totalMeters = _distance(start, end);
    final stepMeters = math.max(1.0, radiusMeters * 0.5);
    final steps = math.max(1, (totalMeters / stepMeters).ceil());
    final cells = <CloudDiscoveryCell>{};

    for (var index = 0; index <= steps; index++) {
      final progress = index / steps;
      final point = LatLng(
        start.latitude + ((end.latitude - start.latitude) * progress),
        start.longitude + ((end.longitude - start.longitude) * progress),
      );
      cells.add(
        cellForPointData(
          point: point,
          cellDegrees: cellDegrees,
        ),
      );
    }

    return cells;
  }

  static double metersPerPixel(double latitude, double zoom) {
    final latRad = latitude * math.pi / 180.0;
    return 156543.03392 * math.cos(latRad) / math.pow(2.0, zoom);
  }

  static String sharedViewportCacheKey({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    required int mapZoom,
  }) {
    final northWest = _slippyTile(maxLat, minLon, mapZoom);
    final southEast = _slippyTile(minLat, maxLon, mapZoom);
    final minX = math.min(northWest.x, southEast.x);
    final maxX = math.max(northWest.x, southEast.x);
    final minY = math.min(northWest.y, southEast.y);
    final maxY = math.max(northWest.y, southEast.y);

    return 'z${northWest.z}/x$minX-$maxX/y$minY-$maxY';
  }

  static List<String> sharedTileIdsForBounds({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    required int mapZoom,
  }) {
    final northWest = _slippyTile(maxLat, minLon, mapZoom);
    final southEast = _slippyTile(minLat, maxLon, mapZoom);
    final minX = math.min(northWest.x, southEast.x);
    final maxX = math.max(northWest.x, southEast.x);
    final minY = math.min(northWest.y, southEast.y);
    final maxY = math.max(northWest.y, southEast.y);

    final ids = <String>[];
    for (var x = minX; x <= maxX; x++) {
      for (var y = minY; y <= maxY; y++) {
        ids.add('z${northWest.z}/x$x/y$y');
      }
    }
    return ids;
  }

  static double coveragePercent({
    required int discoveredCells,
    required double cellDegrees,
  }) {
    final totalCells = (360 / cellDegrees) * (180 / cellDegrees);
    return (discoveredCells / totalCells) * 100.0;
  }

  static _SharedTileAddress _slippyTile(double lat, double lon, int mapZoom) {
    final z = aggregateSharedTileZoom(mapZoom);
    final clampedLat = lat.clamp(-85.05112878, 85.05112878);
    final normalizedLon = lon.clamp(-180.0, 180.0 - 1e-9);
    final n = math.pow(2.0, z).toDouble();
    final x = (((normalizedLon + 180.0) / 360.0) * n).floor();
    final latRad = clampedLat * math.pi / 180.0;
    final mercator = math.log(math.tan(latRad) + (1 / math.cos(latRad)));
    final y = (((1.0 - (mercator / math.pi)) / 2.0) * n).floor();

    return _SharedTileAddress(
      x: x.clamp(0, n.toInt() - 1),
      y: y.clamp(0, n.toInt() - 1),
      z: z,
    );
  }
}

class _SharedTileAddress {
  const _SharedTileAddress({
    required this.x,
    required this.y,
    required this.z,
  });

  final int x;
  final int y;
  final int z;
}
