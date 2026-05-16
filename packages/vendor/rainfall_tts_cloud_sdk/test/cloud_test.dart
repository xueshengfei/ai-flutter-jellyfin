import 'dart:io';
import 'package:rainfall_tts_cloud_sdk/rainfall_tts_cloud_sdk.dart';

const voiceFile =
    'E:/AI_play/indextts-v0.4.2/index-tts-rainfall-v0.4.2/index-tts-rainfall/resources/prompt_audio/九九妈.mp3';

void main() async {
  final client = RainfallCloudTTS();

  try {
    // ── 1. 健康检查 ──
    stdout.write('[1/4] 健康检查... ');
    final alive = await client.isServerAlive();
    print(alive ? 'OK' : 'FAIL');
    if (!alive) exit(1);

    // ── 2. 文件上传 ──
    stdout.write('[2/4] 上传参考音色... ');
    final serverPath = await client.uploadFile(voiceFile);
    print('OK -> $serverPath');

    // ── 3. 单条合成 ──
    stdout.write('[3/4] 单条语音合成... ');
    final result = await client.generate(
      voiceFilePath: voiceFile,
      text: '你好，这是一个测试。',
    );
    print('OK');
    print('      audioUrl: ${result.audioUrl}');

    // ── 4. 下载验证 ──
    stdout.write('[4/4] 下载音频... ');
    final outputPath =
        '${Directory.current.path}/test_output.wav';
    await client.downloadFile(result.audioUrl, outputPath);
    final size = await File(outputPath).length();
    print('OK -> test_output.wav ($size bytes)');

    // 清理
    await File(outputPath).delete();

    print('\n所有测试通过!');
  } catch (e) {
    print('\n测试失败: $e');
    exit(1);
  } finally {
    client.close();
  }
}
