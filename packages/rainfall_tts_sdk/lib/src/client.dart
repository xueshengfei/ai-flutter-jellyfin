import 'dart:convert';
import 'dart:io';

import 'exceptions.dart';
import 'models.dart';

const String _gradioApiPrefix = '/gradio_api';

/// 雨落TTS SDK 客户端
///
/// 封装 Gradio v5 两步协议（POST 提交 → SSE 轮询结果）。
///
/// ```dart
/// final client = RainfallTTS(baseUrl: 'http://192.168.1.100:7860');
/// try {
///   final voices = await client.listVoices();
///   final result = await client.generate('你好，这是测试');
///   final localPath = await client.downloadAudio(result, 'output.wav');
/// } finally {
///   client.close();
/// }
/// ```
final class RainfallTTS {
  final String baseUrl;
  final Duration timeout;

  final HttpClient _httpClient = HttpClient();

  /// [baseUrl] Gradio 服务地址，默认 http://127.0.0.1:7860
  /// [timeoutSeconds] API 请求超时秒数，默认 300
  RainfallTTS({
    String baseUrl = 'http://127.0.0.1:7860',
    int timeoutSeconds = 300,
  })  : baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        timeout = Duration(seconds: timeoutSeconds) {
    _httpClient.connectionTimeout = const Duration(seconds: 30);
  }

  /// 默认输出目录（相对路径，由服务端解析为其工作目录下的 outputs）
  String get _defaultOutputDir => 'outputs';

  // ===========================================================================
  // 健康检查
  // ===========================================================================

