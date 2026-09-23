/// `flutter_downloader` has no web implementation, so even importing it breaks
/// the JS compile. Startup initialisation goes through this seam instead.
export 'downloader_boot_io.dart'
    if (dart.library.js_interop) 'downloader_boot_web.dart';
