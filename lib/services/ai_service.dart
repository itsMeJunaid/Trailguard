import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../core/platform/local_files.dart';
import 'survival_kb.dart';
import '../models/model_config.dart';
import '../models/user_profile.dart';

/// On-device Gemma inference via LiteRT-LM Kotlin API.
/// Text + multimodal image via MethodChannel; streamed tokens via EventChannel.
class AIService {
  static final AIService _singleton = AIService._();
  factory AIService() => _singleton;
  AIService._();

  static const MethodChannel _channel =
      MethodChannel(AppConstants.litertlmChannel);
  static const EventChannel _stream =
      EventChannel(AppConstants.litertlmStreamChannel);

  bool _modelLoaded = false;
  GemmaVariant? _loadedVariant;
  bool _useGpu = false;
  String? _modelPath;

  // Token / timing stats from last response
  int lastTokenCount = 0;
  int lastElapsedMs = 0;
  int totalTokens = 0;
  int sessionTokens = 0;

  bool get isModelLoaded => _modelLoaded;
  GemmaVariant? get loadedVariant => _loadedVariant;
  bool get useGpu => _useGpu;

  // ── Prompts ───────────────────────────────────────────────────────

  static const String survivalPrompt =
      'You are TrailGuard AI, an expert offline survival assistant. '
      'Answer in under 120 words. Be direct and practical. Prioritize safety. '
      'Address the user by their first name when known. '
      'Topics: trail navigation, weather hazards, plant/animal identification, '
      'first aid, shelter, water, fire, SOS. '
      'If the user has a relevant medical condition or allergy, factor it in.';

  static const String rescueDispatchPrompt =
      'You are TRAILGUARD RESCUE DISPATCH — a calm, professional emergency '
      'coordinator in a TRAINING SIMULATION. '
      'Keep the caller calm, assess their condition, give clear first-aid / '
      'survival instructions until (simulated) rescuers arrive. '
      'Use the caller\'s profile where it matters. Under 120 words. '
      'Ask ONE focused question per reply when you need more info. '
      'For injury keywords, give 2-3 numbered first-aid steps IMMEDIATELY. '
      'Never break character. No real emergency services will be contacted.';

  static const String trailGuidePrompt =
      'You are TrailGuard Trail Guide — an offline hiking coach. '
      'Given a hiker\'s position, distance, elevation, and direction, '
      'give ONE short actionable tip (under 35 words). '
      'Focus on pacing, hydration, hazards, or navigation.';

  // ── Model lifecycle ───────────────────────────────────────────────

  Future<void> setUseGpu(bool value) async {
    if (_useGpu == value) return;
    _useGpu = value;
    if (_modelLoaded && _modelPath != null && _loadedVariant != null) {
      await unloadModel();
      await loadModel(_modelPath!, _loadedVariant!);
    }
  }

  /// The LiteRT-LM engine is a native Kotlin/Swift bridge. In the browser
  /// there is nothing on the other end of the MethodChannel, so the app runs
  /// on [_stubResponse] — its built-in offline survival knowledge base.
  bool get isEngineAvailable => !kIsWeb;

  Future<bool> loadModel(String modelPath, GemmaVariant variant) async {
    if (!isEngineAvailable) return false;
    try {
      if (!localFileExists(modelPath) ||
          await localFileSize(modelPath) < 50 * 1024 * 1024) {
        return false;
      }
    } catch (_) {
      return false;
    }

    try {
      final ok = await _channel.invokeMethod<bool>('loadModel', {
        'path': modelPath,
        'useGpu': _useGpu,
      });
      if (ok == true) {
        _modelLoaded = true;
        _loadedVariant = variant;
        _modelPath = modelPath;
        sessionTokens = 0;
        return true;
      }
    } on PlatformException catch (e) {
      print('LiteRT-LM loadModel: ${e.code} ${e.message}');
    } catch (e) {
      print('LiteRT-LM loadModel: $e');
    }
    _modelLoaded = false;
    return false;
  }

