import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/platform/local_files.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/trail_point.dart';

class StorageService {
  static const _selectedModelKey = 'selected_model_variant';
  static const _modelPathKey = 'model_path';

  /// Model files only exist on a real filesystem; the browser build returns
  /// an empty list and the Model Setup screen explains why.
  Future<List<String>> scanForModels() => scanForModelFiles();

  Future<String?> getModelPath(String filename) async {
    final paths = await scanForModels();
    final target = filename.toLowerCase();
    for (final p in paths) {
      if (p.toLowerCase().endsWith(target)) return p;
    }
    return null;
  }

  Future<void> saveTrail(List<TrailPoint> points, String trailName) async {
    final data = jsonEncode(points.map((p) => p.toJson()).toList());
    await writeDocText('trail_$trailName.json', data);
  }

  Future<List<TrailPoint>> loadTrail(String trailName) async {
    try {
      final raw = await readDocText('trail_$trailName.json');
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list.map((j) => TrailPoint.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Chat history ─────────────────────────────────────────────────────

  static const _kChatHistoryKey = 'chat_history_v1';
  static const _kRescueHistoryKey = 'rescue_history_v1';

  Future<void> saveChatHistory(List<ChatMessage> messages,
      {bool rescue = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = messages.length > 100
        ? messages.sublist(messages.length - 100)
        : messages;
    final list = trimmed
        .map((m) => {
              'id': m.id,
              'content': m.content,
              'role': m.role.name,
              'timestamp': m.timestamp.toIso8601String(),
              'isVoice': m.isVoice,
              'imageTag': m.imageTag,
              'imagePath': m.imagePath,
            })
        .toList();
    await prefs.setString(
        rescue ? _kRescueHistoryKey : _kChatHistoryKey, jsonEncode(list));
  }

  Future<List<ChatMessage>> loadChatHistory({bool rescue = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw =
          prefs.getString(rescue ? _kRescueHistoryKey : _kChatHistoryKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((j) => ChatMessage(
                id: j['id'],
                content: j['content'],
                role: MessageRole.values.firstWhere(
                  (r) => r.name == j['role'],
                  orElse: () => MessageRole.assistant,
                ),
                timestamp: DateTime.parse(j['timestamp']),
                isVoice: j['isVoice'] ?? false,
                imageTag: j['imageTag'],
                imagePath: j['imagePath'],
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearChatHistory({bool rescue = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(rescue ? _kRescueHistoryKey : _kChatHistoryKey);
  }

  // ── Multi-session chat history ───────────────────────────────────────
  static const _kSessionsKey = 'chat_sessions_v1';

  Future<List<ChatSession>> loadSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSessionsKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((j) => ChatSession.fromJson(j as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSessions(List<ChatSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    // Keep at most 50 newest sessions to bound storage growth.
    final pruned = sessions.length > 50
        ? (sessions.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt))).sublist(0, 50)
        : sessions;
    await prefs.setString(
        _kSessionsKey, jsonEncode(pruned.map((s) => s.toJson()).toList()));
  }

  Future<void> upsertSession(ChatSession session) async {
    final all = await loadSessions();
    final idx = all.indexWhere((s) => s.id == session.id);
    if (idx >= 0) {
      all[idx] = session;
    } else {
      all.add(session);
    }
    await saveSessions(all);
  }

  Future<void> deleteSession(String id) async {
    final all = await loadSessions();
    all.removeWhere((s) => s.id == id);
    await saveSessions(all);
  }

  Future<void> saveModelSelection(String variant, String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedModelKey, variant);
    await prefs.setString(_modelPathKey, path);
  }

  Future<Map<String, String?>> getSavedModelSelection() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'variant': prefs.getString(_selectedModelKey),
      'path': prefs.getString(_modelPathKey),
    };
  }
}
