import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../widgets/brand_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _devName = 'Muhammad Junaid';
  static const _devRole = 'AI Engineer';
  static const _devEmail = 'itxjunaid22@gmail.com';

  Future<void> _openEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _devEmail,
      query: Uri.encodeFull(
          'subject=TrailGuard AI — Feedback&body=Hi Muhammad,\n\n'),
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.primary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('About', style: AppTheme.h2()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
        children: [
          // Brand card
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primary, AppTheme.primaryContainer],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const TrailGuardLogo(size: 96),
                const SizedBox(height: 14),
                Text('TrailGuard AI',
                    style: AppTheme.display(color: Colors.white)),
                const SizedBox(height: 4),
                Text('Offline survival companion',
                    style: AppTheme.body(
                            color: Colors.white.withOpacity(0.85))
                        .copyWith(letterSpacing: 0.3)),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text('FREE TO USE',
                          style: AppTheme.label(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _SectionHeader('DEVELOPER'),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryFixed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.engineering_rounded,
                          color: AppTheme.primary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_devName,
                              style: AppTheme.h2(color: AppTheme.primary)),
                          Text(_devRole, style: AppTheme.body()),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openEmail,
                    icon: const Icon(Icons.email_rounded, size: 18),
                    label: Text(_devEmail.toUpperCase()),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          _SectionHeader('LICENSE'),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryFixed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.verified_user_rounded,
                          color: AppTheme.onSecondaryFixedVariant, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text('Free to use',
                          style: AppTheme.h3(color: AppTheme.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'This app is distributed free of charge for personal, educational, '
                  'and hackathon use. All AI inference happens on your device — '
                  'no data is sent to any server. Use at your own risk on the trail; '
                  'always consult qualified professionals for real medical emergencies.',
                  style: AppTheme.body().copyWith(height: 1.6),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          _SectionHeader('CREDITS'),
          _CreditRow(
            icon: Icons.auto_awesome_rounded,
            text: 'Gemma 4 by Google · LiteRT-LM runtime',
          ),
          _CreditRow(
            icon: Icons.map_rounded,
            text: 'OpenStreetMap contributors (map tiles)',
          ),
          _CreditRow(
            icon: Icons.mic_rounded,
            text: 'Android on-device speech recognition',
          ),
          _CreditRow(
            icon: Icons.flutter_dash_rounded,
            text: 'Built with Flutter · Dart',
          ),

          const SizedBox(height: 22),
          Center(
            child: Text('v1.0.0 • Kaggle Gemma 4 Hackathon',
                style: AppTheme.body()),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(text, style: AppTheme.label(color: AppTheme.primary)),
    );
  }
}

class _CreditRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _CreditRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primaryFixed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: AppTheme.bodyBold())),
          ],
        ),
      ),
    );
  }
}
