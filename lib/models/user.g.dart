// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserBadge _$UserBadgeFromJson(Map<String, dynamic> json) => UserBadge(
  data: json['data'] as String?,
  name: json['name'] as String,
  description: json['description'] as String?,
  expireDate: json['expireDate'] as String?,
  id: json['id'] as String,
  attr: json['attr'] as String,
  type: json['type'] as String?,
  enabled: json['enabled'] as bool,
  order: (json['order'] as num).toInt(),
);

Map<String, dynamic> _$UserBadgeToJson(UserBadge instance) => <String, dynamic>{
  'data': instance.data,
  'name': instance.name,
  'description': instance.description,
  'expireDate': instance.expireDate,
  'id': instance.id,
  'attr': instance.attr,
  'type': instance.type,
  'enabled': instance.enabled,
  'order': instance.order,
};

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
  userCreateTime: json['userCreateTime'] as String?,
  userLatestLoginTime: json['userLatestLoginTime'] as String?,
  userLongestCheckinStreak: _stringToInt(json['userLongestCheckinStreak']),
  userCurrentCheckinStreak: _stringToInt(json['userCurrentCheckinStreak']),
  userArticleCount: _stringToInt(json['userArticleCount']),
  userCommentCount: _stringToInt(json['userCommentCount']),
  userTagCount: _stringToInt(json['userTagCount']),
  userFollowerCount: _stringToInt(json['userFollowerCount']),
  allMetalOwned: (json['allMetalOwned'] as List<dynamic>?)
      ?.map((e) => UserBadge.fromJson(e as Map<String, dynamic>))
      .toList(),
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
  'userCreateTime': instance.userCreateTime,
  'userLatestLoginTime': instance.userLatestLoginTime,
  'userLongestCheckinStreak': instance.userLongestCheckinStreak,
  'userCurrentCheckinStreak': instance.userCurrentCheckinStreak,
  'userArticleCount': instance.userArticleCount,
  'userCommentCount': instance.userCommentCount,
  'userTagCount': instance.userTagCount,
  'userFollowerCount': instance.userFollowerCount,
  'allMetalOwned': instance.allMetalOwned,
};
