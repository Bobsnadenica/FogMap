import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/discovery_math.dart';
import '../../data/models/reveal_point.dart';

class FogOfWarOverlay extends StatelessWidget {
  const FogOfWarOverlay({
    super.key,
    required this.camera,
    required this.reveals,
    required this.trailPoints,
    required this.revision,
  });

  final MapCamera camera;
  final List<RevealPoint> reveals;
  final List<LatLng> trailPoints;
  final int revision;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FogOfWarPainter(
        camera: camera,
        reveals: reveals,
        trailPoints: trailPoints,
        revision: revision,
      ),
      size: Size.infinite,
    );
  }
}

class _FogOfWarPainter extends CustomPainter {
  _FogOfWarPainter({
    required this.camera,
    required this.reveals,
    required this.trailPoints,
    required this.revision,
  }) : _revealSignature = Object.hashAll(
          reveals.map(
            (reveal) => DiscoveryMath.cellIdFromLatLng(
              LatLng(reveal.latitude, reveal.longitude),
              AppConstants.statsCellDegrees,
            ),
          ),
        ),
        _trailSignature = Object.hashAll(
          trailPoints.map(
            (point) =>
                '${point.latitude.toStringAsFixed(6)}:${point.longitude.toStringAsFixed(6)}',
          ),
        );

  final MapCamera camera;
  final List<RevealPoint> reveals;
  final List<LatLng> trailPoints;
  final int revision;
  final int _revealSignature;
  final int _trailSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.saveLayer(rect, Paint());

    // Heavier unexplored shroud so street labels/details are hard to read.
    canvas.drawRect(
      rect,
      Paint()..color = const Color(0xB5120F0C),
    );

    // Warm parchment tint.
    canvas.drawRect(
      rect,
      Paint()..color = const Color(0x331E1408),
    );

