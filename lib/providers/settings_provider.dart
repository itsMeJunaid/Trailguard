import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final bool voiceAutoSpeak;
  final bool keepScreenOn;
  final double ttsSpeed;

  const SettingsState({
    this.voiceAutoSpeak = true,
    this.keepScreenOn = false,
    this.ttsSpeed = 0.5,
  });

  SettingsState copyWith({
    bool? voiceAutoSpeak,
    bool? keepScreenOn,
    double? ttsSpeed,
  }) => SettingsState(
    voiceAutoSpeak: voiceAutoSpeak ?? this.voiceAutoSpeak,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    ttsSpeed: ttsSpeed ?? this.ttsSpeed,
  );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      voiceAutoSpeak: prefs.getBool('voiceAutoSpeak') ?? true,
      keepScreenOn: prefs.getBool('keepScreenOn') ?? false,
      ttsSpeed: prefs.getDouble('ttsSpeed') ?? 0.5,
    );
  }

  Future<void> setVoiceAutoSpeak(bool v) async {
    state = state.copyWith(voiceAutoSpeak: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voiceAutoSpeak', v);
  }

  Future<void> setKeepScreenOn(bool v) async {
    state = state.copyWith(keepScreenOn: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('keepScreenOn', v);
  }

  Future<void> setTtsSpeed(double v) async {
    state = state.copyWith(ttsSpeed: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('ttsSpeed', v);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (_) => SettingsNotifier(),
);
