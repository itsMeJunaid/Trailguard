/// The on-device MobileNet classifier runs through `tflite_flutter`, which is
/// `dart:ffi`-based and cannot compile to JavaScript. The web build swaps in a
/// no-op that simply reports itself as not ready.
export 'camera_service_io.dart'
    if (dart.library.js_interop) 'camera_service_web.dart';
