import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../controllers/app_controller.dart';
import '../../core/constants/app_constants.dart';
import '../widgets/fog_of_war_overlay.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _mapRevision = 0;
  bool _mapReady = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final current = widget.controller.currentLatLng;
        final center = current ??
            const LatLng(
              AppConstants.defaultLat,
              AppConstants.defaultLon,
            );

        final isTracking = widget.controller.tracking;
        final isBusy = widget.controller.busy;

        return Scaffold(
          appBar: AppBar(
            title: const Text('World Of Fog'),
            actions: [
              IconButton(
                tooltip: 'Center on me',
                onPressed: (!_mapReady || current == null)
                    ? null
                    : () {
                        widget.controller.mapController.move(center, 17);
                        setState(() => _mapRevision++);
                      },
                icon: const Icon(Icons.my_location),
              ),
            ],
          ),
          body: Stack(
            children: [
              ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  0.92, 0.12, 0.03, 0, 4,
                  0.22, 0.82, 0.08, 0, 2,
                  0.10, 0.16, 0.74, 0, -6,
                  0.00, 0.00, 0.00, 1, 0,
                ]),
                child: FlutterMap(
                  mapController: widget.controller.mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: AppConstants.initialZoom,
                    minZoom: AppConstants.minZoom,
                    maxZoom: AppConstants.maxZoom,
                    onMapReady: () {
                      if (mounted && !_mapReady) {
                        setState(() {
                          _mapReady = true;
                          _mapRevision++;
                        });
                      }
                    },
                    onPositionChanged: (_, __) {
                      if (mounted && _mapReady) {
                        setState(() => _mapRevision++);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: AppConstants.tileUrlTemplate,
                      userAgentPackageName:
                          AppConstants.userAgentPackageName,
                    ),
                    if (widget.controller.revealLatLngs.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: widget.controller.revealLatLngs,
                            strokeWidth: 2.5,
                            color: const Color(0xA8D6B36A),
                          ),
                        ],
                      ),
                    if (current != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: current,
                            width: 28,
                            height: 28,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFD6B36A),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: const Color(0x10170F07),
                  ),
                ),
              ),
              if (_mapReady)
                Positioned.fill(
                  child: IgnorePointer(
                    child: FogOfWarOverlay(
                      key: ValueKey(_mapRevision),
                      camera: widget.controller.mapController.camera,
                      reveals: widget.controller.reveals,
                    ),
                  ),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0x996A4A22),
                        width: 6,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                left: 12,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _MiniStat(
                              label: 'Cells',
                              value:
                                  '${widget.controller.discoveredCellsCount}',
                            ),
                            _MiniStat(
                              label: 'Coverage',
                              value:
                                  '${widget.controller.coveragePercent.toStringAsFixed(6)}%',
                            ),
                            _MiniStat(
                              label: 'Distance',
                              value:
                                  '${widget.controller.totalKm.toStringAsFixed(2)} km',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isTracking
                              ? const Color(0xAA234229)
                              : const Color(0xAA4A2A1A),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isTracking
                                ? const Color(0xFF79C27F)
                                : const Color(0xFFD6B36A),
                          ),
                        ),
                        child: Text(
                          isBusy
                              ? 'Requesting location...'
                              : isTracking
                                  ? 'Tracking active'
                                  : 'Tracking unavailable',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xAA0B0D10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '© OpenStreetMap contributors',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white60,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}