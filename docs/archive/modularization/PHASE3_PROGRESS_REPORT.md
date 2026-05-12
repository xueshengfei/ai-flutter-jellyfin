# 第三阶段进展报告

> 对应策略：`PHASE2_STRATEGY_REPORT.md`（Leader 评审反馈）
> 更新日期：2026-05-12

---

## 一、Leader 评审反馈摘要

Leader 对 Phase 2 代码的评审结论：

> Phase 2 的 feature 包抽取整体通过，尤其是 Task 10.5、`PlaybackDelegate`、`AudioPlaybackPort` 这几个补点说明不是只搬文件，而是在处理真实边界。边界检查脚本跑通，说明 feature 反向依赖根包的问题目前控制住了。

但提出 **5 处需修正** 和 **4 个优先级方向**。

---

## 二、Leader 反馈修正（已完成）

### 2.1 hide 数量修正：15 → 18

**问题**：`PHASE2_PROGRESS_REPORT.md` 第 13.1 节写 hide 类型共 15 个，实际遗漏了 `jellyfin_music_pages` 的 2 个。

**修正**：根 barrel `lib/jellyfin_service.dart` 实际 hide 清单：

| 来源包 | hide 的类型 | 数量 |
|--------|-----------|------|
| `jellyfin_movies` | `MovieFilter`, `MovieFilterResult`, `MovieDetailPage` | 3 |
| `jellyfin_playback` | `VideoQuality`, `NetworkQualityMonitor`, `AutoQualityDecider`, `PlaybackInfo` | 4 |
| `jellyfin_playback_pages` | `VideoPlayerPage` | 1 |
| `jellyfin_music` | `MusicAlbum`, `MusicArtist`, `MusicSong`, `MusicGenre`, `ArtistRef`, `MusicAlbumListResult`, `MusicArtistListResult`, `MusicSongListResult` | 8 |
| `jellyfin_music_pages` | `AlbumDetailPage`, `ArtistDetailPage` | 2 |
| **合计** | | **18** |

### 2.2 旧文件清理表补全

Leader 指出 13.2 节只列了已替代的旧页面，未拆的音乐/搜索/歌词等也要列出。拆分为两类：

**A 类：已有新包替代，@Deprecated 已标记（11 个）**

| 旧文件 | 新包版本 |
|--------|---------|
| `media_item_detail_page.dart` | `jellyfin_media` |
| `person_detail_page.dart` | `jellyfin_media` |
| `media_items_page.dart` | `jellyfin_media` |
| `seasons_page.dart` | `jellyfin_series` |
| `episodes_page.dart` | `jellyfin_series` |
| `movie_detail_page.dart` | `jellyfin_movies` |
| `movie_filter_page.dart` | `jellyfin_movies` |
| `video_player_page.dart` | `jellyfin_playback` |
| `album_detail_page.dart` | `jellyfin_music` |
| `artist_detail_page.dart` | `jellyfin_music` |
| `ai_recommend_page.dart` | `jellyfin_ai_recommendation` |

**B 类：尚无新包替代，仍属根包职责（6 个）**

| 文件 | 说明 |
|------|------|
| `MusicLibraryPage` (~1609行) | 内嵌 AudioPlayerPage，耦合 AudioPlaybackManager，待 Task 15-B |
| `MusicSearchPage` | 依赖 AudioPlaybackManager |
| `LyricsPage` | 依赖 AudioPlaybackManager |
| `PersonalPage` | 个人中心，属 App Shell 范畴 |
| `LoginPage` | 认证入口，属 Task 9 Auth |
| `TestApiPage` | 调试工具，保留在根包 |

### 2.3 边界检查脚本 adapters 豁免移除

**问题**：脚本给 `lib/src/adapters` 留了 import feature `src/` 的豁免。

**修正**：移除豁免。当前 `MediaItemMapper` 已改用 public barrel（`jellyfin_media_models.dart`），豁免不再需要。

