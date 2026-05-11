import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/model_config.dart';
import '../services/ai_service.dart';
import '../services/voice_service.dart';

class AIState {
  final bool isModelLoaded;
  final bool isLoading;
  final GemmaVariant? loadedVariant;
  final bool useGpu;
  final String? error;

  const AIState({
    this.isModelLoaded = false,
    this.isLoading = false,
    this.loadedVariant,
    this.useGpu = false,
    this.error,
  });

  AIState copyWith({
    bool? isModelLoaded,
    bool? isLoading,
    GemmaVariant? loadedVariant,
    bool? useGpu,
    String? error,
  }) =>
      AIState(
        isModelLoaded: isModelLoaded ?? this.isModelLoaded,
        isLoading: isLoading ?? this.isLoading,
        loadedVariant: loadedVariant ?? this.loadedVariant,
        useGpu: useGpu ?? this.useGpu,
        error: error,
      );
}

class AINotifier extends StateNotifier<AIState> {
  final AIService _aiService = AIService();
  final VoiceService _voiceService = VoiceService();

  AINotifier() : super(const AIState()) {
    _voiceService.initTTS();
  }

  VoiceService? get voiceService => _voiceService;
  AIService get aiService => _aiService;

  Future<bool> loadModel(String path, GemmaVariant variant) async {
    state = state.copyWith(isLoading: true, error: null);
    final success = await _aiService.loadModel(path, variant);
    state = state.copyWith(
      isLoading: false,
      isModelLoaded: success,
      loadedVariant: success ? variant : null,
      error: success ? null : 'Failed to load model',
    );
    return success;
  }

  Future<void> setUseGpu(bool v) async {
    state = state.copyWith(useGpu: v, isLoading: true);
    await _aiService.setUseGpu(v);
    state = state.copyWith(isLoading: false);
  }

  Future<String> chat(String message, {String? imageContext}) async {
    return _aiService.chat(message, imageContext: imageContext);
  }

  @override
  void dispose() {
    _aiService.unloadModel();
    _voiceService.dispose();
    super.dispose();
  }
}

final aiProvider = StateNotifierProvider<AINotifier, AIState>(
  (_) => AINotifier(),
);
