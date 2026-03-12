import 'package:flutter/material.dart';

class FantasyPanel extends StatelessWidget {
  const FantasyPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accentColor = const Color(0xFFD6B36A),
    this.background = const [
      Color(0xEE1B1610),
      Color(0xEE241C14),
      Color(0xEE151A20),
    ],
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color accentColor;
  final List<Color> background;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: background,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x1FFFFFFF)),
        ),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class FantasyProgressBar extends StatelessWidget {
  const FantasyProgressBar({
    super.key,
    required this.value,
    this.height = 10,
    this.fill = const [Color(0xFFB87924), Color(0xFFE8C26B)],
    this.trackColor = const Color(0x5524130A),
  });

  final double value;
  final double height;
  final List<Color> fill;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: BorderRadius.circular(height),
              ),
            ),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: clamped,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: fill),
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
