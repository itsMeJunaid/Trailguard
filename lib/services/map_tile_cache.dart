import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_map/flutter_map.dart';

/// Custom CacheManager tuned for OSM map tiles:
/// • 90-day stalePeriod so cached tiles stay useful during long offline treks
/// • 5 000 maxNrOfCacheObjects — covers a ~15 km radius at zoom 14–16
class MapTileCacheManager extends CacheManager with ImageCacheManager {
  static const _key = 'trailguard_osm_tiles';

  static final MapTileCacheManager _instance = MapTileCacheManager._();
  factory MapTileCacheManager() => _instance;

  MapTileCacheManager._()
      : super(
          Config(
            _key,
            stalePeriod: const Duration(days: 90),
            maxNrOfCacheObjects: 5000,
          ),
        );
}

/// TileProvider that reads from [MapTileCacheManager] first, falling back to
/// network if the tile isn't cached. This lets the map work offline for any
/// area the user has already viewed while online.
class CachedTileProvider extends TileProvider {
  // Built lazily so the file-backed cache manager is never constructed on web.
  MapTileCacheManager? _cache;

  @override
  ImageProvider getImage(TileCoordinates coords, TileLayer options) {
    final url = getTileUrl(coords, options);
    // The browser already keeps its own HTTP cache and has no writable tile
    // directory, so on web flutter_map gets a plain network image.
    if (kIsWeb) return NetworkImage(url);
    return _CachedTileImage(url, _cache ??= MapTileCacheManager());
  }
}

/// ImageProvider backed by flutter_cache_manager — tries local cache first,
/// fetches from network on miss, then caches the result for offline use.
class _CachedTileImage extends ImageProvider<_CachedTileImage> {
  final String url;
  final MapTileCacheManager cache;

  _CachedTileImage(this.url, this.cache);

  @override
  ImageStreamCompleter loadImage(
      _CachedTileImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadTile(key, decode),
      scale: 1.0,
    );
  }

  Future<ui.Codec> _loadTile(
      _CachedTileImage key, ImageDecoderCallback decode) async {
    final file = await cache.getSingleFile(key.url);
    final bytes = await file.readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  Future<_CachedTileImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is _CachedTileImage && other.url == url);

  @override
  int get hashCode => url.hashCode;
}

/// Pre-fetches every tile covering a bounding box across a zoom range, so the
/// area is on disk before the signal disappears.
///
/// Android/iOS only. `flutter_cache_manager` on web is backed by
/// `MemoryCacheSystem` with a `NonStoringObjectProvider` — the cache is RAM and
/// is wiped on reload — so downloading there would burn bandwidth and persist
/// nothing. [isSupported] says so rather than pretending.
class TileAreaDownloader {
  static bool get isSupported => !kIsWeb;

  static const String unsupportedMessage =
      'Offline map download needs the Android app — a browser tab cannot keep '
      'map tiles between visits.';

  final MapTileCacheManager _cache = MapTileCacheManager();
  bool _cancelled = false;

  void cancel() => _cancelled = true;

  /// Tile x/y covering [lat]/[lon] at [zoom] (standard slippy-map scheme).
  static Point<int> tileFor(double lat, double lon, int zoom) {
    final n = 1 << zoom;
    final latRad = lat * pi / 180.0;
    final x = ((lon + 180.0) / 360.0 * n).floor();
    final y = ((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0 * n)
        .floor();
    return Point(x.clamp(0, n - 1), y.clamp(0, n - 1));
  }

  /// Number of tiles [download] would fetch — show this before starting so the
  /// user is not surprised by the data cost.
  static int estimateTiles({
    required double north,
    required double south,
    required double east,
    required double west,
    required int minZoom,
    required int maxZoom,
  }) {
    var total = 0;
    for (var z = minZoom; z <= maxZoom; z++) {
      final tl = tileFor(north, west, z);
      final br = tileFor(south, east, z);
      total += ((br.x - tl.x).abs() + 1) * ((br.y - tl.y).abs() + 1);
    }
    return total;
  }

  /// Fetches the area into the tile cache. [onProgress] fires with
  /// (done, total). Failed tiles are skipped, not fatal — a partial offline
  /// area still beats none.
  Future<int> download({
    required String urlTemplate,
    required double north,
    required double south,
    required double east,
    required double west,
    required int minZoom,
    required int maxZoom,
    void Function(int done, int total)? onProgress,
  }) async {
    if (!isSupported) throw UnsupportedError(unsupportedMessage);
    _cancelled = false;

    final total = estimateTiles(
      north: north, south: south, east: east, west: west,
      minZoom: minZoom, maxZoom: maxZoom,
    );
    var done = 0;
    var saved = 0;

    for (var z = minZoom; z <= maxZoom && !_cancelled; z++) {
      final tl = tileFor(north, west, z);
      final br = tileFor(south, east, z);
      final x0 = min(tl.x, br.x), x1 = max(tl.x, br.x);
      final y0 = min(tl.y, br.y), y1 = max(tl.y, br.y);

      for (var x = x0; x <= x1 && !_cancelled; x++) {
        for (var y = y0; y <= y1 && !_cancelled; y++) {
          final url = urlTemplate
              .replaceAll('{z}', '$z')
              .replaceAll('{x}', '$x')
              .replaceAll('{y}', '$y');
          try {
            await _cache.getSingleFile(url);
            saved++;
          } catch (_) {
            // Tile missing or server throttling — keep going.
          }
          done++;
          onProgress?.call(done, total);
        }
      }
    }
    return saved;
  }
}