  /// 检查服务是否在线
  Future<bool> isServerAlive() async {
    try {
      final uri = Uri.parse('$baseUrl/config');
      final req = await _httpClient.getUrl(uri);
      final resp = await req.close();
      await resp.drain<void>();
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ===========================================================================
  // 单条语音合成
  // ===========================================================================

  /// 单条文本语音合成
  ///
  /// [text] 待合成文本
  /// [voice] 参考音色文件名或 wav 全路径
  /// [maxTokensPerSegment] 每段最大 token 数 (10-300)
  /// [verbose] 是否在控制台显示详细信息
  /// [generateSubtitle] 是否生成字幕文件
  /// [speed] 语速调节，1.0 = 原速 (0.2-3.0)
  /// [volumeDb] 音量调节，单位分贝 (-20 ~ 20)
  /// [outputDir] 保存路径，为空则使用服务端默认
  /// [outputFilename] 保存文件名（不含后缀），为空则自动生成
  /// [outputFormat] 文件格式，"wav" 或 "mp3"
  /// [doSample] 是否采样
  /// [topP] top-p 采样参数 (0.0-1.0)
  /// [topK] top-k 采样参数 (0-100)
  /// [temperature] 温度参数 (0.1-2.0)
  /// [lengthPenalty] 长度惩罚 (-2.0 ~ 2.0)
  /// [numBeams] beam search 宽度 (1-10)
  /// [repetitionPenalty] 重复惩罚 (0.1-20.0)
  /// [maxMelTokens] 最大 mel token 数 (50-800)
  Future<TTSResult> generate(
    String text, {
    String voice = 'demo_boy.wav',
    int maxTokensPerSegment = 120,
    bool verbose = false,
    bool generateSubtitle = false,
    double speed = 1.0,
    int volumeDb = 0,
    String outputDir = '',
    String outputFilename = '',
    String outputFormat = 'wav',
    bool doSample = true,
    double topP = 0.8,
    int topK = 30,
    double temperature = 0.8,
    double lengthPenalty = 0.0,
    int numBeams = 3,
    double repetitionPenalty = 10.0,
    int maxMelTokens = 600,
  }) async {
    // 按组件 ID 顺序组装参数: 7,18,24,22,23,27,28,11,14,15,33,35,36,34,41,37,40,42
    final params = <dynamic>[
      voice, // id=7
      text, // id=18
      maxTokensPerSegment, // id=24
      _boolToCn(verbose, '显示', '不显示'), // id=22
      _boolToCn(generateSubtitle, '生成', '不生成'), // id=23
      speed, // id=27
      volumeDb, // id=28
      outputDir.isEmpty ? _defaultOutputDir : outputDir, // id=11
      outputFilename, // id=14
      outputFormat, // id=15
      doSample, // id=33
      topP, // id=35
      topK, // id=36
      temperature, // id=34
      lengthPenalty, // id=41
      numBeams, // id=37
      repetitionPenalty, // id=40
      maxMelTokens, // id=42
    ];

    final payload = await _callGradio('rainfall_gen_single', params);
    return _parseAudioResult(payload);
  }

  // ===========================================================================
  // 音色列表
  // ===========================================================================

  /// 获取可用音色列表
  Future<List<VoiceInfo>> listVoices() async {
    final payload =
        await _callGradio('refresh_single_prompt_audio', <dynamic>[]);

    // Gradio v5 返回: [{"choices": [["a","a"],["b","b"]], "__type__": "update"}]
    final voices = <VoiceInfo>[];
    if (payload is List) {
      for (final item in payload) {
        if (item is Map) {
          final choices = item['choices'];
          if (choices is List) {
            for (final c in choices) {
              if (c is List && c.isNotEmpty) {
                voices.add(VoiceInfo(name: c[0].toString()));
              } else {
                voices.add(VoiceInfo(name: c.toString()));
              }
            }
          }
        }
      }
    } else if (payload is Map) {
      final choices = payload['choices'];
      if (choices is List) {
        for (final c in choices) {
          if (c is List && c.isNotEmpty) {
            voices.add(VoiceInfo(name: c[0].toString()));
          } else {
            voices.add(VoiceInfo(name: c.toString()));
          }
        }
      }
    }
    return voices;
  }

  // ===========================================================================
  // 批量文本合成
  // ===========================================================================

  /// 批量文本语音合成（从 txt 文件目录）
  ///
  /// [inputDir] txt 文件所在目录
  /// [voice] 参考音色文件名或 wav 全路径
  /// [outputDir] 保存路径，为空使用服务端默认
  /// [lineInterval] 单文件内每行对话间隔（秒）
  /// [mergeLines] 连续多行是否合并
  /// [generateSubtitle] 是否生成字幕文件
  /// [maxTokensPerSegment] 每段最大 token 数 (10-300)
  Future<String> batchGenerate(
    String inputDir, {
    String voice = 'demo_boy.wav',
    String outputDir = '',
    double lineInterval = 0.1,
    bool mergeLines = true,
    bool generateSubtitle = false,
    int maxTokensPerSegment = 120,
  }) async {
    final params = <dynamic>[
      voice, // id=54
      outputDir.isEmpty ? _defaultOutputDir : outputDir, // id=58
      inputDir, // id=61
      lineInterval, // id=64
      _boolToCn(mergeLines, '合并', '不合并'), // id=65
      _boolToCn(generateSubtitle, '生成', '不生成'), // id=68
      maxTokensPerSegment, // id=69
    ];

    final payload =
        await _callGradio('single_batch_txt_generate', params);
    if (payload is List) {
      for (final item in payload) {
        if (item is String) return item;
      }
    }
    return payload != null ? payload.toString() : '';
  }

  // ===========================================================================
  // 多角色合成
  // ===========================================================================

  /// 多角色对话语音合成
  ///
  /// 文本格式: "小帅：你好啊！ 小美：你好，很高兴认识你。"
  ///
  /// [text] 对话文本，格式为 "角色名：台词"
  /// [roles] 角色音色分配列表（最多 10 个角色）
  /// [outputDir] 保存路径
  /// [outputFilename] 保存文件名（不含后缀）
  /// [outputFormat] 文件格式
  /// [dialogueInterval] 对话间隔（秒）
  Future<TTSResult> multiRoleGenerate(
    String text, {
    List<RoleAssignment> roles = const [],
    String outputDir = '',
    String outputFilename = '',
    String outputFormat = 'wav',
    double dialogueInterval = 0.1,
  }) async {
    // 10 个 (角色名, 参考音频) 对 + 用户输入 + 保存路径 + 文件名 + 格式 + 间隔
    final params = <dynamic>[];

    for (var i = 0; i < 10; i++) {
      if (i < roles.length) {
        params.add(roles[i].roleName);
        params.add(roles[i].voice);
      } else {
        params.add('');
        params.add('');
      }
    }

    params.addAll([
      text, // id=123 用户输入
      outputDir.isEmpty ? _defaultOutputDir : outputDir, // id=125 保存路径
      outputFilename, // id=128 文件名
      outputFormat, // id=129 格式
      dialogueInterval, // id=132 对话间隔
    ]);

    final payload = await _callGradio(
        'rainfall_quick_multi_role_text_generate', params);
    return _parseAudioResult(payload);
  }

  // ===========================================================================
  // 下载音频
  // ===========================================================================

  /// 从服务端下载音频文件到本地
  ///
  /// [result] generate 或 multiRoleGenerate 的返回结果
  /// [localPath] 本地保存路径
  /// 返回下载后的本地文件绝对路径。
  Future<String> downloadAudio(TTSResult result, String localPath) async {
    if (result.audioUrl.isEmpty) {
      throw RainfallSynthesisError('没有可下载的音频 URL，请先调用 generate()');
    }

    try {
      final uri = Uri.parse(result.audioUrl);
      final req = await _httpClient.getUrl(uri);
      final resp = await req.close();

      if (resp.statusCode != 200) {
        throw RainfallServerError('下载音频失败，HTTP ${resp.statusCode}');
      }

      final file = File(localPath);
      await file.parent.create(recursive: true);
      final sink = file.openWrite();
      await resp.pipe(sink);
      await sink.close();

      return file.absolute.path;
    } on RainfallTTSError {
      rethrow;
    } catch (e) {
      throw RainfallConnectionError('下载音频失败: $e');
    }
  }

  // ===========================================================================
  // 资源释放
  // ===========================================================================

  /// 关闭底层 HTTP 连接
  void close() => _httpClient.close();

  // ===========================================================================
  // 内部方法
  // ===========================================================================

  static String _boolToCn(bool value, String trueStr, String falseStr) =>
      value ? trueStr : falseStr;

  /// Gradio v5 两步协议调用
  ///
  /// 第一步: POST /gradio_api/call/<endpoint>  提交任务，获取 event_id
  /// 第二步: GET  /gradio_api/call/<endpoint>/<event_id>  轮询 SSE 结果
  Future<dynamic> _callGradio(
    String endpoint,
    List<dynamic> data, {
    Duration? callTimeout,
  }) async {
    final effectiveTimeout = callTimeout ?? timeout;
    final callUrl = '$baseUrl$_gradioApiPrefix/call/$endpoint';
    final uri = Uri.parse(callUrl);

    // 第一步: 提交任务
    final postReq = await _httpClient.postUrl(uri);
    final body = jsonEncode({'data': data});
    postReq.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    postReq.add(utf8.encode(body));

    HttpClientResponse postResp;
    try {
      postResp = await postReq.close();
    } on SocketException catch (e) {
      throw RainfallConnectionError('无法连接到 $baseUrl: $e');
    } on HttpException catch (e) {
      if (e.message.contains('timed out') || e.message.contains('Timeout')) {
        throw RainfallTimeoutError('提交任务超时: $e');
      }
      rethrow;
    }

    if (postResp.statusCode != 200) {
      final respBody = await _readBody(postResp);
      throw RainfallServerError(
        '提交任务失败，HTTP ${postResp.statusCode}: ${respBody.substring(0, respBody.length > 500 ? 500 : respBody.length)}',
      );
    }

    final respBody = await _readBody(postResp);
    final Map<String, dynamic> result;
    try {
      result = jsonDecode(respBody) as Map<String, dynamic>;
    } catch (e) {
      throw RainfallServerError(
        '解析提交响应失败: $e, body=${respBody.substring(0, respBody.length > 500 ? 500 : respBody.length)}',
      );
    }

    final eventId = result['event_id'];
    if (eventId is! String || eventId.isEmpty) {
      throw RainfallServerError('未获取到 event_id, body=$respBody');
    }

    // 第二步: SSE 轮询结果
    final sseUri = Uri.parse('$callUrl/$eventId');
    final getReq = await _httpClient.getUrl(sseUri);

    final HttpClientResponse getResp;
    try {
      getResp = await getReq.close().timeout(effectiveTimeout);
    } on SocketException catch (e) {
      throw RainfallConnectionError('获取结果时连接失败: $e');
    } catch (e) {
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('timed out')) {
        throw RainfallTimeoutError(
            '获取结果超时 (${effectiveTimeout.inSeconds}s)');
      }
      rethrow;
    }

    if (getResp.statusCode != 200) {
      final errBody = await _readBody(getResp);
      throw RainfallServerError(
        '获取结果失败，HTTP ${getResp.statusCode}: ${errBody.substring(0, errBody.length > 500 ? 500 : errBody.length)}',
      );
    }

    return _parseSseStream(getResp);
  }

  /// 解析 SSE 事件流，返回最终 payload
  static Future<dynamic> _parseSseStream(
      HttpClientResponse response) async {
    final buffer = <int>[];
    await for (final chunk in response) {
      buffer.addAll(chunk);
    }

    final fullText = utf8.decode(buffer);
    dynamic lastData;

    for (final rawLine in fullText.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('data:')) {
        final payloadStr = line.substring(5).trim();
        try {
          lastData = jsonDecode(payloadStr);
        } catch (_) {
          lastData = payloadStr;
        }
      }
    }

    if (lastData is Map && lastData.containsKey('error')) {
      throw RainfallSynthesisError('服务端合成错误: ${lastData['error']}');
    }

    return lastData;
  }

