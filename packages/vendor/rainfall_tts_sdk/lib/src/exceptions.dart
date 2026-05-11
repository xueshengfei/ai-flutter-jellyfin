/// SDK 基础异常
base class RainfallTTSError implements Exception {
  final String message;
  RainfallTTSError(this.message);

  @override
  String toString() => 'RainfallTTSError: $message';
}

/// 连接服务端失败
final class RainfallConnectionError extends RainfallTTSError {
  RainfallConnectionError(super.message);
}

/// TTS 合成过程中的错误
final class RainfallSynthesisError extends RainfallTTSError {
  RainfallSynthesisError(super.message);
}

/// 请求超时
final class RainfallTimeoutError extends RainfallTTSError {
  RainfallTimeoutError(super.message);
}

/// 服务端返回错误
final class RainfallServerError extends RainfallTTSError {
  RainfallServerError(super.message);
}
