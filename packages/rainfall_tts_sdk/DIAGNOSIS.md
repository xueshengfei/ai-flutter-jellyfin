# RainfallTTS SDK 问题诊断报告

## 问题现象

SDK 调用 `generate()` 合成语音时，服务端返回 `event: error, data: null`，所有音色均失败。
但 **Gradio Web UI 上点击"生成语音"按钮可以正常合成**。

## 根因分析

SDK 使用的是 Gradio v5 的 `call/<endpoint>` API 模式，而 **该 RainfallTTS 服务端只支持 `queue/join` + `queue/data` 模式**。
UI 网络请求证实了这一点。

## 两种 API 模式对比

### SDK 当前使用的模式（失败）

```
第一步: POST /gradio_api/call/rainfall_gen_single
        Body: {"data": [...]}
        Response: {"event_id": "xxx"}

第二步: GET /gradio_api/call/rainfall_gen_single/xxx
        Response SSE:
          event: error
          data: null
```

### UI 实际使用的模式（成功）

```
第一步: POST /gradio_api/queue/join?
        Body: {
          "data": [...],
          "event_data": null,
          "fn_index": 0,
          "trigger_id": 45,
          "session_hash": "xxx"
        }
        Response: {"event_id": "xxx"}

第二步: GET /gradio_api/queue/data?session_hash=xxx
        Response SSE (流式):
          data: {"msg":"estimation","event_id":"xxx","rank":0,"queue_size":1}
          data: {"msg":"process_starts","event_id":"xxx"}
          data: {"msg":"progress","event_id":"xxx","progress_data":[...]}
          data: {"msg":"process_completed","event_id":"xxx","output":{...},"success":true}
          data: {"msg":"close_stream"}
```

## 关键差异

| 项目 | SDK (call模式) | UI (queue模式) |
|------|----------------|----------------|
| 提交URL | `/gradio_api/call/rainfall_gen_single` | `/gradio_api/queue/join?` |
| 轮询URL | `/gradio_api/call/rainfall_gen_single/{event_id}` | `/gradio_api/queue/data?session_hash={hash}` |
| 额外字段 | 无 | `fn_index`, `trigger_id`, `session_hash`, `event_data` |
| SSE格式 | `event: xxx\ndata: xxx` | `data: {"msg":"xxx", ...}` |
| 成功标志 | data 为音频 JSON | `msg == "process_completed"` 且 `success == true` |

## 成功的 curl/Python 复现

以下 Python 代码可以成功合成语音（queue/join 模式）：

```python
import json, urllib.request, http.client

# ====== 第一步: 提交任务 ======
data = json.dumps({
    "data": [
        "demo_boy.wav",          # 参考音色
        "你好测试",               # 待合成文本
        120,                      # max_tokens_per_segment
        "不显示",                  # verbose
        "不生成",                  # generate_subtitle
        1,                        # speed
        0,                        # volume_db
        "E:/AI_play/indextts-v0.4.2/index-tts-rainfall-v0.4.2/index-tts-rainfall/outputs",  # output_dir (必须有效!)
        "",                       # output_filename
        "wav",                    # output_format
        True,                     # do_sample
        0.8,                      # top_p
        30,                       # top_k
        0.8,                      # temperature
        0,                        # length_penalty
        3,                        # num_beams
        10,                       # repetition_penalty
        600                       # max_mel_tokens
    ],
    "event_data": None,
    "fn_index": 0,
    "trigger_id": 45,
    "session_hash": "test_sdk_001"
}).encode()

req = urllib.request.Request(
    "http://127.0.0.1:7860/gradio_api/queue/join?",
    data=data,
    headers={"Content-Type": "application/json"}
)
resp = urllib.request.urlopen(req, timeout=10)
body = json.loads(resp.read().decode())
event_id = body["event_id"]
print(f"event_id: {event_id}")

# ====== 第二步: SSE 轮询结果 ======
conn = http.client.HTTPConnection("127.0.0.1", 7860, timeout=120)
conn.request("GET", "/gradio_api/queue/data?session_hash=test_sdk_001")
r = conn.getresponse()
raw = r.read().decode("utf-8")

for line in raw.split("\n"):
    s = line.strip()
    if s:
        print(s)
conn.close()
```

