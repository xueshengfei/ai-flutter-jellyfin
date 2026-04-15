# 06 播放控制与流媒体 — PlaystateApi / MediaInfoApi / VideosApi / AudioApi / DynamicHlsApi / UniversalAudioApi / HlsSegmentApi

---

## PlaystateApi — 播放状态报告

获取方式：`client.getPlaystateApi()`

### markPlayedItem — 标记为已播放

```
POST /UserPlayedItems/{itemId}
返回: Response<UserItemDataDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |
| `userId` | String? | query | 否 | 用户 ID |
| `datePlayed` | DateTime? | query | 否 | 播放时间 |

### markUnplayedItem — 标记为未播放

```
DELETE /UserPlayedItems/{itemId}
返回: Response<UserItemDataDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |
| `userId` | String? | query | 否 | 用户 ID |

### reportPlaybackStart — 报告播放开始

```
POST /Sessions/Playing
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `playbackStartInfo` | PlaybackStartInfo? | body | 否 | 播放开始信息 |

**PlaybackStartInfo 关键字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `itemId` | String? | 正在播放的条目 ID |
| `session` | String? | 会话 ID |
| `mediaSourceId` | String? | 媒体源 ID |
| `audioStreamIndex` | int? | 音频流索引 |
| `subtitleStreamIndex` | int? | 字幕流索引 |
| `isPaused` | bool? | 是否暂停 |
| `isMuted` | bool? | 是否静音 |
| `positionTicks` | int? | 播放位置（刻度） |
| `playbackStartTimeTicks` | int? | 播放开始时间 |
| `volumeLevel` | int? | 音量级别 |
| `brightness` | int? | 亮度 |
| `aspectRatio` | String? | 宽高比 |
| `playMethod` | PlayMethod? | 播放方式 |
| `liveStreamId` | String? | 直播流 ID |
| `playSessionId` | String? | 播放会话 ID |
| `repeatMode` | RepeatMode? | 重复模式 |
| `nowPlayingQueue` | List\<QueueItem\>? | 当前播放队列 |
| `playlistItemId` | String? | 播放列表条目 ID |

### reportPlaybackProgress — 报告播放进度

```
POST /Sessions/Playing/Progress
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `playbackProgressInfo` | PlaybackProgressInfo? | body | 否 | 播放进度信息 |

**PlaybackProgressInfo 字段同 PlaybackStartInfo，额外包含：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `isPaused` | bool? | 是否暂停 |
| `isMuted` | bool? | 是否静音 |
| `volumeLevel` | int? | 音量 |
| `positionTicks` | int? | 当前播放位置 |

### reportPlaybackStopped — 报告播放停止

```
POST /Sessions/Playing/Stopped
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `playbackStopInfo` | PlaybackStopInfo? | body | 否 | 播放停止信息 |

**PlaybackStopInfo 关键字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `itemId` | String? | 条目 ID |
| `positionTicks` | int? | 停止时的播放位置 |
| `liveStreamId` | String? | 直播流 ID |
| `playSessionId` | String? | 播放会话 ID |
| `failed` | bool? | 是否播放失败 |

### pingPlaybackSession — 心跳保活

```
POST /Sessions/Playing/Ping
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `playSessionId` | String | query | **是** | 播放会话 ID |

---

## MediaInfoApi — 媒体信息与播放准备

获取方式：`client.getMediaInfoApi()`

### getPlaybackInfo — 获取播放信息（GET）

