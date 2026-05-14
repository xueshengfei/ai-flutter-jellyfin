import 'dart:async';

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
  final Map<String, RvcTaskSnapshot> _tasksBySourceKey = {};
  String? _activeSourceKey;
  String? _playingTaskId;

  // ---- 播放 ----
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  StreamSubscription? _playerStateSub;

  RvcTaskController({
    required String serverUrl,
    RVCClient? client,
  })  : _serverUrl = serverUrl,
        _client = client ?? RVCClient(baseUrl: serverUrl);

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
    _tasksBySourceKey.clear();
    _activeSourceKey = null;
    _playingTaskId = null;
    notifyListeners();
    connect();
  }

  // ==================== 任务执行 ====================

  RvcTaskSnapshot? get currentTask => activeTask;
  RvcTaskSnapshot? get activeTask => taskForSource(_activeSourceKey);
  List<RvcTaskSnapshot> get tasks {
    final sorted = _tasksBySourceKey.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List.unmodifiable(sorted);
  }

  bool get hasRunningTask => activeTask?.status == RvcTaskStatus.running;
  int get runningTaskCount => _tasksBySourceKey.values
      .where((task) => task.status == RvcTaskStatus.running)
      .length;
  String? get activeSourceKey => _activeSourceKey;

  String activateSource({String? inputPath, String? audioFilename}) {
    final sourceKey = _sourceKeyFor(
      inputPath: inputPath,
      audioFilename: audioFilename,
    );
    _activeSourceKey = sourceKey;
    notifyListeners();
    return sourceKey;
  }

  RvcTaskSnapshot? taskForSource(String? sourceKey) {
    if (sourceKey == null || sourceKey.isEmpty) return null;
    return _tasksBySourceKey[sourceKey];
  }

  bool hasRunningTaskForSource(String? sourceKey) =>
      taskForSource(sourceKey)?.status == RvcTaskStatus.running;

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
    final sourceKey = activateSource(
      inputPath: inputPath,
      audioFilename: audioFilename,
    );
    final taskId = DateTime.now().microsecondsSinceEpoch.toString();
    _tasksBySourceKey[sourceKey] = RvcTaskSnapshot(
      id: taskId,
      status: RvcTaskStatus.running,
      sourceKey: sourceKey,
      sourcePath: inputPath,
      mode: 'convert',
      sourceName: _sourceNameFor(inputPath, audioFilename),
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

      if (_tasksBySourceKey[sourceKey]?.id != taskId) return;

      if (!result.success) {
        _tasksBySourceKey[sourceKey] = _tasksBySourceKey[sourceKey]!.copyWith(
          status: RvcTaskStatus.failed,
          errorMessage: '转换失败',
          completedAt: DateTime.now(),
        );
      } else {
        _tasksBySourceKey[sourceKey] = _tasksBySourceKey[sourceKey]!.copyWith(
          status: RvcTaskStatus.succeeded,
          result: result,
          completedAt: DateTime.now(),
        );
      }
      notifyListeners();
    } catch (e) {
      if (_tasksBySourceKey[sourceKey]?.id != taskId) return;
      _tasksBySourceKey[sourceKey] = _tasksBySourceKey[sourceKey]!.copyWith(
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
    final sourceKey = activateSource(
      inputPath: inputPath,
      audioFilename: audioFilename,
    );
    final taskId = DateTime.now().microsecondsSinceEpoch.toString();
    _tasksBySourceKey[sourceKey] = RvcTaskSnapshot(
      id: taskId,
      status: RvcTaskStatus.running,
      sourceKey: sourceKey,
      sourcePath: inputPath,
      mode: 'cover',
      sourceName: _sourceNameFor(inputPath, audioFilename),
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

      if (_tasksBySourceKey[sourceKey]?.id != taskId) return;

      if (!result.success) {
        _tasksBySourceKey[sourceKey] = _tasksBySourceKey[sourceKey]!.copyWith(
          status: RvcTaskStatus.failed,
          errorMessage: '翻唱失败',
          completedAt: DateTime.now(),
        );
      } else {
        _tasksBySourceKey[sourceKey] = _tasksBySourceKey[sourceKey]!.copyWith(
          status: RvcTaskStatus.succeeded,
          result: result,
          completedAt: DateTime.now(),
        );
      }
      notifyListeners();
    } catch (e) {
      if (_tasksBySourceKey[sourceKey]?.id != taskId) return;
      _tasksBySourceKey[sourceKey] = _tasksBySourceKey[sourceKey]!.copyWith(
        status: RvcTaskStatus.failed,
        errorMessage: e.toString(),
        completedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  /// 清除当前任务结果
  void clearTask() {
    clearTaskForSource(_activeSourceKey);
  }

  void clearTaskForSource(String? sourceKey) {
    if (sourceKey == null || sourceKey.isEmpty) return;
    final removed = _tasksBySourceKey.remove(sourceKey);
    if (removed?.id == _playingTaskId) {
      _stopPlayback();
    }
    notifyListeners();
  }

  // ==================== 结果播放 ====================

  bool get isPlaying => _isPlaying;
  AudioPlayer get audioPlayer => _ensureAudioPlayer();

  /// 切换播放/停止
  Future<void> togglePlayback() async {
    if (_isPlaying) {
      _stopPlayback();
      return;
    }

    final task = activeTask;
    final playUrl = task?.playUrl;
    if (playUrl == null) return;

    try {
      final player = _ensureAudioPlayer();
      await player.setUrl(playUrl);
      await player.play();
      _playingTaskId = task?.id;
      _isPlaying = true;
      notifyListeners();
    } catch (_) {
      // 播放失败静默处理
    }
  }

  void _stopPlayback() {
    _audioPlayer?.stop();
    _isPlaying = false;
    _playingTaskId = null;
    notifyListeners();
  }

  String _sourceKeyFor({String? inputPath, String? audioFilename}) {
    if (inputPath != null && inputPath.isNotEmpty) return inputPath;
    if (audioFilename != null && audioFilename.isNotEmpty) {
      return 'manual:$audioFilename';
    }
    return 'manual:audio';
  }

  String? _sourceNameFor(String? inputPath, String? audioFilename) {
    if (audioFilename != null && audioFilename.isNotEmpty) {
      return audioFilename;
    }
    if (inputPath == null || inputPath.isEmpty) return null;
    return inputPath.split(RegExp(r'[\\/]')).last;
  }

  AudioPlayer _ensureAudioPlayer() {
    final existing = _audioPlayer;
    if (existing != null) return existing;
    final player = AudioPlayer();
    _audioPlayer = player;
    _playerStateSub = player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        _playingTaskId = null;
        notifyListeners();
      }
    });
    return player;
  }

  // ==================== 生命周期 ====================

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _audioPlayer?.dispose();
    _client.close();
    super.dispose();
  }
}
