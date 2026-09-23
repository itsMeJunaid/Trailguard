/// Web stand-in for [ModelDownloadService].
///
/// A 1.5–2.8 GB `.litertlm` file has nowhere to live in a browser tab, and
/// there is no native LiteRT-LM runtime to hand it to, so the browser build
/// reports the feature as unavailable and lets the UI fall back to
/// TrailGuard's built-in offline survival knowledge base.
class ModelDownloadService {
  static const String unsupportedMessage =
      'Model download needs the Android app — the browser build runs on '
      'TrailGuard\'s built-in survival knowledge base.';

  void Function(int received, int total, double percent, double bps)?
      onProgress;

  void Function(String? savedPath, String? error)? onComplete;

  Future<void> init() async {}

  Future<String?> startDownload({
    required String url,
    required String filename,
    Map<String, String>? headers,
  }) async {
    onComplete?.call(null, unsupportedMessage);
    return null;
  }

  Future<void> cancel() async {}

  void dispose() {}
}
