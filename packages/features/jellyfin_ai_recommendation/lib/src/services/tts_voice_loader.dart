import 'package:flutter/services.dart';

/// 从 Flutter assets 加载音色文件的原始字节
class TtsVoiceLoader {
  static final Map<String, Uint8List> _cache = {};

  /// 加载指定音色文件
  ///
  /// [voiceName] 音色文件名，如 demo_boy.wav
  /// 首次加载后缓存到内存，避免重复读 assets
  static Future<Uint8List> load(String voiceName) async {
    if (_cache.containsKey(voiceName)) return _cache[voiceName]!;
    final data = await rootBundle.load(
      'packages/jellyfin_ai_recommendation/assets/prompt_audio/$voiceName',
    );
    final bytes = data.buffer.asUint8List();
    _cache[voiceName] = bytes;
    return bytes;
  }

  /// 清除缓存
  static void clearCache() => _cache.clear();
}
