import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class ApiLogger {
  static final ApiLogger _instance = ApiLogger._internal();
  factory ApiLogger() => _instance;
  ApiLogger._internal();

  File? _logFile;

  Future<void> init() async {
    if (_logFile != null) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      _logFile = File('${logDir.path}/api_error.log');
    } catch (e) {
      print('Failed to initialize logger: $e');
    }
  }

  Future<void> logError(dynamic error, {StackTrace? stackTrace}) async {
    try {
      if (_logFile == null) await init();
      if (_logFile == null) return;

      final now = DateTime.now();
      final buffer = StringBuffer();
      buffer.writeln('[$now] ----------------------------------------');

      if (error is DioException) {
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
    } catch (e) {
      print('Failed to write log: $e');
    }
  }

  Future<String> getLogs() async {
    try {
      if (_logFile == null) await init();
      if (_logFile != null && await _logFile!.exists()) {
        return await _logFile!.readAsString();
      }
    } catch (e) {
      print('Failed to read logs: $e');
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
      print('Failed to clear logs: $e');
    }
  }
}
