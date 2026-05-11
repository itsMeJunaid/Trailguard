import 'chat_message.dart';

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  ChatSession copyWith({
    String? title,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  }) =>
      ChatSession(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        messages: messages ?? this.messages,
      );

  String get preview {
    for (final m in messages.reversed) {
      if (m.content.trim().isNotEmpty) {
        final text = m.content.trim();
        return text.length > 80 ? '${text.substring(0, 80)}…' : text;
      }
    }
    return 'Empty conversation';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages
            .map((m) => {
                  'id': m.id,
                  'content': m.content,
                  'role': m.role.name,
                  'timestamp': m.timestamp.toIso8601String(),
                  'isVoice': m.isVoice,
                  'imageTag': m.imageTag,
                  'imagePath': m.imagePath,
                })
            .toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> j) => ChatSession(
        id: j['id'],
        title: j['title'],
        createdAt: DateTime.parse(j['createdAt']),
        updatedAt: DateTime.parse(j['updatedAt']),
        messages: ((j['messages'] as List?) ?? const [])
            .map((e) => ChatMessage(
                  id: e['id'],
                  content: e['content'],
                  role: MessageRole.values.firstWhere(
                    (r) => r.name == e['role'],
                    orElse: () => MessageRole.assistant,
                  ),
                  timestamp: DateTime.parse(e['timestamp']),
                  isVoice: e['isVoice'] ?? false,
                  imageTag: e['imageTag'],
                  imagePath: e['imagePath'],
                ))
            .toList(),
      );
}
