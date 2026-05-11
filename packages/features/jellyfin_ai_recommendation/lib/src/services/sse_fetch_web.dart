import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// Web 平台：用 XMLHttpRequest 渐进式读取实现流式 SSE
///
/// GET 请求下，XMLHttpRequest 的 responseText 在 readyState==3（LOADING）时
/// 即可读到已接收的部分数据，实现逐 chunk 推送。
Stream<Uint8List> createSseStream(
  String url,
  Map<String, String> headers,
) {
  final controller = StreamController<Uint8List>();
  var lastLength = 0;

  final xhr = html.HttpRequest();
  xhr.open('GET', url);
  headers.forEach((k, v) => xhr.setRequestHeader(k, v));

  xhr.onReadyStateChange.listen((_) {
    if (xhr.readyState >= 3) {
      // LOADING 或 DONE — 可以读取已接收的数据
      final text = xhr.responseText ?? '';
      if (text.length > lastLength) {
        final newText = text.substring(lastLength);
        lastLength = text.length;
        controller.add(Uint8List.fromList(utf8.encode(newText)));
      }
    }
    if (xhr.readyState == 4) {
      controller.close();
    }
  });

  xhr.onError.listen((e) {
    controller.addError(Exception('请求失败: $e'));
    controller.close();
  });

  xhr.send();

  return controller.stream;
}
