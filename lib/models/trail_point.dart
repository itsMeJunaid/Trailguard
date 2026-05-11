class TrailPoint {
  final double latitude;
  final double longitude;
  final double altitude;
  final double accuracy;
  final DateTime timestamp;

  const TrailPoint({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.accuracy,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lng': longitude,
    'alt': altitude,
    'acc': accuracy,
    'ts': timestamp.toIso8601String(),
  };

  factory TrailPoint.fromJson(Map<String, dynamic> j) => TrailPoint(
    latitude: j['lat'],
    longitude: j['lng'],
    altitude: j['alt'] ?? 0.0,
    accuracy: j['acc'] ?? 0.0,
    timestamp: DateTime.parse(j['ts']),
  );
}
