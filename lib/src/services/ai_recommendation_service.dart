import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:jellyfin_service/src/models/ai_recommendation_models.dart';

// ═══════════════════════════════════════════
// SSE 事件统一封装
// ═══════════════════════════════════════════

/// SSE 事件（type + 原始 data JSON）
class SseEvent {
  final SseEventType type;
  final Map<String, dynamic> data;

  const SseEvent({required this.type, required this.data});

  @override
  String toString() => 'SseEvent(type: $type, data: $data)';
}

// ═══════════════════════════════════════════
// AI 流式通信服务
// ═══════════════════════════════════════════

/// AI 流式推荐服务
///
/// 直连后端 `http://localhost:5000`，通过 POST `/ask_stream` 建立 SSE 连接。
/// 后端负责全部 AI + Jellyfin 逻辑，客户端只负责消费 SSE 事件流并渲染。
///
/// 仅用 dart:async + dart:convert，兼容鸿蒙平台。
class AiStreamService {
  /// 后端地址
  static const String _baseUrl = 'http://localhost:5000';

  final Dio _dio;

  /// 当前会话 ID（多轮对话自动传递）
  String? sessionId;

  /// 取消令牌（用于取消上一次请求）
  CancelToken? _cancelToken;

  AiStreamService() : _dio = Dio(BaseOptions(baseUrl: _baseUrl));

  /// 发送提问并返回 SSE 事件流
  ///
  /// [question] 用户自然语言提问
  /// 返回 `Stream<SseEvent>`，调用方逐事件监听即可
  Stream<SseEvent> askStream(String question) {
    // 取消上一次未完成的请求
    _cancelToken?.cancel('新请求已发起');
    _cancelToken = CancelToken();

    final controller = StreamController<SseEvent>();

    _startSseConnection(question, controller);

    return controller.stream;
  }

  /// 取消当前请求
  void cancel() {
    _cancelToken?.cancel('用户取消');
    _cancelToken = null;
  }

  /// 建立 SSE 连接并解析事件流
  Future<void> _startSseConnection(
    String question,
    StreamController<SseEvent> controller,
  ) async {
    try {
      final body = <String, dynamic>{'question': question};
      if (sessionId != null) {
        body['session_id'] = sessionId;
      }

      final response = await _dio.post<ResponseBody>(
        '/ask_stream',
        data: body,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
        cancelToken: _cancelToken,
      );

      final stream = response.data!.stream;
      final buffer = StringBuffer();
      String charset = 'utf-8';

      // 监听字节流
      await for (final chunk in stream) {
        // 解码字节为字符串
        final text = _decodeChunk(chunk, charset);
        buffer.write(text);

        // 按 \n\n 分块处理 SSE 事件
        String content = buffer.toString();
        while (content.contains('\n\n')) {
          final index = content.indexOf('\n\n');
          final block = content.substring(0, index).trim();
          content = content.substring(index + 2);

          if (block.isNotEmpty) {
            final event = _parseSseBlock(block);
            if (event != null) {
              // 自动保存 sessionId
              if (event.type == SseEventType.session) {
                final sessionEvent = SseSessionEvent.fromJson(event.data);
                sessionId = sessionEvent.sessionId;
              }
              controller.add(event);
            }
          }
        }
        buffer.clear();
        buffer.write(content);
      }

      // 处理 buffer 中可能残余的最后一块
      final remaining = buffer.toString().trim();
      if (remaining.isNotEmpty) {
        final event = _parseSseBlock(remaining);
        if (event != null) {
          controller.add(event);
        }
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        // 用户主动取消，不报错
      } else {
        controller.add(SseEvent(
          type: SseEventType.error,
          data: {'message': '连接失败: $e'},
        ));
      }
    } finally {
      await controller.close();
    }
  }

  /// 解码字节块
  String _decodeChunk(List<int> chunk, String charset) {
    // 简单处理：绝大多数场景为 UTF-8
    return utf8.decode(chunk, allowMalformed: true);
  }

  /// 解析单个 SSE 块（多行 key:value）
  SseEvent? _parseSseBlock(String block) {
    String? eventName;
    String? dataStr;

    for (final line in block.split('\n')) {
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataStr = line.substring(5).trim();
      }
    }

    if (eventName == null || dataStr == null) return null;

    try {
      final data = jsonDecode(dataStr) as Map<String, dynamic>;
      return SseEvent(
        type: SseEventType.fromName(eventName),
        data: data,
      );
    } catch (e) {
      // JSON 解码失败，返回 error 事件
      return SseEvent(
        type: SseEventType.error,
        data: {'message': '解析失败: $e', 'raw': dataStr},
      );
    }
  }
}
