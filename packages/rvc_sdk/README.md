# RVC Dart SDK

RVC 语音转换 API 的 Dart 客户端 SDK，适配 Dart SDK >=3.2.0（含 3.32）。

## 安装

将 `rvc_sdk/` 目录放到项目中，在 `pubspec.yaml` 添加：

```yaml
dependencies:
  rvc_sdk:
    path: ./rvc_sdk
```

然后执行：

```bash
dart pub get
```

## 快速开始

### 一键AI翻唱（推荐）

输入一首完整歌曲，自动完成：人声分离 → 去混响 → 音色转换 → AI混音。

```dart
import 'dart:io';
import 'package:rvc_sdk/rvc_sdk.dart';

void main() async {
  final client = RVCClient(baseUrl: 'http://192.168.1.100:9880');

  // 一键翻唱：上传歌曲 → 自动分离 → 转换 → 混音
  final result = await client.cover(
    modelName: 'TaylorSwift.pth',
    inputPath: 'D:/song.mp3',
    f0UpKey: 12,
  );

  // 播放地址
  print(client.getPlayUrl(result));
  // http://192.168.1.100:9880/audio/TaylorSwift_song_cover_xxx.wav

  print(result.filename);      // TaylorSwift_song_cover_xxx.wav
  print(result.durationSec);   // 45.2（总耗时，含分离+转换+混音）

  client.close();
}
```

### 纯音色转换

需要预先准备干声（已分离人声的音频）。

```dart
final result = await client.convert(
  modelName: 'TaylorSwift.pth',
  inputPath: 'D:/vocals.wav',
  f0UpKey: 12,
);
print(client.getPlayUrl(result));
```

## 客户端配置

```dart
// 基础用法
final client = RVCClient(baseUrl: 'http://192.168.1.100:9880');

// 自定义超时（默认 5 分钟，翻唱流水线建议 10 分钟+）
final client = RVCClient(
  baseUrl: 'http://192.168.1.100:9880',
  timeout: Duration(minutes: 10),
);

// 注入自定义 http.Client
final client = RVCClient(
  baseUrl: 'http://192.168.1.100:9880',
  httpClient: myCustomHttpClient,
);
```

## API 一览

### 系统接口

| 方法 | 返回类型 | 说明 |
|------|---------|------|
| `getStatus()` | `Future<ServiceStatus>` | 获取服务运行状态 |

### 模型接口

| 方法 | 返回类型 | 说明 |
|------|---------|------|
| `listModels()` | `Future<List<ModelInfo>>` | 列出所有可用模型 |
| `listIndices()` | `Future<List<String>>` | 列出所有索引文件路径 |

### 翻唱接口（完整流水线）

| 方法 | 返回类型 | 说明 |
|------|---------|------|
| `cover(...)` | `Future<CoverResult>` | 一键AI翻唱：分离 → 转换 → 混音 |
| `coverAndDownload(...)` | `Future<Uint8List>` | 一键翻唱并下载音频字节 |

### 转换接口（仅音色转换）

| 方法 | 返回类型 | 说明 |
|------|---------|------|
| `convert(...)` | `Future<ConvertResult>` | 转换音频，返回播放/下载地址 |
| `convertAndDownload(...)` | `Future<Uint8List>` | 转换并从服务端下载音频字节 |
| `convertServerSave(...)` | `Future<ConvertFileResult>` | 转换并保存在服务端 |

### URL 辅助

| 方法 | 说明 |
|------|------|
| `getPlayUrl(result)` | 拼接完整播放 URL |
| `getDownloadUrl(result)` | 拼接完整下载 URL |

## 翻唱 vs 转换

| | `cover()` 一键翻唱 | `convert()` 音色转换 |
|---|---|---|
| **输入** | 完整歌曲（含伴奏） | 干声（纯人声） |
| **流程** | 分离 → 去混响 → 转换 → AI混音 | 仅音色转换 |
| **输出** | 成品歌曲（人声+伴奏混音） | 转换后的干声 |
| **耗时** | 较长（1-5分钟） | 较短（几秒~几十秒） |
| **适用** | 快速出成品 | 专业用户精细调参 |

