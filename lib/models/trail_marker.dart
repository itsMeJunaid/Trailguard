class TrailMarker {
  final double latitude;
  final double longitude;
  final String label;
  final String icon;
  final DateTime timestamp;

  const TrailMarker({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.icon,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'label': label,
        'icon': icon,
        'ts': timestamp.toIso8601String(),
      };

  factory TrailMarker.fromJson(Map<String, dynamic> j) => TrailMarker(
        latitude: (j['lat'] as num).toDouble(),
        longitude: (j['lng'] as num).toDouble(),
        label: j['label'] as String,
        icon: j['icon'] as String? ?? 'place',
        timestamp: DateTime.parse(j['ts']),
      );

  /// Predefined marker kinds → label + Material icon name.
  static const Map<String, String> suggestedIcons = {
    'hotel': 'hotel',
    'camp': 'cottage',
    'water': 'water_drop',
    'view': 'landscape',
    'food': 'restaurant',
    'hazard': 'warning',
    'rest': 'pause_circle',
    'place': 'place',
  };
}
