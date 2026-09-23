import 'package:flutter/material.dart';

/// A basemap TrailGuard can draw, with the attribution its licence requires.
///
/// All three are keyless on purpose — the app asks for location permission and
/// nothing else. No account, no API key, no billing to set up.
class MapLayerSource {
  final String id;
  final String name;

  /// Why a hiker would pick this one.
  final String blurb;

  final IconData icon;
  final String urlTemplate;

  /// Attribution text. Required by every one of these licences — showing the
  /// tiles without it is a licence violation, not a style choice.
  final String attribution;
  final String attributionUrl;

  /// Highest zoom the server actually publishes. Past this the tiles 404 and
  /// the map goes blank, so flutter_map must be told where to stop.
  final int maxZoom;

  const MapLayerSource({
    required this.id,
    required this.name,
    required this.blurb,
    required this.icon,
    required this.urlTemplate,
    required this.attribution,
    required this.attributionUrl,
    required this.maxZoom,
  });

  static const topo = MapLayerSource(
    id: 'topo',
    name: 'Topographic',
    blurb: 'Contours, paths and peaks. Best for hiking.',
    icon: Icons.terrain_rounded,
    urlTemplate: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
    attribution: '© OpenTopoMap (CC-BY-SA) · © OpenStreetMap contributors',
    attributionUrl: 'https://opentopomap.org/about',
    // OpenTopoMap publishes to z17 only.
    maxZoom: 17,
  );

  static const standard = MapLayerSource(
    id: 'standard',
    name: 'Standard',
    blurb: 'Familiar street map. Lightest to load.',
    icon: Icons.map_rounded,
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '© OpenStreetMap contributors',
    attributionUrl: 'https://www.openstreetmap.org/copyright',
    maxZoom: 19,
  );

  static const satellite = MapLayerSource(
    id: 'satellite',
    name: 'Satellite',
    blurb: 'Real imagery. Good for spotting water and cover.',
    icon: Icons.satellite_alt_rounded,
    // Note the {z}/{y}/{x} order — Esri differs from the OSM convention.
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    attribution: 'Imagery © Esri, Maxar, Earthstar Geographics',
    attributionUrl:
        'https://www.arcgis.com/home/item.html?id=10df2279f9684e4a9f6a7f08febac2a9',
    maxZoom: 19,
  );

  /// Topographic first: this is a hiking app, not a driving one.
  static const all = [topo, standard, satellite];

  static MapLayerSource byId(String? id) =>
      all.firstWhere((l) => l.id == id, orElse: () => topo);
}
