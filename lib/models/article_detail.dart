class ArticleDetail {
  final String id;
  final String title;
  final String content;
  final String authorName;
  final String authorAvatar;
  final String timeAgo;
  final List<String> tags;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int collectCount;
  final List<ArticleComment> comments;

  ArticleDetail({
    required this.id,
    required this.title,
    required this.content,
    required this.authorName,
    required this.authorAvatar,
    required this.timeAgo,
    required this.tags,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.collectCount,
    required this.comments,
  });

  factory ArticleDetail.fromJson(Map<String, dynamic> json) {
    final article = json['article'] ?? {};
    final commentsList = json['comments'] as List? ?? [];

    return ArticleDetail(
      id: article['oId'] ?? '',
      title: article['articleTitle'] ?? '',
      content: article['articleContent'] ?? '',
      authorName: article['articleAuthorName'] ?? '',
      authorAvatar: article['articleAuthorThumbnailURL48'] ?? '',
      timeAgo:
          article['timeAgo'] ??
          '', // API often provides formatted time or we parse timestamp
      tags: (article['articleTags'] as String?)?.split(',') ?? [],
      viewCount: article['articleViewCount'] ?? 0,
      likeCount: article['articleGoodCnt'] ?? 0,
      commentCount: article['articleCommentCount'] ?? 0,
      collectCount: article['articleCollectCnt'] ?? 0,
      comments: commentsList.map((e) => ArticleComment.fromJson(e)).toList(),
    );
  }
}

class ArticleComment {
  final String id;
  final String content;
  final String authorName;
  final String authorAvatar;
  final String timeAgo;
  final String originalCommentId;
  final DateTime? created;
  List<ArticleComment> replies;

  ArticleComment({
    required this.id,
    required this.content,
    required this.authorName,
    required this.authorAvatar,
    required this.timeAgo,
    this.originalCommentId = '',
    this.created,
    this.replies = const [],
  });

  factory ArticleComment.fromJson(Map<String, dynamic> json) {
    final commenter = json['commenter'] ?? {};
    DateTime? createdTime;
    if (json['commentCreateTimeStr'] != null) {
      try {
        createdTime = DateTime.parse(json['commentCreateTimeStr']);
      } catch (e) {
        // ignore date parse error
      }
    }

    return ArticleComment(
      id: json['oId'] ?? '',
      content: json['commentContent'] ?? '',
      authorName:
          json['commentAuthorName'] ?? commenter['userNickname'] ?? 'Unknown',
      authorAvatar:
          json['commentAuthorThumbnailURL'] ?? commenter['userAvatarURL'] ?? '',
      timeAgo: json['timeAgo'] ?? '',
      originalCommentId: json['commentOriginalCommentId'] ?? '',
      created: createdTime,
      replies: [], // Initialize as empty mutable list
    );
  }
}
