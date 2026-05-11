# 雨落TTS SDK

封装雨落AI语音 Gradio v5 服务端 API，支持单条合成、批量生成、多角色对话、音色列表查询。

## 文件说明

| 文件 | 语言 | 依赖 |
|---|---|---|
| `rainfall_tts_sdk.py` | Python | requests |
| `rainfall_tts_sdk.dart` | Dart | 零依赖 (dart:io + dart:convert) |

## 快速开始

### Python

```python
from rainfall_tts_sdk import RainfallTTS, RoleAssignment

client = RainfallTTS("http://127.0.0.1:7861")

# 健康检查
if client.is_server_alive():
    print("服务在线")
```

### Dart

```dart
import 'rainfall_tts_sdk.dart';

var client = RainfallTTS(baseUrl: 'http://127.0.0.1:7861');
if (await client.isServerAlive()) {
  print('服务在线');
}
```

## API 参考

### 单条语音合成

**Python:**
```python
result = client.generate(
    "你好，欢迎收听今天的节目。",
    voice="孙悟空.WAV",       # 音色文件名或 wav 全路径
    speed=1.0,               # 语速 0.2~3.0，默认 1.0
    volume_db=0,             # 音量 -20~20 dB
    output_format="wav",     # wav 或 mp3
    temperature=0.8,         # 温度 0.1~2.0
    top_p=0.8,               # top-p 0.0~1.0
    top_k=30,                # top-k 0~100
    num_beams=3,             # beam search 1~10
    max_tokens_per_segment=120,  # 每段最大token 10~300
)
```

**Dart:**
```dart
var result = await client.generate(
  '你好，欢迎收听今天的节目。',
  voice: '孙悟空.WAV',
  speed: 1.0,
  temperature: 0.8,
);
```

### 前端获取音频

`generate()` 返回 `TTSResult`，包含 `audio_url` 字段。前端直接用这个 URL 播放或下载：

**Python:**
```python
result = client.generate("你好世界", voice="孙悟空.WAV")

# 方式1: 获取 URL，前端直接播放
print(result.audio_url)
# → http://127.0.0.1:7861/gradio_api/file=C:\Users\...\generated_xxx.wav

# 方式2: 下载到本地
client.download_audio(result, "output.wav")
```

**Dart:**
```dart
var result = await client.generate('你好世界', voice: '孙悟空.WAV');

// 方式1: URL 传给前端播放器
print(result.audioUrl);

// 方式2: 下载到本地
await client.downloadAudio(result, 'output.wav');
```

**前端播放示例 (HTML/JS):**
```html
<!-- 后端返回 audio_url 后，前端直接用 -->
<audio controls src="http://127.0.0.1:7861/gradio_api/file=xxx/generated_xxx.wav"></audio>
```

**前端播放示例 (Flutter):**
```dart
// 使用 audioplayers 或 just_audio 包
import 'package:audioplayers/audioplayers.dart';
var player = AudioPlayer();
await player.play(UrlSource(result.audioUrl));
```

### 获取音色列表

```python
# Python
voices = client.list_voices()
for v in voices:
    print(v.name)  # "孙悟空.WAV", "唐僧.WAV", ...
```

```dart
// Dart
var voices = await client.listVoices();
for (var v in voices) {
  print(v.name);
}
```

### 多角色对话

文本格式: `"角色名：台词"`，用中文冒号分隔。

```python
result = client.multi_role_generate(
    "旁白：故事发生在很久以前。孙悟空：俺老孙来也！唐僧：悟空，不可鲁莽。",
    roles=[
        RoleAssignment(role_name="旁白", voice="舌尖上的中国.WAV"),
        RoleAssignment(role_name="孙悟空", voice="孙悟空.WAV"),
        RoleAssignment(role_name="唐僧", voice="唐僧.WAV"),
    ],
    dialogue_interval=0.1,  # 对话间隔（秒）
)
```

```dart
var result = await client.multiRoleGenerate(
  '旁白：故事发生在很久以前。孙悟空：俺老孙来也！',
  roles: [
    RoleAssignment(roleName: '旁白', voice: '舌尖上的中国.WAV'),
    RoleAssignment(roleName: '孙悟空', voice: '孙悟空.WAV'),
  ],
  dialogueInterval: 0.1,
);
```