```
GET /Items/{itemId}/PlaybackInfo
返回: Response<PlaybackInfoResponse>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |
| `userId` | String? | query | 否 | 用户 ID |

### getPostedPlaybackInfo — 获取播放信息（POST，推荐）

```
POST /Items/{itemId}/PlaybackInfo
返回: Response<PlaybackInfoResponse>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |
| `userId` | String? | query | 否 | 用户 ID（已弃用，建议放 body） |
| `maxStreamingBitrate` | int? | query | 否 | 最大流比特率（已弃用） |
| `startTimeTicks` | int? | query | 否 | 起始时间刻度（已弃用） |
| `audioStreamIndex` | int? | query | 否 | 音频流索引（已弃用） |
| `subtitleStreamIndex` | int? | query | 否 | 字幕流索引（已弃用） |
| `maxAudioChannels` | int? | query | 否 | 最大音频通道数（已弃用） |
| `mediaSourceId` | String? | query | 否 | 媒体源 ID（已弃用） |
| `liveStreamId` | String? | query | 否 | 直播流 ID（已弃用） |
| `autoOpenLiveStream` | bool? | query | 否 | 自动打开直播流（已弃用） |
| `enableDirectPlay` | bool? | query | 否 | 启用直接播放（已弃用） |
| `enableDirectStream` | bool? | query | 否 | 启用直接流（已弃用） |
| `enableTranscoding` | bool? | query | 否 | 启用转码（已弃用） |
| `allowVideoStreamCopy` | bool? | query | 否 | 允许视频流复制（已弃用） |
| `allowAudioStreamCopy` | bool? | query | 否 | 允许音频流复制（已弃用） |
| `playbackInfoDto` | PlaybackInfoDto? | body | 否 | 播放信息请求体（推荐方式） |

**PlaybackInfoDto 关键字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `userId` | String? | 用户 ID |
| `maxStreamingBitrate` | int? | 最大流比特率 |
| `startTimeTicks` | int? | 起始时间刻度 |
| `audioStreamIndex` | int? | 音频流索引 |
| `subtitleStreamIndex` | int? | 字幕流索引 |
| `maxAudioChannels` | int? | 最大音频通道数 |
| `mediaSourceId` | String? | 媒体源 ID |
| `liveStreamId` | String? | 直播流 ID |
| `deviceProfile` | DeviceProfile? | 设备能力配置 |
| `enableDirectPlay` | bool? | 启用直接播放 |
| `enableDirectStream` | bool? | 启用直接流 |
| `enableTranscoding` | bool? | 启用转码 |
| `allowVideoStreamCopy` | bool? | 允许视频流复制 |
| `allowAudioStreamCopy` | bool? | 允许音频流复制 |
| `autoOpenLiveStream` | bool? | 自动打开直播流 |

**PlaybackInfoResponse 返回字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `mediaSources` | List\<MediaSourceInfo\>? | 可用媒体源列表（含播放 URL） |
| `playSessionId` | String? | 播放会话 ID |
| `errorCode` | PlaybackErrorCode? | 错误码 |

### openLiveStream — 打开直播流

```
POST /LiveStreams/Open
返回: Response<LiveStreamResponse>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `openToken` | String? | query | 否 | 打开令牌 |
| `userId` | String? | query | 否 | 用户 ID |
| `playSessionId` | String? | query | 否 | 播放会话 ID |
| `maxStreamingBitrate` | int? | query | 否 | 最大流比特率 |
| `startTimeTicks` | int? | query | 否 | 起始时间 |
| `audioStreamIndex` | int? | query | 否 | 音频流索引 |
| `subtitleStreamIndex` | int? | query | 否 | 字幕流索引 |
| `maxAudioChannels` | int? | query | 否 | 最大音频通道 |
| `itemId` | String? | query | 否 | 条目 ID |
| `enableDirectPlay` | bool? | query | 否 | 启用直接播放 |
| `enableDirectStream` | bool? | query | 否 | 启用直接流 |
| `alwaysBurnInSubtitleWhenTranscoding` | bool? | query | 否 | 转码时始终烧入字幕 |
| `openLiveStreamDto` | OpenLiveStreamDto? | body | 否 | 请求体 |

### closeLiveStream — 关闭直播流

```
POST /LiveStreams/Close
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `liveStreamId` | String | query | **是** | 直播流 ID |

### getBitrateTestBytes — 网速测试