## 翻唱接口详解

### 方式一：获取成品播放/下载地址（推荐）

```dart
final result = await client.cover(
  modelName: 'TaylorSwift.pth',
  inputPath: 'D:/song.mp3',
  f0UpKey: 12,
);

final playUrl = client.getPlayUrl(result);
final downloadUrl = client.getDownloadUrl(result);

// Flutter 中直接播放
// AudioPlayer().play(UrlSource(playUrl));
```

### 方式二：翻唱并下载音频字节

```dart
final bytes = await client.coverAndDownload(
  modelName: 'TaylorSwift.pth',
  inputPath: 'D:/song.mp3',
  f0UpKey: 12,
);
await File('output.wav').writeAsBytes(bytes);
```

### 方式三：上传音频字节（远程调用）

```dart
final bytes = await File('song.mp3').readAsBytes();
final result = await client.cover(
  modelName: 'TaylorSwift.pth',
  audioBytes: bytes,
  f0UpKey: 12,
);
print(client.getPlayUrl(result));
```

### 翻唱混音参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `vocalVol` | double | `1.0` | **人声音量**。1.0 = 原始音量 |
| `instVol` | double | `0.8` | **伴奏音量**。0.8 = 略低于人声 |

## 转换参数说明

### 必填参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `modelName` | String | 模型文件名（通过 `listModels()` 查询可用模型） |

### 音频输入（二选一）

| 参数 | 类型 | 说明 |
|------|------|------|
| `inputPath` | String? | 音频文件本地路径（服务端可访问）。支持 wav/mp3/flac 等格式 |
| `audioBytes` | Uint8List? | 音频文件的原始字节数据（远程上传场景使用） |

### 音色控制参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `f0UpKey` | int | `0` | **音高偏移（半音）**。男声转女声用 `12`，女声转男声用 `-12` |
| `f0Method` | F0Method | `rmvpe` | **基频提取算法**（详见下方） |
| `protect` | double | `0.33` | **辅音保护阈值** `0~0.5`。防止爆破音/齿音走样 |

### 特征检索参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `indexRate` | double | `0.75` | **特征检索混合比率** `0~1`。利用索引文件修正音色 |
| `indexFile` | String? | `null` | **索引文件路径**（通过 `listIndices()` 查询） |

### 音频处理参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `filterRadius` | int | `3` | **F0 中值滤波半径**。平滑音高曲线中的毛刺 |
| `resampleSr` | int | `0` | **输出采样率**。`0` = 跟随模型原始采样率 |
| `rmsMixRate` | double | `1.0` | **音量包络混合** `0~1`。`1.0` = 模型音量，`0.0` = 原始音量 |

### F0 提取算法对比

| 值 | 精度 | 速度 | 适用场景 |
|----|------|------|---------|
| `F0Method.rmvpe` | 高 | 中 | **推荐**，通用首选 |
| `F0Method.harvest` | 较高 | 慢 | 噪声环境 |
| `F0Method.crepe` | 高 | 慢 | 深度学习方法，需额外 GPU 显存 |
| `F0Method.pm` | 一般 | 快 | 实时场景 |
| `F0Method.dio` | 低 | 最快 | 不推荐 |

### 常见场景参数推荐

```
男声 → 女声：  f0UpKey: 12,  f0Method: F0Method.rmvpe, protect: 0.33
女声 → 男声：  f0UpKey: -12, f0Method: F0Method.rmvpe, protect: 0.33
同性别音色替换：f0UpKey: 0,   f0Method: F0Method.rmvpe
提升音色相似度：indexRate: 0.8, indexFile: 'logs/xxx.index'
转换后含糊不清：降低 protect（如 0.2）
转换后音量不稳：降低 rmsMixRate（如 0.5）
```

## 返回类型

### CoverResult

