class Message {
  final String id;
  final String? senderId;
  final String? content;
  final String? type;
  final String? createdAt;
  final bool read;

  const Message({
    required this.id,
    this.senderId,
    this.content,
    this.type,
    this.createdAt,
    this.read = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        senderId: json['sender_id'] as String?,
        content: json['content'] as String?,
        type: json['type'] as String?,
        createdAt: json['created_at'] as String?,
        read: json['read'] as bool? ?? false,
      );
}
