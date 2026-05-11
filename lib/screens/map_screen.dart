import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme.dart';
import '../providers/trail_provider.dart';
import '../services/ai_service.dart';
import '../services/map_tile_cache.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  final AIService _ai = AIService();
  final CachedTileProvider _tileProvider = CachedTileProvider();

  String? _aiTip;
  bool _tipLoading = false;
  DateTime? _lastTipAt;
  double _lastGuidedKm = 0;
  bool _sheetExpanded = true;

  /// Live GPS position for the blue dot (independent of trail tracking).
  LatLng? _livePosition;
  double _liveAccuracy = 0;
  StreamSubscription<Position>? _gpsSub;

  @override
  void initState() {
    super.initState();
    _startLiveGps();
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    super.dispose();
  }

  Future<void> _startLiveGps() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) return;

      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
        ),
      ).listen((pos) {
        if (!mounted) return;
        setState(() {
          _livePosition = LatLng(pos.latitude, pos.longitude);
          _liveAccuracy = pos.accuracy;
        });
      });

      // Also grab an initial fix so the dot appears immediately.
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      if (mounted) {
        setState(() {
          _livePosition = LatLng(pos.latitude, pos.longitude);
          _liveAccuracy = pos.accuracy;
        });
      }
    } catch (_) {}
  }

  Future<void> _centerOnMe() async {
    // Prefer the live-streamed position (already updating via _gpsSub).
    if (_livePosition != null) {
      _mapController.move(_livePosition!, 16);
      return;
    }
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _mapController.move(LatLng(last.latitude, last.longitude), 15);
      }
    }
  }

  Future<void> _requestTrailTip() async {
    if (_tipLoading) return;
    final trail = ref.read(trailProvider);
    final current = trail.points.isEmpty ? null : trail.points.last;
    if (current == null) return;

    setState(() => _tipLoading = true);
    final ctx =
        'Position: ${current.latitude.toStringAsFixed(4)}, ${current.longitude.toStringAsFixed(4)}. '
        'Altitude: ${current.altitude.toStringAsFixed(0)}m. '
        'Distance walked: ${trail.distanceKm.toStringAsFixed(2)} km in ${trail.trackingDuration}. '
        'Return bearing: ${trail.returnBearing ?? "unknown"}.';

    final tip = await _ai.chatWithPrompt(
      systemPrompt: AIService.trailGuidePrompt,
      userMessage: ctx,
    );

    setState(() {
      _aiTip = tip;
      _tipLoading = false;
      _lastTipAt = DateTime.now();
      _lastGuidedKm = trail.distanceKm;
    });
  }

  void _maybeAutoTip(double distanceKm, bool paused) {
    if (paused) return;
    if (distanceKm - _lastGuidedKm < 0.5) return;
    if (_lastTipAt != null &&
        DateTime.now().difference(_lastTipAt!).inSeconds < 180) return;
    _requestTrailTip();
  }

  Future<void> _showPinDialog() async {
    final label = await showModalBottomSheet<_PinChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _PinSheet(),
    );

    if (label == null || label.text.trim().isEmpty) return;

    final marker = await ref
        .read(trailProvider.notifier)
        .addMarker(label.text.trim(), icon: label.iconKey);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: marker != null ? AppTheme.primary : AppTheme.error,
      behavior: SnackBarBehavior.floating,
      content: Text(marker != null
          ? 'Pinned "${marker.label}"'
          : 'Could not get location — try again in a moment.'),
    ));
  }

  IconData _iconFor(String key) {
    switch (key) {
      case 'hotel':
        return Icons.hotel_rounded;
      case 'camp':
        return Icons.cottage_rounded;
      case 'water':
        return Icons.water_drop_rounded;
      case 'view':
        return Icons.landscape_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'hazard':
        return Icons.warning_amber_rounded;
      case 'rest':
        return Icons.pause_circle_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  Future<void> _openSearch() async {
    final trail = ref.read(trailProvider);
    final result = await showModalBottomSheet<_SearchAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _SearchSheet(
        markers: trail.markers,
        iconFor: _iconFor,
      ),
    );

    if (result == null) return;

    switch (result.type) {
      case _SearchActionType.goto:
        _mapController.move(
          LatLng(result.lat!, result.lng!),
          17,
        );
        break;
      case _SearchActionType.analyze:
        _requestTrailTip();
        break;
      case _SearchActionType.startTracking:
        if (!trail.isTracking) {
          ref.read(trailProvider.notifier).startTracking();
          setState(() => _sheetExpanded = false);
        }
        break;
      case _SearchActionType.pin:
        _showPinDialog();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trail = ref.watch(trailProvider);
    if (trail.isTracking && !trail.isPaused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeAutoTip(trail.distanceKm, trail.isPaused);
      });
    }

    final points =
        trail.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final center = _livePosition ??
        (points.isNotEmpty ? points.last : const LatLng(34.0, 71.0));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Map surface — tap-to-collapse sheet
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                if (_sheetExpanded) setState(() => _sheetExpanded = false);
              },
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 15,
                  onTap: (_, __) {
                    if (_sheetExpanded) {
                      setState(() => _sheetExpanded = false);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.trailguard.ai',
                    tileProvider: _tileProvider,
                  ),
                  if (points.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: points,
                          color: trail.isPaused
                              ? AppTheme.outline
                              : AppTheme.userBubble,
                          strokeWidth: 6,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      for (final m in trail.markers)
                        Marker(
                          width: 120,
                          height: 70,
                          point: LatLng(m.latitude, m.longitude),
                          child: _PinMarker(
                              label: m.label, icon: _iconFor(m.icon)),
                        ),
                      if (points.isNotEmpty)
                        Marker(
                          point: points.first,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerLowest,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppTheme.primary, width: 2),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: const Icon(Icons.flag_rounded,
                                color: AppTheme.primary, size: 18),
                          ),
                        ),
                      if (points.isNotEmpty)
                        Marker(
                          point: points.last,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: trail.isPaused
                                  ? AppTheme.outline
                                  : AppTheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppTheme.surfaceContainerLowest,
                                  width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 4,
                                )
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Live GPS accuracy ring
                  if (_livePosition != null && _liveAccuracy > 0)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _livePosition!,
                          radius: _liveAccuracy,
                          useRadiusInMeter: true,
                          color: const Color(0x204CC9F0),
                          borderColor: const Color(0x554CC9F0),
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                    ),

                  // Live GPS blue dot
                  if (_livePosition != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 28,
                          height: 28,
                          point: _livePosition!,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CC9F0),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x504CC9F0),
                                  blurRadius: 12,
                                  spreadRadius: 4,
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Top overlays
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _openSearch,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color:
                            AppTheme.surfaceContainerLowest.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.onPrimaryFixed.withOpacity(0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded,
                              color: AppTheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              trail.markers.isEmpty
                                  ? 'Search pins · ask AI · start trail'
                                  : '${trail.markers.length} pins · AI analyse · start/stop',
                              style: AppTheme.body(
                                      color: AppTheme.onSurfaceVariant)
                                  .copyWith(fontSize: 13),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryFixed,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('AI',
                                style: AppTheme.label(
                                    color: AppTheme.primary)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (trail.isPaused)
                        const _StatusChip(
                          icon: Icons.pause_circle_filled_rounded,
                          label: 'PAUSED',
                          color: AppTheme.tertiary,
                        )
                      else if (trail.isTracking)
                        const _StatusChip(
                          icon: Icons.fiber_manual_record_rounded,
                          label: 'TRACKING',
                          color: AppTheme.primary,
                          pulse: true,
                        ),
                      const Spacer(),
                      if (trail.returnBearing != null)
                        _StatusChip(
                          icon: Icons.navigation_rounded,
                          label: 'Return ${trail.returnBearing}',
                          color: AppTheme.onPrimaryContainer,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // FAB cluster
          Positioned(
            right: 16,
            bottom: _sheetExpanded ? 330 : 180,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Column(
                key: ValueKey(_sheetExpanded),
                children: [
                  if (trail.isTracking)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FabButton(
                        icon: Icons.add_location_alt_rounded,
                        color: AppTheme.tertiaryFixed,
                        iconColor: AppTheme.onTertiaryFixedVariant,
                        tooltip: 'Pin a place',
                        onTap: _showPinDialog,
                      ),
                    ),
                  _FabButton(
                    icon: Icons.layers_rounded,
                    color: AppTheme.surfaceContainerLowest,
                    iconColor: AppTheme.primary,
                    onTap: () {},
                  ),
                  const SizedBox(height: 10),
                  _FabButton(
                    icon: Icons.my_location_rounded,
                    color: AppTheme.primary,
                    iconColor: Colors.white,
                    large: true,
                    onTap: _centerOnMe,
                  ),
                ],
              ),
            ),
          ),

          // AI tip floating card
          if (_aiTip != null || _tipLoading)
            Positioned(
              left: 20,
              right: 20,
              bottom: _sheetExpanded ? 330 : 180,
              child: _TrailGuideBubble(
                tip: _aiTip,
                loading: _tipLoading,
                onClose: () => setState(() => _aiTip = null),
              ),
            ),

          // Collapsible control sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _TrackingSheet(
              expanded: _sheetExpanded,
              onToggle: () =>
                  setState(() => _sheetExpanded = !_sheetExpanded),
              trail: trail,
              onStart: () {
                ref.read(trailProvider.notifier).startTracking();
                _lastGuidedKm = 0;
                setState(() => _sheetExpanded = false);
              },
              onPause: () => ref.read(trailProvider.notifier).pauseTracking(),
              onResume: () => ref.read(trailProvider.notifier).resumeTracking(),
              onStop: () {
                ref.read(trailProvider.notifier).stopTracking();
                setState(() => _sheetExpanded = true);
              },
              onAiTip: trail.isTracking ? _requestTrailTip : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingSheet extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final dynamic trail;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback? onAiTip;

  const _TrackingSheet({
    required this.expanded,
    required this.onToggle,
    required this.trail,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onAiTip,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow.withOpacity(0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.onPrimaryFixed.withOpacity(0.12),
            blurRadius: 40,
            offset: const Offset(0, -12),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.outlineVariant.withOpacity(0.6),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          if (!expanded)
            _CompactRow(
              trail: trail,
              onStart: onStart,
              onPause: onPause,
              onResume: onResume,
              onStop: onStop,
            )
          else
            _ExpandedSheet(
              trail: trail,
              onStart: onStart,
              onPause: onPause,
              onResume: onResume,
              onStop: onStop,
              onAiTip: onAiTip,
            ),
        ],
      ),
    );
  }
}

