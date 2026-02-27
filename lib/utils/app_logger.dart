/// 应用程序日志工具
///
/// 负责记录全局异常、业务错误和网络请求错误到本地文件系统。
/// 符合规则：异常必须统一捕获并记录日志。
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'exceptions.dart';

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  File? _logFile;

  Future<void> init() async {
    if (_logFile != null) return;
    try {
      String logDirPath;
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        // 桌面端使用项目根目录下的 logs 文件夹
        logDirPath = '${Directory.current.path}/logs';
      } else {
        // Web 端或移动端使用应用文档目录
        final directory = await getApplicationDocumentsDirectory();
        logDirPath = '${directory.path}/logs';
      }

      final logDir = Directory(logDirPath);
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      _logFile = File('${logDir.path}/app_error.log');
    } catch (e) {
      debugPrint('Failed to initialize logger: $e');
    }
  }

  /// 记录错误到文件
  Future<void> logError(dynamic error, {StackTrace? stackTrace, String? context}) async {
    try {
      if (_logFile == null) await init();
      if (_logFile == null) return;

      final now = DateTime.now();
      final buffer = StringBuffer();
      buffer.writeln('[$now] ${context != null ? "[$context] " : ""}----------------------------------------');

      if (error is AppException) {
        buffer.writeln('Type: ${error.runtimeType}');
        buffer.writeln('Message: ${error.message}');
        if (error is BusinessException) {
          buffer.writeln('Code: ${error.code}');
        }
        if (error.originalError != null) {
          buffer.writeln('Original Error: ${error.originalError}');
        }
      } else if (error is DioException) {
        buffer.writeln('Type: DioException');
        buffer.writeln('URL: ${error.requestOptions.uri}');
        buffer.writeln('Method: ${error.requestOptions.method}');
        buffer.writeln('Status Code: ${error.response?.statusCode}');
        buffer.writeln('Message: ${error.message}');
        if (error.response?.data != null) {
          buffer.writeln('Response Data: ${error.response?.data}');
        }
      } else {
        buffer.writeln('Type: ${error.runtimeType}');
        buffer.writeln('Error: $error');
      }

      if (stackTrace != null) {
        buffer.writeln('StackTrace:');
        buffer.writeln(stackTrace.toString());
      }
      buffer.writeln('----------------------------------------\n');

      await _logFile!.writeAsString(
        buffer.toString(),
        mode: FileMode.append,
        flush: true,
      );
      
      // 同时在调试模式下打印到控制台
      if (kDebugMode) {
        debugPrint(buffer.toString());
      }
    } catch (e) {
      debugPrint('Failed to write log: $e');
    }
  }

  Future<String> getLogs() async {
    try {
      if (_logFile == null) await init();
      if (_logFile != null && await _logFile!.exists()) {
        return await _logFile!.readAsString();
      }
    } catch (e) {
      debugPrint('Failed to read logs: $e');
    }
    return '';
  }

  Future<void> clearLogs() async {
    try {
      if (_logFile == null) await init();
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.writeAsString('');
      }
    } catch (e) {
      debugPrint('Failed to clear logs: $e');
    }
  }
}
