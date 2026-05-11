import 'package:flutter/material.dart';
import '../core/theme.dart';

class CameraResultCard extends StatelessWidget {
  final Map<String, String> result;
  final VoidCallback onAskAI;

  const CameraResultCard({
    super.key,
    required this.result,
    required this.onAskAI,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result['label'] ?? 'Unknown',
                        style: AppTheme.h1(color: AppTheme.primary)),
                    const SizedBox(height: 2),
                    Text('Confidence: ${result['confidence']}',
                        style: AppTheme.body()),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: onAskAI,
                icon: const Icon(Icons.smart_toy_rounded, size: 16),
                label: const Text('ASK AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryFixed,
                  foregroundColor: AppTheme.onSecondaryFixedVariant,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.errorContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined,
                    color: AppTheme.onErrorContainer, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(result['hint'] ?? '',
                      style: AppTheme.body(color: AppTheme.onErrorContainer)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