  /// 解析 Gradio 返回的音频结果
  TTSResult _parseAudioResult(dynamic payload) {
    var audioPath = '';
    var audioUrl = '';

    if (payload == null) {
      throw RainfallSynthesisError('服务端返回空结果');
    }

    // Gradio v5 返回: [{"visible": true, "value": {"path": "...", "url": "..."}, "__type__": "update"}]
    if (payload is List) {
      for (final item in payload) {
        if (item is Map) {
          final val = item['value'];
          if (val is Map) {
            audioPath = (val['path'] ?? '').toString();
            audioUrl = (val['url'] ?? '').toString();
            if (audioPath.isNotEmpty || audioUrl.isNotEmpty) break;
          } else if (val is String &&
              (val.endsWith('.wav') || val.endsWith('.mp3'))) {
            audioPath = val;
            break;
          }
          if (item.containsKey('path') || item.containsKey('url')) {
            audioPath = (item['path'] ?? '').toString();
            audioUrl = (item['url'] ?? '').toString();
            if (audioPath.isNotEmpty || audioUrl.isNotEmpty) break;
          }
        }
        if (item is String &&
            (item.endsWith('.wav') || item.endsWith('.mp3'))) {
          audioPath = item;
          break;
        }
      }
    } else if (payload is Map) {
      final val = payload['value'];
      if (val is Map) {
        audioPath = (val['path'] ?? '').toString();
        audioUrl = (val['url'] ?? '').toString();
      } else {
        audioPath = (payload['path'] ?? '').toString();
        audioUrl = (payload['url'] ?? '').toString();
      }
    } else if (payload is String) {
      audioPath = payload;
    }

    if (audioPath.isEmpty && audioUrl.isEmpty) {
      throw RainfallSynthesisError('无法解析音频结果: $payload');
    }

    if (audioUrl.isEmpty && audioPath.isNotEmpty) {
      final encoded = Uri.encodeComponent(audioPath);
      audioUrl = '$baseUrl$_gradioApiPrefix/file=$encoded';
    }

    return TTSResult(audioPath: audioPath, audioUrl: audioUrl);
  }

  static Future<String> _readBody(HttpClientResponse resp) =>
      resp.transform(utf8.decoder).join();
}
