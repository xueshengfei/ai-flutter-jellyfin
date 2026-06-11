# Jellyfin Service SDK - 项目指南

## 项目定位

Jellyfin 媒体服务业务 SDK（Flutter Monorepo），版本 0.3.0。基于官方接口 SDK `jellyfin_dart` 构建完整的媒体浏览、播放、推荐能力。

## 仓库结构

```
Jellyfin_Service/
├── lib/                          # 旧单体包（冻结维护，仅作参考实现）
│   ├── jellyfin_service.dart     # 旧 barrel 文件
│   └── src/                      # 旧代码：core/services/models/ui/app_shell/
│
├── Product/                      # 产品 App（入口）
│   ├── jellyfin_app/             # 全功能 App（电影+音乐+AI+个人）
│   ├── jellyfin_video_app/       # 视频专用 App（支持 FlutterBoost 宿主路由）
│   ├── jellyfin_music_app/       # 音乐专用 App
│   └── android_jellyfin_module/  # Android 宿主集成用 FlutterBoost 模块
│
├── packages/
│   ├── foundation/               # 基础组件/基础工具包
│   │   ├── jellyfin_core/        # 基础组件层：配置、异常基类、模块协议
│   │   └── jellyfin_api/         # 基础工具层：Dio HTTP 客户端、鉴权、jellyfin_dart 适配
│   │
│   ├── shared/                   # 基础组件层
│   │   ├── jellyfin_models/      # 跨模块共用纯 Dart 模型
│   │   ├── jellyfin_ui_kit/      # 跨业务复用 UI 组件库
│   │   └── jellyfin_testing/     # 测试 fixtures、fake navigator
│   │
│   ├── features/                 # 业务 Feature 模块
│   │   ├── jellyfin_auth/        # 登录/注册 UI
│   │   ├── jellyfin_movies/      # 电影筛选/详情
│   │   ├── jellyfin_series/      # 剧集季/集列表
│   │   ├── jellyfin_media/       # 通用媒体项详情/人物详情
│   │   ├── jellyfin_music/       # 音乐专辑/艺术家/歌曲/歌词/搜索/迷你播放器
│   │   ├── jellyfin_playback/    # 视频播放 + 画质控制
│   │   ├── jellyfin_personal/    # 个人中心（继续观看/收藏/历史）
│   │   ├── jellyfin_ai_recommendation/ # AI 推荐/SSE/TTS
│   │   └── rvc_flutter/          # RVC 语音转换任务中心
│   │
│   ├── vendor/                   # 基础工具层：第三方包（含定制修改）
│   │   ├── jellyfin_dart_3.8/    # Jellyfin Dart SDK（OpenAPI 生成）
│   │   ├── rvc_sdk/              # RVC SDK
│   │   └── rainfall_tts_sdk/     # TTS SDK
│   │
│   └── plugins/                  # 基础组件层：自定义组件插件
│       └── video_gesture_controls/ # 视频手势控制
│
├── docs/                         # 文档
├── scripts/                      # 脚本
└── test/                         # 旧根包测试
```

## 四层架构与依赖图

```
产品层 Product
  Product/jellyfin_app / jellyfin_video_app / jellyfin_music_app
    ↓
业务层 Business
  packages/features/*
    ↓
基础组件层 Base Components
  packages/shared/*
  packages/foundation/jellyfin_core
  video_player / video_player_ohos / chewie / just_audio / 手势组件
    ↓
基础工具层 Base Tools
  packages/foundation/jellyfin_api
  packages/vendor/*
  path_provider / shared_preferences / Dio / 文件、缓存、字符串、日志工具
```

分层标准：业务层放用户可感知的业务能力；基础组件层放可被业务直接组合的模型、协议、UI、播放器/音频等组件能力；基础工具层放文件、存储、网络、SDK/API、字符串、键值对、日志等底层工具能力。

各 feature 包之间 **禁止互相 import**，通过回调/协议解耦。feature 包不直接创建 `JellyfinClient`，由产品层 Gateway/Repository/Port 注入数据和能力。

## 产品 App 架构与路由入口

```
Product/jellyfin_app/lib/src/
├── app/
│   ├── jellyfin_app.dart          # MaterialApp 入口
│   └── app_router.dart            # GoRouter 路由表与 ServiceRegistry 注入
├── session/
│   ├── app_session.dart           # 登录态（token/serverUrl/userId）
│   └── app_session_controller.dart
├── data/
│   ├── legacy_jellyfin_gateway.dart  # Gateway: jellyfin_api/dart → jellyfin_models
│   ├── jellyfin_gateway.dart         # Gateway 接口
│   ├── playback_adapter.dart         # 视频播放适配
│   ├── audio_playback_adapter.dart   # 音频播放适配（just_audio 单例）
│   └── personal_repository_adapter.dart # 个人模块 Repository 适配
├── features/
│   ├── home/media_libraries_page.dart  # 首页（媒体库列表）
│   ├── media/media_route_pages.dart    # 媒体路由页（FutureBuilder → feature 页面）
│   ├── music/music_route_pages.dart    # 音乐路由页
│   ├── playback/playback_route_page.dart
│   ├── personal/personal_route_page.dart
│   └── rvc/rvc_route_page.dart
└── ui/
    └── jellyfin_app_image_provider.dart # 图片 Provider 注入
```