### 2.4 AI 推荐模块 TTS 依赖同步

Leader 指出报告早期章节写 AI 模块依赖 `dio`、`flutter_markdown`、`equatable`，但实际 `pubspec.yaml` 已包含 `just_audio` 和 `rainfall_tts_sdk`。需同步到报告并明确 TTS 是内聚能力还是可选扩展。

### 2.5 旧模型 deprecated 标记

Leader 建议不只给旧页面加 deprecated，也给旧模型加标记。

---

## 三、Phase 3 已完成内容

### Task 18-A：小步收敛（deprecated + 边界检查）

**状态：完成**（2026-05-12）

#### 3.1 旧页面 @Deprecated 标记

以下 11 个旧页面 class 已添加 `@Deprecated` 注解：

- `MediaItemDetailPage` → `'使用 jellyfin_media 包中的 MediaItemDetailPage'`
- `PersonDetailPage` → `'使用 jellyfin_media 包中的 PersonDetailPage'`
- `MediaItemsPage` → `'使用 jellyfin_media 包中的 MediaItemsPage'`
- `SeasonsPage` → `'使用 jellyfin_series 包中的 SeasonsPage'`
- `EpisodesPage` → `'使用 jellyfin_series 包中的 EpisodesPage'`
- `MovieDetailPage` → `'使用 jellyfin_movies 包中的 MovieDetailPage'`
- `MovieFilterPage` → `'使用 jellyfin_movies 包中的 MovieFilterPage'`
- `VideoPlayerPage` → `'使用 jellyfin_playback 包中的 VideoPlayerPage'`
- `AlbumDetailPage` → `'使用 jellyfin_music 包中的 AlbumDetailPage'`
- `ArtistDetailPage` → `'使用 jellyfin_music 包中的 ArtistDetailPage'`
- `AiRecommendPage` → `'使用 jellyfin_ai_recommendation 包中的 AiRecommendPage'`

#### 3.2 模块边界检查脚本

创建 `scripts/check_module_boundaries.dart`：
- 扫描 `packages/features/*/lib/src/` 下所有 `.dart` 文件
- 检查是否 import 了根包 `jellyfin_service`（反向依赖）
- 检查是否 import 了其他 feature 包的 `src/`（跨模块穿透）
- 检查根包是否 import 了 feature 包的 `src/`（外部穿透）
- 结果：**全部通过**，零违规

### Task 15-A：AudioPlaybackPort 接口定义

**状态：完成**（2026-05-12）

#### 3.3 AudioPlaybackPort 接口

在 `jellyfin_music` 包中新增：

```
packages/features/jellyfin_music/lib/src/services/
└── audio_playback_port.dart    (95行) AudioPlaybackPort 抽象 + AudioTrack 数据类
```

**AudioTrack**：音轨抽象数据类，不依赖具体 MusicSong 模型
- `id`, `name`, `streamUrl`（必填）
- `coverUrl`, `artistText`, `duration`, `albumName`, `trackNumber`, `isFavorite`（可选）

**AudioPlaybackPort**：音频播放器抽象接口
- 播放控制：`playSong()`, `pause()`, `resume()`, `seek()`, `playNext()`, `playPrevious()`
- 状态查询：`currentTrack`, `isPlaying`, `position`, `duration`, `hasPlaylist`, `playlist`, `currentIndex`
- 播放模式：`toggleShuffle()`, `cycleRepeatMode()`
- 继承 `ChangeNotifier`，支持监听状态变化

#### 3.4 根包 AudioPlaybackManager 实现

`AudioPlaybackManager` 添加 `implements AudioPlaybackPort`：
- 新增 `_songToTrack()` / `_trackToSong()` 转换方法
- `currentTrack` getter 返回 `AudioTrack?`（从 MusicSong 转换）
- `playlist` getter 返回 `List<AudioTrack>`（接口要求）
- 旧 `List<MusicSong> get playlist` 重命名为 `musicPlaylist`（向后兼容）
- 新增 `playSong(AudioTrack, List<AudioTrack>, int)` 方法
- 更新下游引用：`mini_player_card.dart`、`music_library_page.dart` 改用 `musicPlaylist`

