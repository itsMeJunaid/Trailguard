import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../core/theme.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../providers/ai_provider.dart';
import '../providers/profile_provider.dart';
import '../services/ai_service.dart';
import '../services/camera_service.dart';
import '../services/storage_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/voice_button.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  final _cameraService = CameraService();
  final _storage = StorageService();
  final _ai = AIService();
  final _uuid = const Uuid();
  final _drawerKey = GlobalKey<ScaffoldState>();

  List<ChatMessage> _messages = [];
  List<ChatSession> _sessions = [];
  String? _currentSessionId;
  bool _isThinking = false;
  bool _classifying = false;

  /// Pending image attachment — sits in the input bar until user taps Send.
  String? _pendingImagePath;
  String? _pendingImageTag;

  @override
  void initState() {
    super.initState();
    _cameraService.initialize();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final sessions = await _storage.loadSessions();
    setState(() => _sessions = sessions);
    if (sessions.isNotEmpty) {
      _loadSession(sessions.first);
    } else {
      _startNewSession(showWelcome: true);
    }
    _scrollToBottom();
  }

  void _startNewSession({bool showWelcome = true}) {
    final profile = ref.read(profileProvider);
    final name = (profile?.name ?? '').split(' ').first;
    final greet = name.isEmpty ? 'Hello!' : 'Hello, $name!';
    final id = _uuid.v4();
    setState(() {
      _currentSessionId = id;
      _messages = showWelcome
          ? [
              ChatMessage(
                id: _uuid.v4(),
                content:
                    '$greet I\'m your offline survival assistant. Ask me anything — or tap 📎 to attach a photo.',
                role: MessageRole.assistant,
                timestamp: DateTime.now(),
              )
            ]
          : [];
      _pendingImagePath = null;
      _pendingImageTag = null;
    });
  }

  void _loadSession(ChatSession session) {
    setState(() {
      _currentSessionId = session.id;
      _messages = List.of(session.messages);
      _pendingImagePath = null;
      _pendingImageTag = null;
    });
    _scrollToBottom();
  }

  Future<void> _persistCurrent() async {
    if (_currentSessionId == null) return;
    if (!_messages.any((m) => m.role == MessageRole.user)) return;
    final title = _titleFromMessages();
    final existing =
        _sessions.firstWhere((s) => s.id == _currentSessionId, orElse: () {
      return ChatSession(
          id: _currentSessionId!,
          title: title,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          messages: const []);
    });
    final updated = existing.copyWith(
        title: title, updatedAt: DateTime.now(), messages: _messages);
    await _storage.upsertSession(updated);
    final refreshed = await _storage.loadSessions();
    if (mounted) setState(() => _sessions = refreshed);
  }

  String _titleFromMessages() {
    for (final m in _messages) {
      if (m.role == MessageRole.user && m.content.trim().isNotEmpty) {
        final t = m.content.trim();
        return t.length > 40 ? '${t.substring(0, 40)}…' : t;
      }
    }
    return 'New chat';
  }

  Future<void> _deleteSession(String id) async {
    await _storage.deleteSession(id);
    final refreshed = await _storage.loadSessions();
    setState(() => _sessions = refreshed);
    if (id == _currentSessionId) {
      refreshed.isNotEmpty
          ? _loadSession(refreshed.first)
          : _startNewSession(showWelcome: true);
    }
  }

  // ── Send ────────────────────────────────────────────────────────────

  Future<void> _send(String text, {bool isVoice = false}) async {
    final pendingImg = _pendingImagePath;
    final pendingTag = _pendingImageTag;

    // Nothing to send?
    if (text.trim().isEmpty && pendingImg == null) return;

    _controller.clear();
    setState(() {
      _pendingImagePath = null;
      _pendingImageTag = null;
    });

    final content = text.trim().isEmpty
        ? (pendingTag != null
            ? 'What is this? ($pendingTag)'
            : 'What is this?')
        : text.trim();

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      content: content,
      role: MessageRole.user,
      timestamp: DateTime.now(),
      isVoice: isVoice,
      imagePath: pendingImg,
      imageTag: pendingTag,
    );

    setState(() {
      _messages.add(userMsg);
      _isThinking = true;
    });
    _scrollToBottom();
    await _persistCurrent();

    final profile = ref.read(profileProvider);
    final aiState = ref.read(aiProvider);

    // Model-not-ready guard
    if (!aiState.isModelLoaded) {
      setState(() {
        _messages.add(ChatMessage(
          id: _uuid.v4(),
          content:
              '⚠️ AI model not loaded yet. Open Profile → Model Setup → download & load a Gemma .litertlm model first.',
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
        ));
        _isThinking = false;
      });
      _scrollToBottom();
      await _persistCurrent();
      return;
    }

    // Stream the response token-by-token.
    final aiId = _uuid.v4();
    final buffer = StringBuffer();
    final stopwatch = Stopwatch()..start();

    setState(() {
      _messages.add(ChatMessage(
          id: aiId,
          content: '',
          role: MessageRole.assistant,
          timestamp: DateTime.now()));
      _isThinking = false;
    });

    // Pick the right stream: multimodal if we have an image, text-only otherwise.
    final Stream<String> tokenStream;
    if (pendingImg != null) {
      tokenStream = _ai.chatStreamWithImage(
        userMsg.content,
        imagePath: pendingImg,
        profile: profile,
      );
    } else {
      tokenStream = _ai.chatStream(
        userMsg.content,
        imageContext: pendingTag,
        profile: profile,
      );
    }

    try {
      await for (final token in tokenStream) {
        buffer.write(token);
        if (!mounted) return;
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == aiId);
          if (idx != -1) {
            _messages[idx] = ChatMessage(
              id: aiId,
              content: buffer.toString(),
              role: MessageRole.assistant,
              timestamp: _messages[idx].timestamp,
            );
          }
        });
        _scrollToBottom();
      }
    } catch (_) {}

    stopwatch.stop();
    final tokens = _ai.lastTokenCount;
    final elapsed = stopwatch.elapsedMilliseconds;
    final secs = (elapsed / 1000).toStringAsFixed(1);
    final tps = tokens > 0 && elapsed > 0
        ? (tokens / (elapsed / 1000)).toStringAsFixed(1)
        : '—';

    // Append stats footer to the AI message
    if (buffer.isNotEmpty) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == aiId);
        if (idx != -1) {
          _messages[idx] = ChatMessage(
            id: aiId,
            content:
                '${buffer.toString().trimRight()}\n\n— ${tokens > 0 ? "$tokens tokens" : ""} · ${secs}s${tokens > 0 ? " · $tps tok/s" : ""}',
            role: MessageRole.assistant,
            timestamp: _messages[idx].timestamp,
          );
        }
      });
    }

    await _persistCurrent();
    final voice = ref.read(aiProvider.notifier).voiceService;
    await voice?.speak(buffer.toString());
  }

  // ── Attach image (no auto-send) ───────────────────────────────────

  Future<void> _attachImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.outlineVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('Attach a photo', style: AppTheme.h2()),
              const SizedBox(height: 14),
              _SourceTile(
                icon: Icons.photo_camera_rounded,
                title: 'Take a photo',
                subtitle: 'Use the camera now',
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 10),
              _SourceTile(
                icon: Icons.photo_library_rounded,
                title: 'Pick from gallery',
                subtitle: 'Choose from your photos',
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;
    XFile? x;
    try {
      x = await _picker.pickImage(source: source, maxWidth: 1280);
    } catch (_) {}
    if (x == null) return;

    // No TFLite classification — Gemma handles image analysis directly
    // when the user taps Send. Just show the preview thumbnail.
    setState(() {
      _pendingImagePath = x!.path;
      _pendingImageTag = 'Photo';
    });
  }

  void _clearPendingImage() {
    setState(() {
      _pendingImagePath = null;
      _pendingImageTag = null;
    });
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

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _drawerKey,
      backgroundColor: const Color(0xFFF1FAF5),
      drawer: _HistoryDrawer(
        sessions: _sessions,
        activeId: _currentSessionId,
        onNewChat: () {
          Navigator.of(context).pop();
          _startNewSession();
        },
        onOpen: (s) {
          Navigator.of(context).pop();
          _loadSession(s);
        },
        onDelete: _deleteSession,
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppTheme.primary),
          tooltip: 'Chat history',
          onPressed: () => _drawerKey.currentState?.openDrawer(),
        ),
        title: Text('AI Chat', style: AppTheme.h2()),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_rounded,
                color: AppTheme.primary),
            onPressed: () => _startNewSession(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              itemCount:
                  _messages.length + (_isThinking ? 1 : 0) + (_classifying ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i < _messages.length) return ChatBubble(message: _messages[i]);
                final rel = i - _messages.length;
                if (_classifying && rel == 0) return const _ClassifyingBubble();
                return const _ThinkingBubble();
              },
            ),
          ),

          // Input bar with optional image preview
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pending-image preview strip
                  if (_pendingImagePath != null) _ImagePreview(
                    path: _pendingImagePath!,
                    label: _pendingImageTag,
                    onRemove: _clearPendingImage,
                  ),

                  // Input row
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.onPrimaryFixed.withOpacity(0.05),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: VoiceButton(
                            onTranscribed: (text) =>
                                _send(text, isVoice: true),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _RoundIconBtn(
                          icon: Icons.attach_file_rounded,
                          onTap: _attachImage,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            maxLines: 4,
                            minLines: 1,
                            textInputAction: TextInputAction.send,
                            style: AppTheme.body(color: AppTheme.onSurface),
                            decoration: InputDecoration(
                              hintText: _pendingImagePath != null
                                  ? 'Ask about this image…'
                                  : 'Message TrailGuard…',
                              hintStyle: AppTheme.body(
                                  color: AppTheme.onSurfaceVariant
                                      .withOpacity(0.5)),
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
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.send_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _cameraService.dispose();
    super.dispose();
  }
}

// ─── Image preview strip ──────────────────────────────────────────────────

class _ImagePreview extends StatelessWidget {
  final String path;
  final String? label;
  final VoidCallback onRemove;
  const _ImagePreview({
    required this.path,
    this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.primaryFixed,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(path),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 56,
                height: 56,
                color: AppTheme.surfaceContainerHigh,
                child: const Icon(Icons.broken_image_rounded,
                    color: AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Image attached',
                    style: AppTheme.bodyBold(color: AppTheme.primary)),
                if (label != null && label != 'Unknown')
                  Text('Detected: $label',
                      style: AppTheme.body().copyWith(fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppTheme.primary,
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

class _RoundIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceContainerLow,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryFixed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.h3(color: AppTheme.primary)),
                    Text(subtitle, style: AppTheme.body()),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppTheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassifyingBubble extends StatelessWidget {
  const _ClassifyingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.primary),
          ),
          const SizedBox(width: 10),
          Text('Analysing image…',
              style: AppTheme.label(color: AppTheme.primary)),
        ],
      ),
    );
  }
}

