# 11 会话与同步播放 — SessionApi / SyncPlayApi

---

## SessionApi — 会话管理

获取方式：`client.getSessionApi()`

### getSessions — 获取所有会话

```
GET /Sessions
返回: Response<List<SessionInfoDto>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `controllableByUserId` | String? | query | 否 | 可被指定用户控制的会话 |
| `deviceId` | String? | query | 否 | 按设备 ID 过滤 |
| `activeWithinSeconds` | int? | query | 否 | 最近活跃秒数（如 960 表示 16 分钟内活跃） |

### postCapabilities — 报告客户端能力

```
POST /Sessions/Capabilities
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| `id` | String? | query | 否 | | 会话/设备 ID |
| `playableMediaTypes` | List\<MediaType\>? | query | 否 | | 可播放的媒体类型列表 |
| `supportedCommands` | List\<GeneralCommandType\>? | query | 否 | | 支持的命令列表 |
| `supportsMediaControl` | bool? | query | 否 | false | 是否支持媒体控制 |
| `supportsPersistentIdentifier` | bool? | query | 否 | true | 是否支持持久标识 |

**GeneralCommandType 常用值：**

| 值 | 说明 |
|----|------|
| `moveUp` | 上移 |
| `moveDown` | 下移 |
| `moveLeft` | 左移 |
| `moveRight` | 右移 |
| `pageUp` | 上一页 |
| `pageDown` | 下一页 |
| `previousLetter` | 上一个字母 |
| `nextLetter` | 下一个字母 |
| `toggleOsd` | 切换 OSD |
| `toggleContextMenu` | 切换上下文菜单 |
| `select` | 选择 |
| `back` | 返回 |
| `takeScreenshot` | 截图 |
| `sendKey` | 发送按键 |
| `sendString` | 发送字符串 |
| `goHome` | 回到首页 |
| `goToSettings` | 进入设置 |
| `volumeUp` | 音量增大 |
| `volumeDown` | 音量减小 |
| `mute` | 静音 |
| `unmute` | 取消静音 |
| `toggleMute` | 切换静音 |
| `setVolume` | 设置音量 |
| `setAudioStreamIndex` | 设置音频流 |
| `setSubtitleStreamIndex` | 设置字幕流 |
| `toggleFullscreen` | 切换全屏 |
| `displayContent` | 显示内容 |
| `goToSearch` | 进入搜索 |
| `displayMessage` | 显示消息 |
| `setRepeatMode` | 设置重复模式 |
| `channelUp` | 频道+ |
| `channelDown` | 频道- |
| `guide` | 节目指南 |
| `toggleStats` | 切换统计 |
| `playMediaSource` | 播放媒体源 |
| `playTrailers` | 播放预告片 |

### postFullCapabilities — 报告完整客户端能力（含设备配置）

```
POST /Sessions/Capabilities/Full
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `clientCapabilitiesDto` | ClientCapabilitiesDto | body | **是** | 完整客户端能力 |
| `id` | String? | query | 否 | 会话 ID |

### play — 向会话发送播放命令

```
POST /Sessions/{sessionId}/Playing
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `sessionId` | String | path | **是** | 目标会话 ID |
| `playCommand` | PlayCommand | query | **是** | 播放命令 |
| `itemIds` | List\<String\> | query | **是** | 要播放的条目 ID 列表 |
| `startPositionTicks` | int? | query | 否 | 起始位置 |
| `mediaSourceId` | String? | query | 否 | 媒体源 ID |
| `audioStreamIndex` | int? | query | 否 | 音频流索引 |
| `subtitleStreamIndex` | int? | query | 否 | 字幕流索引 |
| `startIndex` | int? | query | 否 | 播放列表中的起始索引 |

**PlayCommand 枚举值：**

| 值 | 说明 |
|----|------|
| `playNow` | 立即播放 |
| `playNext` | 下一首播放 |
| `playLast` | 添加到末尾 |
| `playInstantMix` | 播放即时混音 |
| `playShuffle` | 随机播放 |

### sendPlaystateCommand — 发送播放状态命令（暂停/停止/跳转等）

```
POST /Sessions/{sessionId}/Playing/{command}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `sessionId` | String | path | **是** | 会话 ID |
| `command` | PlaystateCommand | path | **是** | 播放状态命令 |
| `seekPositionTicks` | int? | query | 否 | 跳转位置（仅用于 Seek 命令） |
| `controllingUserId` | String? | query | 否 | 控制用户 ID |

**PlaystateCommand 枚举值：**

| 值 | 说明 |
|----|------|
| `stop` | 停止 |
| `pause` | 暂停 |
| `unpause` | 取消暂停 |
| `nextTrack` | 下一曲 |
| `previousTrack` | 上一曲 |
| `seek` | 跳转 |

### sendGeneralCommand — 发送通用命令

```
POST /Sessions/{sessionId}/Command/{command}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `sessionId` | String | path | **是** | 会话 ID |
| `command` | GeneralCommandType | path | **是** | 命令类型 |

### sendFullGeneralCommand — 发送带参数的通用命令

```
POST /Sessions/{sessionId}/Command
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `sessionId` | String | path | **是** | 会话 ID |
| `generalCommand` | GeneralCommand | body | **是** | 完整命令对象 |

**GeneralCommand 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | GeneralCommandType? | 命令类型 |
| `controllingUserId` | String? | 控制用户 ID |
| `arguments` | Map\<String, String\>? | 命令参数 |

### sendMessageCommand — 发送消息到会话

```
POST /Sessions/{sessionId}/Message
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `sessionId` | String | path | **是** | 会话 ID |
| `messageCommand` | MessageCommand | body | **是** | 消息内容 |