class _CompactRow extends StatelessWidget {
  final dynamic trail;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const _CompactRow({
    required this.trail,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _miniStat('${trail.distanceKm.toStringAsFixed(2)} km',
                    Icons.straighten_rounded),
                const SizedBox(width: 8),
                _miniStat('${trail.trackingDuration}',
                    Icons.timer_outlined),
                const SizedBox(width: 8),
                _miniStat('${trail.markers.length}',
                    Icons.push_pin_rounded),
              ],
            ),
          ),
          if (!trail.isTracking)
            _roundBtn(Icons.play_arrow_rounded, AppTheme.primary, onStart)
          else if (trail.isPaused) ...[
            _roundBtn(Icons.play_arrow_rounded, AppTheme.primary, onResume),
            const SizedBox(width: 6),
            _roundBtn(Icons.stop_rounded, AppTheme.error, onStop),
          ] else ...[
            _roundBtn(Icons.pause_rounded, AppTheme.tertiary, onPause),
            const SizedBox(width: 6),
            _roundBtn(Icons.stop_rounded, AppTheme.error, onStop),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primary, size: 14),
          const SizedBox(width: 4),
          Text(text, style: AppTheme.bodyBold(color: AppTheme.primary)),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _ExpandedSheet extends StatelessWidget {
  final dynamic trail;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback? onAiTip;

  const _ExpandedSheet({
    required this.trail,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onAiTip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _MapStat(
                  label: 'DISTANCE',
                  value: '${trail.distanceKm.toStringAsFixed(2)} km'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MapStat(label: 'PINS', value: '${trail.markers.length}'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child:
                  _MapStat(label: 'TIME', value: trail.trackingDuration),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!trail.isTracking)
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_circle_outline_rounded,
                      size: 20),
                  label: const Text('START TRACKING'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.psychology_rounded, size: 18),
                  label: const Text('AI TIP'),
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: trail.isPaused ? onResume : onPause,
                      icon: Icon(
                        trail.isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        size: 20,
                      ),
                      label: Text(trail.isPaused ? 'RESUME' : 'PAUSE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: trail.isPaused
                            ? AppTheme.primary
                            : AppTheme.tertiary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onStop,
                      icon: const Icon(Icons.stop_circle_rounded, size: 20),
                      label: const Text('STOP'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAiTip,
                  icon: const Icon(Icons.psychology_rounded, size: 18),
                  label: const Text('AI TIP'),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ─── Search sheet ─────────────────────────────────────────────────────────

enum _SearchActionType { goto, analyze, startTracking, pin }

class _SearchAction {
  final _SearchActionType type;
  final double? lat;
  final double? lng;
  _SearchAction(this.type, {this.lat, this.lng});
}

class _SearchSheet extends StatefulWidget {
  final List<dynamic> markers;
  final IconData Function(String) iconFor;
  const _SearchSheet({required this.markers, required this.iconFor});

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.markers
        : widget.markers
            .where((m) => (m.label as String)
                .toLowerCase()
                .contains(_query.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scroll) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.outlineVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                style: AppTheme.body(color: AppTheme.onSurface),
                decoration: const InputDecoration(
                  hintText: 'Search pins or pick an AI action…',
                  prefixIcon: Icon(Icons.search_rounded,
                      color: AppTheme.primary),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 4, top: 4, bottom: 6),
                      child: Text('AI & QUICK ACTIONS',
                          style: AppTheme.label(color: AppTheme.primary)),
                    ),
                    _ActionRow(
                      icon: Icons.auto_awesome_rounded,
                      iconBg: AppTheme.primaryFixed,
                      iconColor: AppTheme.primary,
                      title: 'Ask AI to analyse my trail',
                      subtitle: 'Gemma 4 looks at position, pace & elevation',
                      onTap: () => Navigator.pop(
                          context, _SearchAction(_SearchActionType.analyze)),
                    ),
                    _ActionRow(
                      icon: Icons.play_circle_outline_rounded,
                      iconBg: AppTheme.secondaryFixed,
                      iconColor: AppTheme.onSecondaryFixedVariant,
                      title: 'Start / continue tracking',
                      subtitle: 'Begin a new trail recording',
                      onTap: () => Navigator.pop(context,
                          _SearchAction(_SearchActionType.startTracking)),
                    ),
                    _ActionRow(
                      icon: Icons.push_pin_rounded,
                      iconBg: AppTheme.tertiaryFixed,
                      iconColor: AppTheme.onTertiaryFixedVariant,
                      title: 'Pin this place',
                      subtitle: 'Tag your current spot with a name',
                      onTap: () => Navigator.pop(
                          context, _SearchAction(_SearchActionType.pin)),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 4, top: 4, bottom: 6),
                      child: Text(
                        filtered.isEmpty
                            ? (widget.markers.isEmpty
                                ? 'NO PINS YET'
                                : 'NO MATCHES')
                            : 'YOUR PINS (${filtered.length})',
                        style: AppTheme.label(color: AppTheme.primary),
                      ),
                    ),
                    if (widget.markers.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Start tracking and tap the pin button to save places — hotels, water sources, hazards. They\'ll appear here.',
                          style: AppTheme.body(),
                        ),
                      ),
                    for (final m in filtered)
                      _ActionRow(
                        icon: widget.iconFor(m.icon as String),
                        iconBg: AppTheme.primaryFixed,
                        iconColor: AppTheme.primary,
                        title: m.label as String,
                        subtitle:
                            '${(m.latitude as double).toStringAsFixed(4)}, ${(m.longitude as double).toStringAsFixed(4)}',
                        onTap: () => Navigator.pop(
                          context,
                          _SearchAction(
                            _SearchActionType.goto,
                            lat: m.latitude,
                            lng: m.longitude,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppTheme.bodyBold(color: AppTheme.primary)),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body().copyWith(fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Pin sheet ─────────────────────────────────────────────────────────────

class _PinChoice {
  final String text;
  final String iconKey;
  const _PinChoice(this.text, this.iconKey);
}

class _PinSheet extends StatefulWidget {
  const _PinSheet();

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  final _ctrl = TextEditingController();
  String _iconKey = 'place';

  static const _chips = [
    _ChipDef('hotel', 'Hotel', Icons.hotel_rounded),
    _ChipDef('camp', 'Camp', Icons.cottage_rounded),
    _ChipDef('water', 'Water', Icons.water_drop_rounded),
    _ChipDef('view', 'Viewpoint', Icons.landscape_rounded),
    _ChipDef('food', 'Food', Icons.restaurant_rounded),
    _ChipDef('hazard', 'Hazard', Icons.warning_amber_rounded),
    _ChipDef('rest', 'Rest', Icons.pause_circle_rounded),
  ];

  void _pick(String key, String suggestedLabel) {
    setState(() {
      _iconKey = key;
      if (_ctrl.text.trim().isEmpty) _ctrl.text = suggestedLabel;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.outlineVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Pin this place', style: AppTheme.h2()),
          const SizedBox(height: 6),
          Text('Give it a name so you can find it again later.',
              style: AppTheme.body()),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            style: AppTheme.body(color: AppTheme.onSurface),
            decoration: const InputDecoration(
              hintText: 'e.g. Riverside Hotel',
              prefixIcon: Icon(Icons.edit_location_alt_rounded,
                  color: AppTheme.primary),
            ),
            onSubmitted: (_) =>
                Navigator.of(context).pop(_PinChoice(_ctrl.text, _iconKey)),
          ),
          const SizedBox(height: 16),
          Text('TYPE', style: AppTheme.label()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _chips
                .map((c) => ChoiceChip(
                      avatar: Icon(c.icon,
                          size: 16,
                          color: _iconKey == c.key
                              ? Colors.white
                              : AppTheme.primary),
                      label: Text(c.label),
                      selected: _iconKey == c.key,
                      selectedColor: AppTheme.primary,
                      backgroundColor: AppTheme.surfaceContainerLow,
                      labelStyle: AppTheme.bodyBold(
                          color: _iconKey == c.key
                              ? Colors.white
                              : AppTheme.primary),
                      onSelected: (_) => _pick(c.key, c.label),
                    ))
                .toList(),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context)
                      .pop(_PinChoice(_ctrl.text, _iconKey)),
                  icon: const Icon(Icons.push_pin_rounded, size: 18),
                  label: const Text('PIN HERE'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipDef {
  final String key;
  final String label;
  final IconData icon;
  const _ChipDef(this.key, this.label, this.icon);
}

class _PinMarker extends StatelessWidget {
  final String label;
  final IconData icon;
  const _PinMarker({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.primary, width: 1),
          ),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: AppTheme.label(color: AppTheme.primary)
                .copyWith(letterSpacing: 0.2),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ],
    );
  }
}

class _StatusChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool pulse;
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
    this.pulse = false,
  });

  @override
  State<_StatusChip> createState() => _StatusChipState();
}

class _StatusChipState extends State<_StatusChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest.withOpacity(0.95),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 14, color: widget.color),
          const SizedBox(width: 6),
          Text(widget.label, style: AppTheme.label(color: widget.color)),
        ],
      ),
    );

    if (!widget.pulse) return child;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) =>
          Opacity(opacity: 0.6 + _ctrl.value * 0.4, child: child),
    );
  }
}

class _TrailGuideBubble extends StatelessWidget {
  final String? tip;
  final bool loading;
  final VoidCallback onClose;
  const _TrailGuideBubble({
    required this.tip,
    required this.loading,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.onPrimaryFixed.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.primaryFixed,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.park_rounded, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI TRAIL GUIDE',
                    style: AppTheme.label(color: AppTheme.primary)),
                const SizedBox(height: 4),
                if (loading)
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 8),
                      Text('Analysing your path…', style: AppTheme.body()),
                    ],
                  )
                else if (tip != null)
                  Text(tip!, style: AppTheme.bodyBold()),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppTheme.onSurfaceVariant,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _MapStat extends StatelessWidget {
  final String label;
  final String value;
  const _MapStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.label()),
          const SizedBox(height: 4),
          Text(value, style: AppTheme.h2()),
        ],
      ),
    );
  }
}

class _FabButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;
  final bool large;
  final String? tooltip;
  const _FabButton({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
    this.large = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final size = large ? 56.0 : 48.0;
    final btn = Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      elevation: 6,
      shadowColor: AppTheme.onPrimaryFixed.withOpacity(0.2),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: iconColor, size: large ? 26 : 22),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
