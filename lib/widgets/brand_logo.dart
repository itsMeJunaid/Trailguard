import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme.dart';

/// Vector TrailGuard shield logo (shield + circuits + mountain + river trail).
class TrailGuardLogo extends StatelessWidget {
  final double size;
  const TrailGuardLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/trailguard_logo.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

/// Horizontal brand mark: shield + "TrailGuard AI" wordmark.
class TrailGuardBrand extends StatelessWidget {
  final double logoSize;
  final double fontSize;
  final Color? color;
  const TrailGuardBrand({
    super.key,
    this.logoSize = 36,
    this.fontSize = 22,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TrailGuardLogo(size: logoSize),
        const SizedBox(width: 10),
        Text(
          'TrailGuard AI',
          style: AppTheme.h1(color: color ?? AppTheme.primary)
              .copyWith(fontSize: fontSize),
        ),
      ],
    );
  }
}
