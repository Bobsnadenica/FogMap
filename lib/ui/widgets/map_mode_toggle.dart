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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0x55101314),
        border: Border.all(color: const Color(0x2FD4B16B)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _ModeButton(
                label: 'Personal',
                icon: Icons.person_pin_circle_outlined,
                selected: mode == MapMode.personal,
                onTap: () => onChanged(MapMode.personal),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _ModeButton(
                label: 'Shared',
                icon: Icons.public_outlined,
                selected: mode == MapMode.shared,
                onTap: () => onChanged(MapMode.shared),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? const Color(0xFF17140F) : const Color(0xFFF1E7D3);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFF4DFB1),
                      Color(0xFFD0A767),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x99202620),
                      Color(0x9920292E),
                    ],
                  ),
            border: Border.all(
              color: selected
                  ? const Color(0x66FFE7B0)
                  : const Color(0x22FFF4E0),
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x33D0A767),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
