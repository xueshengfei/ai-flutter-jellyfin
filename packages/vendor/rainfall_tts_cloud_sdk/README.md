# rainfall_tts_cloud_sdk

雨落TTS (RainfallTTS) 云端版 Dart SDK，适配 IndexTTS2 云端 Gradio v5 API。

## 快速开始

```dart
import 'package:rainfall_tts_cloud_sdk/rainfall_tts_cloud_sdk.dart';

void main() async {
  final client = RainfallCloudTTS();

  try {
    // 健康检查
    final alive = await client.isServerAlive();
    print('服务状态: ${alive ? "在线" : "离线"}');

    // 单条语音合成
    final result = await client.generate(
      voiceFilePath: 'voices/demo_boy.wav',
      text: '你好，这是测试语音',
    );
    print('音频URL: ${result.audioUrl}');

    // 下载到本地
    await client.downloadFile(result.audioUrl, 'output.wav');

    // 带情感参数
    final happy = await client.generate(
      voiceFilePath: 'voices/demo_boy.wav',
      text: '今天天气真好！',
      emoHappy: 0.8,
      generateSubtitle: true,
    );
    print('SRT: ${happy.srtUrl}');
    await client.downloadFile(happy.audioUrl, 'happy.wav');

    // 多角色对话
    final multi = await client.multiRoleGenerate(
      roles: [
        RoleAssignment(roleName: '小帅', audioFilePath: 'voices/male.wav'),
        RoleAssignment(roleName: '小美', audioFilePath: 'voices/female.wav'),
      ],
      text: '小帅：你好啊！ 小美：你好，很高兴认识你。',
    );
    await client.downloadFile(multi.audioUrl, 'dialogue.wav');

    // 批量文本合成
    final files = await client.batchGenerate(
      voiceFilePath: 'voices/demo_boy.wav',
      txtFilePaths: ['scripts/01.txt', 'scripts/02.txt'],
    );
    for (final url in files) {
      print('生成文件: $url');
    }

    // 音频格式转换
    final converted = await client.convertAudioFormat(
      inputFilePath: 'output.wav',
      outputFormat: 'mp3',
    );
    await client.downloadFile(converted.audioUrl, 'output.mp3');

    // 从视频提取音频
    final extracted = await client.extractFromVideo(
      videoFilePath: 'video.mp4',
    );
    await client.downloadFile(extracted.audioUrl, 'extracted.wav');

  } finally {
    client.close();
  }
}
```

## API 方法

| 方法 | 端点 | 说明 |
|------|------|------|
| `generate()` | `/rainfall_gen_single` | 单条语音合成（28参数） |
| `batchGenerate()` | `/single_batch_txt_generate` | 批量txt文件合成 |
| `multiRoleGenerate()` | `/rainfall_quick_multi_role_text_generate` | 多角色对话合成 |
| `handleExcel()` | `/handle_excel` | Excel文件处理 |
| `convertAudioFormat()` | `/convert_audio_format` | 音频格式转换 |
| `extractFromVideo()` | `/extract_from_video` | 从视频提取音频 |
| `uploadFile()` | `/gradio_api/upload` | 上传本地文件 |
| `uploadBytes()` | `/gradio_api/upload` | 上传原始字节数据 |
| `downloadFile()` | - | 下载结果文件 |

## generate() 参数映射

```
SDK 参数名              → 云端参数名                  默认值
voiceFilePath          → prompt                     (必填)
text                   → text                       "注意看，这个男人叫小帅"
emoHappy               → emo_vector1                0.0
emoAngry               → emo_vector2                0.0
emoSad                 → emo_vector3                0.0
emoAfraid              → emo_vector4                0.0
emoDisgusted           → emo_vector5                0.0
emoMelancholic         → emo_vector6                0.0
emoSurprised           → emo_vector7                0.0
emoCalm                → emo_vector8                0.0
emoText                → single_emo_text            ""
emoAlpha               → single_emo_alpha           0.65
useEmoText             → single_use_emo_text        "不使用"
emoAudioFilePath       → single_emo_audio           (复用voiceFilePath)
useRandom              → single_use_random          "不使用"
maxTokensPerSegment    → max_text_tokens_per_segment 120
verbose                → single_verbose             "不显示"
generateSubtitle       → single_need_srt            "不生成"
outputFilename         → output_file_name           ""
outputFormat           → single_file_suffix         "wav"
doSample               → param_20 (do_sample)       true
topP                   → param_21 (top_p)           0.8
topK                   → param_22 (top_k)           30
temperature            → param_23 (temperature)     0.8
lengthPenalty          → param_24 (length_penalty)  0.0
numBeams               → param_25 (num_beams)       3
repetitionPenalty      → param_26 (repetition_penalty) 10.0
maxMelTokens           → param_27 (max_mel_tokens)  1500
```
