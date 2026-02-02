/// 清风明月 (BreezeMoon) 内容模型
///
/// 对应社区的“清风明月”板块（类似朋友圈/微博动态），
/// 包含内容文本、发布者信息、发布时间、来源及评论数。
class BreezeMoon {
  final String oId;
  final String content;
  final String authorName;
  final String authorAvatarURL;
  final String created;
  final String timeAgo;
  final String? city;

  BreezeMoon({
    required this.oId,
    required this.content,
    required this.authorName,
    required this.authorAvatarURL,
    required this.created,
    required this.timeAgo,
    this.city,
  });

  factory BreezeMoon.fromJson(Map<String, dynamic> json) {
    return BreezeMoon(
      oId: json['oId']?.toString() ?? '',
      content: json['breezemoonContent']?.toString() ?? '',
      authorName: json['breezemoonAuthorName']?.toString() ?? '',
      authorAvatarURL: json['breezemoonAuthorThumbnailURL48']?.toString() ?? '',
      created: json['breezemoonCreated']?.toString() ?? '',
      timeAgo: json['timeAgo']?.toString() ?? '',
      city: json['breezemoonCity']?.toString(),
    );
  }
}
