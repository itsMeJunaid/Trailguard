import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

class ProfileNotifier extends StateNotifier<UserProfile?> {
  final ProfileService _service = ProfileService();
  final _readyCompleter = Completer<void>();

  /// Completes when the saved profile has been loaded from disk (or absence
  /// confirmed). The boot gate awaits this so it doesn't route on stale state.
  Future<void> get ready => _readyCompleter.future;

  ProfileNotifier() : super(null) {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final p = await _service.load();
      state = p;
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  Future<void> reload() async {
    state = await _service.load();
  }

  Future<void> save(UserProfile profile) async {
    await _service.save(profile);
    state = profile;
  }

  Future<String> setPicture(File file) async {
    final path = await _service.saveProfilePicture(file);
    if (state != null) {
      final updated = state!.copyWith(profilePicPath: path);
      await save(updated);
    }
    return path;
  }

  Future<void> clear() async {
    await _service.clear();
    state = null;
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, UserProfile?>(
  (_) => ProfileNotifier(),
);
