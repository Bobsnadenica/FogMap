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
  });

  final MapCamera camera;
  final List<RevealPoint> reveals;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FogOfWarPainter(
        camera: camera,
        reveals: reveals,
      ),
      size: Size.infinite,
    );
  }
}

class _FogOfWarPainter extends CustomPainter {
  _FogOfWarPainter({
    required this.camera,
    required this.reveals,
  });

  final MapCamera camera;
  final List<RevealPoint> reveals;

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

    for (final reveal in reveals) {
      final latLng = LatLng(reveal.latitude, reveal.longitude);
      final screenPoint = camera.latLngToScreenOffset(latLng);
      final radiusPx = _radiusInPixels(latLng.latitude, camera.zoom);

      if (screenPoint.dx < -radiusPx * 2 ||
          screenPoint.dx > size.width + radiusPx * 2 ||
          screenPoint.dy < -radiusPx * 2 ||
          screenPoint.dy > size.height + radiusPx * 2) {
        continue;
      }

      final revealRect = Rect.fromCircle(
        center: screenPoint,
        radius: radiusPx * 1.75,
      );

      // Softer outer reveal + much clearer center.
      final revealPaint = Paint()
        ..blendMode = BlendMode.dstOut
        ..shader = RadialGradient(
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xF2FFFFFF),
            Color(0xB8FFFFFF),
            Color(0x55FFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: const [0.0, 0.24, 0.48, 0.78, 1.0],
        ).createShader(revealRect);

      canvas.drawCircle(screenPoint, radiusPx * 1.75, revealPaint);

      // Clear center so discovered roads/labels become readable.
      canvas.drawCircle(
        screenPoint,
        radiusPx * 0.72,
        Paint()..blendMode = BlendMode.clear,
      );
    }

    canvas.restore();

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0x996A4A22);

    canvas.drawRect(rect.deflate(3), borderPaint);
  }

  double _radiusInPixels(double latitude, double zoom) {
    final metersPerPixel = DiscoveryMath.metersPerPixel(latitude, zoom);
    return AppConstants.discoveryRadiusMeters / metersPerPixel;
  }

  @override
  bool shouldRepaint(covariant _FogOfWarPainter oldDelegate) {
    return oldDelegate.reveals.length != reveals.length ||
        oldDelegate.camera.center != camera.center ||
        oldDelegate.camera.zoom != camera.zoom ||
        oldDelegate.camera.rotation != camera.rotation;
  }
}