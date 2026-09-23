/// Model downloads run through `flutter_downloader`, which is Android/iOS only
/// (it reaches for `dart:isolate` and a background OS task queue). The web
/// build gets a stub that reports the feature as unavailable rather than
/// failing to compile.
export 'model_download_service_io.dart'
    if (dart.library.js_interop) 'model_download_service_web.dart';
