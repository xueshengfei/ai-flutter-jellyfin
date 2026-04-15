# Flutter Web SSE 打字机效果 — 踩坑记录

## 问题

AI 挑片页面使用 SSE 流式通信（后端 `/ask_stream`），期望像 ChatGPT 一样逐字显示 AI 回复。但在 Flutter Web 上，**所有 token 在后端响应完成后一次性渲染**，没有打字机效果。

## 根因分析

### 1. Dio 在 Flutter Web 使用 XMLHttpRequest，缓冲整个 POST 响应

```
curl 测试（正常）：每个 token 间隔 30-300ms 逐个推送
Flutter Web 日志：chunk #1 @1ms (15305 chars) — 全部数据在一个 chunk 到达
```

**Dio 在 Flutter Web 底层使用 `XMLHttpRequest`，POST 请求的响应体会被完全缓冲后才触发回调。** 这不是 Dio 的 bug，而是 `XMLHttpRequest` 对 POST 请求的行为限制。服务端确实在逐个 flush，但客户端在 Web 平台收不到中间数据。

### 2. dart:html 的 fetch API 属性不可直接访问

尝试用 `dart:html` 的 `window.fetch()` + `ReadableStream` 替代 Dio：
- `html.RequestInit` 构造函数不存在 → 编译报错
- 去掉 `RequestInit` 后，`response.ok` / `response.status` 在运行时报 `NoSuchMethodError` → `dart:html` 的 `Response` 对象属性在 Flutter Web 运行时无法通过 Dart getter 访问

### 3. 代码块渲染

LLM 有时输出 `` ```jellyfin `` 等代码块包裹内容，`flutter_markdown` 会原样渲染，需要在客户端过滤。

## 解决方案

### 最终方案：GET 请求 + 条件导入 + XHR 渐进式读取

```
sse_fetch.dart         ← stub（不支持的平台）
sse_fetch_web.dart     ← Web: XMLHttpRequest GET + readyState 渐进读取
sse_fetch_native.dart  ← 原生/鸿蒙: Dio GET + ResponseType.stream
```

**条件导入**：
```dart
import 'sse_fetch.dart'
  if (dart.library.html) 'sse_fetch_web.dart'
  if (dart.library.io) 'sse_fetch_native.dart';
```

**关键发现：GET 请求下 XMLHttpRequest 的 `responseText` 在 `readyState == 3`（LOADING）时即可读取已接收的部分数据。** 每次 `onReadyStateChange` 触发时，只 yield 增量部分（`substring(lastLength)`）。

```dart
xhr.onReadyStateChange.listen((_) {
  if (xhr.readyState >= 3) {
    final text = xhr.responseText ?? '';
    if (text.length > lastLength) {
      final newText = text.substring(lastLength);
      lastLength = text.length;
      controller.add(Uint8List.fromList(utf8.encode(newText)));
    }
  }
});
```

### 方案对比

| 方案 | 结果 | 原因 |
|------|------|------|
| Dio POST + ResponseType.stream | 所有 token 一次性到达 | XHR 缓冲 POST 响应体 |
| dart:html fetch + ReadableStream | 编译/运行时报错 | RequestInit 不存在，Response 属性不可访问 |
| **GET + XHR readyState 渐进读取** | **逐 token 流式渲染** | **GET 请求下 responseText 支持 LOADING 状态渐进读取** |

### 代码块过滤

```dart
static String _stripCodeBlocks(String content) {
  var result = content;
  result = result.replaceAll(RegExp(r'```\w*\n[\s\S]*?\n```'), '');      // 完整代码块
  result = result.replaceAll(RegExp(r'\n*```\w*\n[\s\S]*$'), '');        // 未闭合代码块
  result = result.replaceAll(RegExp(r'\n*```\w*\n*'), '');               // 残留标记
  return result.trim();
}
```

## 调试经验

1. **三级诊断日志**（服务 chunk → 服务派发 → UI 接收）+ 毫秒时间戳，是定位流式问题的关键
2. `js_primitives.dart` 出现在堆栈中 → 确认运行在 Flutter Web
3. curl 的 `-s -N` 参数可以模拟流式接收，对比客户端行为判断是服务端还是客户端问题
4. Dart 事件循环会批量处理 microtask，但每个 SSE chunk 触发独立的 `setState`，不会合并

## 涉及文件

| 文件 | 说明 |
|------|------|
| `sse_fetch.dart` | 条件导入 stub |
| `sse_fetch_web.dart` | Web 平台：XHR GET 渐进读取 |
| `sse_fetch_native.dart` | 原生/鸿蒙：Dio GET stream |
| `ai_recommendation_service.dart` | POST body → GET query params |
| `ai_recommend_page.dart` | `_stripCodeBlocks` + 诊断日志 |