    // Extra vignette for the game-map feeling.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.08,
          colors: const [
            Color(0x00000000),
            Color(0x33000000),
            Color(0x66000000),
            Color(0x99000000),
          ],
          stops: const [0.0, 0.58, 0.82, 1.0],
        ).createShader(rect),
    );

    final stripSoftPaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..style = PaintingStyle.fill
      ..color = const Color(0xD8FFFFFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4);

    final stripCorePaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..style = PaintingStyle.fill
      ..color = const Color(0xF2FFFFFF);

    for (final strip in _mergedCellStrips()) {
      final featherPath = _pathForStrip(strip, inflatePixels: 2.0);
      final corePath = _pathForStrip(strip);

      canvas.drawPath(featherPath, stripSoftPaint);
      canvas.drawPath(corePath, stripCorePaint);
    }

    final trailPath = _trailPath();
    if (trailPath != null) {
      final trailWidth = _trailWidthPixels();
      final trailSoftPaint = Paint()
        ..blendMode = BlendMode.dstOut
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = trailWidth + 6
        ..color = const Color(0xD8FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.8);

      final trailClearPaint = Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = trailWidth;

      canvas.drawPath(trailPath, trailSoftPaint);
      canvas.drawPath(trailPath, trailClearPaint);

      if (trailPoints.length == 1) {
        final center = camera.latLngToScreenOffset(trailPoints.first);
        canvas.drawCircle(center, trailWidth / 2, trailClearPaint);
      }
    }

    canvas.restore();

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0x996A4A22);

    canvas.drawRect(rect.deflate(3), borderPaint);
  }

  List<_CellStrip> _mergedCellStrips() {
    final rows = <int, Set<int>>{};

    for (final reveal in reveals) {
      final cellId = DiscoveryMath.cellIdFromLatLng(
        LatLng(reveal.latitude, reveal.longitude),
        AppConstants.statsCellDegrees,
      );
      final parts = cellId.split(':');
      final latIndex = int.parse(parts[0]);
      final lonIndex = int.parse(parts[1]);
      rows.putIfAbsent(latIndex, () => <int>{}).add(lonIndex);
    }

    final strips = <_CellStrip>[];

    for (final entry in rows.entries) {
      final sorted = entry.value.toList()..sort();
      if (sorted.isEmpty) continue;

      var start = sorted.first;
      var end = start;

      for (final lonIndex in sorted.skip(1)) {
        if (lonIndex == end + 1) {
          end = lonIndex;
          continue;
        }

        strips.add(
          _CellStrip(
            latIndex: entry.key,
            lonStart: start,
            lonEnd: end,
          ),
        );
        start = lonIndex;
        end = lonIndex;
      }

      strips.add(
        _CellStrip(
          latIndex: entry.key,
          lonStart: start,
          lonEnd: end,
        ),
      );
    }

    return strips;
  }

  ui.Path _pathForStrip(_CellStrip strip, {double inflatePixels = 0}) {
    final southLat = (strip.latIndex * AppConstants.statsCellDegrees) - 90.0;
    final northLat =
        ((strip.latIndex + 1) * AppConstants.statsCellDegrees) - 90.0;
    final westLon = (strip.lonStart * AppConstants.statsCellDegrees) - 180.0;
    final eastLon =
        ((strip.lonEnd + 1) * AppConstants.statsCellDegrees) - 180.0;

    final northWest = camera.latLngToScreenOffset(LatLng(northLat, westLon));
    final northEast = camera.latLngToScreenOffset(LatLng(northLat, eastLon));
    final southEast = camera.latLngToScreenOffset(LatLng(southLat, eastLon));
    final southWest = camera.latLngToScreenOffset(LatLng(southLat, westLon));

    if (camera.rotation.abs() < 0.001) {
      final minX = math.min(
        math.min(northWest.dx, northEast.dx),
        math.min(southWest.dx, southEast.dx),
      );
      final maxX = math.max(
        math.max(northWest.dx, northEast.dx),
        math.max(southWest.dx, southEast.dx),
      );
      final minY = math.min(
        math.min(northWest.dy, northEast.dy),
        math.min(southWest.dy, southEast.dy),
      );
      final maxY = math.max(
        math.max(northWest.dy, northEast.dy),
        math.max(southWest.dy, southEast.dy),
      );
      final rect = Rect.fromLTRB(minX, minY, maxX, maxY).inflate(inflatePixels);
      final radius = Radius.circular(
        math.min(rect.width, rect.height).clamp(0.0, 12.0).toDouble() * 0.45,
      );
      return ui.Path()
        ..addRRect(ui.RRect.fromRectAndRadius(rect, radius));
    }

    return ui.Path()
      ..moveTo(northWest.dx, northWest.dy)
      ..lineTo(northEast.dx, northEast.dy)
      ..lineTo(southEast.dx, southEast.dy)
      ..lineTo(southWest.dx, southWest.dy)
      ..close();
  }

  ui.Path? _trailPath() {
    if (trailPoints.isEmpty) return null;

    final path = ui.Path();
    for (var index = 0; index < trailPoints.length; index++) {
      final point = camera.latLngToScreenOffset(trailPoints[index]);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    return path;
  }

  double _trailWidthPixels() {
    final metersPerPixel = DiscoveryMath.metersPerPixel(
      camera.center.latitude,
      camera.zoom,
    );
    final width = (AppConstants.discoveryRadiusMeters * 2.1) / metersPerPixel;
    return width.clamp(12.0, 34.0).toDouble();
  }

  @override
  bool shouldRepaint(covariant _FogOfWarPainter oldDelegate) {
    return oldDelegate._revealSignature != _revealSignature ||
        oldDelegate._trailSignature != _trailSignature ||
        oldDelegate.revision != revision ||
        oldDelegate.camera.center != camera.center ||
        oldDelegate.camera.zoom != camera.zoom ||
        oldDelegate.camera.rotation != camera.rotation;
  }
}

class _CellStrip {
  const _CellStrip({
    required this.latIndex,
    required this.lonStart,
    required this.lonEnd,
  });

  final int latIndex;
  final int lonStart;
  final int lonEnd;
}
