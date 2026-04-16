# 13 字幕 — SubtitleApi / VideoAttachmentsApi

---

## SubtitleApi — 字幕管理

获取方式：`client.getSubtitleApi()`

### searchRemoteSubtitles — 搜索远程字幕

```
GET /Items/{itemId}/RemoteSearch/Subtitles/{language}
返回: Response<List<RemoteSubtitleInfo>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 视频 ID |
| `language` | String | path | **是** | 语言代码（如 zh、en） |
| `isPerfectMatch` | bool? | query | 否 | 是否要求完美匹配 |

**RemoteSubtitleInfo 返回字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `threeLetterISOLanguageName` | String? | 三字母语言代码 |
| `id` | String? | 字幕 ID |
| `providerName` | String? | 提供商名称 |
| `name` | String? | 字幕名称 |
| `format` | String? | 字幕格式 |
| `author` | String? | 作者 |
| `comment` | String? | 评论 |
| `dateCreated` | DateTime? | 创建日期 |
| `communityRating` | double? | 社区评分 |
| `frameRate` | double? | 帧率 |
| `downloadCount` | int? | 下载数 |
| `isHashMatch` | bool? | 是否哈希匹配 |
| `isForced` | bool? | 是否强制显示 |
| `isHearingImpaired` | bool? | 是否为听障字幕 |

### getRemoteSearchResults — 获取远程字幕搜索结果详情

```
POST /Items/RemoteSearch/Subtitles/{itemId}
返回: Response<List<RemoteSubtitleInfo>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 视频 ID |
| `language` | String? | query | 否 | 语言代码 |
| `isPerfectMatch` | bool? | query | 否 | 完美匹配 |
| `body` | Object? | body | 否 | 搜索条件 |

### downloadRemoteSubtitle — 下载远程字幕

```
POST /Items/{itemId}/RemoteSearch/Subtitles/{subtitleId}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 视频 ID |
| `subtitleId` | String | path | **是** | 字幕 ID |

### uploadSubtitle — 上传本地字幕

```
POST /Videos/{itemId}/Subtitles
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 视频 ID |
| `uploadSubtitleDto` | UploadSubtitleDto | body | **是** | 字幕上传信息 |

**UploadSubtitleDto 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `language` | String? | 语言代码 |
| `format` | String? | 字幕格式（srt、ass、ssa 等） |
| `isForced` | bool? | 是否强制显示 |
| `data` | String? | 字幕内容（Base64 编码） |
| `fileName` | String? | 文件名 |

### getSubtitle — 获取字幕流

```
GET /Videos/{itemId}/{mediaSourceId}/Subtitles/{index}/Stream.{format}
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 视频 ID |
| `mediaSourceId` | String | path | **是** | 媒体源 ID |
| `index` | int | path | **是** | 字幕流索引 |
| `format` | String | path | **是** | 输出格式（srt、vtt、ass 等） |
| `startPositionTicks` | int? | query | 否 | 起始位置（用于时间偏移） |

### getSubtitleWithTicks — 获取字幕流（带时间偏移）

```
GET /Videos/{itemId}/{mediaSourceId}/Subtitles/{index}/{startPositionTicks}/Stream.{format}
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 视频 ID |
| `mediaSourceId` | String | path | **是** | 媒体源 ID |
| `index` | int | path | **是** | 字幕流索引 |
| `startPositionTicks` | int | path | **是** | 起始位置（刻度） |
| `format` | String | path | **是** | 输出格式 |
| `endPositionTicks` | int? | query | 否 | 结束位置 |
| `copyTimestamps` | bool? | query | 否 | 是否复制时间戳 |

### getSubtitlePlaylist — 获取字幕 HLS 播放列表

```
GET /Videos/{itemId}/{mediaSourceId}/Subtitles/{index}/subtitles.m3u8
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 视频 ID |
| `mediaSourceId` | String | path | **是** | 媒体源 ID |
| `index` | int | path | **是** | 字幕流索引 |
| `startPositionTicks` | int? | query | 否 | 起始位置 |
| `endPositionTicks` | int? | query | 否 | 结束位置 |
| `copyTimestamps` | bool? | query | 否 | 复制时间戳 |
| `addSegment` | bool? | query | 否 | 添加分片 |

### deleteSubtitle — 删除字幕

```
DELETE /Videos/{itemId}/Subtitles/{index}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 视频 ID |
| `index` | int | path | **是** | 字幕流索引 |

### getFallbackFont — 获取备用字体

```
GET /FallbackFont/Fonts/{name}
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `name` | String | path | **是** | 字体文件名 |

---

## VideoAttachmentsApi — 视频附件

获取方式：`client.getVideoAttachmentsApi()`

### getAttachment — 获取视频附件（如字体文件）

```
GET /Videos/{videoId}/{mediaSourceId}/Attachments/{index}
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `videoId` | String | path | **是** | 视频 ID |
| `mediaSourceId` | String | path | **是** | 媒体源 ID |
| `index` | int | path | **是** | 附件索引 |
