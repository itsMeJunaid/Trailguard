import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme.dart';
import 'providers/profile_provider.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/map_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/about_screen.dart';
import 'widgets/brand_logo.dart';

GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _BootGate()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(
        path: '/profile-setup',
        builder: (_, __) => const ProfileScreen(onboarding: true),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            MainShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
          GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
          GoRoute(path: '/camera', builder: (_, __) => const CameraScreen()),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/about',
            builder: (_, __) => const AboutScreen(),
          ),
        ],
      ),
    ],
  );
}

class TrailGuardApp extends ConsumerWidget {
  const TrailGuardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'TrailGuard AI',
      theme: AppTheme.lightTheme,
      routerConfig: buildRouter(ref),
      debugShowCheckedModeBanner: false,
      builder: (context, child) => _WebShell(child: child ?? const SizedBox()),
    );
  }
}

/// TrailGuard is a phone-shaped app. On a desktop browser the same layout
/// stretched to 1900px reads as broken, so above [_phoneWidth] the web build
/// pins the app to a centred phone-width frame. Set [_frameWideWeb] to false
/// to let it fill the window instead. No effect on Android/iOS.
const bool _frameWideWeb = true;
const double _phoneWidth = 440;

class _WebShell extends StatelessWidget {
  final Widget child;
  const _WebShell({required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !_frameWideWeb) return child;

    final media = MediaQuery.of(context);
    if (media.size.width <= _phoneWidth + 48) return child;

    final height = media.size.height;

    return ColoredBox(
      color: AppTheme.surfaceDim,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          child: SizedBox(
            width: _phoneWidth,
            height: height,
            // Give the app the frame's dimensions, not the window's, so
            // MediaQuery-driven layout inside it stays phone-accurate.
            child: MediaQuery(
              data: media.copyWith(size: Size(_phoneWidth, height)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// First-launch gate:
/// • No profile saved → onboarding → profile setup → home
/// • Profile exists → straight to home
class _BootGate extends ConsumerStatefulWidget {
  const _BootGate();

  @override
  ConsumerState<_BootGate> createState() => _BootGateState();
}

class _BootGateState extends ConsumerState<_BootGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    // Block until the profile provider has actually read SharedPreferences.
    await ref.read(profileProvider.notifier).ready;
    final profile = ref.read(profileProvider);
    if (!mounted) return;
    if (profile == null || profile.isEmpty) {
      context.go('/onboarding');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const TrailGuardLogo(size: 96),
            const SizedBox(height: 20),
            Text('TrailGuard AI', style: AppTheme.display()),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppTheme.primary),
          ],
        ),
      ),
    );
  }
}

class MainShell extends ConsumerWidget {
  final Widget child;
  final String location;
  const MainShell({super.key, required this.child, required this.location});

  static const _items = [
    _NavItem(path: '/home', icon: Icons.home_rounded, label: 'Home'),
    _NavItem(path: '/chat', icon: Icons.chat_bubble_rounded, label: 'Chat'),
    _NavItem(path: '/map', icon: Icons.explore_rounded, label: 'Map'),
    _NavItem(
        path: '/camera', icon: Icons.photo_camera_rounded, label: 'Camera'),
    _NavItem(path: '/profile', icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBody: true,
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.onPrimaryFixed.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                )
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _items.map((item) {
                final active = location == item.path;
                return _NavPill(
                  item: item,
                  active: active,
                  onTap: () => context.go(item.path),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String path;
  final IconData icon;
  final String label;
  const _NavItem(
      {required this.path, required this.icon, required this.label});
}

class _NavPill extends StatefulWidget {
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;
  const _NavPill(
      {required this.item, required this.active, required this.onTap});

  @override
  State<_NavPill> createState() => _NavPillState();
}

class _NavPillState extends State<_NavPill> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final active = widget.active;
    // 0.75, not 0.55: at 0.55 the inactive label computed to #7BA092 on white
    // — 2.88:1, which fails WCAG at every threshold. 0.75 gives #4B7D6A, 4.73:1.
    final inactive = AppTheme.primary.withValues(alpha: 0.75);

    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          onFocusChange: (f) => setState(() => _focused = f),
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          hoverColor: AppTheme.hoverOverlay,
          focusColor: AppTheme.focusOverlay,
          highlightColor: AppTheme.pressedOverlay,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            constraints: const BoxConstraints(
              minWidth: AppTheme.minTapTarget,
              minHeight: AppTheme.minTapTarget,
            ),
            decoration: BoxDecoration(
              color: active ? AppTheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: _focused
                  ? Border.all(
                      color: active ? Colors.white : AppTheme.primary,
                      width: 2,
                    )
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  color: active ? Colors.white : inactive,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  style: AppTheme.label(
                    color: active ? Colors.white : inactive,
                    // Sentence case, so the eyebrow tracking would be wrong here.
                  ).copyWith(letterSpacing: 0.2, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
