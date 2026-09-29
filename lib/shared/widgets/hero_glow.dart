import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// A soft primary-colored circle used to light the dark hero gradients.
class HeroGlow extends StatelessWidget {
  const HeroGlow({super.key, required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppTheme.primary.withValues(alpha: opacity),
    ),
  );
}
