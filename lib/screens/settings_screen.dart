import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../models/model_config.dart';
import '../providers/ai_provider.dart';
import '../providers/download_provider.dart';
import '../providers/profile_provider.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import 'profile_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _storage = StorageService();
  List<String> _foundModels = [];
  bool _scanning = false;

  /// False in the browser: no LiteRT-LM bridge, no model files, no GPU backend.
  bool get _nativeEngine => AIService().isEngineAvailable;

  @override
  void initState() {
    super.initState();
    if (_nativeEngine) _scanModels();
  }

  Future<void> _scanModels() async {
    setState(() => _scanning = true);
    final models = await _storage.scanForModels();
    setState(() {
      _foundModels = models;
      _scanning = false;
    });
  }

  Future<void> _loadModel(String path, GemmaVariant variant) async {
    final ok = await ref.read(aiProvider.notifier).loadModel(path, variant);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: ok ? AppTheme.primary : AppTheme.error,
        behavior: SnackBarBehavior.floating,
        content: Text(ok ? 'Model loaded.' : 'Failed to load model.'),
      ));
    }
  }

  Future<void> _startDownload() async {
    final note = ref.read(downloadProvider.notifier);
    final path = await note.startDownload(
      url: AppConstants.hfModelFileE2B,
      filename: AppConstants.modelE2B,
    );
    if (!mounted) return;

    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        content: Text('Saved to $path'),
      ));
      await _scanModels();
    } else {
      final err = ref.read(downloadProvider).error;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          content: Text('Download failed. $err'),
        ));
      }
    }
  }

  Future<void> _openInBrowser() async {
    try {
      await launchUrl(Uri.parse(AppConstants.hfModelPageE2B),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiProvider);
    final download = ref.watch(downloadProvider);
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.primary),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text('Settings', style: AppTheme.h2()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          // Profile quick-card
          _SectionHeader('YOUR PROFILE'),
          _ProfileCard(
            profile: profile,
            onEdit: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 22),

          _SectionHeader('AI MODEL'),
          if (_nativeEngine) ...[
            _ModelStatusCard(
                isLoaded: aiState.isModelLoaded,
                variant: aiState.loadedVariant),
            const SizedBox(height: 12),
          ] else ...[
            const _WebEngineNotice(),
            const SizedBox(height: 12),
          ],
          _TokenUsageCard(ai: ref.read(aiProvider.notifier).aiService),

          // Model download, storage scanning and the GPU backend all need the
          // native LiteRT-LM bridge, which the browser build does not have.
          if (_nativeEngine) ...[
            const SizedBox(height: 12),
            _BackendToggle(
              useGpu: aiState.useGpu,
              loading: aiState.isLoading,
              onChanged: (v) => ref.read(aiProvider.notifier).setUseGpu(v),
            ),
            const SizedBox(height: 22),

            _SectionHeader('DOWNLOAD GEMMA 4 LITERT-LM'),
            _DownloadCard(
              state: download,
              onStart: _startDownload,
              onCancel: () => ref.read(downloadProvider.notifier).cancel(),
              onOpenBrowser: _openInBrowser,
            ),
            const SizedBox(height: 18),

            _SectionHeader('INSTALLED MODELS'),
            _ModelCard(
              variant: GemmaVariant.e2b,
              filename: AppConstants.modelE2B,
              foundModels: _foundModels,
              onLoad: _loadModel,
            ),
            const SizedBox(height: 10),
            _ModelCard(
              variant: GemmaVariant.e4b,
              filename: AppConstants.modelE4B,
              foundModels: _foundModels,
              onLoad: _loadModel,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _scanning ? null : _scanModels,
                icon: _scanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.primary),
                      )
                    : const Icon(Icons.search_rounded),
                label: Text(_scanning ? 'Scanning…' : 'Scan storage'),
              ),
            ),
          ],

          const SizedBox(height: 24),
          _SectionHeader('ABOUT'),
          Material(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.go('/about'),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryFixed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.landscape_rounded,
                          color: AppTheme.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TrailGuard AI Lite',
                              style: AppTheme.h3(color: AppTheme.primary)),
                          Text('Free to use · Developer · Credits',
                              style: AppTheme.body()),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppTheme.primary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenUsageCard extends StatelessWidget {
  final AIService ai;
  const _TokenUsageCard({required this.ai});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.secondaryFixed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.token_rounded,
                color: AppTheme.onSecondaryFixedVariant, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Token Usage', style: AppTheme.h3(color: AppTheme.primary)),
                Text(
                  'Session: ${ai.sessionTokens} tokens · Total: ${ai.totalTokens} tokens',
                  style: AppTheme.body(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackendToggle extends StatelessWidget {
  final bool useGpu;
  final bool loading;
  final ValueChanged<bool> onChanged;
  const _BackendToggle({
    required this.useGpu,
    required this.loading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: useGpu ? AppTheme.primaryFixed : AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              useGpu ? Icons.memory_rounded : Icons.developer_board_rounded,
              color: AppTheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(useGpu ? 'GPU backend' : 'CPU backend',
                    style: AppTheme.h3(color: AppTheme.primary)),
                Text(
                  useGpu
                      ? 'Faster, needs a modern GPU. Uses more battery.'
                      : 'Stable. Works on every device.',
                  style: AppTheme.body(),
                ),
              ],
            ),
          ),
          loading
              ? const SizedBox(
                  width: 40,
                  height: 40,
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primary),
                  ),
                )
              : Switch(
                  value: useGpu,
                  onChanged: onChanged,
                  activeThumbColor: AppTheme.primary,
                ),
        ],
      ),
    );
  }
}

