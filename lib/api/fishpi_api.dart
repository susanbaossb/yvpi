/// 摸鱼派 (FishPi) 核心 API 业务类
///
/// 封装了所有与后端交互的业务接口，包括：
/// - 用户认证 (登录, 获取用户信息)
/// - 内容获取 (文章列表, 文章详情, 清风明月, 聊天室)
/// - 交互操作 (点赞, 关注, 评论, 发送消息)
/// - 榜单数据 (签到榜, 在线榜)
import 'dart:convert';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/article.dart';
import '../models/article_detail.dart';
import '../models/breezemoon.dart';
import '../models/chat_message.dart';
import '../utils/exceptions.dart';
import '../utils/app_logger.dart';
import 'package:dio/dio.dart';
import 'client.dart';

class FishPiException extends BusinessException {
  @override
  final int code;
  final String msg;

  FishPiException(this.code, this.msg) : super(msg, code: code);

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
        throw FishPiException(
          response.data['code'] ?? -1,
          response.data['msg'] ?? 'Login failed',
        );
      }
    } catch (e, stack) {
      AppLogger().logError(e, stackTrace: stack, context: 'FishPiApi.login');
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
        throw FishPiException(
          response.data['code'] ?? -1,
          response.data['msg'] ?? 'Failed to get user info',
        );
      }
    } catch (e, stack) {
      AppLogger().logError(e, stackTrace: stack, context: 'FishPiApi.getUser');
      rethrow;
    }
  }

  // 获取指定用户信息
  Future<User?> getUserInfo(String username) async {
    try {
      final Response response = await _client.dio.get('/user/$username');
      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(response.data);

        // 如果 userCreateTime/userLatestLoginTime 是毫秒时间戳，转换为字符串
        if (data['userCreateTime'] is int) {
          data['userCreateTime'] = DateTime.fromMillisecondsSinceEpoch(
            data['userCreateTime'],
          ).toString().split('.')[0];
        }
        if (data['userLatestLoginTime'] is int) {
          data['userLatestLoginTime'] = DateTime.fromMillisecondsSinceEpoch(
            data['userLatestLoginTime'],
          ).toString().split('.')[0];
        }

        // 解析 allMetalOwned 字符串为 List
        if (data['allMetalOwned'] is String &&
            data['allMetalOwned'].isNotEmpty) {
          try {
            final metalJson = jsonDecode(data['allMetalOwned']);
            if (metalJson is Map && metalJson['list'] is List) {
              data['allMetalOwned'] = metalJson['list'];
            }
          } catch (e) {
            debugPrint('解析徽章数据失败: $e');
            data['allMetalOwned'] = null;
          }
        }

        return User.fromJson(data);
      } else if (response.data is Map && response.data['code'] != 0) {
        debugPrint('获取用户信息失败: ${response.data['msg']}');
      }
    } catch (e) {
      debugPrint('获取用户信息失败: $e');
    }
    return null;
  }

  // 获取用户文章列表
  Future<List<ArticleSummary>> getUserArticles(
    String username, {
    int page = 1,
    int size = 20,
  }) async {
    // 假设 API 为 /api/user/{username}/articles
    // 如果不正确，可能需要调整为 /api/articles?author=username
    // 根据 Sym 源码习惯，通常是 /api/user/{username}/articles
    try {
      return await _fetchArticles(
        '/api/user/$username/articles',
        page: page,
        size: size,
      );
    } catch (e) {
      // Fallback: try search/filter if specific endpoint doesn't exist?
      // For now, return empty or rethrow.
      debugPrint('Failed to get user articles: $e');
      return [];
    }
  }

  // 获取用户清风明月
  Future<List<BreezeMoon>> getUserBreezeMoons(
    String username, {
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _client.dio.get(
        '/api/user/$username/breezemoons',
        queryParameters: {'p': page, 'size': size},
      );
      if (response.data['code'] == 0) {
        final list = response.data['data']['breezemoons'] as List;
        return list.map((e) => BreezeMoon.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Failed to get user breezemoons: $e');
    }
    return [];
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

  // 通用获取文章列表方法
  Future<List<ArticleSummary>> _fetchArticles(
    String path, {
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _client.dio.get(
        path,
        queryParameters: {'p': page, 'size': size},
        options: Options(responseType: ResponseType.bytes),
      );

      final Uint8List bytes = response.data is Uint8List
          ? response.data
          : Uint8List.fromList(List<int>.from(response.data));
      final data = TransferableTypedData.fromList([bytes]);

      return await compute(_parseArticlesFromTransferable, data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('请先登录后查看文章列表');
      }
      rethrow;
    }
  }

  // 获取最新文章列表
  Future<List<ArticleSummary>> getRecentArticles({
    int page = 1,
    int size = 20,
  }) async {
    return _fetchArticles('/api/articles/recent', page: page, size: size);
  }

  // 获取热门文章列表
  Future<List<ArticleSummary>> getHotArticles({
    int page = 1,
    int size = 20,
  }) async {
    return _fetchArticles('/api/articles/recent/hot', page: page, size: size);
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
        throw FishPiException(
          response.data['code'] ?? -1,
          response.data['msg'] ?? '发送失败',
        );
      }
    } catch (e, stack) {
      AppLogger().logError(
        e,
        stackTrace: stack,
        context: 'FishPiApi.sendChatMessage',
      );
      rethrow;
    }
  }

  /// 发送红包
  ///
  /// [type] 红包类型: random(拼手气), average(平分), specify(专属), heartbeat(心跳), rockPaperScissors(猜拳)
  /// [money] 红包总积分 (平分红包为单个积分)
  /// [count] 红包个数
  /// [msg] 祝福语
  /// [receivers] 接收者列表 (专属红包有效)
  /// [gesture] 猜拳手势 (0:石头, 1:剪刀, 2:布)
  Future<void> sendRedPacket({
    required String type,
    required int money,
    required int count,
    String msg = '摸鱼者，事竟成！',
    List<String>? receivers,
    int? gesture,
  }) async {
    final Map<String, dynamic> packetData = {
      'msg': msg,
      'money': money,
      'count': count,
      'type': type,
    };

    if (receivers != null && receivers.isNotEmpty) {
      packetData['recivers'] = receivers;
    }

    if (type == 'rockPaperScissors' && gesture != null) {
      packetData['gesture'] = gesture;
    }

    final String content = '[redpacket]${jsonEncode(packetData)}[/redpacket]';
    return sendChatMessage(content);
  }

  // 获取聊天室历史消息
  Future<List<ChatMessage>> getChatRoomHistory({int page = 1}) async {
    try {
      final response = await _client.dio.get(
        '/chat-room/more',
        queryParameters: {'page': page},
      );
      final data = response.data;
      if (data is Map) {
        // 后端可能返回 {code, data: {msgs: []}} 或 {msgs: []}
        final root = data['data'] ?? data;
        final List msgs = root is Map
            ? (root['msgs'] ?? root['data'] ?? [])
            : (root ?? []);
        return msgs
            .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 发布清风明月
  Future<void> sendBreezeMoon(String content) async {
    try {
      final response = await _client.dio.post(
        '/breezemoon',
        data: {'breezemoonContent': content},
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

  // 打开聊天室红包
  Future<Map<String, dynamic>> openRedPacket(String oId) async {
    try {
      final response = await _client.dio.post(
        '/chat-room/red-packet/open',
        data: {'oId': oId},
      );
      // The API returns the data object directly without a wrapper code in some cases,
      // or we need to handle it flexibly.
      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data.containsKey('who') || data.containsKey('info')) {
          return data;
        }
        if (data['code'] != null && data['code'] != 0) {
          throw Exception(data['msg'] ?? '红包领取失败');
        }
        return data;
      }
      throw Exception('未知响应格式');
    } catch (e) {
      rethrow;
    }
  }

  // 用户名联想
  Future<List<Map<String, dynamic>>> suggestUsers(String name) async {
    try {
      final response = await _client.dio.post(
        '/users/names',
        data: {'name': name},
      );
      if (response.data['code'] == 0) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

// Top-level function for compute
List<ArticleSummary> _parseArticlesFromTransferable(
  TransferableTypedData transferableData,
) {
  try {
    final bytes = transferableData.materialize().asUint8List();
    if (bytes.isEmpty) return [];

    final jsonStr = utf8.decode(bytes);
    final json = jsonDecode(jsonStr);

    if (json is Map && json['code'] == 0) {
      final responseData = json['data'];
      List list = [];

      if (responseData is List) {
        list = responseData;
      } else if (responseData is Map && responseData['articles'] is List) {
        list = responseData['articles'];
      }

      return list.map((e) {
        final map = Map<String, dynamic>.from(e);

        // 映射 ID 字段
        if (map['id'] == null && map['oId'] != null) {
          map['id'] = map['oId'];
        }

        // 映射作者名称
        if (map['authorName'] == null && map['articleAuthorName'] != null) {
          map['authorName'] = map['articleAuthorName'];
        }

        // 映射头像 URL 并处理相对路径
        String? avatarUrl =
            map['articleAuthorThumbnailURL48'] ??
            map['articleAuthorThumbnailURL'] ??
            map['thumbnailURL'];

        if (avatarUrl != null) {
          if (!avatarUrl.startsWith('http')) {
            avatarUrl = 'https://fishpi.cn$avatarUrl';
          }
          map['thumbnailURL'] = avatarUrl;
        }

        // 补全热度显示（浏览量）
        if (map['articleViewCntDisplayFormat'] == null) {
          final viewCount = map['articleViewCount'] ?? map['viewCount'];
          if (viewCount != null) {
            final int views = viewCount is int
                ? viewCount
                : int.tryParse(viewCount.toString()) ?? 0;
            if (views >= 1000) {
              map['articleViewCntDisplayFormat'] =
                  '${(views / 1000).toStringAsFixed(1)}k';
            } else {
              map['articleViewCntDisplayFormat'] = views.toString();
            }
          }
        }

        // 优化：截断过长的预览内容，防止主线程反序列化大字符串时卡顿
        if (map['articlePreviewContent'] is String) {
          final String content = map['articlePreviewContent'];
          if (content.length > 200) {
            map['articlePreviewContent'] = '${content.substring(0, 200)}...';
          }
        }

        // 检查缩略图是否为过大的 Data URI
        if (map['thumbnailURL'] is String) {
          final String url = map['thumbnailURL'];
          if (url.startsWith('data:') && url.length > 500) {
            map['thumbnailURL'] = null; // 忽略过大的 Base64 图片
          }
        }

        return ArticleSummary.fromJson(map);
      }).toList();
    }
    throw Exception(
      json is Map
          ? (json['msg'] ?? 'Failed to load articles')
          : 'Unknown error',
    );
  } catch (e) {
    rethrow;
  }
}
