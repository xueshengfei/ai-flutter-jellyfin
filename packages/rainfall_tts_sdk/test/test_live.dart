import 'package:rainfall_tts_sdk/rainfall_tts_sdk.dart';

Future<void> main() async {
  final client = RainfallTTS();

  print('=== 雨落TTS Dart SDK 测试 ===');
  print('服务地址: ${client.baseUrl}');

  // 1. 健康检查
  print('\n--- 1. 健康检查 ---');
  final alive = await client.isServerAlive();
  print('服务在线: $alive');
  if (!alive) {
    print('服务未启动，测试终止。');
    client.close();
    return;
  }

  // 2. 音色列表
  print('\n--- 2. 获取音色列表 ---');
  try {
    final voices = await client.listVoices();
    print('可用音色 (${voices.length} 个):');
    for (final v in voices) {
      print('  - ${v.name}');
    }
  } catch (e) {
    print('获取音色失败: $e');
  }

  // 3. 单条合成
  print('\n--- 3. 单条语音合成测试 ---');
  try {
    final result = await client.generate('你好，这是雨落TTS Dart SDK的测试语音。');
    print('合成成功!');
    print('  audio_path: ${result.audioPath}');
    print('  audio_url:  ${result.audioUrl}');
  } catch (e) {
    print('合成失败: $e');
  }

  print('\n=== 测试完成 ===');
  client.close();
}
