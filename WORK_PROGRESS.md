# Jellyfin App 开发工作记录

> 本文档记录新产品 App（`Product/jellyfin_app`）从零到当前的全部开发阶段。
> 旧路线（Phase 1-5B）归档在 `docs/archive/modularization/`，此处不涉及。

---

## 整体架构

新产品 App 采用 **自顶向下重构** 策略，围绕五层架构搭建：

```text
┌──────────────────────────────────────────────────────┐
│  产品表现层  ─  App 启动、主题、路由、全局状态注入       │
│  Product/jellyfin_app/lib/src/app/*                  │
├──────────────────────────────────────────────────────┤
│  产品业务编排层  ─  首页、route page、session、gateway  │
│  Product/jellyfin_app/lib/src/{features,session,data}│
├──────────────────────────────────────────────────────┤
│  通用业务能力层  ─  可复用 feature 包（movies/music/…）  │
│  packages/features/*                                 │
├──────────────────────────────────────────────────────┤
│  通用 UI / 基础能力层  ─  jellyfin_ui_kit / models     │
│  packages/shared/*                                   │
├──────────────────────────────────────────────────────┤
│  基础设施层  ─  jellyfin_api / jellyfin_dart / testing │
│  packages/foundation/*                               │
└──────────────────────────────────────────────────────┘
```

依赖方向：上层 → 下层，禁止反向。

---

## Milestone A：建立 App 骨架

**目标**：创建 Flutter 工程，搭好 App 入口和基本骨架。

### 新建文件

| 文件 | 说明 |
|------|------|
| `product/jellyfin_app/` | Flutter 工程目录 |
| `lib/main.dart` | App 入口 |
| `lib/src/app/jellyfin_app.dart` | 根 Widget（MaterialApp.router） |
| `lib/src/app/app_router.dart` | go_router 路由表 + 登录重定向 |
| `lib/src/session/app_session.dart` | 登录态数据类 |
| `lib/src/session/app_session_controller.dart` | 登录态控制器（ChangeNotifier） |
| `lib/src/data/jellyfin_gateway.dart` | Gateway 接口（纯抽象） |

### 关键设计

- `GoRouter` + `refreshListenable` 监听登录态，自动重定向
- `resolveAuthRedirect()` 纯函数，可独立测试
- `JellyfinGateway` 定义所有数据访问契约，App 层只依赖接口

### 路由

- `/login` — 登录页（占位）
- `/libraries` — 首页（占位）

---

## Milestone B：接入登录注册

**目标**：连通 `jellyfin_auth` feature 包，完成真实登录流程。

### 新建/修改文件

| 文件 | 说明 |
|------|------|
| `lib/src/data/legacy_jellyfin_gateway.dart` | 实现 `JellyfinGateway`，用 `jellyfin_api` / `jellyfin_dart` 调 API |
| `lib/src/features/home/media_libraries_page.dart` | 媒体库首页（导航枢纽） |

### 关键设计

- `LegacyJellyfinGateway.login()` 调用 `jellyfin_api` 创建 `JellyfinClient`，返回 `AppSession`
- `AppSession` 持有 `serverUrl` / `accessToken` / `userId` / `username`
- 登录成功 → `sessionController.setSession()` → GoRouter 自动重定向到 `/libraries`

### 请求流向

```text
LoginPage.onLogin(serverUrl, username, password)
  → JellyfinGateway.login()
  → LegacyJellyfinGateway（jellyfin_api + jellyfin_dart）
  → AppSessionController.setSession()
  → GoRouter redirect → /libraries
```

---

## Milestone C：接入媒体库首页

**目标**：登录后展示媒体库列表 + 继续观看，作为 App 导航枢纽。

### 修改文件

| 文件 | 说明 |
|------|------|
| `media_libraries_page.dart` | 完整首页：媒体库卡片 + 继续观看 + 退出登录 |
| `app_router.dart` | `/libraries` 路由注入 gateway 回调 |

### 关键设计

- `MediaLibrariesPage` 留在 App 业务编排层（不是通用 feature）
- 根据媒体库类型路由分发：`movies` → `/movies`、`tvshows` → `/series`、`music` → `/music`
- 继续观看点击 → `/media/items/:id`
- 不直接 import 任何 feature 页面，通过回调注入跳转

---

## Milestone D：接入电影与媒体详情链路

**目标**：电影筛选 → 电影详情 → 通用详情 → 剧集（季/集）完整链路。

### 新建/修改文件

| 文件 | 说明 |
|------|------|
| `lib/src/features/media/media_route_pages.dart` | 5 个 route page（FutureBuilder → feature 页面） |
| `packages/features/jellyfin_movies/` | 电影 feature 包 |
| `packages/features/jellyfin_media/` | 通用媒体 feature 包 |
| `packages/features/jellyfin_series/` | 剧集 feature 包 |

