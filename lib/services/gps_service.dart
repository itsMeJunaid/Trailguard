import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/trail_marker.dart';
import '../models/trail_point.dart';

class GPSService {
  StreamSubscription<Position>? _subscription;
  final List<TrailPoint> _trailPoints = [];
  final List<TrailMarker> _markers = [];
  TrailPoint? _startPoint;
  bool _isTracking = false;
  bool _isPaused = false;

  bool get isTracking => _isTracking;
  bool get isPaused => _isPaused;
  List<TrailPoint> get trailPoints => List.unmodifiable(_trailPoints);
  List<TrailMarker> get markers => List.unmodifiable(_markers);
  TrailPoint? get startPoint => _startPoint;
  TrailPoint? get currentPoint =>
      _trailPoints.isNotEmpty ? _trailPoints.last : null;

  final StreamController<TrailPoint> _pointController =
      StreamController.broadcast();
  Stream<TrailPoint> get pointStream => _pointController.stream;

  final StreamController<TrailMarker> _markerController =
      StreamController.broadcast();
  Stream<TrailMarker> get markerStream => _markerController.stream;

  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> startTracking() async {
    if (_isTracking) return;
    _trailPoints.clear();
    _markers.clear();
    _startPoint = null;
    _isPaused = false;
    await _subscribe();
    _isTracking = true;
  }

  /// Pause keeps points + markers intact; only stops receiving new GPS fixes.
  void pauseTracking() {
    if (!_isTracking || _isPaused) return;
    _subscription?.cancel();
    _subscription = null;
    _isPaused = true;
  }

  /// Resume picks up new fixes and appends them to the existing trail.
  Future<void> resumeTracking() async {
    if (!_isTracking || !_isPaused) return;
    await _subscribe();
    _isPaused = false;
  }

  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
    _isTracking = false;
    _isPaused = false;
  }

  Future<void> _subscribe() async {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen((position) {
      final point = TrailPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
      );
      if (_startPoint == null) _startPoint = point;
      _trailPoints.add(point);
      _pointController.add(point);
    });
  }

  /// Drop a named pin at the current GPS position (or the last known point
  /// if we're paused / no fix).
  Future<TrailMarker?> addMarkerAtCurrent({
    required String label,
    String icon = 'place',
  }) async {
    TrailPoint? at = currentPoint;
    if (at == null) {
      final pos = await getCurrentPosition();
      if (pos != null) {
        at = TrailPoint(
          latitude: pos.latitude,
          longitude: pos.longitude,
          altitude: pos.altitude,
          accuracy: pos.accuracy,
          timestamp: DateTime.now(),
        );
      }
    }
    if (at == null) return null;

    final marker = TrailMarker(
      latitude: at.latitude,
      longitude: at.longitude,
      label: label,
      icon: icon,
      timestamp: DateTime.now(),
    );
    _markers.add(marker);
    _markerController.add(marker);
    return marker;
  }

  double get totalDistanceKm {
    if (_trailPoints.length < 2) return 0.0;
    double total = 0;
    for (int i = 1; i < _trailPoints.length; i++) {
      total += Geolocator.distanceBetween(
        _trailPoints[i - 1].latitude,
        _trailPoints[i - 1].longitude,
        _trailPoints[i].latitude,
        _trailPoints[i].longitude,
      );
    }
    return total / 1000;
  }

  String? getReturnBearing() {
    if (_startPoint == null || currentPoint == null) return null;
    final bearing = Geolocator.bearingBetween(
      currentPoint!.latitude,
      currentPoint!.longitude,
      _startPoint!.latitude,
      _startPoint!.longitude,
    );
    return _bearingToDirection(bearing);
  }

  String _bearingToDirection(double bearing) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[((bearing + 22.5) / 45).floor() % 8];
  }

  void dispose() {
    stopTracking();
    _pointController.close();
    _markerController.close();
  }
}
