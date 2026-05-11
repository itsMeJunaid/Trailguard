enum GemmaVariant { e2b, e4b }

class ModelConfig {
  final GemmaVariant variant;
  final String filePath;
  final bool isLoaded;
  final int contextLength;
  final int threads;

  const ModelConfig({
    required this.variant,
    required this.filePath,
    this.isLoaded = false,
    this.contextLength = 4096,
    this.threads = 4,
  });

  String get displayName =>
      variant == GemmaVariant.e2b ? 'Gemma 4 E2B (Lite)' : 'Gemma 4 E4B (Full)';

  String get sizeLabel =>
      variant == GemmaVariant.e2b ? '~1.5 GB' : '~2.8 GB';

  String get description => variant == GemmaVariant.e2b
      ? 'Faster responses, lower RAM (2GB). Best for mid-range devices.'
      : 'Smarter responses, higher RAM (4GB). Best for flagship devices.';

  ModelConfig copyWith({bool? isLoaded, String? filePath}) => ModelConfig(
    variant: variant,
    filePath: filePath ?? this.filePath,
    isLoaded: isLoaded ?? this.isLoaded,
    contextLength: contextLength,
    threads: threads,
  );
}
