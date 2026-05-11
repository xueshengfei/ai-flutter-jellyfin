/// Jellyfin SDK 异常基类
class JellyfinException implements Exception {
  /// 错误消息
  final String message;

  /// 原始错误
  final Object? cause;

  /// 堆栈跟踪
  final StackTrace? stackTrace;

  const JellyfinException(
    this.message, {
    this.cause,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('JellyfinException: $message');
    if (cause != null) {
      buffer.writeln('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}