class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
                color: AppTheme.primary, shape: BoxShape.circle),
            child:
                const Icon(Icons.park_rounded, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 10),
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Row(
              children: List.generate(3, (i) {
                final t = (_ctrl.value + i * 0.2) % 1.0;
                final scale =
                    0.6 + (1 - (t - 0.5).abs() * 2).clamp(0, 1) * 0.6;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 6 * scale,
                  height: 6 * scale,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.4 + scale * 0.4),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── History drawer ─────────────────────────────────────────────────────────

class _HistoryDrawer extends StatelessWidget {
  final List<ChatSession> sessions;
  final String? activeId;
  final VoidCallback onNewChat;
  final void Function(ChatSession) onOpen;
  final Future<void> Function(String) onDelete;

  const _HistoryDrawer({
    required this.sessions,
    required this.activeId,
    required this.onNewChat,
    required this.onOpen,
    required this.onDelete,
  });

  String _groupLabel(DateTime t) {
    final today = DateTime.now();
    final d = DateTime(today.year, today.month, today.day)
        .difference(DateTime(t.year, t.month, t.day))
        .inDays;
    if (d == 0) return 'TODAY';
    if (d == 1) return 'YESTERDAY';
    if (d < 7) return 'THIS WEEK';
    if (d < 30) return 'THIS MONTH';
    return 'EARLIER';
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<ChatSession>>{};
    for (final s in sessions) {
      groups.putIfAbsent(_groupLabel(s.updatedAt), () => []).add(s);
    }

    return Drawer(
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: AppTheme.primaryFixed,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.history_rounded,
                        color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Chat History', style: AppTheme.h2()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onNewChat,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('NEW CHAT'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No chats yet.\nStart a conversation and it will appear here.',
                          textAlign: TextAlign.center,
                          style: AppTheme.body(),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 20),
                      children: [
                        for (final e in groups.entries) ...[
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 14, 20, 6),
                            child: Text(e.key,
                                style:
                                    AppTheme.label(color: AppTheme.primary)),
                          ),
                          for (final s in e.value)
                            _SessionTile(
                              session: s,
                              active: s.id == activeId,
                              onTap: () => onOpen(s),
                              onDelete: () => onDelete(s.id),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final ChatSession session;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _SessionTile({
    required this.session,
    required this.active,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: active
            ? AppTheme.primaryFixed
            : AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    color: active
                        ? AppTheme.primary
                        : AppTheme.primary.withOpacity(0.6),
                    size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppTheme.bodyBold(color: AppTheme.primary)),
                      Text(session.preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body().copyWith(fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.delete_outline_rounded, size: 18),
                  color: AppTheme.error.withOpacity(0.7),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
