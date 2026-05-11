import 'dart:convert';

import 'package:http/http.dart' as http;

import 'exceptions.dart';
import 'file_saver.dart';
import 'models.dart';

const String _gradioApiPrefix = '/gradio_api';

/// 雨落TTS SDK 客户端
///
/// 封装 Gradio v5 两步协议（POST 提交 → SSE 轮询结果）。
/// 匹配 IndexTTS 2.0 服务端 32 参数 API。
///
/// ```dart
/// final client = RainfallTTS(baseUrl: 'http://192.168.1.100:7861');
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

  final http.Client _httpClient = http.Client();

  /// [baseUrl] Gradio 服务地址，默认 http://127.0.0.1:7861
  /// [timeoutSeconds] API 请求超时秒数，默认 300
  RainfallTTS({
    String baseUrl = 'http://127.0.0.1:7861',
    int timeoutSeconds = 300,
  })  : baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        timeout = Duration(seconds: timeoutSeconds);

  /// 默认输出目录（服务端的 outputs，相对路径）
  String get _defaultOutputDir => 'outputs';

  // ===========================================================================
  // 健康检查
  // ===========================================================================

  /// 检查服务是否在线
  Future<bool> isServerAlive() async {
    try {
      final resp = await _httpClient
          .get(Uri.parse('$baseUrl/config'))
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ===========================================================================
  // 单条语音合成 (IndexTTS 2.0, 32 参数)
  // ===========================================================================

  /// 单条文本语音合成
  ///
  /// [text] 待合成文本
  /// [voice] 参考音色文件名或 wav 全路径
  /// [emoHappy] 高兴情感强度 (0.0~1.0)
  /// [emoAngry] 愤怒情感强度 (0.0~1.0)
  /// [emoSad] 悲伤情感强度 (0.0~1.0)
  /// [emoAfraid] 害怕情感强度 (0.0~1.0)
  /// [emoDisgusted] 厌恶情感强度 (0.0~1.0)
  /// [emoMelancholic] 忧郁情感强度 (0.0~1.0)
  /// [emoSurprised] 惊讶情感强度 (0.0~1.0)
  /// [emoCalm] 平静情感强度 (0.0~1.0)
  /// [emoText] 情感参考文本
  /// [emoAlpha] 情感强度系数 (0.0~1.0)
  /// [useEmoText] 是否使用文本控制情感
  /// [emoAudio] 情感参考音频路径
  /// [useRandom] 是否使用随机情感
  /// [maxTokensPerSegment] 每段最大 token 数 (10-300)
  /// [intervalSilence] 段内静音间隔，毫秒 (0~)
  /// [verbose] 是否在控制台显示详细信息
  /// [generateSubtitle] 是否生成字幕文件
  /// [speed] 语速调节，1.0 = 原速 (0.2-3.0)
  /// [volumeDb] 音量调节，单位分贝 (-20 ~ 20)
  /// [outputDir] 保存路径，为空则使用服务端默认 outputs
  /// [outputFilename] 保存文件名（不含后缀），为空则自动生成
  /// [outputFormat] 文件格式，"wav" 或 "mp3"
  /// [doSample] 是否采样
  /// [temperature] 温度参数 (0.1-2.0)
  /// [topK] top-k 采样参数 (0-100)
  /// [topP] top-p 采样参数 (0.0-1.0)
  /// [lengthPenalty] 长度惩罚 (-2.0 ~ 2.0)
  /// [numBeams] beam search 宽度 (1-10)
  /// [repetitionPenalty] 重复惩罚 (0.1-20.0)
  /// [maxMelTokens] 最大 mel token 数 (50-1500)
  Future<TTSResult> generate(
    String text, {
    String voice = 'demo_boy.wav',
    // 情感向量
    double emoHappy = 0.0,
    double emoAngry = 0.0,
    double emoSad = 0.0,
    double emoAfraid = 0.0,
    double emoDisgusted = 0.0,
    double emoMelancholic = 0.0,
    double emoSurprised = 0.0,
    double emoCalm = 0.0,
    // 情感配置
    String emoText = '',
    double emoAlpha = 0.65,
    bool useEmoText = false,
    String? emoAudio,
    bool useRandom = false,
    // 生成参数
    int maxTokensPerSegment = 120,
    int intervalSilence = 200,
    bool verbose = false,
    bool generateSubtitle = false,
    double speed = 1.0,
    double volumeDb = 0,
    // 输出
    String outputDir = '',
    String outputFilename = '',
    String outputFormat = 'wav',
    // 高级参数
    bool doSample = true,
    double temperature = 0.8,
    int topK = 30,
    double topP = 0.8,
    double lengthPenalty = 0.0,
    int numBeams = 3,
    double repetitionPenalty = 10.0,
    int maxMelTokens = 1500,
  }) async {
    // IndexTTS 2.0 服务端 Gradio v5 32 参数，严格按顺序
    final params = <dynamic>[
      voice, // [1]  prompt 参考音色
      text, // [2]  text 待处理文本
      emoHappy, // [3]  emo_vector1 高兴
      emoAngry, // [4]  emo_vector2 愤怒
      emoSad, // [5]  emo_vector3 悲伤
      emoAfraid, // [6]  emo_vector4 害怕
      emoDisgusted, // [7]  emo_vector5 厌恶
      emoMelancholic, // [8]  emo_vector6 忧郁
      emoSurprised, // [9]  emo_vector7 惊讶
      emoCalm, // [10] emo_vector8 平静
      emoText, // [11] single_emo_text
      emoAlpha, // [12] single_emo_alpha
      _boolToCn(useEmoText, '使用', '不使用'), // [13] single_use_emo_text
      emoAudio, // [14] single_emo_audio
      _boolToCn(useRandom, '使用', '不使用'), // [15] single_use_random
      maxTokensPerSegment, // [16] max_text_tokens_per_segment
      intervalSilence, // [17] interval_silence
      _boolToCn(verbose, '显示', '不显示'), // [18] single_verbose
      _boolToCn(generateSubtitle, '生成', '不生成'), // [19] single_need_srt
      speed, // [20] single_speed
      volumeDb, // [21] single_volume
      outputDir.isEmpty ? _defaultOutputDir : outputDir, // [22] output_dir
      outputFilename, // [23] output_file_name
      outputFormat, // [24] single_file_suffix
      doSample, // [25] do_sample
      temperature, // [26] temperature
      topK, // [27] top_k
      topP, // [28] top_p
      lengthPenalty, // [29] length_penalty
      numBeams, // [30] num_beams
      repetitionPenalty, // [31] repetition_penalty
      maxMelTokens, // [32] max_mel_tokens
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
  Future<String> batchGenerate(
    String inputDir, {
    String voice = 'demo_boy.wav',
    String outputDir = '',
    double lineInterval = 0.1,
    bool useEmo = false,
    bool mergeLines = true,
    bool generateSubtitle = false,
    int maxTokensPerSegment = 120,
  }) async {
    final params = <dynamic>[
      voice, // [1] 参考音色
      outputDir.isEmpty ? _defaultOutputDir : outputDir, // [2] 保存路径
      inputDir, // [3] txt目录
      lineInterval, // [4] 行间隔
      _boolToCn(useEmo, '使用', '不使用'), // [5] 是否使用情感
      _boolToCn(mergeLines, '合并', '不合并'), // [6] 是否合并
      _boolToCn(generateSubtitle, '生成', '不生成'), // [7] 是否生成字幕
      maxTokensPerSegment, // [8] 每段最大token
    ];

    final payload =
        await _callGradio('single_batch_txt_generate', params);
    if (payload is List) {
      for (final item in payload) {
        if (item is String) return item;
        if (item is Map) {
          final val = item['value'];
          if (val is String) return val;
        }
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
  Future<TTSResult> multiRoleGenerate(
    String text, {
    List<RoleAssignment> roles = const [],
    String outputDir = '',
    String outputFilename = '',
    String outputFormat = 'wav',
    double dialogueInterval = 0.1,
  }) async {
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
      text,
      outputDir.isEmpty ? _defaultOutputDir : outputDir,
      outputFilename,
      outputFormat,
      dialogueInterval,
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
  /// Web 平台不支持文件写入，会抛出 [UnsupportedError]。
  Future<String> downloadAudio(TTSResult result, String localPath) async {
    if (result.audioUrl.isEmpty) {
      throw RainfallSynthesisError('没有可下载的音频 URL，请先调用 generate()');
    }

    try {
      final resp = await _httpClient.get(Uri.parse(result.audioUrl));

      if (resp.statusCode != 200) {
        throw RainfallServerError('下载音频失败，HTTP ${resp.statusCode}');
      }

      return saveFile(localPath, resp.bodyBytes);
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
  Future<dynamic> _callGradio(
    String endpoint,
    List<dynamic> data, {
    Duration? callTimeout,
  }) async {
    final effectiveTimeout = callTimeout ?? timeout;
    final callUrl = '$baseUrl$_gradioApiPrefix/call/$endpoint';

    // 第一步: 提交任务
    final body = jsonEncode({'data': data});
    http.Response postResp;
    try {
      postResp = await _httpClient
          .post(Uri.parse(callUrl), headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      if (e.toString().contains('timed out') || e.toString().contains('Timeout')) {
        throw RainfallTimeoutError('提交任务超时: $e');
      }
      throw RainfallConnectionError('无法连接到 $baseUrl: $e');
    }

    if (postResp.statusCode != 200) {
      final respBody = postResp.body;
      throw RainfallServerError(
        '提交任务失败，HTTP ${postResp.statusCode}: ${respBody.substring(0, respBody.length > 500 ? 500 : respBody.length)}',
      );
    }

    final Map<String, dynamic> result;
    try {
      result = jsonDecode(postResp.body) as Map<String, dynamic>;
    } catch (e) {
      final respBody = postResp.body;
      throw RainfallServerError(
        '解析提交响应失败: $e, body=${respBody.substring(0, respBody.length > 500 ? 500 : respBody.length)}',
      );
    }

    final eventId = result['event_id'];
    if (eventId is! String || eventId.isEmpty) {
      throw RainfallServerError('未获取到 event_id, body=${postResp.body}');
    }

    // 第二步: SSE 轮询结果
    final sseUrl = '$callUrl/$eventId';
    http.Response getResp;
    try {
      getResp = await _httpClient
          .get(Uri.parse(sseUrl))
          .timeout(effectiveTimeout);
    } catch (e) {
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('timed out')) {
        throw RainfallTimeoutError(
            '获取结果超时 (${effectiveTimeout.inSeconds}s)');
      }
      throw RainfallConnectionError('获取结果时连接失败: $e');
    }

    if (getResp.statusCode != 200) {
      final errBody = getResp.body;
      throw RainfallServerError(
        '获取结果失败，HTTP ${getResp.statusCode}: ${errBody.substring(0, errBody.length > 500 ? 500 : errBody.length)}',
      );
    }

    return _parseSseText(getResp.body);
  }

  /// 解析 SSE 文本，返回最终 payload
  static dynamic _parseSseText(String sseText) {
    dynamic lastData;

    for (final rawLine in sseText.split('\n')) {
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

  /// 解析 Gradio v5 返回的音频结果
  ///
  /// 已知格式:
  ///   - {"visible": true, "value": "/path/to/file.wav", "__type__": "update"}
  ///   - {"visible": true, "value": {"path": "...", "url": "..."}, "__type__": "update"}
  ///   - [以上 dict]
  ///   - 字符串路径
  TTSResult _parseAudioResult(dynamic payload) {
    if (payload == null) {
      throw RainfallSynthesisError('服务端返回空结果');
    }

    if (payload is List) {
      for (final item in payload) {
        final result = _extractAudioFromItem(item);
        if (result != null) return result;
      }
    } else {
      final result = _extractAudioFromItem(payload);
      if (result != null) return result;
    }

    throw RainfallSynthesisError('无法解析音频结果: $payload');
  }

  /// 从单个 Gradio 返回项中提取音频信息
  TTSResult? _extractAudioFromItem(dynamic item) {
    // 字符串路径
    if (item is String && (item.endsWith('.wav') || item.endsWith('.mp3'))) {
      return TTSResult(
        audioPath: item,
        audioUrl: _buildAudioUrl(item),
      );
    }

    if (item is! Map) return null;

    // Gradio v5: {"visible": true, "value": <path_or_dict>, "__type__": "update"}
    final val = item['value'];

    // value 是字符串路径
    if (val is String && (val.endsWith('.wav') || val.endsWith('.mp3'))) {
      return TTSResult(
        audioPath: val,
        audioUrl: _buildAudioUrl(val),
      );
    }

    // value 是文件信息 dict
    if (val is Map) {
      final audioPath = (val['path'] ?? '').toString();
      final audioUrl = (val['url'] ?? '').toString();
      if (audioPath.isNotEmpty || audioUrl.isNotEmpty) {
        return TTSResult(
          audioPath: audioPath,
          audioUrl: audioUrl.isNotEmpty
              ? audioUrl
              : _buildAudioUrl(audioPath),
        );
      }
    }

    // 兜底：item 本身包含 path/url
    final audioPath = (item['path'] ?? '').toString();
    final audioUrl = (item['url'] ?? '').toString();
    if (audioPath.isNotEmpty || audioUrl.isNotEmpty) {
      return TTSResult(
        audioPath: audioPath,
        audioUrl:
            audioUrl.isNotEmpty ? audioUrl : _buildAudioUrl(audioPath),
      );
    }

    return null;
  }

  /// 根据音频路径构建下载 URL（保留 / 不编码）
  String _buildAudioUrl(String audioPath) {
    if (audioPath.isEmpty) return '';
    // 逐段编码路径，保留 / 分隔符
    final segments = audioPath.split('/');
    final encoded = segments.map(Uri.encodeComponent).join('/');
    return '$baseUrl$_gradioApiPrefix/file=$encoded';
  }
}
