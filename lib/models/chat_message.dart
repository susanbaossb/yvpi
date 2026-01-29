class ChatMessage {
  final String oId;
  final String content;
  final String userName;
  final String userAvatarURL;
  final String time;
  final String type; // 'msg', 'online', 'redPacketStatus', etc.

  ChatMessage({
    required this.oId,
    required this.content,
    required this.userName,
    required this.userAvatarURL,
    required this.time,
    required this.type,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      oId: json['oId'] ?? '',
      content: json['content'] ?? '',
      userName: json['userName'] ?? '',
      userAvatarURL: json['userAvatarURL'] ?? '',
      time: json['time'] ?? '',
      type: json['type'] ?? 'msg',
    );
  }
}