### 关键设计

- Gateway 直接返回 `jellyfin_models` 类型（`MediaItem`、`SeasonListResult`、`EpisodeListResult`）
- `BaseItemDto → jellyfin_models` 类型转换在 `LegacyJellyfinGateway` 完成
- Route page 职责：从路由参数取 id → 调 gateway → 把数据传给 feature 页面
- Feature 页面只接受标准模型 + 回调，不依赖 App 层

### 路由（5 条）

| 路径 | Route Page | Feature 页面 |
|------|-----------|-------------|
| `/libraries/:libraryId/movies` | `MoviesRoutePage` | `MovieFilterPage` |
| `/movies/:itemId` | `MovieDetailRoutePage` | `MovieDetailPage` |
| `/media/items/:itemId` | `MediaDetailRoutePage` | `MediaItemDetailPage` |
| `/series/:seriesId/seasons` | `SeriesSeasonsRoutePage` | `SeasonListPage` |
| `/series/:seriesId/seasons/:seasonId/episodes` | `SeriesEpisodesRoutePage` | `EpisodeListPage` |

---

## Milestone E：接入播放模块

**目标**：视频播放链路 — 电影/剧集详情页点击播放 → 视频播放器。

### 新建/修改文件

| 文件 | 说明 |
|------|------|
| `lib/src/features/playback/playback_route_page.dart` | 视频播放 route page |
| `lib/src/data/legacy_jellyfin_gateway.dart` | 新增 `getPlaybackInfo()` 方法 |
| `packages/features/jellyfin_playback/` | 视频播放 feature 包 |

### 关键设计

- `PlaybackAdapter` 用 `jellyfin_api` 直接创建 `PlaybackDelegate`
- 支持 DirectPlay + Transcode，画质切换，进度上报
- `VideoPlaybackRoutePage`：加载 MediaItem → PlaybackAdapter → VideoPlayerPage
- 第三方插件（`video_player` / `chewie`）限制在播放 feature 内部

### 路由

| 路径 | 说明 |
|------|------|
| `/playback/video/:itemId` | 视频播放页 |

### 播放入口

- 电影详情页播放按钮
- 通用媒体详情页播放按钮
- 剧集集列表播放按钮

---

## Milestone G：接入音乐业务模块

> 注：Milestone F 为旧路线编号，新路线跳过。

**目标**：音乐库三 Tab 布局 + 专辑详情 + 艺术家详情 + 音频播放。

### 新建/修改文件

| 文件 | 说明 |
|------|------|
| `lib/src/features/music/music_route_pages.dart` | 音乐 route page（注入 gateway + port + 路由跳转） |
| `lib/src/data/audio_playback_adapter.dart` | `AudioPlaybackAdapter` 单例，实现 `AudioPlaybackPort`（just_audio） |
| `packages/features/jellyfin_music/lib/src/models/music_models.dart` | 音乐领域模型（MusicAlbum / MusicArtist / MusicSong） |
| `packages/features/jellyfin_music/lib/src/services/audio_playback_port.dart` | 音频播放器抽象接口（AudioPlaybackPort / AudioTrack / PlayMode） |
| `packages/features/jellyfin_music/lib/src/pages/music_library_page.dart` | 音乐库三 Tab 页面（专辑 / 艺术家 / 歌曲） |
| `packages/features/jellyfin_music/lib/src/pages/album_detail_page.dart` | 专辑详情页 |
| `packages/features/jellyfin_music/lib/src/pages/artist_detail_page.dart` | 艺术家详情页 |
| `packages/features/jellyfin_music/lib/src/pages/music_player_page.dart` | 音乐播放详情页（唱片旋转 + 进度条 + 控制栏） |

### 关键设计

- `AudioPlaybackPort` 抽象接口（extends ChangeNotifier），feature 包不依赖 `just_audio`
- `AudioPlaybackAdapter` 单例在 App 层，生命周期与 App 一致，退出播放页后音乐继续
- `MusicSong → AudioTrack` 转换在 `music_route_pages.dart` 顶层函数，feature 包不感知
- `createAppRouter` 新增 `audioPlaybackPort` 参数
- Feature 页面通过回调注入：`AlbumsFetcher` / `OnOpenAlbum` / `OnPlayTracks` 等

### 路由（4 条）

| 路径 | Route Page | Feature 页面 |
|------|-----------|-------------|
| `/libraries/:libraryId/music` | `MusicLibraryRoutePage` | `MusicLibraryPage`（三 Tab） |
| `/music/albums/:albumId` | `AlbumDetailRoutePage` | `AlbumDetailPage` |
| `/music/artists/:artistId` | `ArtistDetailRoutePage` | `ArtistDetailPage` |
| `/playback/music` | 直接构建 | `MusicPlayerPage` |

