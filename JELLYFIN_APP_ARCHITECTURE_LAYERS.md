# Jellyfin App 四层架构分层说明

> **状态：当前有效架构规范**
>
> 本文档是当前项目分层的主参考。`docs/archive/` 下的旧计划、旧阶段报告、历史策略只用于追溯，不再作为新开发依据。

本文档用于指导 `Product/*`、`packages/features/*`、`packages/shared/*`、`packages/foundation/*`、`packages/ohos/*`、`packages/plugins/*` 后续开发。当前项目采用四层模型：

```text
┌──────────────────────────────────────────────────────────────┐
│ 产品层 Product                                                │
│ Product/jellyfin_app、Product/jellyfin_video_app、              │
│ Product/jellyfin_music_app                                    │
│ App 入口、主题、路由、登录态、全局对象生命周期、产品级组装         │
├──────────────────────────────────────────────────────────────┤
│ 业务层 Business                                                │
│ packages/features/*                                           │
│ 登录、电影、剧集、媒体详情、音乐、播放、AI 推荐、个人中心、RVC       │
├──────────────────────────────────────────────────────────────┤
│ 基础组件层 Base Components                                     │
│ packages/shared/*、packages/foundation/jellyfin_core、           │
│ Flutter 生态组件：video_player、video_player_ohos、chewie、       │
│ fluttertpc_chewie、just_audio、fluttertpc_just_audio、            │
│ flutter_sound、通用手势组件等                                    │
│ 跨业务模型、UI 组件、协议、配置、异常、测试辅助、可组合组件能力       │
├──────────────────────────────────────────────────────────────┤
│ 基础工具层 Base Tools                                          │
│ packages/foundation/jellyfin_api、packages/vendor/*、             │
│ path_provider/path_provider_ohos、shared_preferences/*、          │
│ Dio/http、文件/缓存/键值对/字符串/格式化/日志工具、SDK/API 适配      │
└──────────────────────────────────────────────────────────────┘

依赖方向：上层可以依赖下层，下层不能反向依赖上层。
```

## 1. 分层标准

分层按“对上层暴露的能力类型”划分，不按目录名、是否有 ohos 实现、是否来自三方包机械划分。

| 层级 | 判断标准 | 典型内容 |
|---|---|---|
| 产品层 | 一个具体 App 或产品形态；负责把业务、组件、工具装配成可运行产品 | App 入口、MaterialApp、GoRouter、session、Gateway 注入、产品级 adapter |
| 业务层 | 面向用户场景的业务功能；可以独立沉淀为 feature 包 | 登录、电影、剧集、音乐、播放页、AI 推荐、个人中心、RVC 页面 |
| 基础组件层 | 被业务直接组合使用的模型、协议、UI、Flutter 生态组件或可复用能力组件 | `jellyfin_models`、`jellyfin_ui_kit`、`jellyfin_core`、`video_player`、`video_player_ohos`、`just_audio`、`fluttertpc_chewie`、手势组件 |
| 基础工具层 | 支撑组件和业务运行的底层技术工具、外部接口、SDK/API 适配 | `jellyfin_api`、`jellyfin_dart`、`path_provider`、`shared_preferences`、Dio、文件工具、缓存工具、字符串工具、日志工具 |

关键边界：

- `video_player` 和 `video_player_ohos` 都属于基础组件层。它们对上层暴露的是播放器组件能力，不因为其中一个是平台实现就降到工具层。
- `chewie`、`fluttertpc_chewie`、`just_audio`、`fluttertpc_just_audio`、`flutter_sound` 属于基础组件层。
- `path_provider`、`path_provider_ohos`、`shared_preferences`、`shared_preferences_ohos` 属于基础工具层。它们提供文件路径、键值存储等底层工具能力。
- `jellyfin_api`、`jellyfin_dart` 属于基础工具层。业务层不应直接创建 `JellyfinClient` 或直接操作 Jellyfin DTO。
- `jellyfin_core` 属于基础组件层。它放配置、异常、协议、导航意图等上层可复用契约。
- `jellyfin_testing` 属于基础组件层的测试组件，只允许测试代码依赖。

## 2. 当前路径归属

