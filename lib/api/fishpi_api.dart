/// 摸鱼派 (FishPi) 核心 API 业务类
///
/// 封装了所有与后端交互的业务接口，包括：
/// - 用户认证 (登录, 获取用户信息)
/// - 内容获取 (文章列表, 文章详情, 清风明月, 聊天室)
/// - 交互操作 (点赞, 关注, 评论, 发送消息)
/// - 榜单数据 (签到榜, 在线榜)
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/user.dart';
import '../models/article.dart';
import '../models/article_detail.dart';
import '../models/breezemoon.dart';
import 'package:dio/dio.dart';
import 'client.dart';

class FishPiException implements Exception {
  final int code;
  final String msg;

  FishPiException(this.code, this.msg);

  @override
  String toString() => 'FishPiException: code=$code, msg=$msg';
}

class FishPiApi {
  final ApiClient _client;

  FishPiApi(this._client);

  // 登录获取 apiKey
  Future<String> login(
    String nameOrEmail,
    String password, {
    String? mfaCode,
  }) async {
    final hashedPassword = md5.convert(utf8.encode(password)).toString();

    final data = {
      'nameOrEmail': nameOrEmail,
      'userPassword': hashedPassword,
      if (mfaCode != null && mfaCode.isNotEmpty) 'mfaCode': mfaCode,
    };

    try {
      final Response response = await _client.dio.post(
        '/api/getKey',
        data: data,
      );

      if (response.data['code'] == 0) {
        return response.data['Key'];
      } else {
        throw Exception(response.data['msg'] ?? 'Login failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 获取当前登录用户信息
  Future<User> getUser() async {
    try {
      final Response response = await _client.dio.get('/api/user');

      if (response.data['code'] == 0) {
        return User.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['msg'] ?? 'Failed to get user info');
      }
    } catch (e) {
      // print('getUser error: $e');
      rethrow;
    }
  }

  // 获取指定用户信息
  Future<User?> getUserInfo(String username) async {
    try {
      final Response response = await _client.dio.get('/user/$username');
      if (response.statusCode == 200) {
        return User.fromJson(response.data);
      }
    } catch (e) {
      // print('Failed to get user info for $username: $e');
    }
    return null;
  }

  // 关注用户
  Future<void> followUser(String followingId) async {
    try {
      final Response response = await _client.dio.post(
        '/follow/user',
        data: {'followingId': followingId},
      );
      if (response.data is Map && response.data['code'] != 0) {
        throw Exception(response.data['msg'] ?? '关注失败');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 取消关注用户
  Future<void> unfollowUser(String followingId) async {
    try {
      final Response response = await _client.dio.post(
        '/unfollow/user',
        data: {'followingId': followingId},
      );
      if (response.data is Map && response.data['code'] != 0) {
        throw Exception(response.data['msg'] ?? '取消关注失败');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 获取用户常用表情
  Future<List<String>> getUserEmotions() async {
    try {
      final Response response = await _client.dio.get('/users/emotions');
      if (response.data is Map && response.data['code'] == 0) {
        final data = response.data['data'];
        if (data is List) {
          final List<String> emojis = [];
          for (final item in data) {
            if (item is Map && item.isNotEmpty) {
              final value = item.values.first?.toString();
              if (value != null && value.isNotEmpty) {
                emojis.add(value);
              } else {
                final key = item.keys.first?.toString();
                if (key != null && key.isNotEmpty) {
                  // 部分表情（如 trollface）返回空值，需要拼接默认图片地址
                  emojis.add('https://file.fishpi.cn/emoji/graphics/$key.png');
                }
              }
            }
          }
          return emojis;
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 上传文件
  Future<String> upload(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file[]': await MultipartFile.fromFile(filePath),
      });

      final response = await _client.dio.post('/upload', data: formData);

      if (response.data is Map && response.data['code'] == 0) {
        final data = response.data['data'];
        if (data != null && data['succMap'] != null) {
          final succMap = data['succMap'] as Map;
          if (succMap.isNotEmpty) {
            return succMap.values.first.toString();
          }
        }
      }
      throw Exception(response.data['msg'] ?? '上传失败');
    } catch (e) {
      rethrow;
    }
  }

  // 获取最新文章列表
  Future<List<ArticleSummary>> getRecentArticles({
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _client.dio.get(
        '/api/articles/recent',
        queryParameters: {'p': page, 'size': size},
      );
      if (response.data is Map && response.data['code'] == 0) {
        final data = response.data['data'];
        final List list = data is Map ? (data['articles'] ?? []) : (data ?? []);
        return list
            .map((e) => ArticleSummary.fromJson(_normalizeArticleJson(e)))
            .toList();
      }
      throw Exception(response.data['msg'] ?? 'Failed to load recent articles');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('请先登录后查看文章列表');
      }
      rethrow;
    }
  }

  // 获取热门文章列表
  Future<List<ArticleSummary>> getHotArticles({
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _client.dio.get(
        '/api/articles/recent/hot',
        queryParameters: {'p': page, 'size': size},
      );
      if (response.data is Map && response.data['code'] == 0) {
        final data = response.data['data'];
        final List list = data is Map ? (data['articles'] ?? []) : (data ?? []);
        return list
            .map((e) => ArticleSummary.fromJson(_normalizeArticleJson(e)))
            .toList();
      }
      throw Exception(response.data['msg'] ?? 'Failed to load hot articles');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('请先登录后查看文章列表');
      }
      rethrow;
    }
  }

  Map<String, dynamic> _normalizeArticleJson(Map<String, dynamic> json) {
    return {
      'id': json['oId']?.toString() ?? json['id']?.toString(),
      'articleTitle': json['articleTitle'] ?? json['title'] ?? '',
      'articlePreviewContent':
          json['articlePreviewContent'] ?? json['content'] ?? '',
      'authorName':
          json['articleAuthorName'] ??
          json['articleAuthor']?['userName'] ??
          json['authorName'],
      'thumbnailURL':
          json['articleAuthorThumbnailURL48'] ??
          json['articleAuthor']?['thumbnailURL'] ??
          json['thumbnailURL'],
      'articleCommentCount':
          json['articleCommentCount'] ?? json['comments'] ?? 0,
      'articleViewCntDisplayFormat':
          json['articleViewCntDisplayFormat'] ??
          json['articleViewCount']?.toString(),
    };
  }

  // 获取文章详情
  Future<ArticleDetail> getArticleDetail(String articleId) async {
    try {
      final response = await _client.dio.get('/api/article/$articleId');
      if (response.data['code'] == 0) {
        return ArticleDetail.fromJson(response.data['data']);
      }
      throw Exception(response.data['msg'] ?? 'Failed to load article detail');
    } catch (e) {
      // print('getArticleDetail error: $e');
      rethrow;
    }
  }

  // 获取模拟签到排行榜数据
  Future<List<Map<String, dynamic>>> getMockCheckinRank() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      {'userName': 'csfwff', 'days': 1612},
      {'userName': 'Yui', 'days': 1532},
      {'userName': 'iwpz', 'days': 1355},
      {'userName': '18', 'days': 1288},
    ];
  }

  // 获取模拟在线时长排行榜数据
  Future<List<Map<String, dynamic>>> getMockOnlineRank() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      {'userName': 'KevinPeng', 'minutes': 1282353},
      {'userName': 'wuang', 'minutes': 841346},
      {'userName': 'baba22222', 'minutes': 838966},
      {'userName': 'moyupi', 'minutes': 830556},
    ];
  }

  // 获取用户活跃度
  Future<double> getLiveness() async {
    try {
      final response = await _client.dio.get('/user/liveness');

      // Handle various possible response structures
      if (response.data['liveness'] != null) {
        return (response.data['liveness'] as num).toDouble();
      }
      return 0.0;
    } catch (e) {
      // Silence 500 errors or typical auth errors to avoid console noise
      if (e is DioException && e.response?.statusCode == 500) {
        // Server error (often happens if not logged in or server issue), just return 0
        return 0.0;
      }
      // print('getLiveness error: $e');
      return 0.0;
    }
  }

  // 领取昨日活跃度奖励
  // 返回值：
  // -1: 已领取
  // 0: 无奖励可领取
  // > 0: 成功领取的奖励金额
  Future<int> collectYesterdayReward() async {
    try {
      final response = await _client.dio.get(
        '/activity/yesterday-liveness-reward-api',
      );

      final data = response.data;
      if (data is Map && data.containsKey('sum')) {
        return (data['sum'] as num).toInt();
      }

      throw Exception('领取失败：未知响应格式');
    } catch (e) {
      rethrow;
    }
  }

  // 获取清风明月（BreezeMoon）列表
  Future<List<BreezeMoon>> getBreezeMoons({int page = 1, int size = 20}) async {
    try {
      final response = await _client.dio.get(
        '/api/breezemoons',
        queryParameters: {'p': page, 'size': size},
      );
      if (response.data['code'] == 0) {
        final List list = response.data['breezemoons'] ?? [];
        return list.map((e) => BreezeMoon.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      // print('getBreezeMoons error: $e');
      return [];
    }
  }

  // 获取聊天室节点地址
  Future<String?> getChatRoomNode() async {
    try {
      final Response response = await _client.dio.get('/chat-room/node/get');
      if (response.data['code'] == 0) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      // print('getChatRoomNode error: $e');
      return null;
    }
  }

  // 发送聊天室消息
  Future<void> sendChatMessage(String content) async {
    try {
      final response = await _client.dio.post(
        '/chat-room/send',
        data: {'content': content},
      );
      if (response.data['code'] != 0) {
        throw Exception(response.data['msg'] ?? '发送失败');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 发布清风明月
  Future<void> sendBreezeMoon(String content) async {
    try {
      final response = await _client.dio.post(
        '/api/breezemoon',
        data: {'content': content},
      );
      if (response.data['code'] != 0) {
        throw Exception(response.data['msg'] ?? '发布失败');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 获取文章评论列表
  Future<List<ArticleComment>> getArticleComments(
    String articleId, {
    int page = 1,
  }) async {
    try {
      final response = await _client.dio.get(
        '/api/comment/$articleId',
        queryParameters: {'p': page},
      );
      if (response.data['code'] == 0) {
        final data = response.data['data'];
        List list = [];
        if (data is List) {
          list = data;
        } else if (data is Map) {
          // Combine nice comments and regular comments
          final niceComments = data['articleNiceComments'] as List? ?? [];
          final comments = data['articleComments'] as List? ?? [];
          // Also check for 'comments' key as fallback
          final legacyComments = data['comments'] as List? ?? [];

          list = [...niceComments, ...comments, ...legacyComments];
        }
        return list.map((e) => ArticleComment.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      // print('getArticleComments error: $e');
      return [];
    }
  }

  // 发布或回复评论
  Future<void> postComment({
    required String articleId,
    required String content,
    String? originalCommentId,
    bool visibleToUser = false,
  }) async {
    try {
      final data = {
        'articleId': articleId,
        'commentContent': content,
        if (visibleToUser) 'commentVisibleToUser': true,
      };

      Response response;
      if (originalCommentId != null && originalCommentId.isNotEmpty) {
        // User instruction: 如果是回复评论调用PUT /comment/{评论oId}
        response = await _client.dio.put(
          '/comment/$originalCommentId',
          data: data,
        );
      } else {
        // User instruction: 如果是直接评论调用POST /comment
        response = await _client.dio.post('/comment', data: data);
      }

      if (response.data['code'] != 0) {
        throw FishPiException(
          response.data['code'],
          response.data['msg'] ?? '回复失败',
        );
      }
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        final data = e.response!.data;
        if (data['code'] != null) {
          throw FishPiException(data['code'], data['msg'] ?? '请求失败');
        }
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // 点赞/取消点赞文章
  // 返回: 0: 已取消点赞, -1: 点赞成功
  Future<int> voteArticle(String articleId) async {
    try {
      final response = await _client.dio.post(
        '/vote/up/article',
        data: {'dataId': articleId},
      );
      if (response.data['code'] == 0) {
        return response.data['type'];
      }
      throw Exception(response.data['msg'] ?? '操作失败');
    } catch (e) {
      rethrow;
    }
  }

  // 感谢文章
  Future<void> rewardArticle(String articleId) async {
    try {
      final response = await _client.dio.post(
        '/article/thank',
        queryParameters: {'articleId': articleId},
      );
      if (response.data['code'] != 0) {
        throw Exception(response.data['msg'] ?? '感谢失败');
      }
    } catch (e) {
      rethrow;
    }
  }
}