```
GET /Playback/BitrateTest
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| `size` | int? | query | 否 | 102400 | 测试数据大小（字节） |

---

## VideosApi — 视频流

获取方式：`client.getVideosApi()`

### getVideoStream — 获取视频流（转码）

```
GET /Videos/{itemId}/stream
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 视频 ID |
| `container` | String? | query | 否 | 输出容器格式（如 mp4、mkv） |
| `static_` | bool? | query | 否 | 是否使用静态重定向 |
| `params` | String? | query | 否 | 编码参数 |
| `tag` | String? | query | 媒体标签 |
| `playSessionId` | String? | query | 否 | 播放会话 ID |
| `segmentContainer` | String? | query | 否 | 分片容器格式 |
| `segmentLength` | int? | query | 否 | 分片长度（秒） |
| `minSegments` | int? | query | 否 | 最小分片数 |
| `mediaSourceId` | String? | query | 否 | 媒体源 ID |
| `deviceId` | String? | query | 否 | 设备 ID |
| `audioCodec` | String? | query | 否 | 音频编解码器（如 aac、mp3） |
| `enableAutoStreamCopy` | bool? | query | 否 | 启用自动流复制 |
| `allowVideoStreamCopy` | bool? | query | 否 | 允许视频流复制 |
| `allowAudioStreamCopy` | bool? | query | 否 | 允许音频流复制 |
| `breakOnNonKeyFrames` | bool? | query | 否 | 在非关键帧处断开 |
| `audioSampleRate` | int? | query | 否 | 音频采样率 |
| `maxAudioBitDepth` | int? | query | 否 | 最大音频位深 |
| `audioBitRate` | int? | query | 否 | 音频比特率 |
| `audioChannels` | int? | query | 否 | 音频通道数 |
| `maxAudioChannels` | int? | query | 否 | 最大音频通道数 |
| `profile` | String? | query | 否 | 编码配置（如 high、main） |
| `level` | String? | query | 否 | 编码级别（如 4.1） |
| `framerate` | double? | query | 否 | 帧率 |
| `maxFramerate` | double? | query | 否 | 最大帧率 |
| `copyTimestamps` | bool? | query | 否 | 复制时间戳 |
| `startTimeTicks` | int? | query | 否 | 起始位置（刻度，1秒=10000000） |
| `width` | int? | query | 否 | 输出宽度 |
| `height` | int? | query | 否 | 输出高度 |
| `maxWidth` | int? | query | 否 | 最大宽度 |
| `maxHeight` | int? | query | 否 | 最大高度 |
| `videoBitRate` | int? | query | 否 | 视频比特率 |
| `subtitleStreamIndex` | int? | query | 否 | 字幕流索引 |
| `subtitleMethod` | SubtitleDeliveryMethod? | query | 否 | 字幕投递方式 |
| `maxRefFrames` | int? | query | 否 | 最大参考帧数 |
| `maxVideoBitDepth` | int? | query | 否 | 最大视频位深 |
| `requireAvc` | bool? | query | 否 | 要求 AVC 编码 |
| `deInterlace` | bool? | query | 否 | 去隔行 |
| `requireNonAnamorphic` | bool? | query | 否 | 要求非变形 |
| `transcodingMaxAudioChannels` | int? | query | 否 | 转码最大音频通道 |
| `cpuCoreLimit` | int? | query | 否 | CPU 核心限制 |
| `liveStreamId` | String? | query | 否 | 直播流 ID |
| `enableMpegtsM2TsMode` | bool? | query | 否 | 启用 MPEG-TS M2TS 模式 |
| `videoCodec` | String? | query | 否 | 视频编解码器（如 h264、hevc） |
| `subtitleCodec` | String? | query | 否 | 字幕编解码器 |
| `transcodeReasons` | String? | query | 否 | 转码原因 |
| `audioStreamIndex` | int? | query | 否 | 音频流索引 |
| `videoStreamIndex` | int? | query | 否 | 视频流索引 |
| `context` | EncodingContext? | query | 否 | 编码上下文 |
| `streamOptions` | Map\<String, String\>? | query | 否 | 自定义流选项 |
| `enableAudioVbrEncoding` | bool? | query | 否 | 启用音频 VBR 编码（默认 true） |

### getVideoStreamByContainer — 按容器格式获取视频流