当前产品层允许按交付形态选择路由入口：

| 产品形态 | 路由方式 | 适用场景 |
|---|---|---|
| `Product/jellyfin_app` | `GoRouter + MaterialApp.router` | 全功能独立 App，本仓库内联调和完整业务验证 |
| `Product/jellyfin_music_app` | `GoRouter + MaterialApp.router` | 音乐专用独立 App |
| `Product/jellyfin_video_app` | `FlutterBoostApp + routeFactory` 为当前入口，保留 GoRouter 文件作独立 App/迁移参考 | 宿主 App 通过页面名打开视频业务页 |
| `Product/android_jellyfin_module` | `FlutterBoostApp + routeFactory` | Android 原生团队集成 Flutter 模块 |

路由框架只属于产品层。业务 feature 不绑定 `go_router`、`flutter_boost` 或宿主 App 页面类，只暴露页面、模型、回调、Repository、Port、`AppNavigator`/`NavigationIntent` 等稳定契约。产品层负责把稳定 route name、宿主页面名或 URL path 映射到具体页面，并注入 Gateway、Session、ImageProvider、播放适配器等依赖。

## 核心约定

### 模块化规则
1. **Feature 模块**通过 `flutter create --template=package` 创建
2. Feature 只接受 `jellyfin_models.MediaItem`，不依赖旧根包
3. **类型转换在 Gateway 层**完成（`BaseItemDto` → `jellyfin_models`）
4. 外部禁止 `import src/`，使用 public sub-barrel
5. **页面跳转用回调/注入**，不直接 import 其它 feature 页面
6. `MovieFilter`/`MovieFilterResult` 在 `jellyfin_movies` 包，不在 `jellyfin_models`

### 路由注册模式
- 每个 feature 有 public barrel，导出纯 UI 页面、协议、Repository/Port/Fetcher typedef
- Feature 内部跳转通过回调、`AppNavigator` 或 `NavigationIntent` 表达，不直接依赖具体路由框架
- 独立 App 可以在 `app_router.dart` 里集中注册 GoRouter 路由
- 宿主集成 App 使用 `FlutterBoostApp` 的 `routeFactory` 按稳定页面名注册路由
- Product 层的 route page、route widget 或 route factory 负责注入 Gateway/回调，并按需用 FutureBuilder 包装异步数据

### 数据获取模式
- Gateway 定义数据获取接口
- Route Page 用 FutureBuilder 调 Gateway，结果注入 feature 页面
- Feature 页面通过 `typedef` 回调获取数据（如 `MediaItemDetailFetcher`）

### CI/CD 与版本化协作
- 多团队协作时以 `packages/features/*`、`packages/shared/*`、`Product/*` 为交付边界，避免跨 feature 私有 `src/` 依赖
- 可独立发布的包必须维护 `pubspec.yaml` `version` 和 `CHANGELOG.md`，通过版本号表达兼容性和交付内容
- 宿主侧优先依赖 CI/CD 产出的 Flutter module/AAR/HAR 或锁定版本的内部包，不直接绑定开发分支临时代码
- 稳定 route name、页面名、Repository/Port 接口属于跨团队契约，变更时必须同步版本号、文档和兼容说明

### 图片加载
- `JellyfinImageProvider` 注入式，各 App 提供 URL 构建实现
- `JellyfinImage` 组件统一处理认证图片

## 关键模型位置

| 模型 | 位置 |
|------|------|
| MediaItem, MediaLibrary | `packages/shared/jellyfin_models/lib/src/` |
| Person, PersonCreditsResult | `packages/features/jellyfin_media/` |
| MusicAlbum, MusicSong, MusicArtist | `packages/features/jellyfin_music/` |
| MovieFilter, MovieFilterResult | `packages/features/jellyfin_movies/` |
| LyricsData, RemoteLyricsInfo | `packages/features/jellyfin_music/` |
| PersonalMediaKind, PersonalSectionState | `packages/features/jellyfin_personal/` |
| RvcTaskSnapshot, RvcTaskStatus | `packages/features/rvc_flutter/` |
| VideoQuality, PlaybackInfo | `packages/features/jellyfin_playback/` |
| 数据获取 typedef | `packages/shared/jellyfin_models/lib/src/media_contracts.dart` |

## 测试

```bash
# 全部测试（新 App）
cd Product/jellyfin_app && flutter test

# 单包测试
cd packages/features/jellyfin_movies && flutter test

# 静态分析
cd Product/jellyfin_app && flutter analyze
```

测试规模：jellyfin_app 15 个测试，jellyfin_video_app 8 个测试，jellyfin_music_app 8 个测试，各 feature 包独立测试。

## 开发偏好

- 中文代码注释和文档
- UI 文本中文显示
- Git 日志使用中文，长度控制在 10 到 100 字，说明本次实际变更
- 过滤器后做，先整理业务链路
- 旧 `lib/` 冻结维护，新功能只加在 `packages/` 和 `Product/`
