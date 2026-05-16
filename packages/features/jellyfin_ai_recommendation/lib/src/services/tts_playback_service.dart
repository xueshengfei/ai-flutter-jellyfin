import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rainfall_tts_sdk/rainfall_tts_sdk.dart';

import '../models/tts_models.dart';

/// TTS 语音播报服务
///
/// 流程：SSE tokens → SentenceBuffer → 分句 → 并发 TTS 合成 → 顺序播放队列
class TtsPlaybackService extends ChangeNotifier {
  TtsSettings _settings;
  late final AudioPlayer _player;
  RainfallTTS _ttsClient;

  final StringBuffer _buffer = StringBuffer();
  final List<TtsSegment> _segments = [];
  int _playCursor = 0;
  TtsPlaybackState _state = TtsPlaybackState.idle;
  bool _inputDone = false;
  final Set<int> _synthesizing = {};
  StreamSubscription? _playerSub;

  /// 最大并发合成数（避免后端过载排队）
  static const _maxConcurrent = 2;

  TtsPlaybackService({TtsSettings settings = const TtsSettings()})
      : _settings = settings,
        _ttsClient = RainfallTTS(baseUrl: settings.ttsBaseUrl) {
    _player = AudioPlayer();
    _listenPlayerState();
  }

  TtsPlaybackState get state => _state;
  TtsSettings get settings => _settings;

  void updateSettings(TtsSettings newSettings) {
    _settings = newSettings;
    _ttsClient.close();
    _ttsClient = RainfallTTS(baseUrl: newSettings.ttsBaseUrl);
  }

  // ─────────────────────────────────────────
  // 公开 API
  // ─────────────────────────────────────────

  void feedToken(String token) {
    if (_state == TtsPlaybackState.idle) {
      _state = TtsPlaybackState.preparing;
      notifyListeners();
    }
    _buffer.write(token);
    if (_endsWithSentenceBoundary(_buffer.toString())) {
      _flushBuffer();
    }
  }

  void flushRemaining() {
    _inputDone = true;
    if (_buffer.isNotEmpty) _flushBuffer();
    _tryStartPlayback();
  }

  Future<void> playFullText(String text) {
    stop();
    _inputDone = true;
    final parts = _splitSentences(text);
    for (var i = 0; i < parts.length; i++) {
      final clean = _stripMarkdown(parts[i]);
      if (clean.trim().isEmpty) continue;
      _segments.add(TtsSegment(index: _segments.length, text: clean.trim()));
    }
    if (_segments.isEmpty) return Future.value();
    _state = TtsPlaybackState.preparing;
    notifyListeners();
    _scheduleSynthesis();
    _tryStartPlayback();
    return Future.value();
  }

  Future<void> play() async {
    if (_state == TtsPlaybackState.paused) {
      await _player.play();
      _state = TtsPlaybackState.playing;
      notifyListeners();
    } else if (_state == TtsPlaybackState.idle ||
        _state == TtsPlaybackState.completed) {
      _playCursor = 0;
      _resetSegmentsState();
      _state = TtsPlaybackState.preparing;
      notifyListeners();
      _scheduleSynthesis();
      _tryStartPlayback();
    }
  }

