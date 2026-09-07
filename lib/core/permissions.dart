import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsManager {
  static Future<bool> requestAll() async {
    // Browsers prompt at the point of use — for geolocation, getUserMedia and
    // notifications alike. Asking up front here would flash the camera and mic
    // on during onboarding for permissions the user may never need.
    if (kIsWeb) return true;
    try {
      final statuses = await [
        Permission.locationWhenInUse,
        Permission.camera,
        Permission.microphone,
        Permission.notification,
      ].request();

      return statuses.values.every(
        (s) => s == PermissionStatus.granted || s == PermissionStatus.limited,
      );
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasLocation() async =>
      await Permission.locationWhenInUse.isGranted;

  static Future<bool> hasCamera() async =>
      await Permission.camera.isGranted;

  static Future<bool> hasMicrophone() async =>
      await Permission.microphone.isGranted;

  static Future<bool> hasStorage() async {
    if (kIsWeb) return false;
    return await Permission.storage.isGranted ||
        await Permission.manageExternalStorage.isGranted;
  }
}
