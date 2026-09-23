import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';

/// A tap target that actually responds.
///
/// Ripple, hover, a real keyboard focus ring, a disabled state, a
/// screen-reader name and a 48px minimum — none of which a bare
/// `GestureDetector` gives you. Pass `onPressed: null` to disable it.
class Pressable extends StatefulWidget {
  final Widget child;

  /// Null disables the control: dimmed, no ripple, no hover, not focusable.
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  /// Screen-reader name. Required — an unnamed button is an invisible one.
  final String label;

  /// Shown on hover and long-press. Defaults to [label]. On a disabled
  /// control this is where you say *why* it is disabled. Pass `''` to suppress.
  final String? tooltip;

  final BorderRadius? borderRadius;
  final bool circle;
  final Color? background;
  final double minSize;

  /// Tactile confirmation on press. Silently no-ops on web.
  final bool haptic;

  /// Material elevation. Kept at 0 for controls; used only where the surface
  /// genuinely floats above the map.
  final double elevation;

  const Pressable({
    super.key,
    required this.child,
    required this.label,
    this.onPressed,
    this.onLongPress,
    this.tooltip,
    this.borderRadius,
    this.circle = false,
    this.background,
    this.minSize = AppTheme.minTapTarget,
    this.haptic = true,
    this.elevation = 0,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null || widget.onLongPress != null;
    final radius =
        widget.borderRadius ?? BorderRadius.circular(AppTheme.radiusPill);
    final ShapeBorder shape = widget.circle
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: radius);

    Widget button = Material(
      color: widget.background ?? Colors.transparent,
      elevation: widget.elevation,
      shadowColor: AppTheme.onPrimaryFixed.withValues(alpha: 0.25),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: shape,
        onTap: widget.onPressed == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.lightImpact();
                widget.onPressed!();
              },
        onLongPress: widget.onLongPress,
        onFocusChange: (f) => setState(() => _focused = f),
        hoverColor: AppTheme.hoverOverlay,
        focusColor: AppTheme.focusOverlay,
        highlightColor: AppTheme.pressedOverlay,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(minWidth: widget.minSize, minHeight: widget.minSize),
          child: Center(widthFactor: 1, heightFactor: 1, child: widget.child),
        ),
      ),
    );

    // Keyboard focus gets a real 2px ring, not just a tint — a tint alone is
    // one channel and does not reach 3:1 against a filled control. Drawn as a
    // foreground decoration so it never shifts layout, and flipped to white on
    // dark fills so it stays visible on the primary and error buttons.
    if (_focused && enabled) {
      final onDark = widget.background != null &&
          ThemeData.estimateBrightnessForColor(widget.background!) ==
              Brightness.dark;
      final ringColor = onDark ? Colors.white : AppTheme.primary;
      final side = BorderSide(color: ringColor, width: 2);
      button = Container(
        foregroundDecoration: ShapeDecoration(
          shape: widget.circle
              ? CircleBorder(side: side)
              : RoundedRectangleBorder(borderRadius: radius, side: side),
        ),
        child: button,
      );
    }

    if (!enabled) {
      button = Opacity(opacity: AppTheme.disabledOpacity, child: button);
    }

    // Deliberately also shown when disabled — that is exactly when the user
    // needs to be told why they cannot press it.
    final tip = widget.tooltip ?? widget.label;
    if (tip.isNotEmpty) {
      button = Tooltip(message: tip, child: button);
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: button,
    );
  }
}
