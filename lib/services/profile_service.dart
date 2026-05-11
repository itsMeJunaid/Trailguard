import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class ProfileService {
  static const _kProfileKey = 'user_profile_v1';

  Future<UserProfile?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kProfileKey);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProfileKey, jsonEncode(profile.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kProfileKey);
  }

  /// Copy a picked image into app documents dir so the reference survives
  /// when the picker's temp file is garbage-collected.
  Future<String> saveProfilePicture(File source) async {
    final dir = await getApplicationDocumentsDirectory();
    final target =
        File('${dir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await source.copy(target.path);
    return target.path;
  }
}
