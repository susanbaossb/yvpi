import 'package:json_annotation/json_annotation.dart';

part 'article.g.dart';

@JsonSerializable()
class ArticleSummary {
  final String? id;
  final String articleTitle;
  final String? articlePreviewContent;
  final String? authorName;
  final String? thumbnailURL;
  final int? articleCommentCount;

  ArticleSummary({
    this.id,
    required this.articleTitle,
    this.articlePreviewContent,
    this.authorName,
    this.thumbnailURL,
    this.articleCommentCount,
  });

  factory ArticleSummary.fromJson(Map<String, dynamic> json) =>
      _$ArticleSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$ArticleSummaryToJson(this);
}
