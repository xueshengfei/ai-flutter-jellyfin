import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'exceptions.dart';
import 'models.dart';

const String _api = '/gradio_api';

// =============================================================================
// 云端 SDK 客户端
// =============================================================================

/// 雨落TTS 云端版 SDK 客户端
///
/// 适配 IndexTTS2 云端 Gradio v5 API。
/// 通过 `/gradio_api/upload` 上传文件，再用两步协议调用 API。
///
/// ```dart
/// final client = RainfallCloudTTS();
/// try {
///   final result = await client.generate(
///     voiceFilePath: '/path/to/voice.wav',
///     text: '你好世界',
///   );
///   print(result.audioUrl);
///   await client.downloadFile(result.audioUrl, 'output.wav');
/// } finally {
///   client.close();
/// }
/// ```
final class RainfallCloudTTS {
  final String baseUrl;
  final Duration timeout;
  final http.Client _httpClient;

  /// 已上传音色的服务端路径缓存（voiceName → serverPath）
  final Map<String, String> _voiceCache = {};

  /// [baseUrl] Gradio 服务地址
  /// [timeoutSeconds] API 请求超时秒数，默认 300
  RainfallCloudTTS({
    this.baseUrl = 'http://106.75.68.11:7860',
    int timeoutSeconds = 300,
    http.Client? httpClient,
  })  : _httpClient = httpClient ?? http.Client(),
        timeout = Duration(seconds: timeoutSeconds);

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
  // 音色列表（静态，来自 prompt_audio 目录）
  // ===========================================================================

  /// 可用音色列表
  static const List<VoiceInfo> voices = [
    VoiceInfo(name: 'demo_boy.wav'),
    VoiceInfo(name: 'demo_girl.wav'),
    VoiceInfo(name: 'ROP.WAV'),
    VoiceInfo(name: 'en.wav'),
    VoiceInfo(name: '九九妈.mp3'),
    VoiceInfo(name: '云.wav'),
    VoiceInfo(name: '云浩宇.WAV'),
    VoiceInfo(name: '云浩宇 影视.WAV'),
    VoiceInfo(name: '云浩宇2.WAV'),
    VoiceInfo(name: '云静芳.WAV'),
    VoiceInfo(name: '傲娇大佬.WAV'),
    VoiceInfo(name: '八重神子.WAV'),
    VoiceInfo(name: '刻晴.WAV'),
    VoiceInfo(name: '可莉.WAV'),
    VoiceInfo(name: '可霖.WAV'),
    VoiceInfo(name: '周星星.WAV'),
    VoiceInfo(name: '哪吒.WAV'),
    VoiceInfo(name: '唐僧.WAV'),
    VoiceInfo(name: '大大.WAV'),
    VoiceInfo(name: '太乙真人.WAV'),
    VoiceInfo(name: '女生.wav'),
    VoiceInfo(name: '好听女声.wav'),
    VoiceInfo(name: '孙悟空.WAV'),
    VoiceInfo(name: '小女孩.WAV'),
    VoiceInfo(name: '小鬼子.WAV'),
    VoiceInfo(name: '找今.MP3'),
    VoiceInfo(name: '承安.WAV'),
    VoiceInfo(name: '敖丙.WAV'),
    VoiceInfo(name: '曹操.WAV'),
    VoiceInfo(name: '李云龙.WAV'),
    VoiceInfo(name: '樱桃小丸子.WAV'),
    VoiceInfo(name: '沙雕男.WAV'),
    VoiceInfo(name: '海绵宝宝.WAV'),
    VoiceInfo(name: '渣渣辉.WAV'),
    VoiceInfo(name: '熊二.WAV'),
    VoiceInfo(name: '熊大.WAV'),
    VoiceInfo(name: '王也.MP3'),
    VoiceInfo(name: '王也.WAV'),
    VoiceInfo(name: '班尼特.WAV'),
    VoiceInfo(name: '甄嬛传—四郎.WAV'),
    VoiceInfo(name: '白小纯.WAV'),
    VoiceInfo(name: '纳希.WAV'),
    VoiceInfo(name: '羽西.WAV'),
    VoiceInfo(name: '老二.WAV'),
    VoiceInfo(name: '老奶奶.WAV'),
    VoiceInfo(name: '胡桃.WAV'),
    VoiceInfo(name: '舌尖.MP3'),
    VoiceInfo(name: '舌尖上的中国.WAV'),
    VoiceInfo(name: '蒋介石.WAV'),
    VoiceInfo(name: '虾仁.WAV'),
    VoiceInfo(name: '蛊真人.WAV'),
    VoiceInfo(name: '蛊真人2.WAV'),
    VoiceInfo(name: '解说2男.WAV'),
    VoiceInfo(name: '解说—魔魔.WAV'),
    VoiceInfo(name: '记录片 男声.WAV'),
    VoiceInfo(name: '逗星辰.WAV'),
    VoiceInfo(name: '逗浩轩.WAV'),
    VoiceInfo(name: '道士.WAV'),
    VoiceInfo(name: '配音云.MP3'),
    VoiceInfo(name: '配音正太.WAV'),
    VoiceInfo(name: '配音白小.MP3'),
    VoiceInfo(name: '配音雪.MP3'),
    VoiceInfo(name: '钟离.WAV'),
    VoiceInfo(name: '鱼叨叨.WAV'),
  ];

