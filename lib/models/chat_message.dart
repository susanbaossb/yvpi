import 'dart:convert';
import 'red_packet.dart';

/// 聊天室消息模型
///
/// 定义聊天室消息的数据结构，包含消息 ID、内容、发送者信息及时间戳。
class ChatMessage {
  final String oId;
  final String content;
  final String userName;
  final String userNickname;
  final String userAvatarURL;
  final String time;
  final String type; // 'msg', 'online', 'redPacketStatus', 'redPacket' etc.
  final RedPacket? redPacket;

  ChatMessage({
    required this.oId,
    required this.content,
    required this.userName,
    this.userNickname = '',
    required this.userAvatarURL,
    required this.time,
    required this.type,
    this.redPacket,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    var type = json['type'] ?? 'msg';
    RedPacket? redPacket;

    if (type == 'redPacket') {
      try {
        final contentStr = json['content'] as String;
        final contentJson = jsonDecode(contentStr);
        redPacket = RedPacket.fromJson(contentJson);
      } catch (e) {
        // Parse error, ignore redPacket data
        print('Error parsing red packet: $e');
      }
    } else if (type == 'msg') {
      // Try to detect if it's a red packet sent as 'msg'
      try {
        final contentStr = json['content'] as String;
        if (contentStr.trim().startsWith('{')) {
          final contentJson = jsonDecode(contentStr);
          if (contentJson is Map<String, dynamic> &&
              contentJson.containsKey('money') &&
              contentJson.containsKey('type') &&
              [
                'random',
                'average',
                'specify',
                'heartbeat',
                'rockPaperScissors',
              ].contains(contentJson['type'])) {
            redPacket = RedPacket.fromJson(contentJson);
            type = 'redPacket'; // Override type to render as red packet
          }
        }
      } catch (_) {
        // Not a red packet or json decode error
      }
    }

    return ChatMessage(
      oId: json['oId'] ?? '',
      content: json['content'] ?? '',
      userName: json['userName'] ?? '',
      userNickname: json['userNickname'] ?? '',
      userAvatarURL: json['userAvatarURL'] ?? '',
      time: json['time'] ?? '',
      type: type,
      redPacket: redPacket,
    );
  }
}