```dart
final class CoverResult {
  final bool success;        // 是否成功
  final String playUrl;      // 成品播放地址（相对路径）
  final String downloadUrl;  // 成品下载地址（相对路径）
  final String filename;     // 成品文件名
  final int sampleRate;      // 采样率
  final double durationSec;  // 总耗时（秒），含分离+转换+混音
  final int fileSize;        // 文件大小（字节）
  final String? vocalPath;   // 分离出的干声路径（服务端）
  final String? instrPath;   // 分离出的伴奏路径（服务端）
}
```

### ConvertResult

```dart
final class ConvertResult {
  final bool success;        // 是否成功
  final String playUrl;      // 流媒体播放地址（相对路径）
  final String downloadUrl;  // 下载地址（相对路径）
  final String filename;     // 文件名
  final int sampleRate;      // 采样率
  final double durationSec;  // 转换耗时（秒）
  final int fileSize;        // 文件大小（字节）
}
```

### ServiceStatus

```dart
final class ServiceStatus {
  final String service;   // "RVC API"
  final String version;   // "1.1.0"
  final String status;    // "running"
}
```

### ModelInfo

```dart
final class ModelInfo {
  final String name;      // "TaylorSwift.pth"
  final double sizeMb;    // 52.7
}
```

### ConvertFileResult

```dart
final class ConvertFileResult {
  final bool success;
  final String message;
  final double durationSec;
}
```

## 异常处理

```dart
try {
  final result = await client.cover(
    modelName: 'model.pth',
    inputPath: 'song.mp3',
    f0UpKey: 12,
  );
} on RVCConnectionError catch (e) {
  print('网络连接失败: ${e.message}');
} on RVCApiError catch (e) {
  print('服务端错误 [${e.statusCode}]: ${e.message}');
  // 404 = 模型不存在 / 音频文件不存在
  // 400 = 参数错误
  // 500 = 服务端推理异常
} on RVCConvertError catch (e) {
  print('转换失败: ${e.message}');
}
```

| 异常类 | 场景 |
|--------|------|
| `RVCError` | SDK 基础异常（sealed class） |
| `RVCConnectionError` | 网络不通、超时、DNS 解析失败 |
| `RVCApiError` | 服务端返回 4xx/5xx，含 `statusCode` 属性 |
| `RVCConvertError` | 转换业务失败 |

## 完整示例

```dart
import 'dart:io';
import 'package:rvc_sdk/rvc_sdk.dart';

Future<void> main() async {
  final client = RVCClient(
    baseUrl: 'http://192.168.1.100:9880',
    timeout: Duration(minutes: 10),
  );

  try {
    final status = await client.getStatus();
    if (status.status != 'running') {
      print('服务未就绪');
      return;
    }

    // 一键翻唱：上传完整歌曲，自动分离+转换+混音
    final result = await client.cover(
      modelName: 'TaylorSwift.pth',
      inputPath: 'D:/song.mp3',
      f0UpKey: 12,
      f0Method: F0Method.rmvpe,
      vocalVol: 1.0,
      instVol: 0.8,
    );

    print('播放: ${client.getPlayUrl(result)}');
    print('下载: ${client.getDownloadUrl(result)}');
    print('文件: ${result.filename} (${result.fileSize} bytes, ${result.durationSec}s)');

  } on RVCConnectionError catch (e) {
    print('无法连接 API 服务: ${e.message}');
  } on RVCApiError catch (e) {
    print('API 错误 [${e.statusCode}]: ${e.message}');
  } finally {
    client.close();
  }
}
```

## 项目结构

```
rvc_sdk/
├── pubspec.yaml           # 包配置 (Dart >=3.2.0)
└── lib/
    ├── rvc_sdk.dart       # 库入口，统一导出
    └── src/
        ├── client.dart    # RVCClient (final class)
        ├── models.dart    # 数据模型 (final class + immutable)
        └── exceptions.dart # 异常 (sealed class 体系)
```

## 依赖

- Dart SDK >= 3.2.0
- http: ^1.2.0
- meta: ^1.12.0
