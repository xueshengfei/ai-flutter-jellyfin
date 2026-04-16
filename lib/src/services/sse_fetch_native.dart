import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';

/// 原生平台：用 Dio GET + ResponseType.stream 实现流式 SSE
Stream<Uint8List> createSseStream(
  String url,
  Map<String, String> headers,
) async* {
  final dio = Dio();
  final response = await dio.get<ResponseBody>(
    url,
    options: Options(
      responseType: ResponseType.stream,
      headers: headers,
      receiveTimeout: const Duration(minutes: 5),
    ),
  );
  await for (final chunk in response.data!.stream) {
    yield chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
  }
}
