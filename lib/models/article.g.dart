// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'article.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ArticleSummary _$ArticleSummaryFromJson(Map<String, dynamic> json) =>
    ArticleSummary(
      id: json['id'] as String?,
      articleTitle: json['articleTitle'] as String,
      articlePreviewContent: json['articlePreviewContent'] as String?,
      authorName: json['authorName'] as String?,
      thumbnailURL: json['thumbnailURL'] as String?,
      articleCommentCount: (json['articleCommentCount'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ArticleSummaryToJson(ArticleSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'articleTitle': instance.articleTitle,
      'articlePreviewContent': instance.articlePreviewContent,
      'authorName': instance.authorName,
      'thumbnailURL': instance.thumbnailURL,
      'articleCommentCount': instance.articleCommentCount,
    };
