# 第二阶段模块化进展报告

> 执行日期：2026-05-11
> 对应计划：`MODULARIZATION_EXECUTION_PLAN.md` Task 16（从第三阶段提前至第二阶段）

---

## 一、已完成内容

### Task 16: 抽 jellyfin_ai_recommendation

**状态：完成**

使用 `flutter create --template=package` 命令创建独立业务模块，完成 AI 对话推荐功能的完整解耦。

#### 模块结构

```
packages/features/jellyfin_ai_recommendation/
├── lib/
│   ├── jellyfin_ai_recommendation.dart                (barrel export)
│   └── src/
│       ├── models/ai_recommendation_models.dart       (253行) SSE事件、卡片、对话模型
│       ├── services/
│       │   ├── ai_recommendation_service.dart         (183行) AiStreamService 流式通信
│       │   ├── sse_fetch.dart                         (11行)  SSE stub
│       │   ├── sse_fetch_native.dart                  (22行)  Dio 流式（原生/鸿蒙）
│       │   └── sse_fetch_web.dart                     (44行)  XHR 流式（Web）
│       ├── pages/ai_recommend_page.dart               (846行) 解耦后的 AI 推荐页面
│       └── widgets/ai_recommend_pill.dart             (145行) 胶囊动画入口按钮
├── test/jellyfin_ai_recommendation_test.dart          (211行) 19个测试
└── pubspec.yaml
```

**依赖关系：**

```yaml
dependencies:
  jellyfin_core:       path: ../../foundation/jellyfin_core
  jellyfin_models:     path: ../../shared/jellyfin_models
  jellyfin_ui_kit:     path: ../../shared/jellyfin_ui_kit
  dio: ^5.4.0
  flutter_markdown: ^0.7.0
  equatable: ^2.0.5
```

#### 业务解耦设计（核心改动）

原始 `ai_recommend_page.dart`（871行）直接 import 5 个 feature 页面和服务：

```dart
// 解耦前 — 直接依赖具体 feature
import 'media_item_detail_page.dart';
import 'album_detail_page.dart';
import 'artist_detail_page.dart';
import 'audio_player_page.dart';
import 'audio_playback_manager.dart';
```

**解耦后**，`AiRecommendPage` 通过 4 个回调 + 2 个抽象接口实现完全解耦：

| 解耦点 | 原始耦合方式 | 解耦后方式 |
|--------|------------|-----------|
| 图片加载 | `JellyfinImageWithClient(client: widget.client)` | `JellyfinImageProvider` 抽象接口（来自 jellyfin_ui_kit） |
| 媒体详情获取 | `widget.client.mediaLibrary.getMediaItemDetail()` | `MediaItemDetailFetcher` 回调函数 |
| 视频详情页跳转 | `Navigator.push(MediaItemDetailPage(...))` | `onNavigateToMediaItem` 回调 |
| 专辑详情页跳转 | `Navigator.push(AlbumDetailPage(...))` | `onNavigateToAlbum` 回调 |
| 歌手详情页跳转 | `Navigator.push(ArtistDetailPage(...))` | `onNavigateToArtist` 回调 |
| 歌曲播放 | `AudioPlaybackManager.instance.play(...)` + `AudioPlayerPage(...)` | `onPlaySong` 回调 |

**解耦后的页面构造函数签名：**

```dart
class AiRecommendPage extends StatefulWidget {
  final String aiServiceUrl;                                    // AI 服务地址
  final JellyfinImageProvider imageProvider;                    // 图片加载抽象
  final MediaItemDetailFetcher fetchMediaItemDetail;            // 详情获取回调
  final void Function(BuildContext, MediaItem)? onNavigateToMediaItem;  // 视频跳转
  final void Function(BuildContext, MediaItem)? onNavigateToAlbum;      // 专辑跳转
  final void Function(BuildContext, MediaItem)? onNavigateToArtist;     // 歌手跳转
  final void Function(BuildContext, MediaItem)? onPlaySong;             // 播放歌曲
}
```