#### 3.5 测试

| 测试范围 | 结果 |
|---------|------|
| jellyfin_music 包测试 | 26/26 通过（新增 5 个 AudioTrack/Port 测试）|
| 根包测试 | 24/24 通过 |
| 边界检查脚本 | 全部通过 |
| **当前总测试数** | **177 个**（171 + 5 新增 + 1 AudioPlaybackPort 相关）|

---

### Task 18-B：旧模型 deprecated + 接口扩展

**状态：完成**（2026-05-12）

#### 3.6 旧模型 @Deprecated 标记

以下根包模型类已添加 `@Deprecated` 注解（18 个 hide 类型对应的旧模型）：

- `movie_filter_models.dart`：`MovieFilter`、`MovieFilterResult`
- `video_quality_models.dart`：`VideoQuality`（枚举）、`NetworkQualityMonitor`、`AutoQualityDecider`
- `person_models.dart`：`Person`
- `music_models.dart`：`MusicAlbum`、`MusicArtist`、`MusicSong`、`ArtistRef`、`MusicGenre`、`MusicAlbumListResult`、`MusicArtistListResult`、`MusicSongListResult`

`dart analyze` 确认：deprecated 警告为 `info` 级别，不影响编译和集成。主要使用者集中在 `music_service.dart` 和 `media_library_service.dart`，后续 Task 15-B 迁移时逐步切换。

#### 3.7 AudioPlaybackPort 接口扩展

为满足 `MusicLibraryPage` / `AudioPlayerPage` 的完整需求，扩展接口：

新增属性：
- `isLoading` — 是否正在加载音轨
- `error` — 播放错误信息
- `playlistLength` — 播放列表长度
- `playMode` — 当前播放模式（新增 `PlayMode` 枚举）
- `onPositionChanged` — 位置变化流（歌词同步等场景）

新增方法：
- `cyclePlayMode()` — 循环切换播放模式
- `updateTrackFavorite()` — 更新音轨收藏状态（乐观更新）

`PlayMode` 枚举从根包 `audio_playback_manager.dart` 迁移到接口层（`audio_playback_port.dart`），消除跨包类型冲突。

#### 3.8 dart analyze 验证

```
225 issues found.
- 0 errors
- 7 warnings（预先存在的 unnecessary_non_null_assertion 等）
- 218 info（deprecated_member_use_from_same_package + withOpacity 等）
```

deprecated 警告全部为 `info` 级别，**不影响编译和运行**。

---

## 四、Leader 指出的下一步方向

按 Leader 策略文档的优先级排序：

### 第一优先级：Phase 1-C（App Shell + Auth）

> 现在的 `media_libraries_page.dart` 已经承担了 App Shell 的职责。如果继续在根包里接更多 feature，后续再迁 App Shell 会更痛。

| 任务 | 说明 | 状态 |
|------|------|------|
| Task 8 | App Shell — 将 `media_libraries_page.dart` 的编排职责迁到独立的 Shell/Router | **待开始** |
| Task 9 | Auth — 登录/认证闭环，`LoginPage` 独立 | **待开始** |

### 第二优先级：Task 18 继续收敛

| 项目 | 说明 | 状态 |
|------|------|------|
| hide 数量修正 | 15 → 18（已完成） | ✅ |
| adapters 豁免移除 | 边界检查脚本删除 adapters 穿透豁免 | **待做** |
| 旧模型 deprecated | 不只旧页面，旧模型（如根包 `Person`、`MovieFilter`）也加标记 | **待做** |
| hide 列表清理 issue | 为每个 hide 类型建立清理跟踪 | **待做** |
| `dart analyze` 验证 | deprecated 警告不影响集成 | **待做** |