  /// 获取可用音色列表
  List<VoiceInfo> listVoices() => voices;

  // ===========================================================================
  // 文件上传
  // ===========================================================================

  /// 上传本地文件到服务端，返回服务端路径
  Future<String> uploadFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw RainfallCloudUploadError('文件不存在: $filePath');
    }
    final uri = Uri.parse('$baseUrl$_api/upload');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('files', filePath));
    return _doUpload(request);
  }

  /// 上传原始字节数据到服务端，返回服务端路径
  Future<String> uploadBytes(Uint8List bytes, String filename) async {
    final uri = Uri.parse('$baseUrl$_api/upload');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes('files', bytes, filename: filename));
    return _doUpload(request);
  }

  /// 批量上传多个本地文件，返回服务端路径列表（顺序一致）
  Future<List<String>> uploadFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) return [];
    final uri = Uri.parse('$baseUrl$_api/upload');
    final request = http.MultipartRequest('POST', uri);
    for (final p in filePaths) {
      if (!await File(p).exists()) {
        throw RainfallCloudUploadError('文件不存在: $p');
      }
      request.files.add(await http.MultipartFile.fromPath('files', p));
    }
    return _doUploadMultiple(request);
  }

  // ===========================================================================
  // 1. 单条语音合成 (/rainfall_gen_single, 28 参数 → 3 返回值)
  // ===========================================================================

  /// 单条文本语音合成
  ///
  /// [voiceFilePath] 参考音色文件路径（必须）
  /// [text] 待合成文本
  /// [emoAudioFilePath] 情感参考音频，默认复用参考音色
  Future<TTSResult> generate({
    required String voiceFilePath,
    String text = '注意看，这个男人叫小帅',
    // --- 情感向量 0.0~1.0 ---
    double emoHappy = 0,
    double emoAngry = 0,
    double emoSad = 0,
    double emoAfraid = 0,
    double emoDisgusted = 0,
    double emoMelancholic = 0,
    double emoSurprised = 0,
    double emoCalm = 0,
    // --- 情感配置 ---
    String emoText = '',
    double emoAlpha = 0.65,
    bool useEmoText = false,
    String? emoAudioFilePath,
    bool useRandom = false,
    // --- 生成参数 ---
    int maxTokensPerSegment = 120,
    bool verbose = false,
    bool generateSubtitle = false,
    // --- 输出 ---
    String outputFilename = '',
    String outputFormat = 'wav',
    // --- 高级参数 ---
    bool doSample = true,
    double topP = 0.8,
    int topK = 30,
    double temperature = 0.8,
    double lengthPenalty = 0,
    int numBeams = 3,
    double repetitionPenalty = 10,
    int maxMelTokens = 1500,
  }) async {
    final voicePath = await uploadFile(voiceFilePath);
    final emoAudioPath =
        emoAudioFilePath != null ? await uploadFile(emoAudioFilePath) : voicePath;

    // 严格按云端 28 参数顺序
    final params = <dynamic>[
      _fd(voicePath),                     // [1]  prompt
      text,                                // [2]  text
      emoHappy,                            // [3]  emo_vector1 高兴
      emoAngry,                            // [4]  emo_vector2 愤怒
      emoSad,                              // [5]  emo_vector3 悲伤
      emoAfraid,                           // [6]  emo_vector4 害怕
      emoDisgusted,                        // [7]  emo_vector5 厌恶
      emoMelancholic,                      // [8]  emo_vector6 忧郁
      emoSurprised,                        // [9]  emo_vector7 惊讶
      emoCalm,                             // [10] emo_vector8 平静
      emoText,                             // [11] single_emo_text
      emoAlpha,                            // [12] single_emo_alpha
      _cn(useEmoText),                     // [13] single_use_emo_text
      _fd(emoAudioPath),                   // [14] single_emo_audio
      _cn(useRandom),                      // [15] single_use_random
      maxTokensPerSegment.toDouble(),      // [16] max_text_tokens_per_segment
      _cn(verbose, '显示', '不显示'),        // [17] single_verbose
      _cn(generateSubtitle, '生成', '不生成'), // [18] single_need_srt
      outputFilename,                      // [19] output_file_name
      outputFormat,                        // [20] single_file_suffix
      doSample,                            // [21] param_20 (do_sample)
      topP,                                // [22] param_21 (top_p)
      topK.toDouble(),                     // [23] param_22 (top_k)
      temperature,                         // [24] param_23 (temperature)
      lengthPenalty,                       // [25] param_24 (length_penalty)
      numBeams.toDouble(),                 // [26] param_25 (num_beams)
      repetitionPenalty,                   // [27] param_26 (repetition_penalty)
      maxMelTokens.toDouble(),             // [28] param_27 (max_mel_tokens)
    ];

    final payload = await _callGradio('rainfall_gen_single', params);
    return _parseTTSResult(payload);
  }

  // ===========================================================================
  // 1b. 从字节上传音色并合成（用于 Flutter assets 场景）
  // ===========================================================================

  /// 从字节数据上传音色并合成语音
  ///
  /// [voiceBytes] 音色文件的原始字节数据
  /// [voiceName] 音色文件名（如 demo_boy.wav），同时作为缓存 key
  /// [text] 待合成文本
  Future<TTSResult> generateWithVoiceBytes({
    required Uint8List voiceBytes,
    required String voiceName,
    String text = '',
    double emoAlpha = 0.65,
    String outputFormat = 'wav',
  }) async {
    // 检查缓存，避免重复上传同一音色
    String voicePath;
    if (_voiceCache.containsKey(voiceName)) {
      voicePath = _voiceCache[voiceName]!;
    } else {
      voicePath = await uploadBytes(voiceBytes, voiceName);
      _voiceCache[voiceName] = voicePath;
      // ignore: avoid_print
      print('[CloudTTS] 上传音色 $voiceName → $voicePath');
    }

    final params = <dynamic>[
      _fd(voicePath),
      text,
      0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, // 8 emotions
      '', emoAlpha, _cn(false), _fd(voicePath), _cn(false), // emo config
      120.0, _cn(false), _cn(false), // maxTokens, verbose, srt
      '', outputFormat, // filename, format
      true, 0.8, 30.0, 0.8, 0.0, 3.0, 10.0, 1500.0, // advanced
    ];

    final payload = await _callGradio('rainfall_gen_single', params);
    // ignore: avoid_print
    print('[CloudTTS] raw payload type=${payload.runtimeType}: ${payload.toString().length > 500 ? payload.toString().substring(0, 500) : payload}');
    return _parseTTSResult(payload);
  }

  // ===========================================================================
  // 2. 批量文本合成 (/single_batch_txt_generate, 4 参数 → 1 返回值)
  // ===========================================================================

  /// 批量文本语音合成
  ///
  /// [voiceFilePath] 参考音色文件路径
  /// [txtFilePaths] 待处理的 txt 文件路径列表
  /// [interval] 每行对话间隔（秒）
  /// [useEmo] 是否使用文本对应的情感
  ///
  /// 返回生成的音频文件 URL 列表
  Future<List<String>> batchGenerate({
    required String voiceFilePath,
    required List<String> txtFilePaths,
    double interval = 0.1,
    bool useEmo = false,
  }) async {
    final voiceServerPath = await uploadFile(voiceFilePath);
    final txtServerPaths = await uploadFiles(txtFilePaths);

    final params = <dynamic>[
      _fd(voiceServerPath),                                    // [1] prompt audio
      txtServerPaths.map((p) => _fd(p)).toList(),              // [2] multi_file
      interval,                                                 // [3] interval
      _cn(useEmo),                                              // [4] need_emo
    ];

    final payload =
        await _callGradio('single_batch_txt_generate', params);
    return _parseFileList(payload);
  }

  // ===========================================================================
  // 3. 多角色对话合成 (/rainfall_quick_multi_role_text_generate, 24 参数)
  // ===========================================================================

  /// 多角色对话语音合成
  ///
  /// [roles] 角色列表（最多 10 个）
  /// [text] 剧本内容，格式：`小帅：你好！ 小美：你好呀！`
  Future<TTSResult> multiRoleGenerate({
    required List<RoleAssignment> roles,
    required String text,
    String outputFilename = '',
    String outputFormat = 'wav',
    double interval = 0.1,
  }) async {
    if (roles.isEmpty) {
      throw ArgumentError('至少需要一个角色');
    }

    // 上传所有角色音色
    final roleServerPaths = <String>[];
    for (final role in roles) {
      roleServerPaths.add(await uploadFile(role.audioFilePath));
    }

    // 空闲位复用第一个角色的音色路径
    final defaultPath = roleServerPaths.first;

    final params = <dynamic>[];

    // 10 组：name + audio
    for (var i = 0; i < 10; i++) {
      if (i < roles.length) {
        params.add(roles[i].roleName);
        params.add(_fd(roleServerPaths[i]));
      } else {
        params.add('');
        params.add(_fd(defaultPath));
      }
    }

    params.addAll([
      text,                    // [21] multi_role_text
      outputFilename,          // [22] multi_file_name
      outputFormat,            // [23] multi_file_suffix
      interval,                // [24] multi_interval
    ]);

    final payload = await _callGradio(
        'rainfall_quick_multi_role_text_generate', params);
    return _parseAudioResult(payload);
  }

  // ===========================================================================
  // 4. Excel 处理 (/handle_excel, 1 参数 → 1 返回值)
  // ===========================================================================

  /// 处理 Excel 文件，生成对应语音
  Future<List<String>> handleExcel(String excelFilePath) async {
    final serverPath = await uploadFile(excelFilePath);
    final payload =
        await _callGradio('handle_excel', [_fd(serverPath)]);
    return _parseFileList(payload);
  }

  // ===========================================================================
  // 5. 音频格式转换 (/convert_audio_format, 2 参数 → 2 返回值)
  // ===========================================================================

  /// 音频格式转换
  ///
  /// [inputFilePath] 原始音频文件路径
  /// [outputFormat] 目标格式：wav / mp3 / flac / ogg
  Future<ConvertResult> convertAudioFormat({
    required String inputFilePath,
    String outputFormat = 'mp3',
  }) async {
    final serverPath = await uploadFile(inputFilePath);
    final payload = await _callGradio(
        'convert_audio_format', [_fd(serverPath), outputFormat]);
    return _parseConvertResult(payload);
  }

  // ===========================================================================
  // 6. 从视频提取音频 (/extract_from_video, 1 dict 参数 → 2 返回值)
  // ===========================================================================

  /// 从视频文件中提取音频
  ///
  /// [videoFilePath] 视频文件路径
  /// [subtitlesFilePath] 字幕文件路径（可选）
  Future<ConvertResult> extractFromVideo({
    required String videoFilePath,
    String? subtitlesFilePath,
  }) async {
    final videoPath = await uploadFile(videoFilePath);
    final subPath =
        subtitlesFilePath != null ? await uploadFile(subtitlesFilePath) : null;

    final videoParam = <String, dynamic>{
      'video': _fd(videoPath),
      'subtitles': subPath != null ? _fd(subPath) : null,
    };

    final payload = await _callGradio('extract_from_video', [videoParam]);
    return _parseConvertResult(payload);
  }

  // ===========================================================================
  // 下载
  // ===========================================================================

  /// 下载文件到本地路径
  Future<String> downloadFile(String url, String localPath) async {
    final effectiveUrl =
        url.startsWith('http') ? url : '$baseUrl$url';
    try {
      final resp = await _httpClient
          .get(Uri.parse(effectiveUrl))
          .timeout(timeout);
      if (resp.statusCode != 200) {
        throw RainfallCloudServerError('下载失败 HTTP ${resp.statusCode}');
      }
      final file = File(localPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(resp.bodyBytes);
      return localPath;
    } on RainfallCloudError {
      rethrow;
    } catch (e) {
      throw RainfallCloudConnectionError('下载失败: $e');
    }
  }

  // ===========================================================================
  // 资源释放
  // ===========================================================================

  /// 关闭 HTTP 连接
  void close() => _httpClient.close();

  // ===========================================================================
  // 内部：上传
  // ===========================================================================

  Future<String> _doUpload(http.MultipartRequest request) async {
    try {
      final streamed = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode != 200) {
        final body = resp.body;
        throw RainfallCloudUploadError(
            '上传失败 HTTP ${resp.statusCode}: ${body.substring(0, body.length > 300 ? 300 : body.length)}');
      }
      final List<dynamic> paths = jsonDecode(resp.body) as List<dynamic>;
      if (paths.isEmpty) throw RainfallCloudUploadError('上传返回空路径');
      return paths.first.toString();
    } on RainfallCloudError {
      rethrow;
    } catch (e) {
      throw RainfallCloudUploadError('上传失败: $e');
    }
  }

  Future<List<String>> _doUploadMultiple(
      http.MultipartRequest request) async {
    try {
      final streamed = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 120));
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode != 200) {
        final body = resp.body;
        throw RainfallCloudUploadError(
            '批量上传失败 HTTP ${resp.statusCode}: ${body.substring(0, body.length > 300 ? 300 : body.length)}');
      }
      final List<dynamic> paths = jsonDecode(resp.body) as List<dynamic>;
      return paths.map((e) => e.toString()).toList();
    } on RainfallCloudError {
      rethrow;
    } catch (e) {
      throw RainfallCloudUploadError('批量上传失败: $e');
    }
  }

  // ===========================================================================
  // 内部：Gradio 协议
  // ===========================================================================

  /// 构建 Gradio FileData
  static Map<String, dynamic> _fd(String serverPath) => {
        'path': serverPath,
        'meta': {'_type': 'gradio.FileData'},
      };

  /// bool 转中文选项
  static String _cn(bool value, [String yes = '使用', String no = '不使用']) =>
      value ? yes : no;

  /// Gradio v5 两步协议：POST 提交 → SSE 获取结果
  Future<dynamic> _callGradio(String endpoint, List<dynamic> data) async {
    final callUrl = '$baseUrl$_api/call/$endpoint';

    // --- 第一步：提交任务 ---
    http.Response postResp;
    try {
      postResp = await _httpClient
          .post(
            Uri.parse(callUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'data': data}),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('timed out') || msg.contains('Timeout')) {
        throw RainfallCloudTimeoutError('提交任务超时: $e');
      }
      throw RainfallCloudConnectionError('无法连接到 $baseUrl: $e');
    }

    if (postResp.statusCode != 200) {
      final b = postResp.body;
      throw RainfallCloudServerError(
          '提交任务失败 HTTP ${postResp.statusCode}: ${b.substring(0, b.length > 500 ? 500 : b.length)}');
    }

    final Map<String, dynamic> submitResult;
    try {
      submitResult = jsonDecode(postResp.body) as Map<String, dynamic>;
    } catch (e) {
      throw RainfallCloudServerError('解析提交响应失败: $e');
    }

    final eventId = submitResult['event_id'];
    if (eventId is! String || eventId.isEmpty) {
      throw RainfallCloudServerError('未获取到 event_id');
    }

    // --- 第二步：SSE 轮询结果 ---
    final sseUrl = '$callUrl/$eventId';
    http.Response getResp;
    try {
      getResp =
          await _httpClient.get(Uri.parse(sseUrl)).timeout(timeout);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Timeout') || msg.contains('timed out')) {
        throw RainfallCloudTimeoutError(
            '获取结果超时 (${timeout.inSeconds}s)');
      }
      throw RainfallCloudConnectionError('获取结果失败: $e');
    }

    if (getResp.statusCode != 200) {
      final b = getResp.body;
      throw RainfallCloudServerError(
          '获取结果失败 HTTP ${getResp.statusCode}: ${b.substring(0, b.length > 500 ? 500 : b.length)}');
    }

    return _parseSse(getResp.body);
  }

  // ===========================================================================
  // 内部：SSE 解析
  // ===========================================================================

  /// 解析 SSE 文本，返回最后一条非 null data
  static dynamic _parseSse(String sseText) {
    dynamic lastData;

    for (final rawLine in sseText.split('\n')) {
      final line = rawLine.trim();
      if (!line.startsWith('data:')) continue;

      final payload = line.substring(5).trim();
      try {
        final decoded = jsonDecode(payload);
        if (decoded != null) lastData = decoded;
      } catch (_) {
        if (payload != 'null' && payload.isNotEmpty) lastData = payload;
      }
    }

    if (lastData is Map && lastData.containsKey('error')) {
      throw RainfallCloudSynthesisError('服务端错误: ${lastData['error']}');
    }
    return lastData;
  }

  // ===========================================================================
  // 内部：结果解析
  // ===========================================================================

  /// 从单个项中提取文件信息
  ///
  /// 处理两种格式：
  ///   - 直接 FileData: {"path": "...", "url": "...", "meta": {...}}
  ///   - Gradio 包装:   {"visible": true, "value": <FileData>, "__type__": "update"}
  ///   - 字符串路径:    "/tmp/gradio/.../file.wav"
  ({String path, String url})? _extractFileInfo(dynamic item) {
    if (item is String && item.isNotEmpty) {
      return (path: item, url: _buildFileUrl(item));
    }
    if (item is! Map) return null;

    // 展开 Gradio 包装层 {"value": ..., "__type__": "update"}
    var target = item;
    if (item.containsKey('__type__') && item.containsKey('value')) {
      final val = item['value'];
      if (val is String) {
        return (path: val, url: _buildFileUrl(val));
      }
      if (val is Map) {
        target = val;
      } else if (val == null) {
        return null;
      }
    }

    final path = (target['path'] ?? '').toString();
    var url = (target['url'] ?? '').toString();
    if (path.isEmpty && url.isEmpty) return null;

    // 相对 URL 转绝对
    if (url.isNotEmpty && !url.startsWith('http')) {
      url = '$baseUrl$url';
    }
    return (path: path, url: url.isNotEmpty ? url : _buildFileUrl(path));
  }

  /// 解析单条合成结果 [audio_preview, audio_download, srt]
  TTSResult _parseTTSResult(dynamic payload) {
    if (payload is! List || payload.isEmpty) {
      throw RainfallCloudSynthesisError('服务端返回空结果');
    }

    // 取第一个非空音频
    final audio = _extractFileInfo(payload[0]) ??
        (payload.length > 1 ? _extractFileInfo(payload[1]) : null);
    final srt =
        payload.length > 2 ? _extractFileInfo(payload[2]) : null;

    if (audio == null) {
      throw RainfallCloudSynthesisError('无法解析音频结果');
    }

    return TTSResult(
      audioPath: audio.path,
      audioUrl: audio.url,
      srtPath: srt?.path ?? '',
      srtUrl: srt?.url ?? '',
    );
  }

  /// 解析多角色结果 [audio_preview, audio_download]
  TTSResult _parseAudioResult(dynamic payload) {
    if (payload is! List || payload.isEmpty) {
      throw RainfallCloudSynthesisError('服务端返回空结果');
    }
    final info = _extractFileInfo(payload[0]) ??
        (payload.length > 1 ? _extractFileInfo(payload[1]) : null);
    if (info == null) {
      throw RainfallCloudSynthesisError('无法解析音频结果');
    }
    return TTSResult(audioPath: info.path, audioUrl: info.url);
  }

  /// 解析格式转换/视频提取结果 [preview, download]
  ConvertResult _parseConvertResult(dynamic payload) {
    if (payload is! List || payload.isEmpty) {
      throw RainfallCloudSynthesisError('服务端返回空结果');
    }
    final info = _extractFileInfo(payload[0]) ??
        (payload.length > 1 ? _extractFileInfo(payload[1]) : null);
    if (info == null) {
      throw RainfallCloudSynthesisError('无法解析结果');
    }
    return ConvertResult(audioPath: info.path, audioUrl: info.url);
  }

  /// 解析文件列表 [[file1, file2, ...]]
  List<String> _parseFileList(dynamic payload) {
    if (payload is! List || payload.isEmpty) return [];

    // 云端返回 [list_of_files]，需展开一层
    final inner = payload.first is List ? payload.first as List : payload;
    return inner
        .map((item) => _extractFileInfo(item))
        .whereType<({String path, String url})>()
        .map((info) => info.url)
        .toList();
  }

  /// 根据服务端路径构建下载 URL
  String _buildFileUrl(String path) {
    if (path.isEmpty) return '';
    final encoded = path.split('/').map(Uri.encodeComponent).join('/');
    return '$baseUrl$_api/file=$encoded';
  }
}