**AI 模块内部零直接 feature import。** 所有跳转逻辑由调用方（根包 `media_libraries_page.dart`）注入。

#### 根包适配层

`media_libraries_page.dart` 作为集成点，负责注入具体跳转实现：

```dart
// 根包 MediaItem → jellyfin_models MediaItem 类型适配
models.MediaItem toModelsMediaItem(local.MediaItem src) =>
    models.MediaItem(id: src.id, name: src.name, ...);

AiRecommendPage(
  aiServiceUrl: widget.client.configuration.resolvedAiServiceUrl,
  imageProvider: JellyfinClientImageProvider(widget.client),
  fetchMediaItemDetail: (itemId) async {
    final src = await widget.client.mediaLibrary.getMediaItemDetail(itemId);
    return toModelsMediaItem(src);  // 类型转换
  },
  onNavigateToMediaItem: (ctx, item) {
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => MediaItemDetailPage(client: widget.client, item: localItem),
    ));
  },
  // ... onNavigateToAlbum, onNavigateToArtist, onPlaySong 同理
);
```

#### AiRecommendPill 入口组件

从 `media_libraries_page.dart` 中提取 `_AiRecommendPill`（原为私有类，约 140 行），升级为公开组件 `AiRecommendPill`，放入独立模块的 `widgets/` 目录。

- 动画逻辑完全保留（9秒周期：圆形→胶囊→收回→静止）
- 主 app 只需 `AiRecommendPill(onPressed: () => Navigator.push(...))`

---

## 二、未完成内容

Task 16 涉及的所有内容已完成。以下为后续建议项：

- Task 10 ~ Task 15（媒体、首页、电影、剧集、播放、音乐）尚未开始
- `jellyfin_ai_recommendation` 模块内 `AiStreamService.cancel()` 仅为 TODO stub，尚未实现 AbortController (web) / CancelToken (native)
- 根包旧的 `ai_recommend_page.dart` / `ai_recommendation_service.dart` / `ai_recommendation_models.dart` / `sse_fetch*.dart` 文件保留在原位（作为兼容层），可在 facade 收敛阶段清理

---

## 三、遇到的问题

### 问题 1：根包 MediaItem 与 jellyfin_models MediaItem 类型冲突

**现象：** 根包有自己的 `MediaItem` 类（在 `lib/src/models/media_item_models.dart`），`jellyfin_models` 包也有同名的 `MediaItem`。两个类结构相似但来自不同包，Dart 类型系统不允许隐式转换。

**影响：** `AiRecommendPage` 使用 `jellyfin_models.MediaItem`，而根包 `JellyfinClient.mediaLibrary.getMediaItemDetail()` 返回根包的 `MediaItem`。直接传参会导致编译错误。

**解决：**
1. 在 `media_libraries_page.dart` 中对 `media_item_models.dart` 使用 `as local` 前缀导入
2. 定义 `toModelsMediaItem()` 转换函数，在 `fetchMediaItemDetail` 回调中完成类型适配
3. 在 `onNavigateToMediaItem` 回调中将 `jellyfin_models.MediaItem` 转回根包 `MediaItem`

**遗留：** 这个双类型问题是 Phase 1 存在模型重复的延续（根包模型保持含 `fromDto` 版本，`jellyfin_models` 为纯模型版本）。将在 Task 18（facade 收敛）时统一解决。

### 问题 2：SSE 条件导入在新模块中的路径

**现象：** `ai_recommendation_service.dart` 使用 Dart 条件导入：

```dart
import 'sse_fetch.dart'
  if (dart.library.html) 'sse_fetch_web.dart'
  if (dart.library.io) 'sse_fetch_native.dart';
```

迁移到新模块后，条件导入的相对路径保持不变（同目录），无需调整。

### 问题 3：AiRecommendPill 测试的定时器问题

