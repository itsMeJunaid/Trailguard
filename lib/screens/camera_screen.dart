import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/ai_provider.dart';
import '../providers/profile_provider.dart';
import '../services/ai_service.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  CameraController? _cam;
  final _ai = AIService();
  final _picker = ImagePicker();
  File? _image;
  bool _analyzing = false;
  String? _aiResponse;
  int _tokens = 0;
  int _elapsedMs = 0;

  @override
  void initState() {
    super.initState();
    _initCam();
  }

  Future<void> _initCam() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) return;
      _cam = CameraController(cams.first, ResolutionPreset.medium,
          enableAudio: false);
      await _cam!.initialize();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _capture() async {
    if (_cam == null || !_cam!.value.isInitialized) return;
    try {
      final x = await _cam!.takePicture();
      setState(() {
        _image = File(x.path);
        _aiResponse = null;
        _tokens = 0;
        _elapsedMs = 0;
      });
    } catch (_) {}
  }

  Future<void> _pickGallery() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1280);
    if (x == null) return;
    setState(() {
      _image = File(x.path);
      _aiResponse = null;
      _tokens = 0;
      _elapsedMs = 0;
    });
  }

  Future<void> _askAI(String question) async {
    if (_image == null) return;
    final aiState = ref.read(aiProvider);
    if (!aiState.isModelLoaded) {
      setState(() {
        _aiResponse =
            '⚠️ AI model not loaded. Go to Profile → Model Setup → download & load a Gemma .litertlm model.';
      });
      return;
    }

    setState(() {
      _analyzing = true;
      _aiResponse = '';
    });

    final profile = ref.read(profileProvider);
    final buf = StringBuffer();
    final sw = Stopwatch()..start();

    try {
      await for (final token in _ai.chatStreamWithImage(
        question,
        imagePath: _image!.path,
        profile: profile,
      )) {
        buf.write(token);
        if (!mounted) return;
        setState(() => _aiResponse = buf.toString());
      }
    } catch (e) {
      if (buf.isEmpty) buf.write('Error: $e');
    }

    sw.stop();
    setState(() {
      _analyzing = false;
      _tokens = _ai.lastTokenCount;
      _elapsedMs = sw.elapsedMilliseconds;
    });
  }

  void _reset() => setState(() {
        _image = null;
        _aiResponse = null;
        _tokens = 0;
        _elapsedMs = 0;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('AI Scout', style: AppTheme.h2()),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_rounded,
                color: AppTheme.primary),
            onPressed: _pickGallery,
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera / image preview
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: _image != null
                    ? Image.file(_image!,
                        fit: BoxFit.cover, width: double.infinity)
                    : (_cam?.value.isInitialized == true
                        ? CameraPreview(_cam!)
                        : Container(
                            color: AppTheme.surfaceContainerLow,
                            child: const Center(
                              child: CircularProgressIndicator(
                                  color: AppTheme.primary),
                            ),
                          )),
              ),
            ),
          ),

          // AI response area
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildResultArea(),
            ),
          ),

          // Bottom controls
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _image == null
                  ? _CaptureButton(onTap: _capture)
                  : _ImageActions(
                      analyzing: _analyzing,
                      onReset: _reset,
                      onAskAI: () => _showQuestionSheet(context),
                      onChat: () => context.go('/chat'),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultArea() {
    if (_analyzing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primary)),
              const SizedBox(width: 10),
              Text('Gemma is analyzing…',
                  style: AppTheme.bodyBold(color: AppTheme.primary)),
            ],
          ),
          if (_aiResponse != null && _aiResponse!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_aiResponse!,
                    style: AppTheme.body(color: AppTheme.onSurface)
                        .copyWith(height: 1.5)),
              ),
            ),
          ],
        ],
      );
    }

    if (_aiResponse != null && _aiResponse!.isNotEmpty) {
      final secs = (_elapsedMs / 1000).toStringAsFixed(1);
      final tps = _tokens > 0 && _elapsedMs > 0
          ? (_tokens / (_elapsedMs / 1000)).toStringAsFixed(1)
          : '—';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryFixed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text('AI Analysis', style: AppTheme.h3(color: AppTheme.primary)),
              const Spacer(),
              Text(
                '${_tokens > 0 ? "$_tokens tok" : ""} · ${secs}s${_tokens > 0 ? " · $tps t/s" : ""}',
                style: AppTheme.body().copyWith(fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(_aiResponse!,
                  style: AppTheme.body(color: AppTheme.onSurface)
                      .copyWith(height: 1.55)),
            ),
          ),
        ],
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.camera_alt_rounded,
              size: 48, color: AppTheme.primary.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text(
            _image == null
                ? 'Capture or pick an image.\nGemma will analyze it directly.'
                : 'Image ready. Tap "Ask AI" to analyze.',
            style: AppTheme.body(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _showQuestionSheet(BuildContext ctx) async {
    final q = await showModalBottomSheet<String>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _QuestionSheet(),
    );
    if (q != null && q.trim().isNotEmpty) {
      _askAI(q.trim());
    }
  }

  @override
  void dispose() {
    _cam?.dispose();
    super.dispose();
  }
}

