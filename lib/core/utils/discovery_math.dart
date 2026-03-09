import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../data/models/cloud_discovery_cell.dart';

class DiscoveryMath {
  static const Distance _distance = Distance();

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

  static double metersPerPixel(double latitude, double zoom) {
    final latRad = latitude * math.pi / 180.0;
    return 156543.03392 * math.cos(latRad) / math.pow(2.0, zoom);
  }

  static double coveragePercent({
    required int discoveredCells,
    required double cellDegrees,
  }) {
    final totalCells = (360 / cellDegrees) * (180 / cellDegrees);
    return (discoveredCells / totalCells) * 100.0;
  }
}