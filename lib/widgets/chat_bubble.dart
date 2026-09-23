import 'package:flutter/material.dart';
import '../core/platform/local_files.dart';
import '../core/theme.dart';
import '../models/chat_message.dart';
import 'pressable.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  /// Read this message aloud. Omitted for user messages and while streaming.
  final VoidCallback? onSpeak;

  const ChatBubble({super.key, required this.message, this.onSpeak});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.imagePath != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: localImage(
                      message.imagePath!,
                      width: 220,
                      height: 160,
                      fit: BoxFit.cover,
                      errorWidget: const SizedBox.shrink(),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.userBubble,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.isVoice)
                      const Padding(
                        padding: EdgeInsets.only(right: 6, top: 2),
                        child: Icon(Icons.mic_rounded,
                            size: 14, color: Colors.white),
                      ),
                    Flexible(
                      child: Text(message.content,
                          style: AppTheme.body(color: Colors.white)
                              .copyWith(height: 1.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(_formatTime(message.timestamp),
                      style: AppTheme.body(
                              color: AppTheme.onSurfaceVariant.withOpacity(0.6))
                          .copyWith(fontSize: 10)),
                  const SizedBox(width: 4),
                  Icon(Icons.done_all_rounded,
                      size: 12, color: AppTheme.secondary),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.park_rounded,
                      size: 14, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text('TrailGuard AI',
                    style: AppTheme.label(color: AppTheme.primary)),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLowest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.onPrimaryFixed.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.imageTag != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryFixed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('📷 ${message.imageTag}',
                          style: AppTheme.label(
                              color: AppTheme.onSecondaryFixedVariant)),
                    ),
                  Text.rich(
                    TextSpan(
                      children: _inlineMarkdown(
                        message.content,
                        AppTheme.body(color: AppTheme.onSurfaceVariant)
                            .copyWith(height: 1.55),
                      ),
                    ),
                  ),
                  if (onSpeak != null && message.content.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Pressable(
                      onPressed: onSpeak,
                      minSize: 36,
                      label: 'Read this answer aloud',
                      tooltip: 'Read aloud',
                      background: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.volume_up_rounded,
                                size: 16, color: AppTheme.primary),
                            const SizedBox(width: 6),
                            Text('Listen',
                                style: AppTheme.bodyBold(
                                        color: AppTheme.primary)
                                    .copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(_formatTime(message.timestamp),
                style: AppTheme.body(
                        color: AppTheme.onSurfaceVariant.withOpacity(0.6))
                    .copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}


/// Renders the small subset of markdown the AI and the offline guide actually
/// emit: `**bold**` for headings and key terms, `_italic_` for asides.
/// Anything else is left as literal text rather than silently swallowed.
List<TextSpan> _inlineMarkdown(String text, TextStyle base) {
  final spans = <TextSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*|_([^_\n]+?)_');
  var index = 0;

  for (final m in pattern.allMatches(text)) {
    if (m.start > index) {
      spans.add(TextSpan(text: text.substring(index, m.start), style: base));
    }
    if (m.group(1) != null) {
      spans.add(TextSpan(
        text: m.group(1),
        style: base.copyWith(
          fontWeight: FontWeight.w800,
          color: AppTheme.onSurface,
        ),
      ));
    } else {
      spans.add(TextSpan(
        text: m.group(2),
        style: base.copyWith(fontStyle: FontStyle.italic),
      ));
    }
    index = m.end;
  }
  if (index < text.length) {
    spans.add(TextSpan(text: text.substring(index), style: base));
  }
  return spans;
}
