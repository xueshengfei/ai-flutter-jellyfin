import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'http://106.75.68.11:7860';
  final voiceFile =
      'E:/AI_play/indextts-v0.4.2/index-tts-rainfall-v0.4.2/index-tts-rainfall/resources/prompt_audio/九九妈.mp3';

  // 1. 上传
  final uri = Uri.parse('$baseUrl/gradio_api/upload');
  final uploadReq = http.MultipartRequest('POST', uri)
    ..files.add(await http.MultipartFile.fromPath('files', voiceFile));
  final uploadResp =
      await http.Response.fromStream(await uploadReq.send());
  final serverPath = (jsonDecode(uploadResp.body) as List).first.toString();
  print('上传路径: $serverPath');

  // 2. 提交任务
  final callUrl = '$baseUrl/gradio_api/call/rainfall_gen_single';
  final fd = {'path': serverPath, 'meta': {'_type': 'gradio.FileData'}};
  final body = jsonEncode({
    'data': [
      fd, '测试',
      0, 0, 0, 0, 0, 0, 0, 0,  // emo
      '', 0.65, '不使用', fd, '不使用',
      120, '不显示', '不生成', '', 'wav',
      true, 0.8, 30, 0.8, 0, 3, 10, 1500,
    ]
  });

  print('\n提交任务...');
  final postResp = await http.post(Uri.parse(callUrl),
      headers: {'Content-Type': 'application/json'}, body: body);
  print('POST status: ${postResp.statusCode}');
  print('POST body: ${postResp.body}');

  final eventId = (jsonDecode(postResp.body) as Map)['event_id'] as String;
  print('event_id: $eventId');

  // 3. SSE 获取结果
  final sseUrl = '$callUrl/$eventId';
  print('\n获取结果 (最长等5分钟)...');
  final sseResp = await http.get(Uri.parse(sseUrl)).timeout(Duration(seconds: 300));
  print('SSE status: ${sseResp.statusCode}');
  print('SSE body length: ${sseResp.body.length}');
  print('--- SSE raw ---');
  // 按行打印，方便看结构
  for (final line in sseResp.body.split('\n')) {
    if (line.trim().isEmpty) continue;
    if (line.startsWith('data:')) {
      final payload = line.substring(5).trim();
      // 如果太长就截断
      if (payload.length > 500) {
        print('data: ${payload.substring(0, 500)}...[truncated, total ${payload.length} chars]');
      } else {
        print('data: $payload');
      }
    } else {
      print(line);
    }
  }
  print('--- END ---');
}
