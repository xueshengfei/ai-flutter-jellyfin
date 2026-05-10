import 'package:rainfall_tts_sdk/rainfall_tts_sdk.dart';

Future<void> main() async {
  final client = RainfallTTS();

  print('=== 雨落TTS 多音色测试 ===');

  // 1. 健康检查
  final alive = await client.isServerAlive();
  print('服务在线: $alive');
  if (!alive) {
    print('服务未启动，测试终止。');
    client.close();
    return;
  }

  // 2. 获取音色列表
  print('\n--- 获取音色列表 ---');
  final voices = await client.listVoices();
  print('可用音色共 ${voices.length} 个');
  if (voices.isNotEmpty) {
    print('前10个: ${voices.take(10).map((v) => v.name).join(", ")}');
  }

  // 3. 测试多个音色
  final testVoices = <String>[
    'demo_boy.wav',
    'demo_girl.wav',
    'en.wav',
    '女生.wav',
    '男生.wav',
    '好听女声.wav',
    '云.wav',
  ];

  for (final voice in testVoices) {
    print('\n=== 测试音色: $voice ===');
    try {
      final result = await client.generate(
        '你好，这是雨落TTS的测试语音。',
        voice: voice,
      );
      print('  成功!');
      print('  audioPath: ${result.audioPath}');
      print('  audioUrl:  ${result.audioUrl}');
    } catch (e) {
      print('  失败: $e');
    }
  }

  print('\n=== 测试完成 ===');
  client.close();
}
