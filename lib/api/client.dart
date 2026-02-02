/// API 客户端配置类
///
/// 封装 Dio 实例，处理基础 HTTP 配置（BaseURL, User-Agent, Cookie），
/// 提供单例访问模式，并包含请求拦截器以自动附加 apiKey。
import 'package:dio/dio.dart';
import '../utils/constants.dart';
import '../utils/api_logger.dart';

class ApiClient {
  late final Dio _dio;
  String? _apiKey;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'User-Agent': AppConstants.userAgent,
          'Accept': 'application/json, text/plain, */*',
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': 'https://fishpi.cn/',
          'Origin': 'https://fishpi.cn',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final skip = options.extra['skipApiKey'] == true;
          if (_apiKey != null && !skip) {
            options.queryParameters['apiKey'] = _apiKey;
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Log error to file
          ApiLogger().logError(e, stackTrace: e.stackTrace);
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;

  void setApiKey(String? apiKey) {
    _apiKey = apiKey;
  }
}