```
GET /Videos/{itemId}/stream.{container}
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 视频 ID |
| `container` | String | path | **是** | 容器格式（如 mp4、mkv、ts） |
| `deviceProfileId` | String? | query | 否 | 设备配置 ID |
| 其余参数同 getVideoStream | | | | |

### headVideoStream / headVideoStreamByContainer — 探测视频流信息

与 getVideoStream / getVideoStreamByContainer 参数相同，使用 HTTP HEAD 方法，只返回头信息不返回流数据。

### mergeVersions — 合并视频版本

```
POST /Videos/MergeVersions
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `ids` | List\<String\> | query | **是** | 要合并的视频 ID 列表 |

### deleteAlternateSources — 删除备用源

```
DELETE /Videos/{itemId}/AlternateSources
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 视频 ID |

### getAdditionalPart — 获取附加部分（多部分视频）

```
GET /Videos/{itemId}/AdditionalParts
返回: Response<BaseItemDtoQueryResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 视频 ID |
| `userId` | String? | query | 否 | 用户 ID |

---

## AudioApi — 音频流

获取方式：`client.getAudioApi()`

参数结构与 VideosApi 几乎完全相同。

### getAudioStream — 获取音频流

```
GET /Audio/{itemId}/stream
返回: Response<Uint8List>
```

参数同 VideosApi.getVideoStream。

### getAudioStreamByContainer — 按容器格式获取音频流

```
GET /Audio/{itemId}/stream.{container}
返回: Response<Uint8List>
```

参数同 VideosApi.getVideoStreamByContainer。

### headAudioStream / headAudioStreamByContainer — 探测音频流

参数同上，使用 HTTP HEAD。

---

## DynamicHlsApi — 动态 HLS 流

获取方式：`client.getDynamicHlsApi()`

### getMasterHlsVideoPlaylist — 获取主 HLS 视频播放列表

```
GET /Videos/{itemId}/master.m3u8
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 视频 ID |
| `mediaSourceId` | String? | query | 否 | 媒体源 ID |
| `static_` | bool? | query | 否 | 静态流 |
| `params` | String? | query | 否 | 编码参数 |
| `tag` | String? | query | 否 | 标签 |
| `deviceProfileId` | String? | query | 否 | 设备配置 ID |
| `playSessionId` | String? | query | 否 | 播放会话 ID |
| `segmentContainer` | String? | query | 否 | 分片容器（如 ts） |
| `segmentLength` | int? | query | 否 | 分片长度（秒） |
| `minSegments` | int? | query | 否 | 最小分片数 |
| `audioCodec` | String? | query | 否 | 音频编码 |
| `enableAutoStreamCopy` | bool? | query | 否 | 自动流复制 |
| `allowVideoStreamCopy` | bool? | query | 否 | 视频流复制 |
| `allowAudioStreamCopy` | bool? | query | 否 | 音频流复制 |
| `breakOnNonKeyFrames` | bool? | query | 否 | 非关键帧断开 |
| `audioSampleRate` | int? | query | 否 | 采样率 |
| `maxAudioBitDepth` | int? | query | 否 | 最大音频位深 |
| `audioBitRate` | int? | query | 否 | 音频比特率 |
| `audioChannels` | int? | query | 否 | 音频通道 |
| `maxAudioChannels` | int? | query | 否 | 最大音频通道 |
| `profile` | String? | query | 否 | 编码配置 |
| `level` | String? | query | 否 | 编码级别 |
| `framerate` | double? | query | 否 | 帧率 |
| `maxFramerate` | double? | query | 否 | 最大帧率 |
| `copyTimestamps` | bool? | query | 否 | 复制时间戳 |
| `startTimeTicks` | int? | query | 否 | 起始时间 |
| `width` | int? | query | 否 | 宽度 |
| `height` | int? | query | 否 | 高度 |
| `videoBitRate` | int? | query | 否 | 视频比特率 |
| `subtitleStreamIndex` | int? | query | 否 | 字幕流索引 |
| `subtitleMethod` | SubtitleDeliveryMethod? | query | 否 | 字幕方式 |
| `maxRefFrames` | int? | query | 否 | 最大参考帧 |
| `maxVideoBitDepth` | int? | query | 否 | 最大视频位深 |
| `requireAvc` | bool? | query | 否 | 要求 AVC |
| `deInterlace` | bool? | query | 否 | 去隔行 |
| `requireNonAnamorphic` | bool? | query | 否 | 非变形 |
| `transcodingMaxAudioChannels` | int? | query | 否 | 转码音频通道上限 |
| `cpuCoreLimit` | int? | query | 否 | CPU 核心限制 |
| `liveStreamId` | String? | query | 否 | 直播流 ID |
| `enableMpegtsM2TsMode` | bool? | query | 否 | M2TS 模式 |
| `videoCodec` | String? | query | 否 | 视频编码 |
| `subtitleCodec` | String? | query | 否 | 字幕编码 |
| `transcodeReasons` | String? | query | 否 | 转码原因 |
| `audioStreamIndex` | int? | query | 否 | 音频流索引 |
| `videoStreamIndex` | int? | query | 否 | 视频流索引 |
| `context` | EncodingContext? | query | 否 | 编码上下文 |
| `streamOptions` | Map\<String, String\>? | query | 否 | 自定义选项 |
| `enableAudioVbrEncoding` | bool? | query | 否 | VBR 编码 |

### getMasterHlsAudioPlaylist — 获取主 HLS 音频播放列表

```
GET /Audio/{itemId}/master.m3u8
返回: Response<Uint8List>
```

参数同 getMasterHlsVideoPlaylist。

### getHlsVideoSegment — 获取 HLS 视频分片

```
GET /Videos/{itemId}/hls/{playlistId}/{segmentId}.{container}
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 视频 ID |
| `playlistId` | String | path | **是** | 播放列表 ID |
| `segmentId` | String | path | **是** | 分片 ID |
| `container` | String | path | **是** | 容器格式 |

