import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../cloud/map_mode.dart';
import '../../cloud/models/shared_viewport_models.dart';
import '../../controllers/app_controller.dart';
import '../../core/constants/app_constants.dart';
import '../widgets/fog_of_war_overlay.dart';
import '../widgets/map_mode_toggle.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _mapRevision = 0;
  bool _mapReady = false;
  bool _autoCenteredOnLiveFix = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final current = widget.controller.currentLatLng;
        final center = widget.controller.mapCenter;
        final fogReveals = widget.controller.activeFogReveals;

        if (_mapReady && current != null && !_autoCenteredOnLiveFix) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_mapReady || _autoCenteredOnLiveFix) {
              return;
            }
            widget.controller.mapController.move(current, AppConstants.initialZoom);
            setState(() {
              _autoCenteredOnLiveFix = true;
              _mapRevision++;
            });
          });
        }

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
                        if (widget.controller.mapMode == MapMode.shared) {
                          widget.controller.refreshSharedViewport(
                            widget.controller.mapController.camera,
                          );
                        }
                      }
                    },
                    onPositionChanged: (_, __) {
                      if (mounted && _mapReady) {
                        setState(() => _mapRevision++);
                        if (widget.controller.mapMode == MapMode.shared) {
                          widget.controller.scheduleSharedViewportRefresh(
                            widget.controller.mapController.camera,
                          );
                        }
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
                    MarkerLayer(
                      markers: [
                        if (current != null)
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
                        if (widget.controller.mapMode == MapMode.shared)
                          ...widget.controller.sharedPlayers.map(_playerMarker),
                        if (widget.controller.mapMode == MapMode.shared)
                          ...widget.controller.sharedLandmarks.map(
                            (e) => _landmarkMarker(context, e),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: MapModeToggle(
                      mode: widget.controller.mapMode,
                      onChanged: (mode) => widget.controller.setMapMode(
                        mode,
                        camera: _mapReady
                            ? widget.controller.mapController.camera
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.controller.mapMode == MapMode.shared &&
                  !widget.controller.isSignedIn)
                Positioned(
                  left: 12,
                  right: 12,
                  top: 80,
                  child: Card(
                    color: const Color(0xAA5B2F1A),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Sign in from Profile to use the shared map.'),
                    ),
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
                      camera: widget.controller.mapController.camera,
                      reveals: fogReveals,
                      trailPoints: widget.controller.revealLatLngs,
                      revision: _mapRevision,
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
                          color: widget.controller.tracking
                              ? const Color(0xAA234229)
                              : const Color(0xAA4A2A1A),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: widget.controller.tracking
                                ? const Color(0xFF79C27F)
                                : const Color(0xFFD6B36A),
                          ),
                        ),
                        child: Text(
                          widget.controller.sharedLoading
                              ? 'Loading shared map...'
                              : widget.controller.busy
                                  ? 'Requesting location...'
                                  : widget.controller.waitingForAccurateLocation
                                      ? 'Waiting for accurate GPS fix...'
                                      : widget.controller.tracking
                                          ? 'Tracking active'
                                          : 'Tracking unavailable',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: widget.controller.isSignedIn
              ? FloatingActionButton.extended(
                  onPressed: () => _showAddLandmarkSheet(context),
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Landmark'),
                )
              : null,
        );
      },
    );
  }

  Marker _playerMarker(SharedPlayer player) {
    return Marker(
      point: LatLng(player.lat, player.lon),
      width: 56,
      height: 56,
      child: Column(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF6FC1FF),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            color: const Color(0xAA0B0D10),
            child: Text(
              player.displayName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Marker _landmarkMarker(BuildContext context, SharedLandmark landmark) {
    return Marker(
      point: LatLng(landmark.lat, landmark.lon),
      width: 36,
      height: 36,
      child: GestureDetector(
        onTap: () async {
          try {
            final viewUrl = await widget.controller.getLandmarkViewUrl(
              landmark.landmarkId,
            );
            if (!context.mounted) return;
            showModalBottomSheet(
              context: context,
              builder: (_) => Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      landmark.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(landmark.description),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        viewUrl,
                        height: 220,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
              ),
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to load landmark image: $e')),
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF9B6A2C),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(
            Icons.photo_camera,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _showAddLandmarkSheet(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final categoryController = TextEditingController(text: 'poi');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: categoryController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    FocusScope.of(sheetContext).unfocus();
                    Navigator.of(sheetContext).pop();

                    try {
                      await widget.controller.uploadLandmark(
                        title: titleController.text,
                        description: descriptionController.text,
                        category: categoryController.text,
                        mapZoom: 17,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Landmark uploaded for review.'),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  },
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Take photo and upload'),
                ),
              ],
            ),
          ),
        ),
      ),
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
