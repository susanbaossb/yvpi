/// 全局常量定义
///
/// 包含应用级常量配置，如：
/// - API 基础地址 (baseUrl)
/// - 默认 User-Agent
/// - 全局路由监听器 (routeObserver)
import 'package:flutter/material.dart';

class AppConstants {
  static const String baseUrl = 'https://fishpi.cn';
  static const String apiKey = 'apiKey'; // Key for SharedPreferences
  static const String userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();
