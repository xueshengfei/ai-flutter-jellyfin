import 'dart:async';
import 'dart:convert';

import 'package:jellyfin_service/src/models/ai_recommendation_models.dart';

// 条件导入：Web 用 fetch API，原生用 Dio
import 'sse_fetch.dart'
  if (dart.library.html) 'sse_fetch_web.dart'
  if (dart.library.io) 'sse_fetch_native.dart';

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
/// 直连后端 `http://localhost:5000`，通过 GET `/ask_stream` 建立 SSE 连接。
/// 后端负责全部 AI + Jellyfin 逻辑，客户端只负责消费 SSE 事件流并渲染。
///
/// Web 平台：使用浏览器 fetch API + ReadableStream（支持真正的流式传输）
/// 原生/鸿蒙平台：使用 Dio ResponseType.stream
class AiStreamService {
  /// 后端地址（与 Jellyfin 同 IP，端口 5000）
  final String _baseUrl;

  /// 当前会话 ID（多轮对话自动传递）
  String? sessionId;

  /// [jellyfinServerUrl] Jellyfin 服务地址，AI 服务复用其 IP + 端口 5000
  /// 例如 Jellyfin 为 http://192.168.1.100:8096 → AI 服务为 http://192.168.1.100:5000
  AiStreamService({required String jellyfinServerUrl})
      : _baseUrl = _extractAiBaseUrl(jellyfinServerUrl);

  /// 从 Jellyfin URL 提取 IP，拼接 :5000
  static String _extractAiBaseUrl(String jellyfinUrl) {
    final uri = Uri.parse(jellyfinUrl);
    return '${uri.scheme}://${uri.host}:5000';
  }

  /// 连接开始时间（诊断用）
  DateTime? _connectStartTime;
  int _eventCount = 0;

  /// 发送提问并返回 SSE 事件流
  Stream<SseEvent> askStream(String question) {
    final controller = StreamController<SseEvent>();
    _startSseConnection(question, controller);
    return controller.stream;
  }

  /// 取消当前请求
  void cancel() {
    // TODO: 支持 AbortController (web) / CancelToken (native)
  }

  /// 建立 SSE 连接并解析事件流
  Future<void> _startSseConnection(
    String question,
    StreamController<SseEvent> controller,
  ) async {
    try {
      // 构造 GET URL（参数通过 query string 传递）
      final params = <String, String>{'question': question};
      if (sessionId != null) {
        params['session_id'] = sessionId!;
      }
      final uri = Uri.parse('$_baseUrl/ask_stream').replace(
        queryParameters: params,
      );

      // 使用平台适配的流式连接（GET 请求）
      final stream = createSseStream(
        uri.toString(),
        {'Accept': 'text/event-stream'},
      );

      _connectStartTime = DateTime.now();
      _eventCount = 0;
      print('[SSE] 连接已建立 @${_connectStartTime!.toIso8601String()}');
      var chunkCount = 0;
      final buffer = StringBuffer();
      String? currentEventName;
      final currentDataLines = <String>[];

      await for (final chunk in stream) {
        chunkCount++;
        final elapsed =
            DateTime.now().difference(_connectStartTime!).inMilliseconds;
        final text = utf8.decode(chunk, allowMalformed: true);
        print(
            '[SSE] chunk #$chunkCount @${elapsed}ms (${text.length} chars): ${text.length > 80 ? '${text.substring(0, 80)}...' : text}');
        buffer.write(text);

        // 逐行处理
        String content = buffer.toString();
        int newlineIdx;
        while ((newlineIdx = content.indexOf('\n')) >= 0) {
          var line = content.substring(0, newlineIdx);
          if (line.endsWith('\r')) {
            line = line.substring(0, line.length - 1);
          }
          content = content.substring(newlineIdx + 1);

          if (line.startsWith('event:')) {
            if (currentEventName != null && currentDataLines.isNotEmpty) {
              _emitEvent(currentEventName, currentDataLines, controller);
            }
            currentEventName = line.substring(6).trim();
            currentDataLines.clear();
          } else if (line.startsWith('data:')) {
            currentDataLines.add(line.substring(5).trim());
          }
        }
        buffer.clear();
        buffer.write(content);
      }

      // 派发最后一个事件（流结束时）
      if (currentEventName != null && currentDataLines.isNotEmpty) {
        _emitEvent(currentEventName, currentDataLines, controller);
      }
    } catch (e) {
      print('[SSE] 连接异常: $e');
      controller.add(SseEvent(
        type: SseEventType.error,
        data: {'message': '连接失败: $e'},
      ));
    } finally {
      await controller.close();
    }
  }

  /// 解析并派发一个完整事件
  void _emitEvent(
    String eventName,
    List<String> dataLines,
    StreamController<SseEvent> controller,
  ) {
    _eventCount++;
    final elapsed = _connectStartTime != null
        ? DateTime.now().difference(_connectStartTime!).inMilliseconds
        : -1;
    print('[SSE] 派发事件 #$_eventCount @${elapsed}ms: $eventName');
    final dataStr = dataLines.join('\n');
    try {
      final data = jsonDecode(dataStr) as Map<String, dynamic>;
      final event = SseEvent(
        type: SseEventType.fromName(eventName),
        data: data,
      );
      // 自动保存 sessionId
      if (event.type == SseEventType.session) {
        final sessionEvent = SseSessionEvent.fromJson(event.data);
        sessionId = sessionEvent.sessionId;
      }
      controller.add(event);
    } catch (e) {
      print('[SSE] JSON解析失败: $e\nevent: $eventName\nraw: $dataStr');
      controller.add(SseEvent(
        type: SseEventType.error,
        data: {'message': '解析失败', 'raw': dataStr},
      ));
    }
  }
}