// ─── Capture button ─────────────────────────────────────────────────────────

class _CaptureButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CaptureButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.3),
                blurRadius: 18,
                spreadRadius: 2,
              )
            ],
          ),
          child:
              const Icon(Icons.camera_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

// ─── Action row (after image captured) ──────────────────────────────────────

class _ImageActions extends StatelessWidget {
  final bool analyzing;
  final VoidCallback onReset;
  final VoidCallback onAskAI;
  final VoidCallback onChat;
  const _ImageActions({
    required this.analyzing,
    required this.onReset,
    required this.onAskAI,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundBtn(icon: Icons.refresh_rounded, onTap: onReset),
        const SizedBox(width: 16),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: analyzing ? null : onAskAI,
            icon: analyzing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome_rounded, size: 20),
            label: Text(analyzing ? 'ANALYZING…' : 'ASK AI'),
          ),
        ),
        const SizedBox(width: 16),
        _RoundBtn(icon: Icons.chat_bubble_rounded, onTap: onChat),
      ],
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceContainerLowest,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: AppTheme.primary, size: 22),
        ),
      ),
    );
  }
}

// ─── Question bottom sheet ──────────────────────────────────────────────────

class _QuestionSheet extends StatefulWidget {
  const _QuestionSheet();

  @override
  State<_QuestionSheet> createState() => _QuestionSheetState();
}

class _QuestionSheetState extends State<_QuestionSheet> {
  final _ctrl = TextEditingController();

  static const _quickQuestions = [
    'What is this?',
    'Is this safe to eat?',
    'Is this dangerous?',
    'Identify this plant or animal.',
    'What first aid if I touched this?',
    'Describe everything you see.',
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.outlineVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Ask Gemma about this image', style: AppTheme.h2()),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.send,
            style: AppTheme.body(color: AppTheme.onSurface),
            decoration: const InputDecoration(
              hintText: 'Type your question…',
              prefixIcon:
                  Icon(Icons.auto_awesome_rounded, color: AppTheme.primary),
            ),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
          const SizedBox(height: 14),
          Text('QUICK QUESTIONS', style: AppTheme.label()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickQuestions
                .map((q) => ActionChip(
                      label: Text(q),
                      labelStyle: AppTheme.body(color: AppTheme.primary)
                          .copyWith(fontSize: 12),
                      backgroundColor: AppTheme.surfaceContainerLow,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                      onPressed: () => Navigator.pop(context, q),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(
                  context,
                  _ctrl.text.trim().isEmpty
                      ? 'What is this?'
                      : _ctrl.text.trim()),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('SEND TO GEMMA'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