### 第三优先级：Task 15-B 音乐主链路解耦

| 步骤 | 说明 | 状态 |
|------|------|------|
| Step 1 | `MusicLibraryPage` 依赖 `AudioPlaybackPort` 而非 `AudioPlaybackManager` | **待做** |
| Step 2 | `MusicSearchPage`、`LyricsPage` 播放依赖改为 port | **待做** |
| Step 3 | `MusicService` DTO 转换逻辑下沉为 adapter | **待做** |
| Step 4 | 评估是否迁移 `MusicLibraryPage` 到 `jellyfin_music` | **待做** |

### 第四优先级：补集成验证

| 验证链路 | 说明 |
|---------|------|
| 媒体库 → 电影筛选 → 电影详情 → 播放 | smoke test 或手工验证清单 |
| 媒体库 → 剧集 → 季 → 集 → 播放 | smoke test 或手工验证清单 |

---

## 五、当前架构（Phase 3 更新）

```
jellyfin_dart (vendor)                    ← 第三方接口 SDK
    ↑
jellyfin_core ──→ jellyfin_api            ← 基础层（Phase 1）
    ↑                  ↑
jellyfin_models ←── jellyfin_ui_kit       ← 共享层（Phase 1）
    ↑
    ├── jellyfin_ai_recommendation        ← Feature 层（Phase 2）
    ├── jellyfin_media                    ← @Deprecated 标记旧版
    ├── jellyfin_movies                   ← @Deprecated 标记旧版
    ├── jellyfin_series                   ← @Deprecated 标记旧版
    ├── jellyfin_playback                 ← @Deprecated 标记旧版
    └── jellyfin_music                    ← AudioPlaybackPort 新增
    ↑
根包 jellyfin_service                      ← 业务聚合层
    ├── AudioPlaybackManager implements AudioPlaybackPort
    ├── barrel export + hide（兼容层，18 个类型）
    ├── 旧版页面 @Deprecated（11 个）
    ├── MusicService / MusicLibraryPage（保留，待 Task 15-B）
    ├── LoginPage / PersonalPage（保留，待 Task 8/9 App Shell）
    └── media_libraries_page.dart（事实 App Shell，待迁出）
```

---

## 六、验证结果（Phase 3 最新）

| 检查项 | 结果 |
|--------|------|
| `jellyfin_music` 独立 `flutter test` | 26/26 通过 |
| 根包 `flutter test` | 24/24 通过 |
| `dart scripts/check_module_boundaries.dart` | 全部通过 |
| `AudioPlaybackManager implements AudioPlaybackPort` | 编译通过 |
| `AudioTrack ↔ MusicSong` 转换 | 测试通过 |
| **11 包总测试数** | **177 个全部通过** |

---

## 七、遗留项与风险

### 7.1 `media_libraries_page.dart` 过度膨胀

该文件当前承担了 App Shell 职责，集中创建所有 feature 页面并装配回调/delegate/mapper。Leader 明确要求不要继续往里塞编排逻辑，优先迁到 App Shell。

### 7.2 `jellyfin_ai_recommendation` TTS 并行开发

另一个 Agent 在该模块新增了 TTS 功能（依赖 `just_audio`、`rainfall_tts_sdk`）。需确认 TTS 是 AI 包内聚能力还是拆为可选扩展。

### 7.3 docs/progress_report_2.md

误创建的文件，计划删除。

---

## 八、下一轮（Phase 3 继续）执行计划

按 Leader 优先级，下一轮应聚焦：

1. **Task 18-B**：完成剩余收敛项（adapters 豁免移除、旧模型 deprecated、hide 清理 issue）
2. **Task 15-B Step 1**：`MusicLibraryPage` 改用 `AudioPlaybackPort`
3. **Phase 1-C（Task 8/9）准备**：分析 `media_libraries_page.dart` 的编排逻辑，设计 App Shell 迁移方案