---

## P0：音乐模块边界修正

**目标**：将音乐 UI 页面从 `product/jellyfin_app` 移到 `jellyfin_music` 包，确保模块边界清晰。

### 变更文件

| 文件 | 变更 |
|------|------|
| `MusicLibraryPage` | 从 App 编排层移入 `jellyfin_music` 包 |
| `MusicPlayerPage` | 从 App 编排层移入 `jellyfin_music` 包 |
| `music_route_pages.dart` | 精简为纯注入层（只注入 gateway + port + 路由跳转） |
| `jellyfin_music_pages.dart` | 新 barrel 导出所有页面 |
| `jellyfin_music.dart` | 主 barrel 只导出 models + services |

### 关键设计

- Feature 页面通过回调注入数据获取和导航（`fetchAlbums` / `onOpenAlbum` / `onPlayTracks`）
- `music_route_pages.dart` 职责明确：路由参数 → 注入 gateway/port → 组装 feature 页面
- Feature 包不依赖 `go_router`，不 import 其他 feature 页面

---

## P1：音乐模块迷你播放器（修正后）

> **修正记录**：原设计为全局 App Shell 迷你播放器（ShellRoute 包裹所有路由），经评审修正为音乐模块范围内显示。

**目标**：音乐库、专辑详情、艺术家详情页面底部显示迷你播放器；非音乐页面不显示；播放详情页不显示。

### 新建文件

| 文件 | 说明 |
|------|------|
| `packages/features/jellyfin_music/lib/src/widgets/mini_player_bar.dart` | 迷你播放器组件 |
| `packages/features/jellyfin_music/lib/src/widgets/music_area_shell.dart` | 音乐模块范围壳（Column: child + MiniPlayerBar） |

### 修改文件

| 文件 | 变更 |
|------|------|
| `jellyfin_music_pages.dart` | 新增 export mini_player_bar / music_area_shell |
| `music_route_pages.dart` | 三个音乐 route page 用 `MusicAreaShell` 包裹 |
| `app_router.dart` | 艺术家详情页注入 `audioPlaybackPort` |

### 已删除文件

| 文件 | 原因 |
|------|------|
| `product/jellyfin_app/lib/src/app/app_shell.dart` | 全局 Shell 方案已废弃 |

### 关键设计

#### 产品边界

```text
显示迷你播放器的页面：
  /libraries/:libraryId/music    音乐库
  /music/albums/:albumId         专辑详情
  /music/artists/:artistId       艺术家详情

不显示迷你播放器的页面：
  /login, /libraries, /movies, /series, /playback/video 等
  /playback/music                播放详情页（避免重复）
```

#### MusicAreaShell

- `Column` 布局：`Expanded(child)` + `MiniPlayerBar`
- 只在音乐 route page 中使用，非音乐页面不会感知
- `showMiniPlayer` 参数控制显示（默认 true）

#### MiniPlayerBar

- `ListenableBuilder` 监听 `AudioPlaybackPort`
- 无播放列表时 `SizedBox.shrink()`，不占空间
- 布局：封面 | 歌名+歌手 | play/pause | next
- 底部带 2px 迷你进度条
- 不 import `go_router`，导航通过 `onOpenPlayer` 回调注入

#### 播放状态保留

- `AudioPlaybackAdapter` 仍为 App 级单例
- 离开音乐模块后音乐继续播放，只是不显示迷你播放器
- 后续如需全 App 迷你播放器，再扩展 ShellRoute

---

## 完整路由表

| 路径 | 阶段 | 说明 |
|------|------|------|
| `/login` | B | 登录页 |
| `/libraries` | C | 媒体库首页 |
| `/libraries/:libraryId/movies` | D | 电影筛选页 |
| `/libraries/:libraryId/series` | D | 剧集列表页 |
| `/libraries/:libraryId/music` | G | 音乐库页 ★ |
| `/music/albums/:albumId` | G | 专辑详情页 ★ |
| `/music/artists/:artistId` | G | 艺术家详情页 ★ |
| `/movies/:itemId` | D | 电影详情页 |
| `/media/items/:itemId` | D | 通用媒体详情页 |
| `/series/:seriesId/seasons` | D | 季列表页 |
| `/series/:seriesId/seasons/:seasonId/episodes` | D | 集列表页 |
| `/playback/video/:itemId` | E | 视频播放页 |
| `/playback/music` | G | 音乐播放详情页 |

共 13 条平铺路由，★ 标记的 3 条音乐页面内嵌迷你播放器。

