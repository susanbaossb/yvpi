/// 文章详情模型
///
/// 用于文章详情页展示，包含文章完整 HTML 内容、
/// 作者详细信息、标签、浏览量、点赞数及评论列表等完整元数据。
class ArticleDetail {
  final String id;
  final String title;
  final String content;
  final String userNickname;
  final String userName;
  final String authorAvatar;
  final String timeAgo;
  final List<String> tags;
  final int viewCount;
  final int likeCount;
  final int badCount;
  final int watchCount;
  final int commentCount;
  final int collectCount;
  final int rewardCount;
  final bool isReward;
  final int voteStatus; // 0: None, -1: Liked (Bad/Hate might be other values)
  final List<ArticleComment> comments;
  final List<SimpleUser> rewardedUsers;
  final List<SimpleUser> participatingUsers;

  ArticleDetail({
    required this.id,
    required this.title,
    required this.content,
    required this.userNickname,
    required this.userName,
    required this.authorAvatar,
    required this.timeAgo,
    required this.tags,
    required this.viewCount,
    required this.likeCount,
    this.badCount = 0,
    this.watchCount = 0,
    required this.commentCount,
    required this.collectCount,
    this.rewardCount = 0,
    this.isReward = false,
    this.voteStatus = 0,
    required this.comments,
    this.rewardedUsers = const [],
    this.participatingUsers = const [],
  });

  factory ArticleDetail.fromJson(Map<String, dynamic> json) {
    final article = json['article'] ?? {};
    final commentsList = json['comments'] as List? ?? [];

    // Parse rewarded users if available (assuming key 'rewardedUsers')
    final rewards = json['rewardedUsers'] as List? ?? [];
    final participants = json['participants'] as List? ?? [];

    return ArticleDetail(
      id: article['oId'] ?? '',
      title: article['articleTitle'] ?? '',
      content: article['articleContent'] ?? '',
      userNickname: article['articleAuthorNickName'] ?? '',
      userName: article['articleAuthorName'] ?? '',
      authorAvatar: article['articleAuthorThumbnailURL48'] ?? '',
      timeAgo:
          article['timeAgo'] ??
          '', // API often provides formatted time or we parse timestamp
      tags: (article['articleTags'] as String?)?.split(',') ?? [],
      viewCount: article['articleViewCount'] ?? 0,
      likeCount: article['articleGoodCnt'] ?? 0,
      badCount: article['articleBadCnt'] ?? 0,
      watchCount: article['articleWatchCnt'] ?? 0,
      commentCount: article['articleCommentCount'] ?? 0,
      collectCount: article['articleCollectCnt'] ?? 0,
      rewardCount: article['articleThankCnt'] ?? 0,
      isReward: article['thanked'] ?? false,
      voteStatus: article['articleVote'] ?? 0,
      comments: commentsList.map((e) => ArticleComment.fromJson(e)).toList(),
      rewardedUsers: rewards.map((e) => SimpleUser.fromJson(e)).toList(),
      participatingUsers: participants
          .map((e) => SimpleUser.fromJson(e))
          .toList(),
    );
  }

  ArticleDetail copyWith({
    String? id,
    String? title,
    String? content,
    String? userNickname,
    String? userName,
    String? authorAvatar,
    String? timeAgo,
    List<String>? tags,
    int? viewCount,
    int? likeCount,
    int? badCount,
    int? watchCount,
    int? commentCount,
    int? collectCount,
    int? rewardCount,
    bool? isReward,
    int? voteStatus,
    List<ArticleComment>? comments,
    List<SimpleUser>? rewardedUsers,
    List<SimpleUser>? participatingUsers,
  }) {
    return ArticleDetail(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      userNickname: userNickname ?? this.userNickname,
      userName: userName ?? this.userName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      timeAgo: timeAgo ?? this.timeAgo,
      tags: tags ?? this.tags,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      badCount: badCount ?? this.badCount,
      watchCount: watchCount ?? this.watchCount,
      commentCount: commentCount ?? this.commentCount,
      collectCount: collectCount ?? this.collectCount,
      rewardCount: rewardCount ?? this.rewardCount,
      isReward: isReward ?? this.isReward,
      voteStatus: voteStatus ?? this.voteStatus,
      comments: comments ?? this.comments,
      rewardedUsers: rewardedUsers ?? this.rewardedUsers,
      participatingUsers: participatingUsers ?? this.participatingUsers,
    );
  }
}

class SimpleUser {
  final String name;
  final String avatar;
  final String userName;

  SimpleUser({
    required this.name,
    required this.avatar,
    required this.userName,
  });

  factory SimpleUser.fromJson(Map<String, dynamic> json) {
    return SimpleUser(
      name: json['userNickname'] ?? json['userName'] ?? '',
      avatar: json['userAvatarURL'] ?? '',
      userName: json['userName'] ?? '',
    );
  }
}

class ArticleComment {
  final String id;
  final String content;
  final String userNickname;
  final String userName;
  final String authorAvatar;
  final String timeAgo;
  final String originalCommentId;
  final DateTime? created;
  List<ArticleComment> replies;
  String?
  replyToUserNickname; // For UI: User nickname of the parent comment being replied to
  String?
  replyToContent; // For UI: Content of the parent comment being replied to

  ArticleComment({
    required this.id,
    required this.content,
    required this.userNickname,
    required this.userName,
    required this.authorAvatar,
    required this.timeAgo,
    this.originalCommentId = '',
    this.created,
    this.replies = const [],
    this.replyToUserNickname,
    this.replyToContent,
  });

  factory ArticleComment.fromJson(Map<String, dynamic> json) {
    final commenter = json['commenter'] ?? {};
    DateTime? createdTime;
    if (json['commentCreateTimeStr'] != null) {
      try {
        createdTime = DateTime.parse(json['commentCreateTimeStr']);
      } catch (e) {}
    }
    return ArticleComment(
      id: json['oId'] ?? '',
      content: json['commentContent'] ?? '',
      userNickname: commenter['userNickname'] ?? 'Unknown',
      userName: commenter['userName'] ?? '',
      authorAvatar:
          json['commentAuthorThumbnailURL'] ?? commenter['userAvatarURL'] ?? '',
      timeAgo: json['timeAgo'] ?? '',
      originalCommentId: json['commentOriginalCommentId'] ?? '',
      created: createdTime,
      replies: [],
    );
  }
}
