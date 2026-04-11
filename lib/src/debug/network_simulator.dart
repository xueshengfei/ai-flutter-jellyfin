import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

/// 网络速度模拟枚举
enum NetworkSpeed {
  /// 2G 网络，延迟 3000ms
  g2(label: '2G', delay: Duration(seconds: 3)),

  /// 3G 网络，延迟 1000ms
  g3(label: '3G', delay: Duration(seconds: 1)),

  /// 4G LTE 网络，延迟 200ms
  lte4g(label: '4G', delay: Duration(milliseconds: 200)),

  /// WiFi，无额外延迟
  wifi(label: 'WiFi', delay: Duration.zero);

  const NetworkSpeed({required this.label, required this.delay});

  /// 显示名称
  final String label;

  /// 模拟延迟
  final Duration delay;
}

/// 请求日志条目
class RequestLogEntry {
  RequestLogEntry({
    required this.method,
    required this.url,
    required this.timestamp,
    this.statusCode,
    this.errorMsg,
    this.simulatedDelay,
    this.simulatedFailure = false,
    this.requestHeaders,
    this.requestBody,
    this.responseHeaders,
    this.responseBody,
    this.duration,
  });

  final String method;
  final String url;
  final DateTime timestamp;
  int? statusCode;
  String? errorMsg;
  Duration? simulatedDelay;
  bool simulatedFailure;

  /// 请求头
  Map<String, dynamic>? requestHeaders;

  /// 请求体
  String? requestBody;

  /// 响应头
  Map<String, dynamic>? responseHeaders;

  /// 响应体（格式化后的字符串）
  String? responseBody;

  /// 请求耗时
  Duration? duration;
}

/// Dio 拦截器，模拟不同网络速度和失败率
///
/// 用法:
/// ```dart
/// SlowNetSimulator.configure(speed: NetworkSpeed.lte4g, failureProbability: 0.1);
/// // 将 SlowNetSimulator.instance 添加到 Dio interceptors
/// ```
class SlowNetSimulator extends Interceptor {
  SlowNetSimulator._();

  /// 单例
  static final SlowNetSimulator instance = SlowNetSimulator._();

  /// 当前网络速度，null 表示不模拟（正常速度）
  NetworkSpeed? _speed;

  /// 失败概率 (0.0 ~ 1.0)
  double _failureProbability = 0.0;

  /// 随机数生成器
  final _random = Random();

  /// 请求日志列表（最多保留 200 条）
  final List<RequestLogEntry> _logs = [];

  /// 日志变更回调（供 UI 面板监听）
  void Function()? onLogUpdated;

  /// 获取当前日志（只读）
  List<RequestLogEntry> get logs => List.unmodifiable(_logs);

  /// 当前速度
  NetworkSpeed? get speed => _speed;

  /// 当前失败概率
  double get failureProbability => _failureProbability;

  /// 配置模拟参数
  static void configure({
    NetworkSpeed? speed,
    double failureProbability = 0.0,
  }) {
    instance._speed = speed;
    instance._failureProbability = failureProbability.clamp(0.0, 0.5);
  }

