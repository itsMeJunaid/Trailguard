import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/permissions.dart';
import '../widgets/brand_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fade;
  int _page = 0;

  final _pages = [
    _OnboardPage(
      icon: Icons.landscape_rounded,
      title: 'TrailGuard AI',
      subtitle: 'Your offline survival companion.\nNo internet. No compromise.',
      accent: AppTheme.primary,
      bg: AppTheme.primaryFixed,
    ),
    _OnboardPage(
      icon: Icons.psychology_outlined,
      title: 'Gemma 4 On-Device',
      subtitle: 'Google\'s AI runs entirely on your phone.\nPrivate by design.',
      accent: AppTheme.secondary,
      bg: AppTheme.secondaryFixed,
    ),
    _OnboardPage(
      icon: Icons.cloud_download_rounded,
      title: 'Get Your Model',
      subtitle: 'Download Gemma 4 E2B LiteRT-LM (≈1.5 GB)\nStored under Download/gemma_model/.',
      accent: AppTheme.tertiary,
      bg: AppTheme.tertiaryFixed,
    ),
    _OnboardPage(
      icon: Icons.shield_rounded,
      title: 'Stay Safe Out There',
      subtitle: 'AI chat, trail tracking,\ncamera scouting & SOS alerts.',
      accent: AppTheme.error,
      bg: AppTheme.errorContainer,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page < _pages.length - 1) {
      _fadeController.reset();
      setState(() => _page++);
      _fadeController.forward();
    } else {
      await PermissionsManager.requestAll();
      if (mounted) context.go('/profile-setup');
    }
  }

  Future<void> _skip() async {
    await PermissionsManager.requestAll();
    if (mounted) context.go('/profile-setup');
  }

  @override
  Widget build(BuildContext context) {
    final p = _pages[_page];
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _skip,
                    child: Text('Skip',
                        style: AppTheme.label(color: AppTheme.primary)),
                  ),
                ),
                const Spacer(),
                _page == 0
                    ? const TrailGuardLogo(size: 140)
                    : Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.bg,
                        ),
                        child: Icon(p.icon, size: 64, color: p.accent),
                      ),
                const SizedBox(height: 40),
                Text(p.title,
                    style: AppTheme.displayXL(color: AppTheme.primary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 14),
                Text(p.subtitle,
                    style: AppTheme.body()
                        .copyWith(fontSize: 16, height: 1.6),
                    textAlign: TextAlign.center),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: i == _page ? 26 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: i == _page
                            ? AppTheme.primary
                            : AppTheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _next,
                    child: Text(
                      _page == _pages.length - 1 ? 'GET STARTED' : 'NEXT',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color bg;
  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.bg,
  });
}
