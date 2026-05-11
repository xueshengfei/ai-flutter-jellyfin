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
    for (final seg in _segments) {
      _synthesizeSegment(seg.index);
    }
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
      for (final seg in _segments) {
        _synthesizeSegment(seg.index);
      }
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
    await _player.stop();
    _buffer.clear();
    _segments.clear();
    _playCursor = 0;
    _inputDone = false;
    _synthesizing.clear();
    _state = TtsPlaybackState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _player.dispose();
    _ttsClient.close();
    super.dispose();
  }

  // ─────────────────────────────────────────
  // 分句
  // ─────────────────────────────────────────

  static final _sentenceEnd = RegExp(r'[。？！；…\n]');

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
        if (s.isNotEmpty) result.add(s);
        start = i + 1;
      }
    }
    if (start < text.length) {
      final r = text.substring(start).trim();
      if (r.isNotEmpty) result.add(r);
    }
    return result;
  }

  void _flushBuffer() {
    final text = _buffer.toString().trim();
    _buffer.clear();
    if (text.isEmpty) return;
    for (final part in _splitSentences(text)) {
      final clean = _stripMarkdown(part);
      if (clean.trim().isEmpty) continue;
      _segments.add(TtsSegment(index: _segments.length, text: clean.trim()));
      _synthesizeSegment(_segments.length - 1);
    }
    _tryStartPlayback();
  }

  // ─────────────────────────────────────────
  // Markdown 清理
  // ─────────────────────────────────────────

  static String _stripMarkdown(String text) {
    var r = text;
    r = r.replaceAll(RegExp(r'```\w*\n[\s\S]*?\n```'), '');
    r = r.replaceAll(RegExp(r'```\w*'), '');
    r = r.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    r = r.replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1');
    r = r.replaceAll(RegExp(r'\*(.+?)\*'), r'$1');
    r = r.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    r = r.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
    r = r.replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), r'$1');
    r = r.replaceAll(RegExp(r'^[\-\*\+]\s+', multiLine: true), '');
    r = r.replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '');
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
