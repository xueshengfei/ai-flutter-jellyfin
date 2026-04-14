import 'dart:typed_data';

/// 创建 SSE 流式连接（stub — 不支持的平台）
///
/// Web 实现见 sse_fetch_web.dart，原生实现见 sse_fetch_native.dart。
Stream<Uint8List> createSseStream(
  String url,
  Map<String, String> headers,
) {
  throw UnsupportedError('SSE streaming not supported on this platform');
}
