import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../cloud/map_mode.dart';
import '../../cloud/models/shared_viewport_models.dart';
import '../../controllers/app_controller.dart';
import '../../core/constants/app_constants.dart';
import '../widgets/fantasy_panel.dart';
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
        final controller = widget.controller;
        final current = controller.currentLatLng;
        final center = controller.mapCenter;
        final fogReveals = controller.activeFogReveals;
        final screenWidth = MediaQuery.sizeOf(context).width;
        final realmPanelWidth =
            math.min(math.max(screenWidth * 0.56, 208.0), 260.0);

        if (_mapReady && current != null && !_autoCenteredOnLiveFix) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_mapReady || _autoCenteredOnLiveFix) {
              return;
            }
            controller.mapController.move(current, AppConstants.initialZoom);
            setState(() {
              _autoCenteredOnLiveFix = true;
              _mapRevision++;
            });
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppConstants.appName),
                Text(
                  controller.mapMode == MapMode.shared
                      ? 'Shared realm cartography'
                      : 'Personal realm cartography',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFCBAF7B),
                        letterSpacing: 0.8,
                      ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Center on me',
                onPressed: (!_mapReady || current == null)
                    ? null
                    : () {
                        controller.mapController.move(center, 17);
                        setState(() => _mapRevision++);
                      },
                icon: const Icon(Icons.my_location),
              ),
            ],
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF130E0A),
                        Color(0xFF1B140D),
                        Color(0xFF0B0D10),
                      ],
                    ),
                  ),
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      0.92,
                      0.12,
                      0.03,
                      0,
                      4,
                      0.22,
                      0.82,
                      0.08,
                      0,
                      2,
                      0.10,
                      0.16,
                      0.74,
                      0,
                      -6,
                      0.00,
                      0.00,
                      0.00,
                      1,
                      0,
                    ]),
                    child: FlutterMap(
                      mapController: controller.mapController,
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
                            if (controller.mapMode == MapMode.shared) {
                              controller.refreshSharedViewport(
                                controller.mapController.camera,
                              );
                            }
                          }
                        },
                        onPositionChanged: (_, __) {
                          if (mounted && _mapReady) {
                            setState(() => _mapRevision++);
                            if (controller.mapMode == MapMode.shared) {
                              controller.scheduleSharedViewportRefresh(
                                controller.mapController.camera,
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
                        if (controller.revealLatLngs.length > 1)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: controller.revealLatLngs,
                                strokeWidth: 2.8,
                                color: const Color(0xAED6B36A),
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            if (current != null)
                              Marker(
                                point: current,
                                width: 36,
                                height: 36,
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
                                  child: Center(
                                    child: Text(
                                      controller.profile.profileIcon,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              ),
                            if (controller.mapMode == MapMode.shared)
                              ...controller.sharedPlayers.map(_playerMarker),
                            if (controller.mapMode == MapMode.shared)
                              ...controller.sharedLandmarks.map(
                                (e) => _landmarkMarker(context, e),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0x22170F07),
                          const Color(0x44170F07),
                          const Color(0x66170F07).withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_mapReady)
                Positioned.fill(
                  child: IgnorePointer(
                    child: FogOfWarOverlay(
                      camera: controller.mapController.camera,
                      reveals: fogReveals,
                      trailPoints: controller.revealLatLngs,
                      revision: _mapRevision,
                    ),
                  ),
                ),
              Positioned.fill(
                child: SafeArea(
                  minimum: const EdgeInsets.all(12),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        child: SizedBox(
                          width: realmPanelWidth,
                          child: FantasyPanel(
                            padding: const EdgeInsets.all(12),
                            background: const [
                              Color(0xF028180D),
                              Color(0xEE17110C),
                              Color(0xEE0F151C),
                            ],
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFF0D48D),
                                            Color(0xFFA56A27),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.explore,
                                        size: 16,
                                        color: Color(0xFF18110A),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Realm View',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            letterSpacing: 1.1,
                                            color: const Color(0xFFE2C58F),
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  controller.mapMode == MapMode.shared
                                      ? 'See your trail together with nearby adventurers.'
                                      : 'Focus on your own conquest of the fog.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 12),
                                MapModeToggle(
                                  mode: controller.mapMode,
                                  onChanged: (mode) => controller.setMapMode(
                                    mode,
                                    camera: _mapReady
                                        ? controller.mapController.camera
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (controller.mapMode == MapMode.shared &&
                          !controller.isSignedIn)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 100,
                          child: FantasyPanel(
                            background: const [
                              Color(0xF04B2010),
                              Color(0xEE60311A),
                              Color(0xEE28160C),
                            ],
                            child: const Text(
                              'Sign in from the Hero tab to enter the shared world and see nearby adventurers.',
                            ),
                          ),
                        ),
                      if (_shouldShowStatus(controller))
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: screenWidth -
                                  (controller.isSignedIn ? 152 : 24),
                            ),
                            child: _StatusChip(
                              label: _statusText(controller),
                              active: controller.tracking,
                              loading:
                                  controller.sharedLoading || controller.busy,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: controller.isSignedIn
              ? FloatingActionButton.extended(
                  backgroundColor: const Color(0xFF8F5D20),
                  foregroundColor: const Color(0xFFF6E7C2),
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: Color(0x55E2C58F)),
                  ),
                  onPressed: () => _showAddLandmarkSheet(context),
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Landmark'),
                )
              : null,
        );
      },
    );
  }

  String _statusText(AppController controller) {
    if (controller.sharedLoading) {
      return 'Loading realm map...';
    }
    if (controller.busy) {
      return 'Requesting location...';
    }
    if (controller.waitingForAccurateLocation) {
      return 'Waiting for GPS...';
    }
    if (controller.tracking) {
      return 'Tracking live';
    }
    return 'Tracking unavailable';
  }

  bool _shouldShowStatus(AppController controller) {
    return controller.sharedLoading ||
        controller.busy ||
        controller.waitingForAccurateLocation ||
        !controller.tracking;
  }

  Marker _playerMarker(SharedPlayer player) {
    return Marker(
      point: LatLng(player.lat, player.lon),
      width: 74,
      height: 60,
      child: Column(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9BE7FF), Color(0xFF4EA5D9)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xAA0B0D10),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Center(
              child: Text(
                player.profileIcon,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xCC0B0D10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x55D6B36A)),
            ),
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
      width: 42,
      height: 42,
      child: GestureDetector(
        onTap: () async {
          try {
            final viewUrl = await widget.controller.getLandmarkViewUrl(
              landmark.landmarkId,
            );
            if (!context.mounted) return;
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => Padding(
                padding: const EdgeInsets.all(16),
                child: FantasyPanel(
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
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          viewUrl,
                          height: 220,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
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
            gradient: const LinearGradient(
              colors: [Color(0xFFD29B3F), Color(0xFF8F5F1D)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0xAA0B0D10),
                blurRadius: 10,
              ),
            ],
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

  Future<void> _showAddLandmarkSheet(BuildContext context) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final categoryController = TextEditingController(text: 'landmark');

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: FantasyPanel(
            background: const [
              Color(0xEE24160D),
              Color(0xEE17110D),
              Color(0xEE11161B),
            ],
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Submit Landmark',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Capture a place worth remembering. Your upload goes to review before it appears in the shared world.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: categoryController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final description = descriptionController.text.trim();
                        final category = categoryController.text.trim();

                        if (title.isEmpty ||
                            description.isEmpty ||
                            category.isEmpty) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Title, category, and description are required.'),
                            ),
                          );
                          return;
                        }

                        FocusScope.of(sheetContext).unfocus();
                        Navigator.of(sheetContext).pop();

                        try {
                          await widget.controller.uploadLandmark(
                            title: title,
                            description: description,
                            category: category,
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
    categoryController.dispose();
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.active,
    required this.loading,
  });

  final String label;
  final bool active;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FantasyPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      background: active
          ? const [
              Color(0xF0132A1A),
              Color(0xEE1E3A29),
            ]
          : const [
              Color(0xF02C1A11),
              Color(0xEE4A2A1A),
            ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                color: Colors.white,
              ),
            )
          else
            Icon(
              active ? Icons.track_changes : Icons.warning_amber_rounded,
              size: 16,
              color: Colors.white,
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