  Future<void> unloadModel() async {
    try { await _channel.invokeMethod('unload'); } catch (_) {}
    _modelLoaded = false;
    _loadedVariant = null;
  }

  Future<void> cancel() async {
    try { await _channel.invokeMethod('cancel'); } catch (_) {}
  }

  Future<Map<String, int>> getStats() async {
    try {
      final r = await _channel.invokeMethod<Map>('getStats');
      if (r != null) {
        totalTokens = (r['totalTokens'] as num?)?.toInt() ?? totalTokens;
        sessionTokens = (r['sessionTokens'] as num?)?.toInt() ?? sessionTokens;
      }
    } catch (_) {}
    return {'totalTokens': totalTokens, 'sessionTokens': sessionTokens};
  }

  // ── Chat — text only ──────────────────────────────────────────────

  Future<String> chat(
    String userMessage, {
    String? imageContext,
    UserProfile? profile,
  }) =>
      chatWithPrompt(
        systemPrompt: survivalPrompt,
        userMessage: userMessage,
        imageContext: imageContext,
        profile: profile,
      );

  Future<String> chatWithPrompt({
    required String systemPrompt,
    required String userMessage,
    String? imageContext,
    UserProfile? profile,
  }) async {
    final buf = StringBuffer();
    try {
      await for (final t in chatStream(userMessage,
          systemPrompt: systemPrompt,
          imageContext: imageContext,
          profile: profile)) {
        buf.write(t);
      }
    } catch (_) {}
    final out = buf.toString().trim();
    return out.isEmpty ? _stubResponse(systemPrompt, userMessage, profile) : out;
  }

  /// Streaming text tokens.
  Stream<String> chatStream(
    String userMessage, {
    String systemPrompt = survivalPrompt,
    String? imageContext,
    UserProfile? profile,
  }) async* {
    if (!_modelLoaded) {
      yield _stubResponse(systemPrompt, userMessage, profile);
      return;
    }
    final system = _composeSystem(systemPrompt, profile);
    final text = _wrapUser(userMessage, imageContext: imageContext);

    yield* _invokeStream('sendMessage', {
      'text': text,
      'systemPrompt': system,
    });
  }

  // ── Chat — with image ─────────────────────────────────────────────

  /// Send text + image file to the multimodal Gemma model.
  /// The Kotlin side downscales to 896px max and JPEG-encodes.
  Stream<String> chatStreamWithImage(
    String userMessage, {
    String? imagePath,
    Uint8List? imageBytes,
    String systemPrompt = survivalPrompt,
    UserProfile? profile,
  }) async* {
    if (!_modelLoaded) {
      yield _stubResponse(systemPrompt, userMessage, profile);
      return;
    }
    final system = _composeSystem(systemPrompt, profile);

    final args = <String, dynamic>{
      'text': userMessage,
      'systemPrompt': system,
    };
    if (imagePath != null) args['imagePath'] = imagePath;
    if (imageBytes != null) args['imageBytes'] = imageBytes;

    yield* _invokeStream('sendMessageWithImage', args);
  }

  // ── Internal streaming helper ─────────────────────────────────────

  Stream<String> _invokeStream(String method, Map<String, dynamic> args) async* {
    final controller = StreamController<String>();
    StreamSubscription? sub;

    sub = _stream.receiveBroadcastStream().listen(
      (event) {
        if (event is! Map) return;
        if (event['done'] == true) {
          lastTokenCount = (event['tokens'] as num?)?.toInt() ?? 0;
          lastElapsedMs = (event['elapsedMs'] as num?)?.toInt() ?? 0;
          totalTokens += lastTokenCount;
          sessionTokens += lastTokenCount;
          sub?.cancel();
          if (!controller.isClosed) controller.close();
        } else if (event['error'] != null) {
          if (!controller.isClosed) controller.addError(event['error'].toString());
          sub?.cancel();
          if (!controller.isClosed) controller.close();
        } else {
          final tok = event['token']?.toString();
          if (tok != null && tok.isNotEmpty && !controller.isClosed) {
            controller.add(tok);
          }
        }
      },
      onError: (e) {
        if (!controller.isClosed) controller.addError(e);
        if (!controller.isClosed) controller.close();
      },
    );

    _unawaited(() async {
      try {
        await _channel.invokeMethod(method, args);
      } on PlatformException catch (e) {
        if (!controller.isClosed) {
          controller.addError(e.message ?? method);
          controller.close();
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e.toString());
          controller.close();
        }
      }
    }());