---

## 关键架构约定

### 模块化

- Feature 模块创建方式：`flutter create --template=package`
- 所有 feature 只接受 `jellyfin_models.MediaItem`，不感知 `BaseItemDto`
- 类型转换在 Gateway 层完成
- 外部禁止 import `src/`，使用 public sub-barrel
- 页面跳转用回调/注入，不直接 import 其他 feature 页面

### 依赖规则

```text
产品 App 可 import → feature public barrel
Feature 禁止 import → App、其他 feature src、go_router
Gateway 返回 → jellyfin_models 类型
AudioPlaybackPort → 抽象接口，just_audio 只在 Adapter 内
```

### 播放器架构

```text
AudioPlaybackPort（抽象，在 jellyfin_music）
    ↑ implements
AudioPlaybackAdapter（单例，在 product/jellyfin_app）
    → just_audio AudioPlayer
```

- `AudioPlaybackAdapter` 生命周期与 App 一致
- 离开音乐模块后音乐继续播放
- `MiniPlayerBar` / `MusicPlayerPage` / `MusicAreaShell` 都只依赖 `AudioPlaybackPort`
- 迷你播放器只在音乐模块范围内显示

---

## P2：RVC 内存级任务中心

**目标**：RVC 一键翻唱任务状态从页面级提升到 App 级，页面退出后任务不丢失。

### 核心问题

旧 `RvcPage` 所有状态（`_isConverting`、`_convertResult`、`_audioPlayer`）都在 `_RvcPageState` 里。
用户退出页面后 `dispose()` 销毁一切，耗时任务结果丢失。

### 新建文件

| 文件 | 说明 |
|------|------|
| `rvc_flutter/lib/src/models/rvc_task.dart` | `RvcTaskStatus` 枚举 + `RvcTaskSnapshot` 不可变快照 |
| `rvc_flutter/lib/src/controllers/rvc_task_controller.dart` | `RvcTaskController`（ChangeNotifier） |
| `product/jellyfin_app/lib/src/features/rvc/rvc_route_page.dart` | RVC 路由页面（注入 controller） |

### 修改文件

| 文件 | 变更 |
|------|------|
| `rvc_flutter/lib/rvc_flutter.dart` | 新增 export controller + models |
| `rvc_flutter/lib/src/rvc_page.dart` | 重构：接收 `RvcTaskController`，用 `ListenableBuilder` |
| `app_router.dart` | 新增 `/rvc` 路由，`createAppRouter` 新增 `rvcTaskController` 参数 |
| `jellyfin_app.dart` | 创建并持有 `RvcTaskController`（延迟初始化） |
| `pubspec.yaml` | 新增 `rvc_flutter` 依赖 |

### 关键设计

#### RvcTaskController

```text
管理三个核心能力（全部 App 级生命周期）：
  1. 服务连接：RVCClient、connect()、status、models
  2. 任务执行：startConvert() / startCover()、RvcTaskSnapshot
  3. 结果播放：AudioPlayer、togglePlayback()
```

#### 任务流程

```text
用户进入 /rvc
  → RvcRoutePage 注入 App 级 controller
  → 用户选择文件/模型/参数 → 点击转换
  → controller.startConvert() / startCover()
  → 用户退出页面
  → controller 仍在 App 内存中
  → HTTP Future 完成后写入 controller
  → 用户再次进入 /rvc
  → 页面通过 ListenableBuilder 读取 controller.currentTask
  → 展示上次任务结果 / 继续播放
```

#### RvcPage 重构

- 从 `StatefulWidget`（自建 `RVCClient` + `AudioPlayer`）→ `StatefulWidget`（接收 `controller`）
- 页面只管理临时 UI 状态（文件选择、参数滑块）
- 所有业务逻辑通过 controller 代理
- `ListenableBuilder` 监听 controller 状态变化

---

## 测试状态

| 阶段 | 测试内容 | 数量 |
|------|---------|------|
| A-B | `resolveAuthRedirect` 纯函数测试 | 4 |
| B-C | `createAppRouter` 路由重定向测试 | 6 |
| B | 登录流程测试（LoginPage） | 5 |
| D | 路由注册验证测试 | 1+ |
| **总计** | | **15+ 全部通过** |

---

## 后续任务

| 编号 | 任务 | 状态 |
|------|------|------|
| P0 | 音乐模块边界修正 | ✅ 已完成 |
| P1 | 音乐模块迷你播放器 | ✅ 已完成（已修正） |
| P2 | RVC 内存级任务中心 | ✅ 已完成 |
| P3 | 搜索 + 歌词 | 待开始 |
| P4 | 模型清理 | 待开始 |
