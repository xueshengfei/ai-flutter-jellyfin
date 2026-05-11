/// 雨落TTS (RainfallTTS) Dart SDK
///
/// 封装雨落AI语音 Gradio v5 服务端 API。
/// 支持单条合成、批量生成、多角色对话、音色列表查询。
///
/// 跨平台：使用 package:http 替代 dart:io HttpClient，
/// Web/原生均可编译（downloadAudio 在 Web 上不可用）。
library;

export 'src/client.dart';
export 'src/exceptions.dart';
export 'src/models.dart';
