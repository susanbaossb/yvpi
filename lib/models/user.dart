/// 用户信息模型
///
/// 定义用户的基本资料（用户名、昵称、头像）及扩展属性（角色、积分、是否可关注、在线状态等）。
/// 包含 json_serializable 生成的序列化代码。
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

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
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}

int? _stringToInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) {
    if (value.isEmpty) return null;
    return int.tryParse(value);
  }
  return null;
}