| 路径 / 依赖 | 层级 | 说明 |
|---|---|---|
| `Product/jellyfin_app` | 产品层 | 全功能 App，组合电影、音乐、AI、个人中心、RVC |
| `Product/jellyfin_video_app` | 产品层 | 视频专用 App |
| `Product/jellyfin_music_app` | 产品层 | 音乐专用 App |
| `packages/features/jellyfin_auth` | 业务层 | 登录/注册 UI |
| `packages/features/jellyfin_movies` | 业务层 | 电影筛选、电影详情 |
| `packages/features/jellyfin_series` | 业务层 | 剧集季/集列表 |
| `packages/features/jellyfin_media` | 业务层 | 通用媒体详情、人物详情 |
| `packages/features/jellyfin_music` | 业务层 | 音乐库、专辑、艺术家、歌曲、歌词、播放器页面 |
| `packages/features/jellyfin_playback` | 业务层 | Jellyfin 视频播放业务、画质控制、播放页 |
| `packages/features/jellyfin_personal` | 业务层 | 继续观看、收藏、历史、个人统计 |
| `packages/features/jellyfin_ai_recommendation` | 业务层 | AI 推荐、SSE、TTS 交互 |
| `packages/features/rvc_flutter` | 业务层 | RVC 语音转换任务页面和状态 |
| `packages/shared/jellyfin_models` | 基础组件层 | 跨业务共享模型和数据契约 |
| `packages/shared/jellyfin_ui_kit` | 基础组件层 | 通用 UI、图片、卡片、列表、分页等组件 |
| `packages/shared/jellyfin_testing` | 基础组件层 | fixtures、fake navigator、测试辅助 |
| `packages/foundation/jellyfin_core` | 基础组件层 | 配置、异常、模块协议、导航意图 |
| `packages/plugins/video_gesture_controls` | 基础组件层 | 播放器手势组件 |
| `packages/ohos/video_player` | 基础组件层 | `video_player` 及其 ohos 实现，整体视为播放器组件能力 |
| `packages/ohos/fluttertpc_chewie` | 基础组件层 | Chewie 播放器 UI 组件及 ohos 适配 |
| `packages/ohos/fluttertpc_just_audio` | 基础组件层 | 音频播放组件及 ohos 适配 |
| `packages/ohos/path_provider` | 基础工具层 | 文件路径工具及 ohos 实现 |
| `packages/ohos/shared_preferences` | 基础工具层 | 键值存储工具及 ohos 实现 |
| `packages/foundation/jellyfin_api` | 基础工具层 | Jellyfin API client、鉴权、网络异常转换 |
| `packages/vendor/jellyfin_dart_3.8` | 基础工具层 | Jellyfin OpenAPI 生成 SDK |
| `packages/vendor/rvc_sdk` | 基础工具层 | RVC 后端接口 SDK |
| `packages/vendor/rainfall_tts_sdk` | 基础工具层 | TTS SDK |
| `lib/` | 历史旧实现 | 冻结维护，仅作参考，不新增业务 |

## 3. 依赖规则

### 产品层

- 可以组合多个业务层 feature。
- 可以直接依赖基础组件层。
- 可以直接依赖基础工具层，并把 API、存储、播放器、平台能力适配成 Gateway / Repository / Port 后注入给业务层。
- 不允许直接 import feature 的 `src/` 内部文件，只使用 public barrel。
- 不允许继续扩张旧根包 `lib/src/ui/pages` 的业务页面。

### 业务层

- 只表达一个清晰业务能力，避免多个 feature 互相 import。
- 不持有 `AppSession`，不直接依赖 `go_router`，不直接创建 `JellyfinClient`。
- 需要数据时，通过产品层注入的 fetcher、repository、delegate、port 获取。
- 需要跳转时，通过回调、导航协议或产品层 route page 完成。
- 可以依赖基础组件层，例如模型、UI Kit、播放器组件、手势组件、协议。
- 原则上不直接依赖基础工具层；确需依赖时要确认它是该业务模块内部的底层实现细节，并避免外泄到 public API。

### 基础组件层

- 提供可被业务层直接组合的组件能力。
- 不能依赖产品层和业务层。
- UI 组件不能读取 App session、不能发网络请求、不能直接持有 Jellyfin token。
- 模型和协议尽量保持轻量、稳定、可测试。
- 测试组件只允许测试代码依赖，不能进入运行时代码路径。

### 基础工具层

- 提供底层技术工具、外部接口和 SDK/API 适配。
- 不能依赖产品层和业务层。
- 不能直接表达业务 UI 或产品流程。
- 文件、缓存、键值存储、字符串、格式化、日志、网络 client、Jellyfin SDK、RVC/TTS SDK 都放在这一层。
- 这一层可以被产品层直接使用，也可以被基础组件层内部使用。

## 4. 新功能放置规则

新增代码时先问两个问题：

1. 它是不是一个用户可感知的业务场景？
   - 是：放业务层 `packages/features/*`。
   - 否：继续判断。
2. 它对上层暴露的是组件能力，还是底层工具能力？
   - 组件能力：放基础组件层。
   - 工具能力：放基础工具层。

例子：

| 新增内容 | 推荐层级 |
|---|---|
| 新的“演员作品时间线”页面 | 业务层 |
| 通用横向媒体卡片 | 基础组件层 |
| 视频手势控制 Overlay | 基础组件层 |
| 字符串首字母/拼音分组工具 | 基础工具层 |
| 本地缓存键值封装 | 基础工具层 |
| Jellyfin API 新端点封装 | 基础工具层 |
| App 内把某个 API 结果转成 feature 页面参数 | 产品层 |

## 5. 当前 App 数据流

```text
LoginPage / Feature Page
  -> 产品层注入的回调 / Repository / Port
  -> Product/jellyfin_app 的 Gateway / Adapter
  -> 基础工具层 jellyfin_api / jellyfin_dart / RVC SDK / TTS SDK
  -> Jellyfin Server / Agent Server / RVC Server
```

类型转换规则：

- Jellyfin DTO 到 `jellyfin_models` 的转换在产品层 Gateway 或基础工具层 adapter 完成。
- Feature 页面只接收业务模型、基础组件层模型或回调，不接收 `BaseItemDto`。
- 图片 URL、鉴权 token、服务端地址等产品上下文由产品层注入。

## 6. 文档使用规则

- 本文档是当前有效分层规范。
- 根目录只保留当前有效的项目说明和架构说明。
- 已完成或过期的计划、策略、阶段报告归档到 `docs/archive/`，并在文件顶部标注 `已完成`、`已归档` 或 `过期`。
- 后续 AI 或开发者如果看到 `docs/archive/` 中与本文档冲突的旧“五层架构”“业务编排层”等说法，以本文档为准。
