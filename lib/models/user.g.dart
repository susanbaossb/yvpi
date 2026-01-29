// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  oId: json['oId'] as String,
  userName: json['userName'] as String,
  userNickname: json['userNickname'] as String,
  userAvatarURL: json['userAvatarURL'] as String,
  userRole: json['userRole'] as String,
  userIntro: json['userIntro'] as String?,
  userPoint: _stringToInt(json['userPoint']),
  userCity: json['userCity'] as String?,
  userOnlineFlag: json['userOnlineFlag'] as bool?,
  cardBg: json['cardBg'] as String?,
  userNo: _stringToInt(json['userNo']),
  canFollow: json['canFollow'] as String?,
  followingUserCount: _stringToInt(json['followingUserCount']),
  onlineMinute: _stringToInt(json['onlineMinute']),
  userURL: json['userURL'] as String?,
  userAppRole: _stringToInt(json['userAppRole']),
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'oId': instance.oId,
  'userName': instance.userName,
  'userNickname': instance.userNickname,
  'userAvatarURL': instance.userAvatarURL,
  'userRole': instance.userRole,
  'userIntro': instance.userIntro,
  'userPoint': instance.userPoint,
  'userCity': instance.userCity,
  'userOnlineFlag': instance.userOnlineFlag,
  'cardBg': instance.cardBg,
  'userNo': instance.userNo,
  'canFollow': instance.canFollow,
  'followingUserCount': instance.followingUserCount,
  'onlineMinute': instance.onlineMinute,
  'userURL': instance.userURL,
  'userAppRole': instance.userAppRole,
};