### 成功时的 SSE 返回示例

```
data: {"msg":"estimation","event_id":"fcd771aad435456d9d05a8b68b7a84a0","rank":0,"queue_size":1,"rank_eta":3.24}
data: {"msg":"process_starts","event_id":"fcd771aad435456d9d05a8b68b7a84a0","eta":3.24}
data: {"msg":"progress","event_id":"fcd771aad435456d9d05a8b68b7a84a0","progress_data":[{"index":null,"length":null,"unit":"steps","progress":0.2,"desc":"gpt latents inference 1/1..."}]}
data: {"msg":"progress","event_id":"fcd771aad435456d9d05a8b68b7a84a0","progress_data":[{"index":null,"length":null,"unit":"steps","progress":0.6,"desc":"gpt speech inference 1/1..."}]}
data: {"msg":"process_completed","event_id":"fcd771aad435456d9d05a8b68b7a84a0","output":{"data":[{"visible":true,"value":{"path":"C:\\Users\\xue13\\AppData\\Local\\Temp\\gradio\\1514d8571e98a54f97790c0a6e1898119fc12a80dbbe782bbe389597e30216a4\\generated_1778433067.wav","url":"http://127.0.0.1:7860/gradio_api/file=C:\\Users\\xue13\\AppData\\Local\\Temp\\gradio\\1514d8571e98a54f97790c0a6e1898119fc12a80dbbe782bbe389597e30216a4\\generated_1778433067.wav","size":null,"orig_name":"generated_1778433067.wav","mime_type":null,"is_stream":false,"meta":{"_type":"gradio.FileData"}},"__type__":"update"}],"is_generating":false,"duration":1.14,"average_duration":3.05,"render_config":null,"changed_state_ids":[]},"success":true,"title":null}
data: {"msg":"close_stream","event_id":null}
```

### 失败时的 SSE 返回（output_dir 为空字符串）

```
data: {"msg":"process_completed","event_id":"xxx","output":{"error":null},"success":false,"title":"Error"}
```

## fn_index 映射

从 `/config` 的 `dependencies` 数组中提取：

| fn_index | api_name | 用途 |
|----------|----------|------|
| 0 | rainfall_gen_single | 单条语音合成 |
| ? | refresh_single_prompt_audio | 获取音色列表 |
| ? | single_batch_txt_generate | 批量文本合成 |
| ? | rainfall_quick_multi_role_text_generate | 多角色对话 |

> `fn_index` 从 `/config` JSON 的 `dependencies` 数组的 `id` 字段获取。
> 已确认 `rainfall_gen_single` 的 `fn_index = 0`。
> 其他 endpoint 的 fn_index 需从 `/config` 中 `dependencies` 数组按顺序查找对应 `api_name`。

## 修复方案

需要修改 `lib/src/client.dart` 中的 `_callGradio()` 方法：

1. **提交**：从 `POST /gradio_api/call/<endpoint>` 改为 `POST /gradio_api/queue/join?`
   - 请求体增加 `fn_index`、`session_hash`、`event_data: null` 字段
   - `fn_index` 需要 endpoint -> index 的映射

2. **轮询**：从 `GET /gradio_api/call/<endpoint>/<event_id>` 改为 `GET /gradio_api/queue/data?session_hash=<hash>`
   - 每次调用生成唯一 session_hash

3. **SSE 解析**：改为解析 `{"msg":"process_completed", "output":{...}, "success":true/false}` 格式
   - 成功时从 `output.data` 中提取音频信息
   - 失败时检查 `success == false`

4. **output_dir**：不能传空字符串，必须传有效路径（或从 `/config` 获取服务端默认路径）

## 文件路径

- Dart SDK: `packages/rainfall_tts_sdk/lib/src/client.dart`
- Python SDK: `packages/rainfall_tts_sdk/rainfall_tts_sdk.py`（也有同样问题）
- 测试: `packages/rainfall_tts_sdk/test/test_multi_voices.dart`
- 服务地址: `http://127.0.0.1:7860`