**MessageCommand 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `header` | String? | 消息标题 |
| `text` | String? | 消息正文 |
| `timeoutMs` | int? | 显示超时（毫秒） |

### sendSystemCommand — 发送系统命令

```
POST /Sessions/{sessionId}/System/{command}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `sessionId` | String | path | **是** | 会话 ID |
| `command` | GeneralCommandType | path | **是** | 命令 |

### displayContent — 在会话中显示内容

```
POST /Sessions/{sessionId}/Viewing
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `sessionId` | String | path | **是** | 会话 ID |
| `itemType` | BaseItemKind | query | **是** | 条目类型 |
| `itemId` | String | query | **是** | 条目 ID |
| `itemName` | String | query | **是** | 条目名称 |

### addUserToSession — 向会话添加用户

```
POST /Sessions/{sessionId}/User/{userId}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `sessionId` | String | path | **是** | 会话 ID |
| `userId` | String | path | **是** | 用户 ID |

### removeUserFromSession — 从会话移除用户

```
DELETE /Sessions/{sessionId}/User/{userId}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `sessionId` | String | path | **是** | 会话 ID |
| `userId` | String | path | **是** | 用户 ID |

### reportViewing — 报告正在查看

```
POST /Sessions/Viewing
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | query | **是** | 正在查看的条目 ID |
| `sessionId` | String? | query | 否 | 会话 ID |

### reportSessionEnded — 报告会话结束

```
POST /Sessions/Logout
返回: Response<void>
```

无参数。

### getAuthProviders — 获取认证提供商

```
GET /Auth/Providers
返回: Response<List<NameIdPair>>
```

无参数。

### getPasswordResetProviders — 获取密码重置提供商

```
GET /Auth/PasswordResetProviders
返回: Response<List<NameIdPair>>
```

无参数。

---

## SyncPlayApi — 同步播放

获取方式：`client.getSyncPlayApi()`

### syncPlayBuffering — 报告缓冲中

```
POST /SyncPlay/Buffering
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `bufferingRequestDto` | BufferingRequestDto | body | **是** | 缓冲请求信息 |

**BufferingRequestDto 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `when_` | DateTime? | 事件时间 |
| `positionTicks` | int? | 播放位置 |
| `isPlaying` | bool? | 是否正在播放 |
| `itemId` | String? | 条目 ID |

### syncPlayJoinGroup — 加入同步播放组

```
POST /SyncPlay/Join
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `joinGroupRequestDto` | JoinGroupRequestDto | body | **是** | 加入组请求 |

**JoinGroupRequestDto 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `groupId` | String? | 组 ID |

### syncPlayLeaveGroup — 离开同步播放组

```
POST /SyncPlay/Leave
返回: Response<void>
```

无参数。

### syncPlayNewGroup — 创建新的同步播放组

```
POST /SyncPlay/New
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `newGroupRequestDto` | NewGroupRequestDto | body | **是** | 创建组请求 |

**NewGroupRequestDto 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `groupName` | String? | 组名 |

### syncPlayPause — 暂停同步播放

```
POST /SyncPlay/Pause
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `pauseRequestDto` | PauseRequestDto | body | **是** | 暂停请求 |

### syncPlayPing — 发送心跳

```
POST /SyncPlay/Ping
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `pingRequestDto` | PingRequestDto | body | **是** | 心跳请求 |

**PingRequestDto 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `ping` | int? | 延迟（毫秒） |

### syncPlayPlay — 同步播放

```
POST /SyncPlay/Play
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `playRequestDto` | PlayRequestDto | body | **是** | 播放请求 |

### syncPlayReady — 报告就绪

```
POST /SyncPlay/Ready
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `readyRequestDto` | ReadyRequestDto | body | **是** | 就绪请求 |

### syncPlaySeek — 同步跳转

```
POST /SyncPlay/Seek
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `seekRequestDto` | SeekRequestDto | body | **是** | 跳转请求 |

**SeekRequestDto 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `positionTicks` | int? | 跳转目标位置 |

### syncPlaySetIgnoreWait — 设置忽略等待

```
POST /SyncPlay/SetIgnoreWait
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `ignoreWaitRequestDto` | IgnoreWaitRequestDto | body | **是** | 请求体 |

### syncPlaySetNewQueue — 设置新的播放队列

```
POST /SyncPlay/SetNewQueue
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `playQueueRequestDto` | PlayQueueRequestDto | body | **是** | 队列请求 |

### syncPlaySetRepeatMode — 设置重复模式

```
POST /SyncPlay/SetRepeatMode
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `setRepeatModeRequestDto` | SetRepeatModeRequestDto | body | **是** | 重复模式请求 |

### syncPlaySetShuffleMode — 设置随机模式

```
POST /SyncPlay/SetShuffleMode
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `setShuffleModeRequestDto` | SetShuffleModeRequestDto | body | **是** | 随机模式请求 |

### syncPlayStop — 停止同步播放

```
POST /SyncPlay/Stop
返回: Response<void>
```

无参数。

### syncPlayUnpause — 取消暂停同步播放

```
POST /SyncPlay/Unpause
返回: Response<void>
```

无参数。

### syncPlayGetInfoForSyncPlay — 获取同步播放信息

```
GET /SyncPlay/List
返回: Response<List<GroupInfoDto>>
```

无参数。返回所有可用的同步播放组列表。
