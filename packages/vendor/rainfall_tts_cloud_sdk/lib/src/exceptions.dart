/// SDK 基础异常
base class RainfallCloudError implements Exception {
  final String message;
  RainfallCloudError(this.message);

  @override
  String toString() => 'RainfallCloudError: $message';
}

/// 连接服务端失败
final class RainfallCloudConnectionError extends RainfallCloudError {
  RainfallCloudConnectionError(super.message);
}

/// TTS 合成过程中的错误
final class RainfallCloudSynthesisError extends RainfallCloudError {
  RainfallCloudSynthesisError(super.message);
}

/// 请求超时
final class RainfallCloudTimeoutError extends RainfallCloudError {
  RainfallCloudTimeoutError(super.message);
}

/// 服务端返回错误
final class RainfallCloudServerError extends RainfallCloudError {
  RainfallCloudServerError(super.message);
}

/// 文件上传失败
final class RainfallCloudUploadError extends RainfallCloudError {
  RainfallCloudUploadError(super.message);
}