    yield* controller.stream;
  }

  // ── Helpers ───────────────────────────────────────────────────────

  String _composeSystem(String prompt, UserProfile? p) {
    final line = (p != null && !p.isEmpty) ? '\n${p.toAIContext()}' : '';
    return '$prompt$line';
  }

  String _wrapUser(String text, {String? imageContext}) {
    final img = imageContext != null ? '\n[Camera detected: $imageContext]' : '';
    return '$text$img';
  }

  // ── Offline stubs ─────────────────────────────────────────────────

  String _stubResponse(String sys, String msg, UserProfile? profile) {
    final you = (profile?.name ?? '').split(' ').first;
    final yc = you.isEmpty ? '' : '$you, ';

    if (sys == rescueDispatchPrompt) return _rescueStub(msg.toLowerCase(), yc, profile);
    if (sys == trailGuidePrompt) {
      const t = [
        'Steady pace — 500m then 20-sec breather.',
        'Drink 200ml now. Dehydration hits before thirst.',
        'Compass bearing back to start every 1 km.',
        'Watch footing on loose scree; shorten stride.',
        'Golden hour near — scout shelter.',
      ];
      return '${yc.isEmpty ? "" : "$you, "}${t[DateTime.now().minute % t.length]}';
    }
    // No model loaded — the whole web build, and on-device before the
    // download finishes. Answer from the built-in guide rather than handing
    // back an error: someone asking how to purify water needs the answer.
    return SurvivalKnowledgeBase.answer(msg, profile: profile) ??
        SurvivalKnowledgeBase.notFound(profile: profile);
  }

  String _rescueStub(String m, String yc, UserProfile? p) {
    if (m.contains('snake') || m.contains('bite'))
      return 'Copy — snake bite. ${yc}stay calm:\n1) Keep limb BELOW heart, immobilise.\n2) Remove rings before swelling.\n3) Do NOT cut, suck, or ice.\nDescribe the snake?';
    if (m.contains('bleed') || m.contains('cut') || m.contains('wound'))
      return 'Bleeding control — ${yc}press firmly:\n1) Direct pressure 10 min.\n2) Elevate above heart.\n3) Add cloth, don\'t remove first layer.\n${p?.bloodGroup != null ? "Blood ${p!.bloodGroup} noted. " : ""}Under control?';
    if (m.contains('fracture') || m.contains('broken') || m.contains('break'))
      return 'Suspected fracture. ${yc}don\'t move limb:\n1) Splint with sticks.\n2) Secure above & below break.\n3) Check circulation (warm & pink?).\nWhich bone?';
    if (m.contains('burn'))
      return 'Burn care. ${yc}act now:\n1) Cool water 10-20 min.\n2) Remove jewellery.\n3) Cover with clean dressing.\nHow large?';
    if (m.contains('allerg') || m.contains('sting'))
      return 'Allergic reaction.${p?.allergies != null ? " File: ${p!.allergies}." : ""}\n1) Epipen if available.\n2) Sit up if breathing hard.\n3) Monitor breathing.\nFace/lip swelling?';
    if (m.length < 8 || m.contains('help'))
      return 'Dispatch copy. ${yc}I have your signal. What happened — one sentence?';
    return 'Copy. Tell me your most urgent concern right now.';
  }

  static void _unawaited(Future<void> f) {}
}
