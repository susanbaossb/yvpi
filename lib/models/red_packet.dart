import 'dart:convert';

/// 红包类型枚举
///
/// 定义了支持的各种红包类型，如拼手气红包、平分红包、专属红包等。
enum RedPacketType {
  random, // 拼手气红包
  average, // 平分红包
  specify, // 专属红包
  heartbeat, // 心跳红包
  rockPaperScissors, // 猜拳红包
  unknown,
}

/// 红包信息模型
///
/// 包含红包的类型、总金额、个数、发送者、接收者、领取状态等详细信息。
class RedPacket {
  final String msg;
  final String senderId;
  final int money;
  final int count;
  final RedPacketType type;
  final int got;
  final List<dynamic> who;
  final List<dynamic> receivers;

  RedPacket({
    required this.msg,
    required this.senderId,
    required this.money,
    required this.count,
    required this.type,
    required this.got,
    required this.who,
    required this.receivers,
  });

  factory RedPacket.fromJson(Map<String, dynamic> json) {
    return RedPacket(
      msg: json['msg'] ?? '',
      senderId: json['senderId'] ?? '',
      money: json['money'] ?? 0,
      count: json['count'] ?? 0,
      type: _parseType(json['type']),
      got: json['got'] ?? 0,
      who: json['who'] ?? [],
      receivers: _parseReceivers(json['recivers']),
    );
  }

  static RedPacketType _parseType(String? type) {
    switch (type) {
      case 'random':
        return RedPacketType.random;
      case 'average':
        return RedPacketType.average;
      case 'specify':
        return RedPacketType.specify;
      case 'heartbeat':
        return RedPacketType.heartbeat;
      case 'rockPaperScissors':
        return RedPacketType.rockPaperScissors;
      default:
        return RedPacketType.unknown;
    }
  }

  static List<dynamic> _parseReceivers(dynamic receivers) {
    if (receivers == null) return [];
    if (receivers is String) {
      try {
        return jsonDecode(receivers);
      } catch (e) {
        return [];
      }
    }
    if (receivers is List) {
      return receivers;
    }
    return [];
  }

  String get typeName {
    switch (type) {
      case RedPacketType.random:
        return '拼手气红包';
      case RedPacketType.average:
        return '平分红包';
      case RedPacketType.specify:
        return '专属红包';
      case RedPacketType.heartbeat:
        return '心跳红包';
      case RedPacketType.rockPaperScissors:
        return '猜拳红包';
      default:
        return '未知红包';
    }
  }
}