### 批量文本合成

从 txt 文件目录批量生成语音：

```python
message = client.batch_generate(
    input_dir="E:/path/to/txt/files",
    voice="孙悟空.WAV",
    line_interval=0.1,      # 行间隔（秒）
    merge_lines=True,        # 是否合并多行
)
```

### 下载音频

```python
result = client.generate("你好")
local_path = client.download_audio(result, "my_audio.wav")
# → E:\...\my_audio.wav
```

## 可用音色

参考音频存放在 `resources/prompt_audio/` 目录。目前包含 67 个音色：

| 音色 | 类型 | 音色 | 类型 |
|---|---|---|---|
| 孙悟空.WAV | 角色 | 唐僧.WAV | 角色 |
| 曹操.WAV | 角色 | 李云龙.WAV | 角色 |
| 钟离.WAV | 角色 | 胡桃.WAV | 角色 |
| 海绵宝宝.WAV | 角色 | 樱桃小丸子.WAV | 角色 |
| 老奶奶.WAV | 角色 | 小女孩.WAV | 角色 |
| 舌尖上的中国.WAV | 旁白 | 记录片 男声.WAV | 旁白 |
| demo_boy.wav | 默认男声 | demo_girl.wav | 默认女声 |
| en.wav | 英文 | ... | 完整列表见 list_voices() |

添加新音色：将 3~10 秒的干净 wav 文件放入 `resources/prompt_audio/` 即可，无需重启服务。

## 参数说明

### generate() 完整参数

| 参数 | 类型 | 默认值 | 范围 | 说明 |
|---|---|---|---|---|
| text | str | 必填 | - | 待合成文本 |
| voice | str | demo_boy.wav | - | 音色文件名或 wav 全路径 |
| speed | float | 1.0 | 0.2~3.0 | 语速调节 |
| volume_db | int | 0 | -20~20 | 音量调节（分贝） |
| output_format | str | wav | wav/mp3 | 输出格式 |
| temperature | float | 0.8 | 0.1~2.0 | 采样温度 |
| top_p | float | 0.8 | 0.0~1.0 | top-p 采样 |
| top_k | int | 30 | 0~100 | top-k 采样 |
| num_beams | int | 3 | 1~10 | beam search 宽度 |
| max_tokens_per_segment | int | 120 | 10~300 | 每段最大 token 数 |
| max_mel_tokens | int | 600 | 50~800 | 最大 mel token 数 |
| length_penalty | float | 0.0 | -2.0~2.0 | 长度惩罚 |
| repetition_penalty | float | 10.0 | 0.1~20.0 | 重复惩罚 |
| do_sample | bool | True | - | 是否采样 |
| generate_subtitle | bool | False | - | 是否生成字幕文件 |
| verbose | bool | False | - | 控制台显示详细信息 |

## 异常处理

| 异常类 | 说明 |
|---|---|
| RainfallTTSError | 基础异常 |
| ConnectionError | 连接服务端失败 |
| TTSError | 合成过程错误 |
| TimeoutError | 请求超时 |
| ServerError | 服务端返回错误 |

```python
from rainfall_tts_sdk import RainfallTTS, ConnectionError, TTSError, TimeoutError

try:
    result = client.generate("你好")
except ConnectionError:
    print("服务未启动")
except TimeoutError:
    print("合成超时，文本可能太长")
except TTSError as e:
    print(f"合成失败: {e}")
```

## 运行测试

```bash
# Python
python rainfall_tts_sdk.py

# Dart
dart run rainfall_tts_sdk.dart
```

## 常见问题

**Q: 音色列表里出现了 .txt 文件？**
`resources/prompt_audio/` 下有非音频文件会被扫入，不影响合成，忽略即可。

**Q: 合成返回空结果？**
`output_dir` 必须是有效路径。SDK 默认使用 `../outputs`，也可手动指定：
```python
result = client.generate("你好", output_dir="E:/my_outputs")
```

**Q: 服务重启后音色列表变了？**
`list_voices()` 每次调用都会从服务端刷新，重启后自动读取最新文件。

**Q: 远程服务器怎么用？**
把 `127.0.0.1` 换成服务器 IP 即可：
```python
client = RainfallTTS("http://192.168.1.100:7861")
```
