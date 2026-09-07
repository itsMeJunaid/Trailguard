import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/ai_provider.dart';
import '../services/ai_service.dart';

class ModelStatusBanner extends ConsumerWidget {
  const ModelStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ai = ref.watch(aiProvider);

    // In the browser there is no LiteRT-LM engine to load a model into, so a
    // red "download a model" call-to-action would send the user nowhere.
    // State the situation instead.
    if (!AIService().isEngineAvailable) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.tertiaryFixed,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.public_rounded,
                color: AppTheme.onTertiaryFixedVariant, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Web preview — running on the built-in survival guide',
                style:
                    AppTheme.bodyBold(color: AppTheme.onTertiaryFixedVariant),
              ),
            ),
          ],
        ),
      );
    }

    if (ai.isModelLoaded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.secondaryFixed,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Gemma 4 ${ai.loadedVariant?.name.toUpperCase() ?? ""} • Offline',
                style: AppTheme.bodyBold(color: AppTheme.onSecondaryFixedVariant),
              ),
            ),
            const Icon(Icons.check_circle_rounded,
                color: AppTheme.primary, size: 20),
          ],
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/settings'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.download_rounded,
                  color: AppTheme.onErrorContainer, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No AI model loaded — tap to download & load',
                  style: AppTheme.bodyBold(color: AppTheme.onErrorContainer),
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppTheme.onErrorContainer, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
