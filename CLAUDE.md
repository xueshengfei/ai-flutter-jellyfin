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
│   ├── jellyfin_video_app/       # 视频专用 App（腾讯视频风格，电影+剧集）
│   └── jellyfin_music_app/       # 音乐专用 App
│
├── packages/
│   ├── foundation/               # 基础层（无 Flutter 依赖）
│   │   ├── jellyfin_core/        # 配置、异常基类、模块协议
│   │   └── jellyfin_api/         # Dio HTTP 客户端、鉴权、jellyfin_dart 适配
│   │
│   ├── shared/                   # 共享层
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
│   ├── vendor/                   # 第三方包（含定制修改）
│   │   ├── jellyfin_dart_3.8/    # Jellyfin Dart SDK（OpenAPI 生成）
│   │   ├── rvc_sdk/              # RVC SDK
│   │   └── rainfall_tts_sdk/     # TTS SDK
│   │
│   └── plugins/                  # 自定义插件
│       └── video_gesture_controls/ # 视频手势控制
│
├── docs/                         # 文档
├── scripts/                      # 脚本
└── test/                         # 旧根包测试
```

## 依赖图

```
Product App (jellyfin_app / jellyfin_video_app / jellyfin_music_app)
  │
  ├── jellyfin_core         ← 配置、异常、导航协议
  ├── jellyfin_api          ← HTTP 客户端、鉴权
  │     └── jellyfin_core
  │     └── jellyfin_dart (vendor)
  ├── jellyfin_models       ← 共享模型（纯 Dart，无 Flutter）
  ├── jellyfin_ui_kit       ← UI 组件库
  │
  └── features/*
        ├── jellyfin_auth
        ├── jellyfin_movies
        ├── jellyfin_series
        ├── jellyfin_media
        ├── jellyfin_music
        ├── jellyfin_playback
        ├── jellyfin_personal
        ├── jellyfin_ai_recommendation
        └── rvc_flutter

各 feature 包只依赖: jellyfin_models + jellyfin_ui_kit（+ 各自所需第三方库）
feature 包之间 **禁止互相 import**，通过回调/协议解耦
```

## 新 App 架构（jellyfin_app）

```
Product/jellyfin_app/lib/src/
├── app/
│   ├── jellyfin_app.dart          # MaterialApp 入口
│   └── app_router.dart            # GoRouter 路由注册
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

## 核心约定

### 模块化规则
1. **Feature 模块**通过 `flutter create --template=package` 创建
2. Feature 只接受 `jellyfin_models.MediaItem`，不依赖旧根包
3. **类型转换在 Gateway 层**完成（`BaseItemDto` → `jellyfin_models`）
4. 外部禁止 `import src/`，使用 public sub-barrel
5. **页面跳转用回调/注入**，不直接 import 其它 feature 页面
6. `MovieFilter`/`MovieFilterResult` 在 `jellyfin_movies` 包，不在 `jellyfin_models`

### 路由注册模式
- 每个 feature 有 `*_pages.dart` barrel，导出纯 UI 页面
- Product App 的 `*_route_page.dart` 负责注入 Gateway/回调，用 FutureBuilder 包装
- GoRouter 路由集中在 `app_router.dart`

### 数据获取模式
- Gateway 定义数据获取接口
- Route Page 用 FutureBuilder 调 Gateway，结果注入 feature 页面
- Feature 页面通过 `typedef` 回调获取数据（如 `MediaItemDetailFetcher`）

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
- 过滤器后做，先整理业务链路
- 旧 `lib/` 冻结维护，新功能只加在 `packages/` 和 `Product/`
