import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trail_marker.dart';
import '../models/trail_point.dart';
import '../services/gps_service.dart';

class TrailState {
  final bool isTracking;
  final bool isPaused;
  final List<TrailPoint> points;
  final List<TrailMarker> markers;
  final double distanceKm;
  final String trackingDuration;
  final String? returnBearing;

  const TrailState({
    this.isTracking = false,
    this.isPaused = false,
    this.points = const [],
    this.markers = const [],
    this.distanceKm = 0,
    this.trackingDuration = '00:00',
    this.returnBearing,
  });

  TrailState copyWith({
    bool? isTracking,
    bool? isPaused,
    List<TrailPoint>? points,
    List<TrailMarker>? markers,
    double? distanceKm,
    String? trackingDuration,
    String? returnBearing,
  }) =>
      TrailState(
        isTracking: isTracking ?? this.isTracking,
        isPaused: isPaused ?? this.isPaused,
        points: points ?? this.points,
        markers: markers ?? this.markers,
        distanceKm: distanceKm ?? this.distanceKm,
        trackingDuration: trackingDuration ?? this.trackingDuration,
        returnBearing: returnBearing ?? this.returnBearing,
      );
}

class TrailNotifier extends StateNotifier<TrailState> {
  final GPSService _gps = GPSService();
  StreamSubscription? _pointSub;
  StreamSubscription? _markerSub;
  DateTime? _startTime;
  Duration _accumulated = Duration.zero;
  DateTime? _segmentStart;
  Timer? _timer;

  TrailNotifier() : super(const TrailState());

  Future<void> startTracking() async {
    await _gps.startTracking();
    _startTime = DateTime.now();
    _segmentStart = _startTime;
    _accumulated = Duration.zero;

    _pointSub = _gps.pointStream.listen((_) {
      state = state.copyWith(
        points: List.from(_gps.trailPoints),
        distanceKm: _gps.totalDistanceKm,
        returnBearing: _gps.getReturnBearing(),
      );
    });

    _markerSub = _gps.markerStream.listen((_) {
      state = state.copyWith(markers: List.from(_gps.markers));
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(
        isTracking: true,
        isPaused: _gps.isPaused,
        trackingDuration: _durationLabel(),
      );
    });

    state = state.copyWith(isTracking: true, isPaused: false);
  }

  void pauseTracking() {
    if (!state.isTracking || state.isPaused) return;
    // Bank elapsed time for the active segment.
    if (_segmentStart != null) {
      _accumulated += DateTime.now().difference(_segmentStart!);
      _segmentStart = null;
    }
    _gps.pauseTracking();
    state = state.copyWith(isPaused: true);
  }

  Future<void> resumeTracking() async {
    if (!state.isTracking || !state.isPaused) return;
    await _gps.resumeTracking();
    _segmentStart = DateTime.now();
    state = state.copyWith(isPaused: false);
  }

  void stopTracking() {
    _gps.stopTracking();
    _pointSub?.cancel();
    _markerSub?.cancel();
    _timer?.cancel();
    _pointSub = null;
    _markerSub = null;
    _timer = null;
    _startTime = null;
    _segmentStart = null;
    _accumulated = Duration.zero;
    state = state.copyWith(isTracking: false, isPaused: false);
  }

  Future<TrailMarker?> addMarker(String label, {String icon = 'place'}) async {
    final marker = await _gps.addMarkerAtCurrent(label: label, icon: icon);
    state = state.copyWith(markers: List.from(_gps.markers));
    return marker;
  }

  String _durationLabel() {
    var total = _accumulated;
    if (_segmentStart != null) {
      total += DateTime.now().difference(_segmentStart!);
    }
    final m = total.inMinutes.toString().padLeft(2, '0');
    final s = (total.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    stopTracking();
    _gps.dispose();
    super.dispose();
  }
}

final trailProvider = StateNotifierProvider<TrailNotifier, TrailState>(
  (_) => TrailNotifier(),
);
