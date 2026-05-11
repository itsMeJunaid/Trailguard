class AppConstants {
  static const String appName = 'TrailGuard AI';
  static const String modelDirName = 'TrailGuardModels';

  // LiteRT-LM native format (.litertlm) — runs via the Kotlin Engine API.
  // These are the filenames Google AI Edge Gallery ships with / uses.
  // The storage scanner matches case-insensitively by variant code so the
  // exact filename doesn't need to line up byte-for-byte.
  static const String modelE2B = 'gemma-4-E2B-it.litertlm';
  static const String modelE4B = 'gemma-4-E4B-it.litertlm';

  static const String hfModelPageE2B =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm';
  static const String hfModelFileE2B =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';
  static const String hfModelPageE4B =
      'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm';
  static const String hfModelFileE4B =
      'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm';

  static const int maxTokens = 512;
  static const int contextWindow = 4096;
  static const double temperature = 0.7;
  static const int topK = 40;
  static const int maxResponseWords = 120;

  static const double trackingIntervalSeconds = 5;
  static const double minDistanceMeters = 5;

  static const String mobileNetModelPath = 'assets/models/mobilenet_v2.tflite';
  static const String mobileNetLabelsPath = 'assets/models/labels.txt';

  /// Public Download folder used by the downloader + storage scanner.
  static const String externalModelFolder =
      '/storage/emulated/0/Download/gemma_model';

  /// MethodChannel / EventChannel names for the Kotlin LiteRT-LM bridge.
  static const String litertlmChannel = 'com.trailguard.ai/litertlm';
  static const String litertlmStreamChannel =
      'com.trailguard.ai/litertlm/stream';
}
