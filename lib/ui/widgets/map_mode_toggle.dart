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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 220;

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x66D8B979)),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF20150E),
                Color(0xFF120D0A),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    label: 'Personal',
                    icon: Icons.person_rounded,
                    selected: mode == MapMode.personal,
                    compact: compact,
                    onTap: () => onChanged(MapMode.personal),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ModeButton(
                    label: 'Shared',
                    icon: Icons.public_rounded,
                    selected: mode == MapMode.shared,
                    compact: compact,
                    onTap: () => onChanged(MapMode.shared),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foregroundColor =
        selected ? const Color(0xFF1A1108) : const Color(0xFFE1C995);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 56),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  selected ? const Color(0xFFE6C783) : const Color(0x33C7A05A),
            ),
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFF5D79A),
                      Color(0xFFD0A24F),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF2B1D13),
                      Color(0xFF17100B),
                    ],
                  ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x44E6C783),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: compact
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: foregroundColor),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: foregroundColor,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: foregroundColor),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: foregroundColor,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
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