/// Explains, in the browser build, why there is no model to download.
class _WebEngineNotice extends StatelessWidget {
  const _WebEngineNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.tertiaryFixed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.public_rounded,
                    color: AppTheme.onTertiaryFixedVariant, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Web preview', style: AppTheme.h3()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Gemma 4 runs through LiteRT-LM, a native engine that only exists '
            'in the Android build. In the browser TrailGuard answers from its '
            'built-in survival guide instead — every other feature (trail '
            'tracking, maps, camera, voice, SOS dispatch) works normally.',
            style: AppTheme.body(color: AppTheme.onSurface).copyWith(height: 1.5),
          ),
          const SizedBox(height: 12),
          Text('Install the Android APK for full on-device AI.',
              style: AppTheme.bodyBold(color: AppTheme.primary)),
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
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(text, style: AppTheme.label(color: AppTheme.primary)),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final dynamic profile;
  final VoidCallback onEdit;
  const _ProfileCard({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final hasProfile = profile != null && !profile.isEmpty;
    return Material(
      color: AppTheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.primaryFixed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded,
                    color: AppTheme.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasProfile ? profile.name : 'Create your profile',
                      style: AppTheme.h3(color: AppTheme.primary),
                    ),
                    Text(
                      hasProfile
                          ? [
                              if (profile.bloodGroup != null)
                                'Blood ${profile.bloodGroup}',
                              if (profile.age != null)
                                '${profile.age} yrs',
                            ].join(' • ').isEmpty
                              ? 'Tap to edit health info'
                              : [
                                  if (profile.bloodGroup != null)
                                    'Blood ${profile.bloodGroup}',
                                  if (profile.age != null)
                                    '${profile.age} yrs',
                                ].join(' • ')
                          : 'Helps AI + rescue respond to you',
                      style: AppTheme.body(),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelStatusCard extends StatelessWidget {
  final bool isLoaded;
  final GemmaVariant? variant;
  const _ModelStatusCard({required this.isLoaded, required this.variant});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isLoaded
                  ? AppTheme.secondaryFixed
                  : AppTheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isLoaded ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: isLoaded ? AppTheme.primary : AppTheme.onErrorContainer,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoaded ? 'Model loaded' : 'No model loaded',
                  style: AppTheme.h3(color: AppTheme.primary),
                ),
                Text(
                  isLoaded
                      ? 'Gemma 4 ${variant?.name.toUpperCase() ?? ""} • LiteRT-LM'
                      : 'Download below to start',
                  style: AppTheme.body(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadCard extends StatelessWidget {
  final DownloadState state;
  final VoidCallback onStart;
  final VoidCallback onCancel;
  final VoidCallback onOpenBrowser;

  const _DownloadCard({
    required this.state,
    required this.onStart,
    required this.onCancel,
    required this.onOpenBrowser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_download_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Gemma 4 E2B (LiteRT-LM)',
                    style: AppTheme.h3(color: Colors.white)),
              ),
              Text('~1.5 GB',
                  style: AppTheme.label(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Saved to Download/gemma_model/. Keep the app open during download.',
            style: AppTheme.body(color: Colors.white.withOpacity(0.85)),
          ),

          if (state.inProgress) ...[
            const SizedBox(height: 18),
            _ProgressRow(state: state),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.5)),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (state.savedPath != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Downloaded. Tap LOAD MODEL below.',
                        style: AppTheme.body(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: onOpenBrowser,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Browser'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.4)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final DownloadState state;
  const _ProgressRow({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: state.percent > 0 ? state.percent : null,
            minHeight: 10,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              '${state.receivedMB} / ${state.totalMB} MB',
              style: AppTheme.bodyBold(color: Colors.white),
            ),
            const Spacer(),
            Text(
              '${(state.percent * 100).toStringAsFixed(0)}%',
              style: AppTheme.h3(color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(state.speedLabel,
                style: AppTheme.body(color: Colors.white.withOpacity(0.85))),
            const Spacer(),
            Text(state.etaLabel,
                style: AppTheme.body(color: Colors.white.withOpacity(0.85))),
          ],
        ),
      ],
    );
  }
}

class _ModelCard extends StatelessWidget {
  final GemmaVariant variant;
  final String filename;
  final List<String> foundModels;
  final Function(String, GemmaVariant) onLoad;

  const _ModelCard({
    required this.variant,
    required this.filename,
    required this.foundModels,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    final config = ModelConfig(variant: variant, filePath: '');

    // Case-insensitive match. Accept either the exact filename OR any
    // .litertlm/.tflite/.task/.bin file whose name contains the variant code
    // (so renamed-by-browser files still get picked up).
    final target = filename.toLowerCase();
    final variantCode =
        variant == GemmaVariant.e2b ? 'e2b' : 'e4b';
    const validExts = ['.litertlm', '.tflite', '.task', '.bin', '.gguf', '.pt'];

    final matches = foundModels.where((p) {
      final lower = p.toLowerCase();
      final name = lower.split('/').last;
      if (name == target) return true;
      if (!validExts.any(name.endsWith)) return false;
      return name.contains(variantCode) && name.contains('gemma');
    }).toList();

    final matchingPath = matches.isEmpty ? null : matches.first;
    final found = matchingPath != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: found
            ? Border.all(color: AppTheme.primary.withOpacity(0.35), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: found
                      ? AppTheme.secondaryFixed
                      : AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  found
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: found
                      ? AppTheme.primary
                      : AppTheme.onSurfaceVariant.withOpacity(0.5),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(config.displayName,
                        style: AppTheme.h3(color: AppTheme.primary)),
                    Text('${config.sizeLabel} • LiteRT-LM',
                        style: AppTheme.body()),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(config.description, style: AppTheme.body()),
          const SizedBox(height: 12),
          if (found)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => onLoad(matchingPath, variant),
                child: const Text('Load model'),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_off_rounded,
                      size: 16, color: AppTheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Not yet downloaded: $filename',
                        style: AppTheme.body().copyWith(fontSize: 11)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
