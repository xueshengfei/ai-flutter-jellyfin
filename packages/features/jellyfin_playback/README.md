# jellyfin_playback

视频播放业务模块。提供视频播放器页面、画质管理（手动/自动切换）、网络质量监测，以及对 Jellyfin 播放会话的完整生命周期管理。

## 功能清单

- 视频播放器页面（基于 `video_player` + `chewie`）
- 5 档画质选择：自动 / 4K / 1080P / 720P / 480P
- 网络带宽滑动窗口采样与实时估算
- 自动画质切换决策（降级立即执行，升级需 3 次确认防抖）
- 续播位置计算（根据 `playedPercentage`）
- 播放倍速控制（0.5x ~ 2.0x）
- 画质切换时保持播放位置，旧转码任务自动停止
- 通过 `PlaybackDelegate` 委托模式解耦，页面不依赖 JellyfinClient

## 核心类说明

### 模型层 (`src/models/`)

| 类名 | 文件 | 说明 |
|------|------|------|
| `VideoQuality` | `video_quality_models.dart` | 画质枚举。`auto`(自动)、`p4k`(15Mbps)、`p1080`(5Mbps)、`p720`(2.5Mbps)、`p480`(1Mbps) |
| `NetworkQualityMonitor` | `video_quality_models.dart` | 网络质量监测器。滑动窗口（最多 10 次采样，3 分钟有效期），估算带宽并推荐画质 |
| `AutoQualityDecider` | `video_quality_models.dart` | 自动画质决策器。降级立即执行，升级需连续 3 次确认 |
| `PlaybackInfo` | `playback_models.dart` | 播放信息。包含播放 URL、会话 ID、是否转码、实际码率 |
| `PlaybackDelegate` | `playback_models.dart` | 播放委托。6 个回调：`getPlaybackUrl`、`startSession`、`switchQuality`、`stopEncoding`、`stopSession`、`dispose` |

### 页面层 (`src/pages/`)

| 类名 | 文件 | 说明 |
|------|------|------|
| `VideoPlayerPage` | `video_player_page.dart` | 视频播放器页面。接收 `MediaItem` + `PlaybackDelegate`，全屏播放，支持画质选择、倍速控制、续播 |

## 导入方式

```dart
// 模型（VideoQuality、PlaybackInfo、PlaybackDelegate 等）
import 'package:jellyfin_playback/jellyfin_playback.dart';

// 页面（VideoPlayerPage）
import 'package:jellyfin_playback/jellyfin_playback_pages.dart';
```

## 依赖关系

```
jellyfin_playback
  ├── flutter
  ├── jellyfin_models        # MediaItem 等共享模型
  ├── video_player           # 视频播放引擎
  ├── chewie                 # 播放器 UI 封装
  └── equatable              # 值对象相等性
```

## 使用示例

### 1. 创建 PlaybackDelegate

`PlaybackDelegate` 是纯回调集合，由 Product App 的适配层创建，将 Jellyfin API 操作注入播放页面。

```dart
import 'package:jellyfin_playback/jellyfin_playback.dart';

// 在 Product App 的 PlaybackAdapter 中创建
final delegate = PlaybackDelegate(
  // 获取播放 URL（DirectPlay 或 Transcode）
  getPlaybackUrl: ({required itemId, startTimeTicks, maxStreamingBitrate}) async {
    final url = await playbackService.getPlaybackUrl(
      itemId: itemId,
      startTimeTicks: startTimeTicks,
      maxStreamingBitrate: maxStreamingBitrate,
    );
    return PlaybackInfo(
      url: url,
      playSessionId: sessionId,
      isTranscoded: isTranscoded,
      actualBitrate: actualBitrate,
    );
  },

  // 开始播放会话
  startSession: ({required itemId, required sessionIds}) async {
    await playbackService.reportPlaybackStart(itemId: itemId);
  },

  // 切换画质（返回新的 PlaybackInfo）
  switchQuality: ({required itemId, required quality, required currentPosition}) async {
    return await playbackService.switchToQuality(
      itemId: itemId,
      bitrate: quality.bitrate,
      startTimeTicks: currentPosition.inMilliseconds * 10000,
    );
  },

  // 停止服务端转码任务
  stopEncoding: (playSessionId) async {
    await playbackService.stopEncoding(playSessionId);
  },

  // 停止播放会话
  stopSession: () async {
    await playbackService.reportPlaybackStopped();
  },

  // 清理资源
  dispose: () {
    playbackService.dispose();
  },
);
```

### 2. 使用 VideoPlayerPage

```dart
import 'package:jellyfin_playback/jellyfin_playback_pages.dart';

// 在路由页面中注入 delegate 并导航
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => VideoPlayerPage(
      item: mediaItem,       // jellyfin_models.MediaItem
      playback: delegate,    // 上面创建的 PlaybackDelegate
    ),
  ),
);
```

### 3. 画质切换流程

页面内置完整的画质切换能力，无需外部额外处理：

1. **手动切换**：点击右下角画质徽章，弹出底部面板选择目标画质
2. **自动切换**：当画质设为「自动」时，每 15 秒检测一次网络质量
   - `NetworkQualityMonitor` 通过 buffering 事件采样估算带宽
   - `AutoQualityDecider` 根据推荐结果决定是否切换
   - 切换时保持当前播放位置，自动停止旧转码任务

### 4. 进度上报

进度上报通过 `PlaybackDelegate` 的回调实现。Product App 适配层在回调中调用 Jellyfin API 的 `reportPlaybackStart` / `reportPlaybackStopped` 等接口完成上报。

## 测试

```bash
# 运行本模块测试
cd packages/features/jellyfin_playback && flutter test
```

测试覆盖 5 个分组，共 17 个测试用例：

| 分组 | 测试数 | 覆盖内容 |
|------|--------|----------|
| `VideoQuality` | 2 | 枚举值 label/bitrate 正确性 |
| `NetworkQualityMonitor` | 8 | 带宽估算、采样平均、画质推荐、无效采样忽略、重置 |
| `AutoQualityDecider` | 5 | 不切换/降级立即/升级 3 次确认/目标变更/重置 |
| `PlaybackInfo` | 2 | 构造与字段访问、转码流码率 |
| `PlaybackDelegate` | 1 | 回调调用验证 |