  /// 关闭模拟
  static void disable() {
    instance._speed = null;
    instance._failureProbability = 0.0;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final entry = RequestLogEntry(
      method: options.method,
      url: options.uri.toString(),
      timestamp: DateTime.now(),
      requestHeaders: Map<String, dynamic>.from(options.headers),
      requestBody: _formatBody(options.data),
    );

    // 网络速度模拟
    if (_speed != null) {
      entry.simulatedDelay = _speed!.delay;
      await Future.delayed(_speed!.delay);

      // 随机失败模拟
      if (_failureProbability > 0 && _random.nextDouble() < _failureProbability) {
        entry.simulatedFailure = true;
        entry.errorMsg = '模拟网络错误 (${_speed!.label})';
        _addLog(entry);
        handler.reject(
          DioException(
            requestOptions: options,
            error: entry.errorMsg,
            type: DioExceptionType.connectionError,
          ),
        );
        return;
      }
    }

    // 记录开始时间
    options.extra['_simulatorStartTime'] = DateTime.now();

    handler.next(options);

    // 注意：响应/错误在 onResponse 和 onError 中记录
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final startTime = response.requestOptions.extra['_simulatorStartTime'] as DateTime?;
    final duration = startTime != null ? DateTime.now().difference(startTime) : null;

    final log = _findPendingLog(response.requestOptions);
    if (log != null) {
      log.statusCode = response.statusCode;
      log.responseHeaders = Map<String, dynamic>.from(response.headers.map);
      log.responseBody = _formatBody(response.data);
      log.duration = duration;
      _notifyUpdate();
    } else {
      _addLog(RequestLogEntry(
        method: response.requestOptions.method,
        url: response.requestOptions.uri.toString(),
        timestamp: startTime ?? DateTime.now(),
        statusCode: response.statusCode,
        simulatedDelay: _speed?.delay,
        requestHeaders: Map<String, dynamic>.from(response.requestOptions.headers),
        requestBody: _formatBody(response.requestOptions.data),
        responseHeaders: Map<String, dynamic>.from(response.headers.map),
        responseBody: _formatBody(response.data),
        duration: duration,
      ));
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final log = _findPendingLog(err.requestOptions);
    if (log != null) {
      log.statusCode = err.response?.statusCode;
      log.errorMsg = err.message ?? err.error?.toString() ?? '未知错误';
      log.responseBody = _formatBody(err.response?.data);
      log.responseHeaders = err.response != null
          ? Map<String, dynamic>.from(err.response!.headers.map)
          : null;
      _notifyUpdate();
    } else {
      _addLog(RequestLogEntry(
        method: err.requestOptions.method,
        url: err.requestOptions.uri.toString(),
        timestamp: DateTime.now(),
        statusCode: err.response?.statusCode,
        errorMsg: err.message ?? err.error?.toString() ?? '未知错误',
        simulatedDelay: _speed?.delay,
        requestHeaders: Map<String, dynamic>.from(err.requestOptions.headers),
        requestBody: _formatBody(err.requestOptions.data),
        responseHeaders: err.response != null
            ? Map<String, dynamic>.from(err.response!.headers.map)
            : null,
        responseBody: _formatBody(err.response?.data),
      ));
    }
    handler.next(err);
  }

  /// 尝试查找未完成的日志条目（匹配 URL + 时间窗口）
  RequestLogEntry? _findPendingLog(RequestOptions options) {
    final url = options.uri.toString();
    final now = DateTime.now();
    for (final log in _logs.reversed) {
      if (log.url == url && log.statusCode == null && log.errorMsg == null) {
        if (now.difference(log.timestamp).inSeconds < 30) {
          return log;
        }
      }
    }
    return null;
  }

  void _addLog(RequestLogEntry entry) {
    _logs.insert(0, entry);
    // 限制日志数量
    if (_logs.length > 200) {
      _logs.removeRange(200, _logs.length);
    }
    _notifyUpdate();
  }

  /// 格式化请求/响应体为可读字符串
  static String? _formatBody(dynamic data) {
    if (data == null) return null;
    if (data is String) {
      // 尝试格式化 JSON 字符串
      try {
        final decoded = jsonDecode(data);
        return const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {
        return data.length > 4096 ? '${data.substring(0, 4096)}...(truncated)' : data;
      }
    }
    if (data is Map || data is List) {
      try {
        return const JsonEncoder.withIndent('  ').convert(data);
      } catch (_) {
        return data.toString();
      }
    }
    final str = data.toString();
    return str.length > 4096 ? '${str.substring(0, 4096)}...(truncated)' : str;
  }

  void _notifyUpdate() {
    onLogUpdated?.call();
  }
}
