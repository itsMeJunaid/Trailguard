enum MessageRole { user, assistant, system }

class ChatMessage {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final bool isVoice;
  final String? imageTag;
  final String? imagePath;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.isVoice = false,
    this.imageTag,
    this.imagePath,
  });
}
