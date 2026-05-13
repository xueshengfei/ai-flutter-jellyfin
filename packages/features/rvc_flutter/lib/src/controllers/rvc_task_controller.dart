import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rvc_sdk/rvc_sdk.dart';

import '../models/rvc_task.dart';

/// RVC 任务控制器
///
/// App 级生命周期，由 `Product/jellyfin_app` 创建并持有。
/// 管理服务连接、任务执行、结果播放三个核心能力。
/// 页面退出后 controller 不销毁，下次进入可恢复任务状态。
class RvcTaskController extends ChangeNotifier {
  RVCClient _client;
  String _serverUrl;

  // ---- 服务连接 ----
  ServiceStatus? _status;
  List<ModelInfo> _models = [];
  bool _isConnecting = false;
  String? _connectionError;

  // ---- 任务状态 ----
  RvcTaskSnapshot? _currentTask;

  // ---- 播放 ----
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  StreamSubscription? _playerStateSub;

  RvcTaskController({
    required String serverUrl,
    RVCClient? client,
  })  : _serverUrl = serverUrl,
        _client = client ?? RVCClient(baseUrl: serverUrl) {
    _setupAudioListener();
  }

  // ==================== 服务连接 ====================

  ServiceStatus? get status => _status;
  List<ModelInfo> get models => List.unmodifiable(_models);
  bool get isConnecting => _isConnecting;
  String? get connectionError => _connectionError;
  String get serverUrl => _serverUrl;
  bool get isConnected => _status != null && _connectionError == null;

  /// 连接 RVC 服务（获取状态 + 模型列表）
  Future<void> connect() async {
    _isConnecting = true;
    _connectionError = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _client.getStatus(),
        _client.listModels(),
      ]);

      _status = results[0] as ServiceStatus;
      _models = results[1] as List<ModelInfo>;
      _isConnecting = false;
      notifyListeners();
    } catch (e) {
      _isConnecting = false;
      _connectionError = e.toString();
      notifyListeners();
    }
  }

  /// 更新服务器地址并重新连接
  void updateServerUrl(String url) {
    if (url == _serverUrl || url.isEmpty) return;
    _serverUrl = url;
    _client.close();
    _client = RVCClient(baseUrl: url);
    _status = null;
    _models = [];
    _connectionError = null;
    _currentTask = null;
    notifyListeners();
    connect();
  }

  // ==================== 任务执行 ====================

  RvcTaskSnapshot? get currentTask => _currentTask;
  bool get hasRunningTask => _currentTask?.status == RvcTaskStatus.running;

  /// 执行音色转换
  Future<void> startConvert({
    required String modelName,
    String? inputPath,
    Uint8List? audioBytes,
    String? audioFilename,
    int f0UpKey = 0,
    F0Method f0Method = F0Method.rmvpe,
    double indexRate = 0.75,
    int filterRadius = 3,
    int resampleSr = 0,
    double protect = 0.33,
  }) async {
    final taskId = DateTime.now().microsecondsSinceEpoch.toString();
    _currentTask = RvcTaskSnapshot(
      id: taskId,
      status: RvcTaskStatus.running,
      mode: 'convert',
      sourceName: audioFilename ?? inputPath?.split(Platform.pathSeparator).last,
      modelName: modelName,
      createdAt: DateTime.now(),
    );
    notifyListeners();

    try {
      final result = await _client.convert(
        modelName: modelName,
        inputPath: inputPath,
        audioBytes: audioBytes,
        audioFilename: audioFilename ?? 'audio.wav',
        f0UpKey: f0UpKey,
        f0Method: f0Method,
        indexRate: indexRate,
        filterRadius: filterRadius,
        resampleSr: resampleSr,
        protect: protect,
      );

      if (_currentTask?.id != taskId) return;

      if (!result.success) {
        _currentTask = _currentTask!.copyWith(
          status: RvcTaskStatus.failed,
          errorMessage: '转换失败',
          completedAt: DateTime.now(),
        );
      } else {
        _currentTask = _currentTask!.copyWith(
          status: RvcTaskStatus.succeeded,
          result: result,
          completedAt: DateTime.now(),
        );
      }
      notifyListeners();
    } catch (e) {
      if (_currentTask?.id != taskId) return;
      _currentTask = _currentTask!.copyWith(
        status: RvcTaskStatus.failed,
        errorMessage: e.toString(),
        completedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  /// 执行一键翻唱
  Future<void> startCover({
    required String modelName,
    String? inputPath,
    Uint8List? audioBytes,
    String? audioFilename,
    int f0UpKey = 0,
    F0Method f0Method = F0Method.rmvpe,
    double indexRate = 0.75,
    int filterRadius = 3,
    int resampleSr = 0,
    double protect = 0.33,
    double vocalVol = 1.0,
    double instVol = 0.8,
  }) async {
    final taskId = DateTime.now().microsecondsSinceEpoch.toString();
    _currentTask = RvcTaskSnapshot(
      id: taskId,
      status: RvcTaskStatus.running,
      mode: 'cover',
      sourceName: audioFilename ?? inputPath?.split(Platform.pathSeparator).last,
      modelName: modelName,
      createdAt: DateTime.now(),
    );
    notifyListeners();

    try {
      final result = await _client.cover(
        modelName: modelName,
        inputPath: inputPath,
        audioBytes: audioBytes,
        audioFilename: audioFilename ?? 'audio.wav',
        f0UpKey: f0UpKey,
        f0Method: f0Method,
        indexRate: indexRate,
        filterRadius: filterRadius,
        resampleSr: resampleSr,
        protect: protect,
        vocalVol: vocalVol,
        instVol: instVol,
      );

      if (_currentTask?.id != taskId) return;

      if (!result.success) {
        _currentTask = _currentTask!.copyWith(
          status: RvcTaskStatus.failed,
          errorMessage: '翻唱失败',
          completedAt: DateTime.now(),
        );
      } else {
        _currentTask = _currentTask!.copyWith(
          status: RvcTaskStatus.succeeded,
          result: result,
          completedAt: DateTime.now(),
        );
      }
      notifyListeners();
    } catch (e) {
      if (_currentTask?.id != taskId) return;
      _currentTask = _currentTask!.copyWith(
        status: RvcTaskStatus.failed,
        errorMessage: e.toString(),
        completedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  /// 清除当前任务结果
  void clearTask() {
    _currentTask = null;
    _stopPlayback();
    notifyListeners();
  }

  // ==================== 结果播放 ====================

  bool get isPlaying => _isPlaying;
  AudioPlayer get audioPlayer => _audioPlayer;

  /// 切换播放/停止
  Future<void> togglePlayback() async {
    if (_isPlaying) {
      _stopPlayback();
      return;
    }

    final playUrl = _currentTask?.playUrl;
    if (playUrl == null) return;

    try {
      await _audioPlayer.setUrl(playUrl);
      await _audioPlayer.play();
      _isPlaying = true;
      notifyListeners();
    } catch (_) {
      // 播放失败静默处理
    }
  }

  void _stopPlayback() {
    _audioPlayer.stop();
    _isPlaying = false;
    notifyListeners();
  }

  void _setupAudioListener() {
    _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        notifyListeners();
      }
    });
  }

  // ==================== 生命周期 ====================

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _audioPlayer.dispose();
    _client.close();
    super.dispose();
  }
}
