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
        final headerWidth = math.min(math.max(screenWidth * 0.58, 232.0), 320.0);

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
          backgroundColor: const Color(0xFF0D1113),
          body: Stack(
            children: [
              Positioned.fill(
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    0.90, 0.08, 0.02, 0, 8,
                    0.12, 0.90, 0.04, 0, 5,
                    0.05, 0.10, 0.86, 0, 0,
                    0.00, 0.00, 0.00, 1, 0,
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
                              strokeWidth: 3.2,
                              color: const Color(0xBFE9D3A4),
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          if (current != null) _currentMarker(controller, current),
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
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0x22090A0B),
                          Colors.transparent,
                          const Color(0x22090A0B),
                        ],
                        stops: const [0.0, 0.32, 1.0],
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
                  minimum: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        child: SizedBox(
                          width: headerWidth,
                          child: _AtlasHeaderCard(controller: controller),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Column(
                          children: [
                            _MapActionButton(
                              icon: Icons.my_location_rounded,
                              tooltip: 'Center on me',
                              onPressed: (!_mapReady || current == null)
                                  ? null
                                  : () {
                                      controller.mapController
                                          .move(center, AppConstants.initialZoom);
                                      setState(() => _mapRevision++);
                                    },
                            ),
                            if (controller.isSignedIn) ...[
                              const SizedBox(height: 10),
                              _MapActionButton(
                                icon: Icons.add_a_photo_outlined,
                                tooltip: 'New landmark',
                                onPressed: () => _showAddLandmarkSheet(context),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_shouldShowStatus(controller))
                        Positioned(
                          left: 0,
                          right: 72,
                          bottom: 116,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: math.min(screenWidth - 100, 320),
                              ),
                              child: _StatusChip(
                                label: _statusText(controller),
                                active: controller.tracking,
                                loading: controller.sharedLoading ||
                                    controller.busy,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: _RealmCard(
                              controller: controller,
                              onChanged: (mode) => controller.setMapMode(
                                mode,
                                camera: _mapReady
                                    ? controller.mapController.camera
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusText(AppController controller) {
    if (controller.sharedLoading) {
      return 'Loading realm map';
    }
    if (controller.busy) {
      return 'Requesting location';
    }
    if (controller.waitingForAccurateLocation) {
      return 'Waiting for GPS lock';
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

  Marker _currentMarker(AppController controller, LatLng current) {
    return Marker(
      point: current,
      width: 44,
      height: 44,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF2E1B8),
              Color(0xFFD2A562),
            ],
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFF9F2E5),
            width: 2.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66101010),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            controller.profile.profileIcon,
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }

  Marker _playerMarker(SharedPlayer player) {
    return Marker(
      point: LatLng(player.lat, player.lon),
      width: 84,
      height: 64,
      child: Column(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDAE7ED), Color(0xFF6FA4BE)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF5F1E8), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66101010),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Text(
                player.profileIcon,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xC8171B1D),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x30F1E5D2)),
            ),
            child: Text(
              player.displayName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: Color(0xFFF3EBDC)),
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
                        borderRadius: BorderRadius.circular(18),
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
              colors: [Color(0xFFF0C87C), Color(0xFFAD7A34)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFF5F1E8), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66101010),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Icon(
            Icons.photo_camera_outlined,
            size: 18,
            color: Color(0xFF17140F),
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
              Color(0xD4151917),
              Color(0xD41B221C),
              Color(0xD414181A),
            ],
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Landmark',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Capture a place worth remembering. Your upload goes to review before it appears in the shared realm.',
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
                                'Title, category, and description are required.',
                              ),
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
                      icon: const Icon(Icons.photo_camera_outlined),
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

class _AtlasHeaderCard extends StatelessWidget {
  const _AtlasHeaderCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return FantasyPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      background: const [
        Color(0xC9131715),
        Color(0xC91A1F1B),
        Color(0xC914181A),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF0D8A8),
                  Color(0xFFC48E4A),
                ],
              ),
            ),
            child: const Icon(
              Icons.explore_outlined,
              color: Color(0xFF17140F),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  controller.mapMode == MapMode.shared
                      ? 'A map-first realm view: your trail, nearby adventurers, and approved landmarks.'
                      : 'A map-first personal atlas that reveals only the places you have truly walked.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RealmCard extends StatelessWidget {
  const _RealmCard({
    required this.controller,
    required this.onChanged,
  });

  final AppController controller;
  final ValueChanged<MapMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return FantasyPanel(
      padding: const EdgeInsets.all(14),
      background: const [
        Color(0xD4131715),
        Color(0xD41A1F1B),
        Color(0xD414181A),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0x22F2E8D1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.layers_outlined,
                  size: 18,
                  color: Color(0xFFF2E8D1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Realm View',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      controller.mapMode == MapMode.shared
                          ? 'Your atlas blended with live realm activity.'
                          : 'Stay focused on your own discovered world.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MapModeToggle(
            mode: controller.mapMode,
            onChanged: onChanged,
          ),
          if (controller.mapMode == MapMode.shared && !controller.isSignedIn) ...[
            const SizedBox(height: 10),
            Text(
              'Sign in from Atlas to enter the shared realm and see nearby adventurers.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xC9131715),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x34F2E8D1)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              icon,
              color: onPressed == null
                  ? const Color(0x66F2E8D1)
                  : const Color(0xFFF2E8D1),
            ),
          ),
        ),
      ),
    );
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
              Color(0xC916241C),
              Color(0xC91C2F25),
            ]
          : const [
              Color(0xC9271816),
              Color(0xC937211B),
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
                color: Color(0xFFF2E8D1),
              ),
            )
          else
            Icon(
              active ? Icons.track_changes : Icons.warning_amber_rounded,
              size: 16,
              color: const Color(0xFFF2E8D1),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFFF2E8D1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
