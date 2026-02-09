import 'package:json_annotation/json_annotation.dart';

part 'article.g.dart';

@JsonSerializable()
/// 文章摘要模型
///
/// 用于首页文章列表、热门文章列表等场景，
/// 包含文章 ID、标题、预览内容、作者信息、缩略图及评论数等简要信息。
class ArticleSummary {
  final String? id;
  final String articleTitle;
  final String? articlePreviewContent;
  final String? authorName;
  final String? thumbnailURL;
  final int? articleCommentCount;
  final String? articleViewCntDisplayFormat;
  final String? articleTags;
  final String? articleCreateTimeStr;

  ArticleSummary({
    this.id,
    required this.articleTitle,
    this.articlePreviewContent,
    this.authorName,
    this.thumbnailURL,
    this.articleCommentCount,
    this.articleViewCntDisplayFormat,
    this.articleTags,
    this.articleCreateTimeStr,
  });

  factory ArticleSummary.fromJson(Map<String, dynamic> json) =>
      _$ArticleSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$ArticleSummaryToJson(this);
}
