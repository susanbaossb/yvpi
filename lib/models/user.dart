/// 用户信息模型
///
/// 定义用户的基本资料（用户名、昵称、头像）及扩展属性（角色、积分、是否可关注、在线状态等）。
/// 包含 json_serializable 生成的序列化代码。
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class UserBadge {
  final String? data;
  final String name;
  final String? description;
  final String? expireDate;
  final String id;
  final String attr; // "url=...&backcolor=...&fontcolor=..."
  final String? type;
  final bool enabled;
  final int order;

  UserBadge({
    this.data,
    required this.name,
    this.description,
    this.expireDate,
    required this.id,
    required this.attr,
    this.type,
    required this.enabled,
    required this.order,
  });

  factory UserBadge.fromJson(Map<String, dynamic> json) =>
      _$UserBadgeFromJson(json);
  Map<String, dynamic> toJson() => _$UserBadgeToJson(this);

  // 解析 attr 中的图片 URL
  String? get imageUrl {
    final params = attr.split('&');
    for (final p in params) {
      if (p.startsWith('url=')) {
        return p.substring(4);
      }
    }
    return null;
  }

  // 解析 attr 中的背景颜色
  Color? get backgroundColor {
    final params = attr.split('&');
    for (final p in params) {
      if (p.startsWith('backcolor=')) {
        final colorStr = p.substring(10);
        return Color(int.parse('FF$colorStr', radix: 16));
      }
    }
    return null;
  }

  // 解析 attr 中的文字颜色
  Color? get fontColor {
    final params = attr.split('&');
    for (final p in params) {
      if (p.startsWith('fontcolor=')) {
        final colorStr = p.substring(10);
        return Color(int.parse('FF$colorStr', radix: 16));
      }
    }
    return null;
  }
}

@JsonSerializable()
class User {
  final String oId;
  final String userName;
  final String userNickname;
  final String userAvatarURL;
  final String userRole;
  final String? userIntro;
  @JsonKey(fromJson: _stringToInt)
  final int? userPoint;
  final String? userCity;
  final bool? userOnlineFlag;
  final String? cardBg;
  @JsonKey(fromJson: _stringToInt)
  final int? userNo;
  final String? canFollow; // no/yes/hide
  @JsonKey(fromJson: _stringToInt)
  final int? followingUserCount;
  @JsonKey(fromJson: _stringToInt)
  final int? onlineMinute;
  final String? userURL;
  @JsonKey(fromJson: _stringToInt)
  final int? userAppRole;
  final String? userCreateTime;
  final String? userLatestLoginTime;
  @JsonKey(name: 'userLongestCheckinStreak', fromJson: _stringToInt)
  final int? userLongestCheckinStreak;
  @JsonKey(name: 'userCurrentCheckinStreak', fromJson: _stringToInt)
  final int? userCurrentCheckinStreak;
  @JsonKey(name: 'userArticleCount', fromJson: _stringToInt)
  final int? userArticleCount;
  @JsonKey(name: 'userCommentCount', fromJson: _stringToInt)
  final int? userCommentCount;
  @JsonKey(name: 'userTagCount', fromJson: _stringToInt)
  final int? userTagCount;
  @JsonKey(name: 'userFollowerCount', fromJson: _stringToInt)
  final int? userFollowerCount;
  final List<UserBadge>? allMetalOwned;

  User({
    required this.oId,
    required this.userName,
    required this.userNickname,
    required this.userAvatarURL,
    required this.userRole,
    this.userIntro,
    this.userPoint,
    this.userCity,
    this.userOnlineFlag,
    this.cardBg,
    this.userNo,
    this.canFollow,
    this.followingUserCount,
    this.onlineMinute,
    this.userURL,
    this.userAppRole,
    this.userCreateTime,
    this.userLatestLoginTime,
    this.userLongestCheckinStreak,
    this.userCurrentCheckinStreak,
    this.userArticleCount,
    this.userCommentCount,
    this.userTagCount,
    this.userFollowerCount,
    this.allMetalOwned,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}

int? _stringToInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final s = value.trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    final i = int.tryParse(s);
    if (i != null) return i;
    final d = double.tryParse(s);
    if (d != null) return d.toInt();
  }
  return null;
}
