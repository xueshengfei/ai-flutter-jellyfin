/// SDK 基础异常
sealed class RVCError implements Exception {
  final String message;
  const RVCError(this.message);

  @override
  String toString() => 'RVCError: $message';
}

/// 网络连接失败
final class RVCConnectionError extends RVCError {
  const RVCConnectionError(super.message);
}

/// 服务端返回 4xx / 5xx
final class RVCApiError extends RVCError {
  final int statusCode;
  const RVCApiError(this.statusCode, super.message);

  @override
  String toString() => 'RVCApiError [$statusCode]: $message';
}

/// 转换业务失败（服务端正常返回但标记失败）
final class RVCConvertError extends RVCError {
  const RVCConvertError(super.message);
}
