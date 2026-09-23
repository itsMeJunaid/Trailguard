import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Which way to turn, relative to the direction you are currently moving.
enum TurnDirection {
  straight,
  slightLeft,
  left,
  sharpLeft,
  around,
  sharpRight,
  right,
  slightRight,
}

/// One piece of navigation guidance: where to turn, how far, and how to say it.
class NavInstruction {
  /// Which way to turn relative to your current heading.
  final TurnDirection turn;

  /// Metres to the target, straight-line.
  final double distanceMeters;

  /// Compass bearing to the target, 0–360 clockwise from north.
  final double bearing;

  /// Turn angle relative to your heading, −180 (hard left) to +180 (hard right).
  /// Null when we have no heading yet — standing still gives no course.
  final double? relativeBearing;

  /// Cardinal direction to the target, e.g. `NE`. Always available.
  final String compass;

  const NavInstruction({
    required this.turn,
    required this.distanceMeters,
    required this.bearing,
    required this.compass,
    this.relativeBearing,
  });

  /// True once we are close enough that turn guidance stops being meaningful.
  bool get arrived => distanceMeters < 15;

  /// True when we had no heading and fell back to compass-only guidance.
  bool get compassOnly => relativeBearing == null;

  String get distanceLabel {
    if (distanceMeters < 1000) return '${distanceMeters.round()} m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  /// The instruction as a person would say it.
  String get text {
    if (arrived) return 'You have arrived';
    if (compassOnly) return 'Head $compass';
    switch (turn) {
      case TurnDirection.straight:
        return 'Straight ahead';
      case TurnDirection.slightLeft:
        return 'Bear left';
      case TurnDirection.left:
        return 'Turn left';
      case TurnDirection.sharpLeft:
        return 'Sharp left';
      case TurnDirection.around:
        return 'Turn around';
      case TurnDirection.sharpRight:
        return 'Sharp right';
      case TurnDirection.right:
        return 'Turn right';
      case TurnDirection.slightRight:
        return 'Bear right';
    }
  }

  /// Rotation in radians for an arrow that points at the target. When we know
  /// the heading the arrow is relative to where the user faces; otherwise it
  /// points along the absolute bearing, like a compass needle.
  double get arrowRadians =>
      ((relativeBearing ?? bearing) * math.pi) / 180.0;
}

/// Direct-line ("as the crow flies") navigation.
///
/// Deliberately not a routing engine: it needs no network and no map data, so
/// it keeps working where the app is actually used. It answers "which way do I
/// turn to get back", not "follow this path".
class NavigationService {
  static const _compassPoints = [
    'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'
  ];

  /// Guidance from [from] to [to]. Pass [headingDeg] — the direction the user
  /// is currently travelling — to get left/right turns instead of a compass
  /// bearing. Null heading (standing still, no course) degrades to compass.
  static NavInstruction guide({
    required LatLng from,
    required LatLng to,
    double? headingDeg,
  }) {
    final distance = const Distance().as(LengthUnit.Meter, from, to);
    final bearing = _bearing(from, to);

    double? relative;
    if (headingDeg != null && headingDeg >= 0) {
      // Normalise into −180..180 so the sign is the turn direction.
      relative = ((bearing - headingDeg + 540) % 360) - 180;
    }

    return NavInstruction(
      turn: _turnFor(relative),
      distanceMeters: distance,
      bearing: bearing,
      compass: compassOf(bearing),
      relativeBearing: relative,
    );
  }

  /// Heading derived from the last leg of a track. More reliable than a single
  /// GPS course reading, which is noisy at walking pace. Returns null when the
  /// last two fixes are too close together to imply a direction.
  static double? headingFromTrack(List<LatLng> recent) {
    if (recent.length < 2) return null;
    final a = recent[recent.length - 2];
    final b = recent.last;
    if (const Distance().as(LengthUnit.Meter, a, b) < 3) return null;
    return _bearing(a, b);
  }

  static String compassOf(double bearing) =>
      _compassPoints[((bearing + 22.5) ~/ 45) % 8];

  static TurnDirection _turnFor(double? relative) {
    if (relative == null) return TurnDirection.straight;
    final a = relative.abs();
    // Bands chosen so a walker is not told to "turn" for ordinary GPS wobble.
    if (a <= 12) return TurnDirection.straight;
    if (a > 160) return TurnDirection.around;
    if (relative < 0) {
      if (a <= 40) return TurnDirection.slightLeft;
      if (a <= 120) return TurnDirection.left;
      return TurnDirection.sharpLeft;
    }
    if (a <= 40) return TurnDirection.slightRight;
    if (a <= 120) return TurnDirection.right;
    return TurnDirection.sharpRight;
  }

  /// Initial great-circle bearing, 0–360 clockwise from north.
  static double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitudeInRad;
    final lat2 = to.latitudeInRad;
    final dLon = (to.longitude - from.longitude) * math.pi / 180.0;

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    return (math.atan2(y, x) * 180.0 / math.pi + 360.0) % 360.0;
  }
}
