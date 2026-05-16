import 'package:shared_preferences/shared_preferences.dart';

import '../models/tts_models.dart';

/// TTS 设置持久化存储
class TtsSettingsStorage {
  static const _keyVoice = 'tts_voice_name';
  static const _keySpeed = 'tts_speed';

  /// 保存 TTS 设置（只存 voiceName 和 speed，ttsBaseUrl 由外部推导）
  static Future<void> save(TtsSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVoice, settings.voiceName);
    await prefs.setDouble(_keySpeed, settings.speed);
  }

  /// 读取持久化的 TTS 设置
  ///
  /// [ttsBaseUrl] 由外部注入（从 Jellyfin IP 推导），不持久化。
  /// 如果没有存储过，返回 null（由调用方决定默认值）。
  static Future<TtsSettings?> load({required String ttsBaseUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    final voice = prefs.getString(_keyVoice);
    if (voice == null) return null;
    return TtsSettings(
      voiceName: voice,
      speed: prefs.getDouble(_keySpeed) ?? 1.0,
      ttsBaseUrl: ttsBaseUrl,
    );
  }
}
