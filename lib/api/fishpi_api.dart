import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/user.dart';
import '../models/article.dart';
import '../models/breezemoon.dart';
import 'package:dio/dio.dart';
import 'client.dart';

class FishPiApi {
  final ApiClient _client;

  FishPiApi(this._client);

  // Login to get apiKey
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

  // Get current user info
  Future<User> getUser() async {
    try {
      final Response response = await _client.dio.get('/api/user');

      if (response.data['code'] == 0) {
        return User.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['msg'] ?? 'Failed to get user info');
      }
    } catch (e) {
      print('getUser error: $e');
      rethrow;
    }
  }

  // Get specific user info (real implementation)
  Future<User?> getUserInfo(String username) async {
    try {
      final Response response = await _client.dio.get('/user/$username');
      if (response.statusCode == 200) {
        return User.fromJson(response.data);
      }
    } catch (e) {
      print('Failed to get user info for $username: $e');
    }
    return null;
  }

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
    };
  }

  Future<List<Map<String, dynamic>>> getMockCheckinRank() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      {'userName': 'csfwff', 'days': 1612},
      {'userName': 'Yui', 'days': 1532},
      {'userName': 'iwpz', 'days': 1355},
      {'userName': '18', 'days': 1288},
    ];
  }

  Future<List<Map<String, dynamic>>> getMockOnlineRank() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      {'userName': 'KevinPeng', 'minutes': 1282353},
      {'userName': 'wuang', 'minutes': 841346},
      {'userName': 'baba22222', 'minutes': 838966},
      {'userName': 'moyupi', 'minutes': 830556},
    ];
  }

  // Get user liveness
  Future<int> getLiveness() async {
    try {
      final response = await _client.dio.get('/user/liveness');
      if (response.data['code'] == 0) {
        // Handle various possible response structures
        if (response.data['liveness'] != null) {
          return (response.data['liveness'] as num).toInt();
        }
        if (response.data['data'] != null) {
          if (response.data['data'] is int) {
            return (response.data['data'] as num).toInt();
          }
          if (response.data['data'] is Map &&
              response.data['data']['liveness'] != null) {
            return (response.data['data']['liveness'] as num).toInt();
          }
        }
      }
      return 0;
    } catch (e) {
      // Silence 500 errors or typical auth errors to avoid console noise
      if (e is DioException && e.response?.statusCode == 500) {
        // Server error (often happens if not logged in or server issue), just return 0
        return 0;
      }
      print('getLiveness error: $e');
      return 0;
    }
  }

  // Collect yesterday's reward
  Future<String> collectYesterdayReward() async {
    try {
      final response = await _client.dio.get(
        '/activity/yesterday-liveness-reward-api',
      );

      final data = response.data;
      if (data is Map && data.containsKey('sum')) {
        final sum = data['sum'];
        if (sum == -1) {
          return '今天已经领取过积分';
        }
        if (sum > 0) {
          return '领取成功，获得 $sum 积分';
        }
        return '暂无奖励可领取';
      }

      throw Exception('领取失败：未知响应格式');
    } catch (e) {
      rethrow;
    }
  }

  // Get BreezeMoon list
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
      print('getBreezeMoons error: $e');
      return [];
    }
  }

  // Get chat room node address
  Future<String?> getChatRoomNode() async {
    try {
      final Response response = await _client.dio.get('/chat-room/node/get');
      if (response.data['code'] == 0) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      print('getChatRoomNode error: $e');
      return null;
    }
  }

  // Send chat message
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
}
