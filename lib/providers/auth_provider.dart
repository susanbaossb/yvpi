/// 认证状态管理 Provider
///
/// 管理全局用户认证状态，包括：
/// - 用户登录/登出逻辑
/// - 存储和更新当前用户信息 (User)
/// - 持久化存储 apiKey
/// - 提供 FishPiApi 实例供全局调用
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/fishpi_api.dart';
import '../api/client.dart';
import '../models/user.dart';
import '../utils/constants.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  late final FishPiApi _fishPiApi;

  User? _user;
  String? _apiKey;
  bool _isLoading = false;
  bool _isInitialized = false;

  User? get user => _user;
  String? get apiKey => _apiKey;
  bool get isLoggedIn => _apiKey != null;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  FishPiApi get api => _fishPiApi;

  AuthProvider() : _apiClient = ApiClient() {
    _fishPiApi = FishPiApi(_apiClient);
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    debugPrint('AuthProvider: _loadApiKey start ${DateTime.now()}');
    final stopwatch = Stopwatch()..start();
    final prefs = await SharedPreferences.getInstance();
    debugPrint(
      'AuthProvider: SharedPreferences loaded in ${stopwatch.elapsedMilliseconds}ms',
    );
    _apiKey = prefs.getString(AppConstants.apiKey);
    if (_apiKey != null) {
      debugPrint('AuthProvider: apiKey found, refreshing user...');
      _apiClient.setApiKey(_apiKey);
      // Notify listeners immediately so the app redirects to Home without waiting for the network call
      _isInitialized = true;
      notifyListeners();
      await refreshUser();
    } else {
      debugPrint('AuthProvider: apiKey not found');
      // If we want to ensure the app knows initialization is done (even if no login), we might want to signal that.
      // But _isLoading is for login action.
      _isInitialized = true;
      notifyListeners();
    }
    debugPrint(
      'AuthProvider: _loadApiKey done in ${stopwatch.elapsedMilliseconds}ms',
    );
  }

  Future<void> login(
    String username,
    String password, {
    String? mfaCode,
    bool rememberMe = true,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final key = await _fishPiApi.login(username, password, mfaCode: mfaCode);
      _apiKey = key;
      _apiClient.setApiKey(key);
      if (rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.apiKey, key);
      }
      await refreshUser();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUser() async {
    debugPrint('AuthProvider: refreshUser start ${DateTime.now()}');
    final stopwatch = Stopwatch()..start();
    try {
      _user = await _fishPiApi.getUser();
      debugPrint(
        'AuthProvider: getUser done in ${stopwatch.elapsedMilliseconds}ms',
      );
      notifyListeners();
    } catch (e) {
      // If token is invalid, maybe logout?
      debugPrint('Error fetching user: $e');
    }
  }

  Future<void> logout() async {
    _apiKey = null;
    _user = null;
    _apiClient.setApiKey(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.apiKey);
    notifyListeners();
  }
}
