/// RVC 语音转换 HTTP API 客户端 SDK
///
/// ```dart
/// import 'package:rvc_sdk/rvc_sdk.dart';
///
/// final client = RVCClient(baseUrl: 'http://192.168.1.100:9880');
/// final models = await client.listModels();
/// final result = await client.convert(
///   modelName: 'model.pth',
///   inputPath: 'D:/song.wav',
///   f0UpKey: 12,
/// );
/// await File('output.wav').writeAsBytes(result.audioBytes);
/// ```
library;

export 'src/client.dart';
export 'src/models.dart';
export 'src/exceptions.dart';