### getHlsAudioSegment — 获取 HLS 音频分片

```
GET /Audio/{itemId}/hls/{playlistId}/{segmentId}.{container}
返回: Response<Uint8List>
```

参数同 getHlsVideoSegment。

### getLiveHlsStream — 获取直播 HLS 流

```
GET /Videos/{itemId}/livestream.{container}
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |
| `container` | String | path | **是** | 容器格式 |

---

## UniversalAudioApi — 通用音频

获取方式：`client.getUniversalAudioApi()`

### getUniversalAudioStream — 获取通用音频流

```
GET /Audio/{itemId}/universal
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 音频 ID |
| `container` | String? | query | 否 | 容器格式 |
| `mediaSourceId` | String? | query | 否 | 媒体源 ID |
| `deviceId` | String? | query | 否 | 设备 ID |
| `userId` | String? | query | 否 | 用户 ID |
| `audioCodec` | String? | query | 否 | 音频编码 |
| `maxStreamingBitrate` | int? | query | 否 | 最大比特率 |
| `startTimeTicks` | int? | query | 否 | 起始时间 |
| `transcodingContainer` | String? | query | 否 | 转码容器 |
| `transcodingProtocol` | String? | query | 否 | 转码协议 |
| `maxAudioSampleRate` | int? | query | 否 | 最大采样率 |
| `maxAudioBitDepth` | int? | query | 否 | 最大位深 |
| `maxAudioChannels` | int? | query | 否 | 最大通道数 |
| `enableRedirection` | bool? | query | 否 | 启用重定向 |

### headUniversalAudioStream — 探测通用音频流

参数同上，HTTP HEAD 方法。

---

## HlsSegmentApi — HLS 分片管理

获取方式：`client.getHlsSegmentApi()`

### getHlsAudioSegmentLegacy — 获取旧版 HLS 音频分片

```
GET /Audio/{itemId}/hls/{playlistId}/{segmentId}.{container}
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 音频 ID |
| `playlistId` | String | path | **是** | 播放列表 ID |
| `segmentId` | String | path | **是** | 分片 ID |
| `container` | String | path | **是** | 容器格式 |

### getHlsVideoSegmentLegacy — 获取旧版 HLS 视频分片

```
GET /Videos/{itemId}/hls/{playlistId}/{segmentId}.{container}
返回: Response<Uint8List>
```

参数同上。

### stopEncodingProcess — 停止编码进程

```
DELETE /Videos/ActiveEncodings
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `deviceId` | String | query | **是** | 设备 ID |
| `playSessionId` | String | query | **是** | 播放会话 ID |
