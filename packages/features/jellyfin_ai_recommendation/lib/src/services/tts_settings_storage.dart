import 'package:shared_preferences/shared_preferences.dart';

import '../models/tts_models.dart';

/// TTS 设置持久化存储
class TtsSettingsStorage {
  static const _keyVoice = 'tts_voice_name';

  /// 保存 TTS 设置（音色名）
  static Future<void> save(TtsSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVoice, settings.voiceName);
  }

  /// 读取持久化的 TTS 设置
  static Future<TtsSettings?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final voice = prefs.getString(_keyVoice);
    if (voice == null) return null;
    return TtsSettings(voiceName: voice);
  }
}
