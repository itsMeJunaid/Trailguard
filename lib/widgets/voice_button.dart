import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../services/voice_service.dart';
import 'pressable.dart';

class VoiceButton extends ConsumerStatefulWidget {
  /// Fires when the user finishes speaking (final transcript).
  final Function(String) onTranscribed;

  /// Optional: fires on every interim transcript so the UI can echo live text.
  final void Function(String)? onPartial;

  const VoiceButton({
    super.key,
    required this.onTranscribed,
    this.onPartial,
  });

  @override
  ConsumerState<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends ConsumerState<VoiceButton>
    with SingleTickerProviderStateMixin {
  final _voice = VoiceService();
  bool _listening = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _voice.initTTS();
    _voice.initSTT();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulse = Tween(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _voice.stopListening();
      setState(() => _listening = false);
      _pulseCtrl.stop();
      _pulseCtrl.reset();
      return;
    }

    setState(() => _listening = true);
    _pulseCtrl.repeat(reverse: true);

    final result = await _voice.listen(
      onText: (text, isFinal) {
        widget.onPartial?.call(text);
      },
    );

    if (!mounted) return;
    setState(() => _listening = false);
    _pulseCtrl.stop();
    _pulseCtrl.reset();

    if (result != null && result.trim().isNotEmpty) {
      widget.onTranscribed(result.trim());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(_voice.sttAvailable
            ? "I didn't catch that. Try again."
            : 'Speech recognition not available on this device.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) => Transform.scale(
        scale: _listening ? _pulse.value : 1.0,
        child: child,
      ),
      child: Pressable(
        circle: true,
        onPressed: _toggle,
        background:
            _listening ? AppTheme.error : AppTheme.surfaceContainerLow,
        label: _listening ? 'Stop listening' : 'Speak your question',
        child: Icon(
          _listening ? Icons.stop_rounded : Icons.mic_rounded,
          color: _listening ? Colors.white : AppTheme.primary,
          size: 22,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _voice.dispose();
    super.dispose();
  }
}