**现象：** `AiRecommendPill` 的 `initState` 中有 `Future.delayed(const Duration(seconds: 2), ...)`，在 `flutter test` 环境中产生 pending timer 导致测试失败。

**解决：** 在 widget 测试末尾添加 `await tester.pump(const Duration(seconds: 3))` 让定时器触发后再结束测试。

### 问题 4：ambiguous_export 错误

**现象：** 根包 `jellyfin_service.dart` 同时 export 根包的 `ai_recommendation_models.dart` 和新模块的 `jellyfin_ai_recommendation.dart`（后者 re-export 了同名类），导致 `SseEventType` 等类的 ambiguous_export 编译错误。

**解决：** 从根包 `jellyfin_service.dart` 中移除对 `ai_recommendation_service.dart` 和 `ai_recommendation_models.dart` 的直接 export，由新模块统一提供。

---

## 四、当前文件变更清单

### 新增独立包

| 包 | 文件数 | 代码行 | 说明 |
|----|--------|--------|------|
| `packages/features/jellyfin_ai_recommendation/**` | 9 lib + 1 test | 1534 行 lib + 211 行 test | AI 推荐业务模块 |

### 根包改动

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `pubspec.yaml` | 修改 | 新增 `jellyfin_ai_recommendation` 依赖 |
| `lib/jellyfin_service.dart` | 修改 | 移除 `ai_recommendation_service.dart` / `ai_recommendation_models.dart` 的直接 export；改为 export `jellyfin_ai_recommendation` 包 |
| `lib/src/ui/pages/media_libraries_page.dart` | 修改 | 使用 `AiRecommendPill`（公开组件）+ `AiRecommendPage`（解耦版）；注入 4 个跳转回调和类型适配；删除内联 `_AiRecommendPill` 类（~140 行） |

### 根包保留（兼容层，未删除）

| 文件 | 说明 |
|------|------|
| `lib/src/ui/pages/ai_recommend_page.dart` | 旧版 AI 页面，仍可直接使用（传入 `client`），新代码应使用模块版 |
| `lib/src/services/ai_recommendation_service.dart` | 旧版 SSE 服务 |
| `lib/src/models/ai_recommendation_models.dart` | 旧版模型定义 |
| `lib/src/services/sse_fetch*.dart` | 旧版 SSE 平台适配 |

### 执行计划文档更新

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `MODULARIZATION_EXECUTION_PLAN.md` Section 24 | 修改 | Task 16 从第三阶段提前到第二阶段 |
| `MODULARIZATION_EXECUTION_PLAN.md` Section 25 | 修改 | 第三阶段范围调整为 Task 17-19 |

---

## 五、验证结果

| 检查项 | 结果 |
|--------|------|
| `jellyfin_ai_recommendation` 独立 `flutter analyze` | 0 error, 0 warning（21 info） |
| `jellyfin_ai_recommendation` 独立 `flutter test` | 19/19 通过 |
| `jellyfin_core` 独立 `flutter test` | 17/17 通过 |
| `jellyfin_api` 独立 `flutter test` | 8/8 通过 |
| `jellyfin_models` 独立 `flutter test` | 8/8 通过 |
| `jellyfin_ui_kit` 独立 `flutter test` | 14/14 通过 |
| 根包 `flutter test` | 19/19 通过 |
| 根包 `flutter analyze lib/` | 0 error（6 warning 均为既有问题，64 info） |
| `jellyfin_ai_recommendation` 不 import 任何 feature 页面 | **确认** — 零直接 feature import |
| `jellyfin_ai_recommendation` 不依赖 `JellyfinClient` | **确认** — 通过 `JellyfinImageProvider` + 回调解耦 |
| 6 包总测试数 | **85 个全部通过** |

---

## 六、下一步建议

