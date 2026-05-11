import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/ai_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/trail_provider.dart';
import '../widgets/brand_logo.dart';
import '../widgets/model_status_banner.dart';
import '../widgets/sos_button.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trail = ref.watch(trailProvider);
    final ai = ref.watch(aiProvider);

    final greeting = _greeting(DateTime.now());

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
          children: [
            // Header greeting
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const TrailGuardBrand(logoSize: 34, fontSize: 20),
                const _AvatarCircle(),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              '$greeting, ${_firstName(ref)}.',
              style: AppTheme.display(color: AppTheme.onPrimaryFixedVariant),
            ),
            const SizedBox(height: 6),
            Text(
              ai.isModelLoaded
                  ? 'Gemma 4 is online. Ready when you are.'
                  : 'Your gear is calibrated. The trail is waiting.',
              style: AppTheme.body(),
            ),
            const SizedBox(height: 20),

            const ModelStatusBanner(),
            const SizedBox(height: 20),

            // Bento grid
            _TrailStatusCard(
              title: trail.isTracking ? 'Active Mission' : 'No Active Trail',
              trailName: trail.isTracking ? 'Current Trek' : 'Pine Ridge Loop',
              distance: trail.distanceKm,
              points: trail.points.length,
              duration: trail.trackingDuration,
              isTracking: trail.isTracking,
              onStart: () {
                if (trail.isTracking) {
                  ref.read(trailProvider.notifier).stopTracking();
                } else {
                  ref.read(trailProvider.notifier).startTracking();
                }
              },
            ),
            const SizedBox(height: 12),

            // Two-column quick actions
            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.chat_bubble_rounded,
                    iconBg: AppTheme.secondaryContainer,
                    iconColor: AppTheme.onSecondaryContainer,
                    title: 'AI Chat',
                    subtitle: 'Ask survival, first-aid, plants.',
                    onTap: () => context.go('/chat'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.explore_rounded,
                    iconBg: AppTheme.tertiaryFixed,
                    iconColor: AppTheme.onTertiaryFixedVariant,
                    title: 'Topo Map',
                    subtitle: 'Offline trail navigation.',
                    onTap: () => context.go('/map'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.photo_camera_rounded,
                    iconBg: AppTheme.primaryFixed,
                    iconColor: AppTheme.onPrimaryFixedVariant,
                    title: 'AI Scout',
                    subtitle: 'Identify plants, hazards & terrain.',
                    onTap: () => context.go('/camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.settings_rounded,
                    iconBg: AppTheme.surfaceContainerHigh,
                    iconColor: AppTheme.primary,
                    title: 'Model Setup',
                    subtitle: 'Load your Gemma 4 LiteRT-LM.',
                    onTap: () => context.go('/settings'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Upcoming milestones
            _UpcomingCard(),

            const SizedBox(height: 20),

            // SOS
            const SOSButton(),

            const SizedBox(height: 20),

            // Safety banner / tip of the day
            _TipBanner(),
          ],
        ),
      ),
    );
  }

  String _greeting(DateTime t) {
    final h = t.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _firstName(WidgetRef ref) {
    final p = ref.read(profileProvider);
    final full = p?.name ?? '';
    if (full.trim().isEmpty) return 'Explorer';
    return full.split(' ').first;
  }
}

class _AvatarCircle extends ConsumerWidget {
  const _AvatarCircle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final picPath = profile?.profilePicPath;
    final hasPic = picPath != null && File(picPath).existsSync();

    return GestureDetector(
      onTap: () => context.go('/profile'),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.primary.withOpacity(0.25), width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasPic
            ? Image.file(File(picPath), fit: BoxFit.cover)
            : const Icon(Icons.person_rounded,
                color: AppTheme.primary, size: 22),
      ),
    );
  }
}

class _TrailStatusCard extends StatelessWidget {
  final String title;
  final String trailName;
  final double distance;
  final int points;
  final String duration;
  final bool isTracking;
  final VoidCallback onStart;

  const _TrailStatusCard({
    required this.title,
    required this.trailName,
    required this.distance,
    required this.points,
    required this.duration,
    required this.isTracking,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.onPrimaryFixed.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, -8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.secondaryFixed,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              title.toUpperCase(),
              style: AppTheme.label(color: AppTheme.onSecondaryFixedVariant),
            ),
          ),
          const SizedBox(height: 12),
          Text(trailName,
              style: AppTheme.display(color: AppTheme.primary)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 16, color: AppTheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('Current location',
                  style: AppTheme.body()),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _TrailStat(
                  label: 'Distance',
                  value: '${distance.toStringAsFixed(2)} km',
                ),
              ),
              Expanded(
                child: _TrailStat(
                  label: 'Waypoints',
                  value: '$points',
                ),
              ),
              Expanded(
                child: _TrailStat(
                  label: 'Duration',
                  value: duration,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onStart,
              icon: Icon(
                isTracking ? Icons.stop_circle_outlined : Icons.play_circle_outline_rounded,
                size: 22,
              ),
              label: Text(isTracking ? 'STOP TRACKING' : 'START TRACKING'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isTracking ? AppTheme.error : AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrailStat extends StatelessWidget {
  final String label;
  final String value;
  const _TrailStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTheme.label()),
          const SizedBox(height: 4),
          Text(value, style: AppTheme.h2()),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(height: 12),
              Text(title, style: AppTheme.h3(color: AppTheme.primary)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: AppTheme.body(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('UPCOMING', style: AppTheme.label()),
          const SizedBox(height: 12),
          _UpcomingRow(
            icon: Icons.water_drop_rounded,
            title: 'Creek Crossing',
            subtitle: 'In 1.2 km • Safe',
          ),
          const SizedBox(height: 8),
          _UpcomingRow(
            icon: Icons.landscape_rounded,
            title: 'Peak Lookout',
            subtitle: 'In 3.5 km • 240m climb',
          ),
          const SizedBox(height: 8),
          _UpcomingRow(
            icon: Icons.home_rounded,
            title: 'North Shelter',
            subtitle: 'In 6.8 km • Camp site',
            dim: true,
          ),
        ],
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool dim;

  const _UpcomingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dim ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.bodyBold()),
                  Text(subtitle,
                      style: AppTheme.body(color: AppTheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipBanner extends StatelessWidget {
  static const _tips = [
    'Golden hour: set camp 30 min before sunset.',
    'Running water is safer to filter than still water.',
    'Moss grows on the north side of trees in the Northern Hemisphere.',
    'Three signal fires in a triangle = universal distress.',
    'Hang food 4 m high and 1.5 m from the tree trunk.',
  ];

  @override
  Widget build(BuildContext context) {
    final tip = _tips[DateTime.now().hour % _tips.length];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryFixed,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.tips_and_updates_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TIP OF THE HOUR',
                    style: AppTheme.label(color: AppTheme.primary)),
                const SizedBox(height: 4),
                Text(tip,
                    style: AppTheme.bodyBold(
                        color: AppTheme.onPrimaryFixedVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
