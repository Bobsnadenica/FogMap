import 'package:flutter/material.dart';

import '../../cloud/map_mode.dart';

class MapModeToggle extends StatelessWidget {
  const MapModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final MapMode mode;
  final ValueChanged<MapMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<MapMode>(
      segments: const [
        ButtonSegment<MapMode>(
          value: MapMode.personal,
          label: Text('Personal'),
          icon: Icon(Icons.person),
        ),
        ButtonSegment<MapMode>(
          value: MapMode.shared,
          label: Text('Shared'),
          icon: Icon(Icons.public),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}