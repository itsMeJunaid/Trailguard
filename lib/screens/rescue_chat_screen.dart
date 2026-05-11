import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../core/theme.dart';
import '../models/chat_message.dart';
import '../providers/ai_provider.dart';
import '../providers/profile_provider.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../widgets/voice_button.dart';

class RescueChatScreen extends ConsumerStatefulWidget {
  const RescueChatScreen({super.key});

  @override
  ConsumerState<RescueChatScreen> createState() => _RescueChatScreenState();
}

class _RescueChatScreenState extends ConsumerState<RescueChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _uuid = const Uuid();
  final AIService _ai = AIService();
  final StorageService _storage = StorageService();
  final List<ChatMessage> _messages = [];
  bool _isThinking = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (_) {
      try {
        pos = await Geolocator.getLastKnownPosition();
      } catch (_) {}
    }

    final coords = pos == null
        ? 'coordinates not yet locked'
        : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';

    final profile = ref.read(profileProvider);
    final name = (profile?.name ?? '').trim();
    final greet = name.isEmpty ? 'caller' : name.split(' ').first;

    setState(() {
      _messages.add(ChatMessage(
        id: _uuid.v4(),
        content: 'TRAILGUARD RESCUE DISPATCH — distress signal received.\n\n'
            'Your location: $coords.\n'
            'Hello $greet, stay calm. I am your coordinator.\n\n'
            'Tell me what happened — you can TYPE or tap the mic and SPEAK.\n'
            'Examples: "snake bite on my leg", "cut my hand deep", "broken ankle", "freezing and can\'t feel my fingers".',
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
      ));
    });
  }

  Future<void> _send(String text, {bool isVoice = false}) async {
    if (text.trim().isEmpty) return;
    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(
        id: _uuid.v4(),
        content: text.trim(),
        role: MessageRole.user,
        timestamp: DateTime.now(),
        isVoice: isVoice,
      ));
      _isThinking = true;
    });
    _scrollToBottom();

    // Compact transcript to keep dispatcher in context
    final transcript = _messages.reversed
        .take(6)
        .toList()
        .reversed
        .map((m) =>
            '${m.role == MessageRole.user ? "CALLER" : "DISPATCH"}: ${m.content}')
        .join('\n');

    final profile = ref.read(profileProvider);

    final response = await _ai.chatWithPrompt(
      systemPrompt: AIService.rescueDispatchPrompt,
      userMessage:
          'Recent transcript:\n$transcript\n\nRespond as DISPATCH to the latest CALLER message.',
      profile: profile,
    );

    setState(() {
      _messages.add(ChatMessage(
        id: _uuid.v4(),
        content: response,
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
      ));
      _isThinking = false;
    });
    _scrollToBottom();

    // Persist rescue conversation (separate bucket from main chat)
    await _storage.saveChatHistory(_messages, rescue: true);

    final voice = ref.read(aiProvider.notifier).voiceService;
    await voice?.speak(response);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.errorContainer,
      appBar: AppBar(
        backgroundColor: AppTheme.error,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text('RESCUE DISPATCH',
                style:
                    AppTheme.h3(color: Colors.white).copyWith(letterSpacing: 1.5)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text('END', style: AppTheme.label(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: AppTheme.error.withOpacity(0.15),
            child: Text(
              'TRAINING SIMULATION • Gemma 4 dispatcher — no real rescuers contacted',
              textAlign: TextAlign.center,
              style: AppTheme.label(color: AppTheme.onErrorContainer),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isThinking ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i == _messages.length && _isThinking) {
                  return const _DispatchThinking();
                }
                return _RescueBubble(message: _messages[i]);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: VoiceButton(
                        onTranscribed: (text) => _send(text, isVoice: true),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        style: AppTheme.body(color: AppTheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Speak or type your emergency...',
                          hintStyle: AppTheme.body(
                              color:
                                  AppTheme.onSurfaceVariant.withOpacity(0.5)),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 10),
                        ),
                        onSubmitted: _send,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _send(_controller.text),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RescueBubble extends StatelessWidget {
  final ChatMessage message;
  const _RescueBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 12,
          left: isUser ? 60 : 0,
          right: isUser ? 0 : 60,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.error : AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('DISPATCH',
                    style: AppTheme.label(color: AppTheme.error)),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isUser && message.isVoice)
                  const Padding(
                    padding: EdgeInsets.only(right: 6, top: 2),
                    child: Icon(Icons.mic_rounded,
                        size: 14, color: Colors.white),
                  ),
                Flexible(
                  child: Text(
                    message.content,
                    style: AppTheme.body(
                            color: isUser ? Colors.white : AppTheme.onSurface)
                        .copyWith(height: 1.55),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DispatchThinking extends StatelessWidget {
  const _DispatchThinking();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.error),
          ),
          const SizedBox(width: 10),
          Text('Dispatch is analysing…',
              style: AppTheme.label(color: AppTheme.error)),
        ],
      ),
    );
  }
}
