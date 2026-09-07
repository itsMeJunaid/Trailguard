/// Cross-platform local-file helpers.
///
/// Android/iOS keep their real `dart:io` behaviour. The web build gets a
/// browser-shaped equivalent (blob URLs for picked images, SharedPreferences
/// for small documents) so every screen compiles and runs in Chrome without
/// a second copy of the UI.
export 'local_files_io.dart' if (dart.library.js_interop) 'local_files_web.dart';
