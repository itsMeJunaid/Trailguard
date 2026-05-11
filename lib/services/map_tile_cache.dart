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
  final MapTileCacheManager _cache = MapTileCacheManager();

  @override
  ImageProvider getImage(TileCoordinates coords, TileLayer options) {
    final url = getTileUrl(coords, options);
    return _CachedTileImage(url, _cache);
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