  Future<void> pause() async {
    if (_state == TtsPlaybackState.playing) {
      await _player.pause();
      _state = TtsPlaybackState.paused;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (_isDisposed) return;
    await _player.stop();
    _buffer.clear();
    _segments.clear();
    _playCursor = 0;
    _inputDone = false;
    _synthesizing.clear();
    _state = TtsPlaybackState.idle;
    notifyListeners();
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _playerSub?.cancel();
    _player.stop();
    _player.dispose();
    _ttsClient.close();
    super.dispose();
  }

  // ─────────────────────────────────────────
  // 分句
  // ─────────────────────────────────────────

  static final _sentenceEnd = RegExp(r'[。？！；…\n]');

  /// 逗号/顿号也作为分句点（缩短单句长度，降低 TTS 延迟）
  static final _clauseEnd = RegExp(r'[，,、：:]');

  /// 单句最大字符数（超过会在逗号处拆分，降低 TTS 合成延迟）
  static const _maxSentenceLen = 40;

  bool _endsWithSentenceBoundary(String text) {
    if (text.isEmpty) return false;
    return _sentenceEnd.hasMatch(text[text.length - 1]);
  }

  List<String> _splitSentences(String text) {
    final result = <String>[];
    var start = 0;
    for (var i = 0; i < text.length; i++) {
      if (_sentenceEnd.hasMatch(text[i])) {
        final s = text.substring(start, i + 1).trim();
        if (s.isNotEmpty) result.addAll(_splitLongSentence(s));
        start = i + 1;
      }
    }
    if (start < text.length) {
      final r = text.substring(start).trim();
      if (r.isNotEmpty) result.addAll(_splitLongSentence(r));
    }
    return result;
  }

  /// 如果单句太长，在逗号处再拆分（短句 TTS 合成更快）
  List<String> _splitLongSentence(String sentence) {
    if (sentence.length <= _maxSentenceLen) return [sentence];
    final result = <String>[];
    var start = 0;
    for (var i = 0; i < sentence.length; i++) {
      if (_clauseEnd.hasMatch(sentence[i])) {
        final s = sentence.substring(start, i + 1).trim();
        if (s.isNotEmpty) result.add(s);
        start = i + 1;
      }
    }
    if (start < sentence.length) {
      final r = sentence.substring(start).trim();
      if (r.isNotEmpty) result.add(r);
    }
    // 如果拆分后仍然有超过长度的，直接返回原句
    return result.isEmpty ? [sentence] : result;
  }

  void _flushBuffer() {
    final text = _buffer.toString().trim();
    _buffer.clear();
    if (text.isEmpty) return;
    for (final part in _splitSentences(text)) {
      final clean = _stripMarkdown(part);
      if (clean.trim().isEmpty) continue;
      _segments.add(TtsSegment(index: _segments.length, text: clean.trim()));
    }
    // 启动合成（受并发数限制）
    _scheduleSynthesis();
    _tryStartPlayback();
  }

  /// 调度合成任务，控制并发数不超过 _maxConcurrent
  void _scheduleSynthesis() {
    for (var i = 0; i < _segments.length; i++) {
      if (_synthesizing.length >= _maxConcurrent) break;
      if (_segments[i].state == TtsSegmentState.pending) {
        _synthesizeSegment(i);
      }
    }
  }

  // ─────────────────────────────────────────
  // Markdown 清理
  // ─────────────────────────────────────────

  static String _stripMarkdown(String text) {
    var r = text;
    // 代码块
    r = r.replaceAll(RegExp(r'```\w*\n[\s\S]*?\n```'), '');
    r = r.replaceAll(RegExp(r'```\w*'), '');
    r = r.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    // 加粗/斜体
    r = r.replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1');
    r = r.replaceAll(RegExp(r'\*(.+?)\*'), r'$1');
    r = r.replaceAll(RegExp(r'__(.+?)__'), r'$1');
    r = r.replaceAll(RegExp(r'_([^_]+)_'), r'$1');
    // 标题
    r = r.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    // 链接/图片
    r = r.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
    r = r.replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), r'$1');
    // 列表
    r = r.replaceAll(RegExp(r'^[\-\*\+]\s+', multiLine: true), '');
    r = r.replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '');
    // 表格分隔线
    r = r.replaceAll(RegExp(r'^\|?[\s\-:]+\|[\s\-:|]+\|?$', multiLine: true), '');
    r = r.replaceAll(RegExp(r'\|'), ' ');
    // 引用符号 >
    r = r.replaceAll(RegExp(r'^>\s*', multiLine: true), '');
    // 水平分割线
    r = r.replaceAll(RegExp(r'^[\-\*\_]{3,}\s*$', multiLine: true), '');
    // HTML 标签
    r = r.replaceAll(RegExp(r'<[^>]+>'), '');
    // 残留的 Markdown 特殊符号（不在 CJK 文本中间的）
    r = r.replaceAll(RegExp(r'[#*~`<>]'), '');
    // 合并多余空白
    r = r.replaceAll(RegExp(r'\s+'), ' ');
    return r.trim();
  }

  // ─────────────────────────────────────────
  // TTS 合成
  // ─────────────────────────────────────────

  Future<void> _synthesizeSegment(int index) async {
    if (index < 0 || index >= _segments.length) return;
    if (_synthesizing.contains(index)) return;
    final seg = _segments[index];
    if (seg.state != TtsSegmentState.pending) return;

    _synthesizing.add(index);
    _updateSegment(index, state: TtsSegmentState.synthesizing);

    try {
      final client = RainfallTTS(baseUrl: _settings.ttsBaseUrl);
      try {
        final result = await client.generate(
          seg.text,
          voice: _settings.voiceName,
          speed: _settings.speed,
          outputFormat: 'wav',
        );
        if (result.audioUrl.isNotEmpty) {
          _updateSegment(index,
              state: TtsSegmentState.ready, audioUrl: result.audioUrl);
        } else {
          _updateSegment(index,
              state: TtsSegmentState.error, errorMessage: '音频 URL 为空');
        }
      } finally {
        client.close();
      }
    } catch (e) {
      _updateSegment(index,
          state: TtsSegmentState.error, errorMessage: e.toString());
    } finally {
      _synthesizing.remove(index);
      _scheduleSynthesis(); // 完成后调度下一段
      _tryStartPlayback();
    }
  }

  void _updateSegment(int index,
      {TtsSegmentState? state, String? audioUrl, String? errorMessage}) {
    if (index < 0 || index >= _segments.length) return;
    _segments[index] = _segments[index].copyWith(
      state: state,
      audioUrl: audioUrl,
      errorMessage: errorMessage,
    );
    notifyListeners();
  }

  // ─────────────────────────────────────────
  // 播放队列
  // ─────────────────────────────────────────

  void _tryStartPlayback() {
    if (_state == TtsPlaybackState.playing ||
        _state == TtsPlaybackState.paused) return;
    _playNextReady();
  }

  void _playNextReady() {
    while (_playCursor < _segments.length) {
      final seg = _segments[_playCursor];
      if (seg.state == TtsSegmentState.ready) {
        _playSegment(_playCursor);
        return;
      } else if (seg.state == TtsSegmentState.error) {
        _playCursor++;
        continue;
      } else {
        return;
      }
    }
    if (_inputDone && _playCursor >= _segments.length) {
      if (_segments.isEmpty ||
          _segments.every((s) => s.state == TtsSegmentState.error)) {
        _state = TtsPlaybackState.error;
      } else {
        _state = TtsPlaybackState.completed;
      }
      notifyListeners();
    }
  }

  Future<void> _playSegment(int index) async {
    final seg = _segments[index];
    if (seg.audioUrl.isEmpty) {
      _playCursor++;
      _playNextReady();
      return;
    }
    try {
      _updateSegment(index, state: TtsSegmentState.playing);
      _state = TtsPlaybackState.playing;
      notifyListeners();
      await _player.setUrl(seg.audioUrl);
      await _player.play();
    } catch (e) {
      _updateSegment(index,
          state: TtsSegmentState.error, errorMessage: '播放失败: $e');
      _playCursor++;
      _playNextReady();
    }
  }

  void _listenPlayerState() {
    _playerSub = _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        if (_playCursor < _segments.length) {
          _updateSegment(_playCursor, state: TtsSegmentState.played);
        }
        _playCursor++;
        _playNextReady();
      }
    });
  }

  void _resetSegmentsState() {
    for (var i = 0; i < _segments.length; i++) {
      _segments[i] = _segments[i].copyWith(
        state: TtsSegmentState.pending,
        audioUrl: '',
        errorMessage: '',
      );
    }
  }
}
