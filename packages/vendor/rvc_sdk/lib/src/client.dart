import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'exceptions.dart';
import 'models.dart';

/// RVC 语音转换 API 客户端
///
/// ```dart
/// final client = RVCClient(baseUrl: 'http://192.168.1.100:9880');
/// final result = await client.convert(
///   modelName: 'model.pth',
///   inputPath: 'D:/song.wav',
///   f0UpKey: 12,
/// );
/// // 播放: client.getPlayUrl(result)
/// // 下载: client.getDownloadUrl(result)
/// ```
final class RVCClient {
  final String _baseUrl;
  final Duration _timeout;
  final http.Client _httpClient;

  RVCClient({
    required String baseUrl,
    Duration timeout = const Duration(minutes: 5),
    http.Client? httpClient,
  })  : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _timeout = timeout,
        _httpClient = httpClient ?? http.Client();

  // =========================================================================
  // 系统接口
  // =========================================================================

  Future<ServiceStatus> getStatus() async {
    final json = await _getJson('/');
    return ServiceStatus.fromJson(json);
  }

  // =========================================================================
  // 模型接口
  // =========================================================================

  Future<List<ModelInfo>> listModels() async {
    final json = await _get('/models');
    return (json as List<dynamic>)
        .map((e) => ModelInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> listIndices() async {
    final json = await _get('/indices');
    return (json as List<dynamic>).cast<String>();
  }

  // =========================================================================
  // 转换接口
  // =========================================================================

  /// 转换音频，返回播放地址和下载地址。
  ///
  /// ```dart
  /// final result = await client.convert(
  ///   modelName: 'TaylorSwift.pth',
  ///   inputPath: 'D:/song.wav',
  ///   f0UpKey: 12,
  /// );
  /// // 播放
  /// AudioElement(client.getPlayUrl(result)).play();
  /// // 下载
  /// // client.getDownloadUrl(result)
  /// ```
  Future<ConvertResult> convert({
    required String modelName,
    String? inputPath,
    Uint8List? audioBytes,
    String? audioFilename,
    int f0UpKey = 0,
    F0Method f0Method = F0Method.rmvpe,
    double indexRate = 0.75,
    int filterRadius = 3,
    int resampleSr = 0,
    double rmsMixRate = 1.0,
    double protect = 0.33,
    String? indexFile,
  }) async {
    _requireInput(inputPath, audioBytes);

    final params = ConvertParams(
      modelName: modelName,
      inputPath: inputPath,
      f0UpKey: f0UpKey,
      f0Method: f0Method,
      indexRate: indexRate,
      filterRadius: filterRadius,
      resampleSr: resampleSr,
      rmsMixRate: rmsMixRate,
      protect: protect,
      indexFile: indexFile,
    );

    final resp = await _doPostMultipart(
      '/convert',
      params: params,
      audioBytes: audioBytes,
      audioFilename: audioFilename,
    );

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return ConvertResult.fromJson(json);
  }

  /// 转换并从服务端下载到本地 Uint8List
  Future<Uint8List> convertAndDownload({
    required String modelName,
    String? inputPath,
    Uint8List? audioBytes,
    String? audioFilename,
    int f0UpKey = 0,
    F0Method f0Method = F0Method.rmvpe,
    double indexRate = 0.75,
    int filterRadius = 3,
    int resampleSr = 0,
    double rmsMixRate = 1.0,
    double protect = 0.33,
    String? indexFile,
  }) async {
    final result = await convert(
      modelName: modelName,
      inputPath: inputPath,
      audioBytes: audioBytes,
      audioFilename: audioFilename,
      f0UpKey: f0UpKey,
      f0Method: f0Method,
      indexRate: indexRate,
      filterRadius: filterRadius,
      resampleSr: resampleSr,
      rmsMixRate: rmsMixRate,
      protect: protect,
      indexFile: indexFile,
    );

    final url = getDownloadUrl(result);
    final resp = await _httpClient.get(Uri.parse(url)).timeout(_timeout);
    return resp.bodyBytes;
  }

  /// 转换音频，在服务端保存文件并返回结果（适合同机场景）。
  Future<ConvertFileResult> convertServerSave({
    required String modelName,
    String? inputPath,
    Uint8List? audioBytes,
    String? audioFilename,
    int f0UpKey = 0,
    F0Method f0Method = F0Method.rmvpe,
    double indexRate = 0.75,
    int filterRadius = 3,
    int resampleSr = 0,
    double rmsMixRate = 1.0,
    double protect = 0.33,
    String? indexFile,
    String? outputDir,
  }) async {
    _requireInput(inputPath, audioBytes);

    final params = ConvertParams(
      modelName: modelName,
      inputPath: inputPath,
      f0UpKey: f0UpKey,
      f0Method: f0Method,
      indexRate: indexRate,
      filterRadius: filterRadius,
      resampleSr: resampleSr,
      rmsMixRate: rmsMixRate,
      protect: protect,
      indexFile: indexFile,
    );

    final extraParams = <String, String>{};
    if (outputDir != null) extraParams['output_dir'] = outputDir;

    final resp = await _doPostMultipart(
      '/convert/file',
      params: params,
      extraParams: extraParams,
      audioBytes: audioBytes,
      audioFilename: audioFilename,
    );

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final result = ConvertFileResult.fromJson(json);

    if (!result.success) {
      throw RVCConvertError(result.message);
    }

    return result;
  }

  // =========================================================================
  // 一键翻唱接口
  // =========================================================================

  /// 一键AI翻唱：人声分离 → 去混响 → RVC音色转换 → AI混音。
  ///
  /// 输入一首完整的歌曲（含伴奏），自动分离人声、转换音色、混音输出成品。
  ///
  /// ```dart
  /// final result = await client.cover(
  ///   modelName: 'TaylorSwift.pth',
  ///   inputPath: 'D:/song.mp3',
  ///   f0UpKey: 12,
  /// );
  /// // 播放: client.getPlayUrl(result)
  /// ```
  Future<CoverResult> cover({
    required String modelName,
    String? inputPath,
    Uint8List? audioBytes,
    String? audioFilename,
    int f0UpKey = 0,
    F0Method f0Method = F0Method.rmvpe,
    double indexRate = 0.75,
    int filterRadius = 3,
    int resampleSr = 0,
    double rmsMixRate = 1.0,
    double protect = 0.33,
    String? indexFile,
    double vocalVol = 1.0,
    double instVol = 0.8,
  }) async {
    _requireInput(inputPath, audioBytes);

    final params = ConvertParams(
      modelName: modelName,
      inputPath: inputPath,
      f0UpKey: f0UpKey,
      f0Method: f0Method,
      indexRate: indexRate,
      filterRadius: filterRadius,
      resampleSr: resampleSr,
      rmsMixRate: rmsMixRate,
      protect: protect,
      indexFile: indexFile,
    );

    final extraParams = <String, String>{
      'vocal_vol': vocalVol.toString(),
      'inst_vol': instVol.toString(),
    };

    final resp = await _doPostMultipart(
      '/cover',
      params: params,
      extraParams: extraParams,
      audioBytes: audioBytes,
      audioFilename: audioFilename,
    );

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return CoverResult.fromJson(json);
  }

  /// 一键AI翻唱，然后从服务端下载成品音频字节。
  Future<Uint8List> coverAndDownload({
    required String modelName,
    String? inputPath,
    Uint8List? audioBytes,
    String? audioFilename,
    int f0UpKey = 0,
    F0Method f0Method = F0Method.rmvpe,
    double indexRate = 0.75,
    int filterRadius = 3,
    int resampleSr = 0,
    double rmsMixRate = 1.0,
    double protect = 0.33,
    String? indexFile,
    double vocalVol = 1.0,
    double instVol = 0.8,
  }) async {
    final result = await cover(
      modelName: modelName,
      inputPath: inputPath,
      audioBytes: audioBytes,
      audioFilename: audioFilename,
      f0UpKey: f0UpKey,
      f0Method: f0Method,
      indexRate: indexRate,
      filterRadius: filterRadius,
      resampleSr: resampleSr,
      rmsMixRate: rmsMixRate,
      protect: protect,
      indexFile: indexFile,
      vocalVol: vocalVol,
      instVol: instVol,
    );

    final url = '$_baseUrl${result.downloadUrl}';
    final resp = await _httpClient.get(Uri.parse(url)).timeout(_timeout);
    return resp.bodyBytes;
  }

  // =========================================================================
  // URL 辅助
  // =========================================================================

  /// 获取完整播放 URL（支持 ConvertResult 和 CoverResult）
  String getPlayUrl(dynamic result) =>
      '$_baseUrl${result.playUrl}';

  /// 获取完整下载 URL（支持 ConvertResult 和 CoverResult）
  String getDownloadUrl(dynamic result) =>
      '$_baseUrl${result.downloadUrl}';

  // =========================================================================
  // 资源释放
  // =========================================================================

  void close() => _httpClient.close();

  // =========================================================================
  // 内部方法
  // =========================================================================

  void _requireInput(String? inputPath, Uint8List? audioBytes) {
    if (inputPath == null && audioBytes == null) {
      throw ArgumentError('inputPath 和 audioBytes 必须提供其中一个');
    }
  }

  Future<dynamic> _get(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final resp = await _httpClient
        .get(uri, headers: _jsonHeaders)
        .timeout(_timeout);
    _checkStatus(resp);
    return jsonDecode(resp.body);
  }

  Future<Map<String, dynamic>> _getJson(String path) async =>
      (await _get(path)) as Map<String, dynamic>;

  Future<http.Response> _doPostMultipart(
    String path, {
    required ConvertParams params,
    Map<String, String>? extraParams,
    Uint8List? audioBytes,
    String? audioFilename,
  }) async {
    final allParams = <String, String>{
      ...params.toQueryParams(),
      ...?extraParams,
    };
    final uri =
        Uri.parse('$_baseUrl$path').replace(queryParameters: allParams);

    final request = http.MultipartRequest('POST', uri);

    if (audioBytes != null) {
      final filename = audioFilename ?? 'audio.wav';
      request.files.add(
        http.MultipartFile.fromBytes('audio', audioBytes, filename: filename),
      );
    }

    final streamed = await request.send().timeout(_timeout);
    final resp = await http.Response.fromStream(streamed).timeout(_timeout);
    _checkStatus(resp);
    return resp;
  }

  static void _checkStatus(http.Response resp) {
    if (resp.statusCode >= 400) {
      String detail;
      try {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        detail = body['detail'] as String? ?? resp.body;
      } catch (_) {
        detail = resp.body;
      }
      throw RVCApiError(resp.statusCode, detail);
    }
  }

  static const _jsonHeaders = {'Accept': 'application/json'};
}
