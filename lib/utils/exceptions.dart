/// 异常体系定义
///
/// 根据规则要求，区分业务异常、逻辑异常和错误异常。

/// 基础异常类
abstract class AppException implements Exception {
  final String message;
  final dynamic originalError;

  AppException(this.message, {this.originalError});

  @override
  String toString() => '$runtimeType: $message';
}

/// 业务异常 (Business Exception)
///
/// 例如：登录失败、积分不足、接口返回 code != 0 等。
class BusinessException extends AppException {
  final int code;
  BusinessException(super.message, {this.code = -1, super.originalError});
}

/// 逻辑异常 (Logic Exception)
///
/// 例如：非法的参数输入、未预期的状态机转换等。
class LogicException extends AppException {
  LogicException(super.message, {super.originalError});
}

/// 错误异常 (Error Exception)
///
/// 例如：网络连接超时、文件读写失败、系统级崩溃等。
class ErrorException extends AppException {
  ErrorException(super.message, {super.originalError});
}
