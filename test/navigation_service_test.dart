import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trailguard_ai/services/navigation_service.dart';

void main() {
  // Equator origin, so a degree of longitude and latitude are comparable and
  // the bearings come out at exact cardinals.
  const origin = LatLng(0, 0);
  const north = LatLng(0.01, 0);
  const east = LatLng(0, 0.01);
  const south = LatLng(-0.01, 0);
  const west = LatLng(0, -0.01);

  group('turn direction, walking north', () {
    NavInstruction to(LatLng target) =>
        NavigationService.guide(from: origin, to: target, headingDeg: 0);

    test('target ahead is straight on', () {
      expect(to(north).turn, TurnDirection.straight);
      expect(to(north).text, 'Straight ahead');
    });

    test('target to the east is a right turn', () {
      final nav = to(east);
      expect(nav.turn, TurnDirection.right);
      expect(nav.text, 'Turn right');
      expect(nav.relativeBearing, closeTo(90, 0.5));
    });

    test('target to the west is a left turn', () {
      final nav = to(west);
      expect(nav.turn, TurnDirection.left);
      expect(nav.text, 'Turn left');
      expect(nav.relativeBearing, closeTo(-90, 0.5));
    });

    test('target behind is a turnaround', () {
      expect(to(south).turn, TurnDirection.around);
      expect(to(south).text, 'Turn around');
    });
  });

  test('walking east, a northern target is a left turn', () {
    final nav = NavigationService.guide(
        from: origin, to: north, headingDeg: 90);
    expect(nav.turn, TurnDirection.left);
  });

  test('small deviations are not called turns', () {
    // ~8 degrees off: GPS wobble, not a turn.
    final nav = NavigationService.guide(
        from: origin, to: north, headingDeg: 352);
    expect(nav.turn, TurnDirection.straight);
  });

  test('no heading falls back to compass, not a bogus turn', () {
    final nav = NavigationService.guide(from: origin, to: east);
    expect(nav.compassOnly, isTrue);
    expect(nav.compass, 'E');
    expect(nav.text, 'Head E');
  });

  test('arrival stops turn guidance', () {
    final nav = NavigationService.guide(
        from: origin, to: const LatLng(0.00005, 0), headingDeg: 0);
    expect(nav.arrived, isTrue);
    expect(nav.text, 'You have arrived');
  });

  group('distance label', () {
    test('metres below a kilometre', () {
      // 0.001 degrees of longitude at the equator is ~111 m.
      final nav =
          NavigationService.guide(from: origin, to: const LatLng(0, 0.001));
      expect(nav.distanceLabel, endsWith(' m'));
      expect(nav.distanceMeters, closeTo(111, 5));
    });

    test('kilometres above one', () {
      final nav =
          NavigationService.guide(from: origin, to: const LatLng(0, 0.5));
      expect(nav.distanceLabel, endsWith(' km'));
    });
  });

  group('heading from track', () {
    test('needs two points', () {
      expect(NavigationService.headingFromTrack([origin]), isNull);
    });

    test('ignores a leg too short to imply direction', () {
      expect(
        NavigationService.headingFromTrack([origin, const LatLng(0.00001, 0)]),
        isNull,
      );
    });

    test('reads the bearing of the last leg', () {
      final h = NavigationService.headingFromTrack([south, origin, east]);
      expect(h, closeTo(90, 0.5));
    });
  });

  test('compass covers all eight points', () {
    expect(NavigationService.compassOf(0), 'N');
    expect(NavigationService.compassOf(45), 'NE');
    expect(NavigationService.compassOf(90), 'E');
    expect(NavigationService.compassOf(180), 'S');
    expect(NavigationService.compassOf(315), 'NW');
    expect(NavigationService.compassOf(359), 'N');
  });
}