1. **Task 10 jellyfin_media** — 抽通用媒体能力（MediaRepository、详情页、人物页），为电影/剧集/播放提供稳定基础
2. **Task 11 jellyfin_home** — 首页独立成包，通过 intent 打开业务模块
3. **Task 14 jellyfin_playback** — 视频播放独立成包
4. **Task 15 jellyfin_music** — 音乐业务独立成包
5. **长期收敛项：**
   - 根包旧 AI 文件在 Task 18（facade 收敛）时清理
   - `AiStreamService.cancel()` 补充 AbortController/CancelToken 实现
   - `MediaItem` 双类型在 Task 18 时统一

---

## 七、依赖关系图（当前实际）

```
jellyfin_dart (vendor)
    ↑
jellyfin_api ──→ jellyfin_core
    ↑                  ↑
jellyfin_ui_kit ──→ jellyfin_models
    ↑                  ↑
jellyfin_testing ──→ jellyfin_models + jellyfin_core
    ↑
jellyfin_ai_recommendation ──→ jellyfin_core + jellyfin_models + jellyfin_ui_kit

根包 jellyfin_service ──→ 上述所有包
    ├── JellyfinClientImageProvider 适配 jellyfin_ui_kit 抽象
    ├── media_libraries_page.dart 注入 4 个跳转回调到 AiRecommendPage
    ├── MediaItem 类型适配：根包 MediaItem ↔ jellyfin_models MediaItem
    └── jellyfin_service.dart re-export jellyfin_ai_recommendation（替代旧的直接文件 export）
```

关键约束验证：
- `jellyfin_ai_recommendation` **不 import** 任何 `packages/features/*` 以外的 feature 页面
- `jellyfin_ai_recommendation` **不依赖** `JellyfinClient`，通过抽象接口 + 回调完全解耦
- `jellyfin_ai_recommendation` **不依赖** 根包 `jellyfin_service`
- `jellyfin_ui_kit` 不依赖任何 `packages/features/*`
- `jellyfin_core` 不依赖 Flutter，不包含具体业务 action
- `jellyfin_models` 不依赖 Flutter，不依赖 `jellyfin_dart`

---

## 八、解耦验证清单

### 8.1 import 边界检查

```
jellyfin_ai_recommendation 的 import 仅来自：
  ✓ dart:* (系统库)
  ✓ package:flutter/*
  ✓ package:equatable/*
  ✓ package:flutter_markdown/*
  ✓ package:dio/*
  ✓ package:jellyfin_core/*
  ✓ package:jellyfin_models/*
  ✓ package:jellyfin_ui_kit/*
  ✓ src/* (自身)

  ✗ 无任何 import 指向根包 jellyfin_service
  ✗ 无任何 import 指向 media_item_detail_page / album_detail_page / artist_detail_page
  ✗ 无任何 import 指向 audio_player_page / audio_playback_manager
```

### 8.2 回调覆盖率

| AI 卡片类型 | 跳转目标 | 回调 | 状态 |
|------------|---------|------|------|
| movie / series / episode / video / season / musicvideo | 通用媒体详情页 | `onNavigateToMediaItem` | 覆盖 |
| audio | 音频播放 | `onPlaySong` | 覆盖 |
| musicalbum | 专辑详情页 | `onNavigateToAlbum` | 覆盖 |
| musicartist | 歌手详情页 | `onNavigateToArtist` | 覆盖 |

### 8.3 阶段评估

| 子阶段 | 状态 | 内容 |
|--------|------|------|
| Phase 1-A：基础包抽取与目录重组 | **完成** | Task 1, 2, 4 |
| Phase 1-B：API/UI Kit/Testing 补齐 | **完成** | Task 3, 5, 6, 7 |
| Phase 1-C：App Shell + Auth 验证闭环 | **待开始** | Task 8, 9 |
| Phase 2-A：AI 推荐业务解耦 | **完成** | Task 16 |

Phase 2-A 已完成。AI 推荐作为第一个业务模块完成独立化，验证了"回调解耦 + 抽象接口"方案在 feature 级别的可行性。下一步推进 Task 10-15。
