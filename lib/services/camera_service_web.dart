/// Web stand-in for [CameraService].
///
/// `tflite_flutter` is FFI-only, so there is no MobileNet interpreter in the
/// browser. Image questions still work — they go straight to the AI chat path
/// instead of being pre-tagged by the local classifier.
class CameraService {
  bool get isReady => false;

  Future<void> initialize() async {}

  Future<Map<String, String>> classify(String imagePath) async => const {
        'label': 'Unknown',
        'hint': 'Local image classifier is unavailable in the browser build.',
        'confidence': '0%',
      };

  void dispose() {}
}
