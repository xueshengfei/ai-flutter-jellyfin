# Jellyfin Personal Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新建可复用的 `jellyfin_personal` 个人模块，让 `jellyfin_app`、`jellyfin_movie_app`、后续 `jellyfin_music_app` 能复用历史记录、收藏、继续观看、个人信息和退出登录能力。

**Architecture:** `jellyfin_personal` 是 Feature 层模块，只定义页面、状态、Repository 协议和点击动作协议；它不依赖 `go_router`、`jellyfin_dart`、`jellyfin_api`、产品 App Session。`jellyfin_app` / `jellyfin_movie_app` 在 Product 层实现 adapter，把当前登录态里的 `serverUrl`、`accessToken`、`userId` 和 `jellyfin_dart` API 转换成模块需要的纯业务数据。

**Tech Stack:** Flutter, Dart, `jellyfin_models`, `jellyfin_ui_kit`, Product App adapter, `jellyfin_dart` `ItemsApi` / `UserLibraryApi` / `PlaystateApi`, `go_router` only in Product apps.

---

## 一期目标

一期交付给 agent 员工执行，目标是先把个人模块跑通，并在两个现有产品 App 中完成真实接入。

一期完成后应具备：

- `packages/features/jellyfin_personal` 独立 Feature 包。
- 个人页展示用户信息、继续观看、收藏、观看历史。
- 点击历史或收藏中的卡片，可以跳到对应媒体详情页。比如历史记录点击“疯狂动物城”，进入“疯狂动物城详情页”。
- 卡片上的播放动作可以进入播放页；详情跳转和播放跳转是两个不同回调。
- `jellyfin_app` 使用完整个人页配置，展示电影、剧集、音乐等媒体。
- `jellyfin_movie_app` 使用电影专用个人页配置，只展示电影相关记录。
- 所有 Jellyfin 请求留在 Product adapter，Feature 包不感知 token 和服务器地址。

## 二期目标

二期在一期跑通后再做，不影响一期验收。

- 接入后续 `jellyfin_music_app`，个人页按音乐产品形态展示收藏歌曲、专辑、艺人、播放历史。
- 把 Product adapter 中重复的 `BaseItemDto -> MediaItem` 映射抽到统一基础设施包。
- 增加个人设置、用户头像、统计页、清除历史、本地缓存。
- 增加 AI/RVC 任务历史入口，但任务控制器生命周期仍留在 Product App。
- 把个人页入口统一接入未来的 App Shell 底部导航或侧边栏。
- 如果产品矩阵继续扩大，再抽 `jellyfin_user_data` 基础能力包承接收藏、历史、播放状态接口。

---

## 当前接口层结论

员工开始写 adapter 前先读这些接口，不要靠猜。

| 能力 | jellyfin_dart 接口 | 参数要点 | 返回 |
|---|---|---|---|
| 继续观看 | `ItemsApi.getResumeItems` | `userId`, `startIndex`, `limit`, `includeItemTypes`, `enableUserData: true` | `BaseItemDtoQueryResult` |
| 收藏列表 | `ItemsApi.getItems` | `userId`, `isFavorite: true`, `includeItemTypes`, `recursive: true`, `enableUserData: true` | `BaseItemDtoQueryResult` |
| 观看历史 | `ItemsApi.getItems` | `userId`, `isPlayed: true`, `includeItemTypes`, `recursive: true`, `sortBy: DatePlayed`, `sortOrder: Descending`, `enableUserData: true` | `BaseItemDtoQueryResult` |
| 标记收藏 | `UserLibraryApi.markFavoriteItem` | `itemId`, `userId` | `UserItemDataDto` |
| 取消收藏 | `UserLibraryApi.unmarkFavoriteItem` | `itemId`, `userId` | `UserItemDataDto` |
| 标记已看 | `PlaystateApi.markPlayedItem` | `itemId`, `userId` | `UserItemDataDto` |
| 标记未看 | `PlaystateApi.markUnplayedItem` | `itemId`, `userId` | `UserItemDataDto` |

一期推荐：

- 继续观看优先用 `getResumeItems`，因为它正好表达 Jellyfin 的 Resume 语义。
- 收藏和历史用 `getItems`，不要在前端过滤。
- 所有列表请求都带 `enableUserData: true`，否则 `isFavorite`、`played`、`playedPercentage` 会缺失。
- `jellyfin_personal` 内只保存 `PersonalMediaKind.movie` 这种业务枚举，不能出现 `jellyfin_dart.BaseItemKind`。

---

## 模块边界

### `jellyfin_personal` 可以依赖

- `flutter`
- `jellyfin_models`
- `jellyfin_ui_kit`
- `equatable`

### `jellyfin_personal` 不可以依赖

- `go_router`
- `jellyfin_dart`
- `jellyfin_api`
- `dio`
- `jellyfin_app`
- `jellyfin_movie_app`
- 任意 Product App 的 Session Controller

### 跳转协议

Feature 包通过动作协议通知外部，不直接导航。

```dart
PersonalActions(
  onOpenMedia: (context, item) {
    context.push('/media/items/${item.id}');
  },
  onPlayMedia: (context, item) {
    context.push('/playback/video/${item.id}');
  },
  onLogout: () {
    sessionController.clearSession();
  },
)
```

点击卡片主体只调用 `onOpenMedia`。播放按钮只调用 `onPlayMedia`。这条规则必须写进测试，避免后面员工把历史记录点击直接做成播放。

---

## 文件结构

### 新建 Feature 包

```text
packages/features/jellyfin_personal/
  pubspec.yaml
  analysis_options.yaml
  lib/
    jellyfin_personal.dart
    jellyfin_personal_pages.dart
    src/
      contracts/
        personal_actions.dart
        personal_repository.dart
      controllers/
        personal_controller.dart
        personal_section_state.dart
      models/
        personal_media_query.dart
        personal_module_config.dart
      pages/
        personal_page.dart
      widgets/
        personal_header.dart
        personal_media_card.dart
        personal_section_view.dart
  test/
    personal_controller_test.dart
    personal_page_test.dart
```

### 修改 `jellyfin_app`

```text
Product/jellyfin_app/pubspec.yaml
Product/jellyfin_app/lib/src/app/jellyfin_app.dart
Product/jellyfin_app/lib/src/app/app_router.dart
Product/jellyfin_app/lib/src/data/personal_repository_adapter.dart
Product/jellyfin_app/lib/src/features/home/media_libraries_page.dart
Product/jellyfin_app/lib/src/features/personal/personal_route_page.dart
Product/jellyfin_app/test/app_router_test.dart
```

### 修改 `jellyfin_movie_app`

```text
Product/jellyfin_movie_app/pubspec.yaml
Product/jellyfin_movie_app/lib/src/app/jellyfin_movie_app.dart
Product/jellyfin_movie_app/lib/src/app/app_router.dart
Product/jellyfin_movie_app/lib/src/data/legacy_jellyfin_gateway.dart
Product/jellyfin_movie_app/lib/src/data/personal_repository_adapter.dart
Product/jellyfin_movie_app/lib/src/features/personal/personal_route_page.dart
Product/jellyfin_movie_app/lib/src/ui/jellyfin_movie_image_provider.dart
```

---

# Phase 1: 可执行任务

## Task 1: 创建 `jellyfin_personal` 包骨架

**Files:**

- Create: `packages/features/jellyfin_personal/pubspec.yaml`
- Create: `packages/features/jellyfin_personal/analysis_options.yaml`
- Create: `packages/features/jellyfin_personal/lib/jellyfin_personal.dart`
- Create: `packages/features/jellyfin_personal/lib/jellyfin_personal_pages.dart`

- [ ] **Step 1: 创建 pubspec**

```yaml
name: jellyfin_personal
description: Reusable personal center feature for Jellyfin product apps.
publish_to: 'none'
version: 0.1.0

environment:
  sdk: ^3.9.0

dependencies:
  flutter:
    sdk: flutter
  equatable: ^2.0.7
  jellyfin_models:
    path: ../../shared/jellyfin_models
  jellyfin_ui_kit:
    path: ../../shared/jellyfin_ui_kit

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
```

- [ ] **Step 2: 创建 analysis options**

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true
```

- [ ] **Step 3: 创建公共导出**

`lib/jellyfin_personal.dart`

```dart
library;

export 'src/contracts/personal_actions.dart';
export 'src/contracts/personal_repository.dart';
export 'src/controllers/personal_controller.dart';
export 'src/controllers/personal_section_state.dart';
export 'src/models/personal_media_query.dart';
export 'src/models/personal_module_config.dart';
```

`lib/jellyfin_personal_pages.dart`

```dart
library;

export 'src/pages/personal_page.dart';
```

- [ ] **Step 4: 跑依赖解析**

Run:

```powershell
flutter pub get
```

Expected: 根目录或当前 package 不出现 `jellyfin_personal` 依赖解析错误。

---

## Task 2: 定义个人模块协议和配置

**Files:**

- Create: `packages/features/jellyfin_personal/lib/src/models/personal_media_query.dart`
- Create: `packages/features/jellyfin_personal/lib/src/models/personal_module_config.dart`
- Create: `packages/features/jellyfin_personal/lib/src/contracts/personal_actions.dart`
- Create: `packages/features/jellyfin_personal/lib/src/contracts/personal_repository.dart`

- [ ] **Step 1: 写媒体查询模型**

```dart
import 'package:equatable/equatable.dart';

enum PersonalMediaKind {
  movie('Movie'),
  series('Series'),
  episode('Episode'),
  audio('Audio'),
  musicAlbum('MusicAlbum'),
  musicArtist('MusicArtist');

  const PersonalMediaKind(this.jellyfinTypeName);

  final String jellyfinTypeName;
}

final class PersonalMediaKindSets {
  static const all = <PersonalMediaKind>[
    PersonalMediaKind.movie,
    PersonalMediaKind.series,
    PersonalMediaKind.episode,
    PersonalMediaKind.audio,
    PersonalMediaKind.musicAlbum,
    PersonalMediaKind.musicArtist,
  ];

  static const video = <PersonalMediaKind>[
    PersonalMediaKind.movie,
    PersonalMediaKind.series,
    PersonalMediaKind.episode,
  ];

  static const moviesOnly = <PersonalMediaKind>[
    PersonalMediaKind.movie,
  ];

  static const music = <PersonalMediaKind>[
    PersonalMediaKind.audio,
    PersonalMediaKind.musicAlbum,
    PersonalMediaKind.musicArtist,
  ];

  const PersonalMediaKindSets._();
}

final class PersonalMediaQuery extends Equatable {
  final int startIndex;
  final int limit;
  final List<PersonalMediaKind> mediaKinds;

  const PersonalMediaQuery({
    this.startIndex = 0,
    this.limit = 30,
    this.mediaKinds = PersonalMediaKindSets.all,
  });

  PersonalMediaQuery copyWith({
    int? startIndex,
    int? limit,
    List<PersonalMediaKind>? mediaKinds,
  }) {
    return PersonalMediaQuery(
      startIndex: startIndex ?? this.startIndex,
      limit: limit ?? this.limit,
      mediaKinds: mediaKinds ?? this.mediaKinds,
    );
  }

  @override
  List<Object?> get props => [startIndex, limit, mediaKinds];
}
```

- [ ] **Step 2: 写模块配置**

```dart
import 'package:equatable/equatable.dart';

import 'personal_media_query.dart';

enum PersonalSection {
  continueWatching,
  favorites,
  history,
}

extension PersonalSectionLabel on PersonalSection {
  String get label {
    return switch (this) {
      PersonalSection.continueWatching => '继续观看',
      PersonalSection.favorites => '我的收藏',
      PersonalSection.history => '观看历史',
    };
  }
}

final class PersonalModuleConfig extends Equatable {
  final String title;
  final List<PersonalSection> sections;
  final List<PersonalMediaKind> mediaKinds;
  final bool showProfileHeader;
  final bool showLogoutAction;

  const PersonalModuleConfig({
    required this.title,
    required this.sections,
    required this.mediaKinds,
    this.showProfileHeader = true,
    this.showLogoutAction = true,
  });

  const PersonalModuleConfig.full()
      : title = '个人中心',
        sections = const [
          PersonalSection.continueWatching,
          PersonalSection.favorites,
          PersonalSection.history,
        ],
        mediaKinds = PersonalMediaKindSets.all,
        showProfileHeader = true,
        showLogoutAction = true;

  const PersonalModuleConfig.moviesOnly()
      : title = '我的电影',
        sections = const [
          PersonalSection.continueWatching,
          PersonalSection.favorites,
          PersonalSection.history,
        ],
        mediaKinds = PersonalMediaKindSets.moviesOnly,
        showProfileHeader = true,
        showLogoutAction = true;

  const PersonalModuleConfig.musicOnly()
      : title = '我的音乐',
        sections = const [
          PersonalSection.favorites,
          PersonalSection.history,
        ],
        mediaKinds = PersonalMediaKindSets.music,
        showProfileHeader = true,
        showLogoutAction = true;

  @override
  List<Object?> get props => [
        title,
        sections,
        mediaKinds,
        showProfileHeader,
        showLogoutAction,
      ];
}
```

- [ ] **Step 3: 写动作协议**

```dart
import 'package:flutter/widgets.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;

typedef PersonalMediaAction = void Function(
  BuildContext context,
  models.MediaItem item,
);

final class PersonalActions {
  final PersonalMediaAction onOpenMedia;
  final PersonalMediaAction? onPlayMedia;
  final VoidCallback? onLogout;
  final VoidCallback? onOpenSettings;

  const PersonalActions({
    required this.onOpenMedia,
    this.onPlayMedia,
    this.onLogout,
    this.onOpenSettings,
  });
}
```

- [ ] **Step 4: 写 Repository 协议**

```dart
import 'package:jellyfin_models/jellyfin_models.dart' as models;

import '../models/personal_media_query.dart';

abstract interface class PersonalRepository {
  Future<models.UserProfile> getProfile();

  Future<models.MediaItemListResult> getContinueWatching(
    PersonalMediaQuery query,
  );

  Future<models.MediaItemListResult> getFavorites(
    PersonalMediaQuery query,
  );

  Future<models.MediaItemListResult> getHistory(
    PersonalMediaQuery query,
  );

  Future<void> setFavorite({
    required String itemId,
    required bool isFavorite,
  });

  Future<void> setPlayed({
    required String itemId,
    required bool isPlayed,
  });
}
```

---

## Task 3: 创建 Controller 和状态模型

**Files:**

- Create: `packages/features/jellyfin_personal/lib/src/controllers/personal_section_state.dart`
- Create: `packages/features/jellyfin_personal/lib/src/controllers/personal_controller.dart`
- Test: `packages/features/jellyfin_personal/test/personal_controller_test.dart`

- [ ] **Step 1: 先写 controller 测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_personal/jellyfin_personal.dart';

void main() {
  test('loadAll loads configured sections with configured media kinds', () async {
    final repository = _FakePersonalRepository();
    final controller = PersonalController(
      repository: repository,
      config: const PersonalModuleConfig.moviesOnly(),
    );

    await controller.loadAll();

    expect(repository.continueWatchingCalls, 1);
    expect(repository.favoriteCalls, 1);
    expect(repository.historyCalls, 1);
    expect(
      repository.lastQuery.mediaKinds,
      PersonalMediaKindSets.moviesOnly,
    );
    expect(
      controller.sectionState(PersonalSection.history).items.single.name,
      'Zootopia',
    );
  });

  test('toggleFavorite calls repository and refreshes favorites', () async {
    final repository = _FakePersonalRepository();
    final controller = PersonalController(
      repository: repository,
      config: const PersonalModuleConfig.full(),
    );

    await controller.toggleFavorite('movie-1', false);

    expect(repository.favoriteMutation, ('movie-1', false));
    expect(repository.favoriteCalls, 1);
  });
}

final class _FakePersonalRepository implements PersonalRepository {
  int continueWatchingCalls = 0;
  int favoriteCalls = 0;
  int historyCalls = 0;
  PersonalMediaQuery lastQuery = const PersonalMediaQuery();
  (String, bool)? favoriteMutation;

  @override
  Future<models.UserProfile> getProfile() async {
    return const models.UserProfile(
      id: 'u1',
      name: 'tester',
      serverUrl: 'http://server',
    );
  }

  @override
  Future<models.MediaItemListResult> getContinueWatching(
    PersonalMediaQuery query,
  ) async {
    continueWatchingCalls++;
    lastQuery = query;
    return const models.MediaItemListResult(items: [_item]);
  }

  @override
  Future<models.MediaItemListResult> getFavorites(
    PersonalMediaQuery query,
  ) async {
    favoriteCalls++;
    lastQuery = query;
    return const models.MediaItemListResult(items: [_item]);
  }

  @override
  Future<models.MediaItemListResult> getHistory(
    PersonalMediaQuery query,
  ) async {
    historyCalls++;
    lastQuery = query;
    return const models.MediaItemListResult(items: [_item]);
  }

  @override
  Future<void> setFavorite({
    required String itemId,
    required bool isFavorite,
  }) async {
    favoriteMutation = (itemId, isFavorite);
  }

  @override
  Future<void> setPlayed({
    required String itemId,
    required bool isPlayed,
  }) async {}
}

const _item = models.MediaItem(
  id: 'movie-1',
  name: 'Zootopia',
  type: 'Movie',
  serverUrl: 'http://server',
);
```

- [ ] **Step 2: 写状态模型**

```dart
import 'package:equatable/equatable.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;

enum PersonalSectionStatus {
  initial,
  loading,
  loaded,
  empty,
  failure,
}

final class PersonalSectionState extends Equatable {
  final PersonalSectionStatus status;
  final List<models.MediaItem> items;
  final String? errorMessage;

  const PersonalSectionState({
    this.status = PersonalSectionStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  const PersonalSectionState.loading()
      : status = PersonalSectionStatus.loading,
        items = const [],
        errorMessage = null;

  const PersonalSectionState.failure(String message)
      : status = PersonalSectionStatus.failure,
        items = const [],
        errorMessage = message;

  factory PersonalSectionState.loaded(List<models.MediaItem> items) {
    return PersonalSectionState(
      status: items.isEmpty
          ? PersonalSectionStatus.empty
          : PersonalSectionStatus.loaded,
      items: items,
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage];
}
```

- [ ] **Step 3: 写 controller**

```dart
import 'package:flutter/foundation.dart';

import '../contracts/personal_repository.dart';
import '../models/personal_media_query.dart';
import '../models/personal_module_config.dart';
import 'personal_section_state.dart';

final class PersonalController extends ChangeNotifier {
  final PersonalRepository repository;
  final PersonalModuleConfig config;

  final Map<PersonalSection, PersonalSectionState> _sectionStates = {
    for (final section in PersonalSection.values)
      section: const PersonalSectionState(),
  };

  PersonalController({
    required this.repository,
    required this.config,
  });

  PersonalSectionState sectionState(PersonalSection section) {
    return _sectionStates[section] ?? const PersonalSectionState();
  }

  Future<void> loadAll() async {
    await Future.wait(config.sections.map(refreshSection));
  }

  Future<void> refreshSection(PersonalSection section) async {
    _setSectionState(section, const PersonalSectionState.loading());

    final query = PersonalMediaQuery(mediaKinds: config.mediaKinds);
    try {
      final result = switch (section) {
        PersonalSection.continueWatching =>
          await repository.getContinueWatching(query),
        PersonalSection.favorites => await repository.getFavorites(query),
        PersonalSection.history => await repository.getHistory(query),
      };
      _setSectionState(
        section,
        PersonalSectionState.loaded(result.items),
      );
    } catch (error) {
      _setSectionState(
        section,
        PersonalSectionState.failure('$error'),
      );
    }
  }

  Future<void> toggleFavorite(String itemId, bool isFavorite) async {
    await repository.setFavorite(
      itemId: itemId,
      isFavorite: isFavorite,
    );
    if (config.sections.contains(PersonalSection.favorites)) {
      await refreshSection(PersonalSection.favorites);
    }
  }

  Future<void> setPlayed(String itemId, bool isPlayed) async {
    await repository.setPlayed(
      itemId: itemId,
      isPlayed: isPlayed,
    );
    if (config.sections.contains(PersonalSection.history)) {
      await refreshSection(PersonalSection.history);
    }
    if (config.sections.contains(PersonalSection.continueWatching)) {
      await refreshSection(PersonalSection.continueWatching);
    }
  }

  void _setSectionState(
    PersonalSection section,
    PersonalSectionState state,
  ) {
    _sectionStates[section] = state;
    notifyListeners();
  }
}
```

- [ ] **Step 4: 跑 controller 测试**

Run:

```powershell
cd packages\features\jellyfin_personal
flutter test test\personal_controller_test.dart
```

Expected: 两个测试通过。

---

## Task 4: 创建个人页 UI

**Files:**

- Create: `packages/features/jellyfin_personal/lib/src/pages/personal_page.dart`
- Create: `packages/features/jellyfin_personal/lib/src/widgets/personal_header.dart`
- Create: `packages/features/jellyfin_personal/lib/src/widgets/personal_media_card.dart`
- Create: `packages/features/jellyfin_personal/lib/src/widgets/personal_section_view.dart`
- Test: `packages/features/jellyfin_personal/test/personal_page_test.dart`

- [ ] **Step 1: 写点击协议 widget 测试**

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_personal/jellyfin_personal.dart';
import 'package:jellyfin_personal/jellyfin_personal_pages.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

void main() {
  testWidgets('history card tap opens detail instead of playback', (tester) async {
    models.MediaItem? opened;
    models.MediaItem? played;

    await tester.pumpWidget(MaterialApp(
      home: PersonalPage(
        repository: _FakeRepository(),
        config: const PersonalModuleConfig.full(),
        imageProvider: _FakeImageProvider(),
        actions: PersonalActions(
          onOpenMedia: (_, item) => opened = item,
          onPlayMedia: (_, item) => played = item,
        ),
      ),
    ));

    await tester.pumpAndSettle();
    await tester.tap(find.text('Zootopia'));
    await tester.pump();

    expect(opened?.id, 'movie-1');
    expect(played, isNull);
  });
}

final class _FakeRepository implements PersonalRepository {
  @override
  Future<models.UserProfile> getProfile() async {
    return const models.UserProfile(
      id: 'u1',
      name: 'tester',
      serverUrl: 'http://server',
    );
  }

  @override
  Future<models.MediaItemListResult> getContinueWatching(
    PersonalMediaQuery query,
  ) async {
    return const models.MediaItemListResult(items: [_item]);
  }

  @override
  Future<models.MediaItemListResult> getFavorites(
    PersonalMediaQuery query,
  ) async {
    return const models.MediaItemListResult(items: [_item]);
  }

  @override
  Future<models.MediaItemListResult> getHistory(
    PersonalMediaQuery query,
  ) async {
    return const models.MediaItemListResult(items: [_item]);
  }

  @override
  Future<void> setFavorite({
    required String itemId,
    required bool isFavorite,
  }) async {}

  @override
  Future<void> setPlayed({
    required String itemId,
    required bool isPlayed,
  }) async {}
}

final class _FakeImageProvider implements JellyfinImageProvider {
  @override
  Future<Uint8List> getPrimaryImage({
    required String itemId,
    String? tag,
    int? fillWidth,
    int? fillHeight,
    int? quality,
  }) async {
    throw Exception('No image in widget test');
  }
}

const _item = models.MediaItem(
  id: 'movie-1',
  name: 'Zootopia',
  type: 'Movie',
  serverUrl: 'http://server',
  isFavorite: true,
  played: true,
);
```

- [ ] **Step 2: 写媒体卡片**

```dart
import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../contracts/personal_actions.dart';

final class PersonalMediaCard extends StatelessWidget {
  final JellyfinImageProvider imageProvider;
  final models.MediaItem item;
  final PersonalActions actions;
  final ValueChanged<bool>? onFavoriteToggle;

  const PersonalMediaCard({
    super.key,
    required this.imageProvider,
    required this.item,
    required this.actions,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: MediaItemCardWithActions(
            imageProvider: imageProvider,
            item: item,
            onTap: () => actions.onOpenMedia(context, item),
            onFavoriteToggle: onFavoriteToggle,
          ),
        ),
        if (actions.onPlayMedia != null)
          Positioned(
            left: 8,
            bottom: 8,
            child: Material(
              color: Theme.of(context).colorScheme.primary,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.play_arrow),
                color: Theme.of(context).colorScheme.onPrimary,
                tooltip: '播放',
                onPressed: () => actions.onPlayMedia!(context, item),
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 3: 写个人头部**

```dart
import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;

final class PersonalHeader extends StatelessWidget {
  final models.UserProfile profile;
  final VoidCallback? onLogout;

  const PersonalHeader({
    super.key,
    required this.profile,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        child: Text(profile.name.isEmpty ? '?' : profile.name[0].toUpperCase()),
      ),
      title: Text(profile.name),
      subtitle: Text(profile.serverUrl),
      trailing: onLogout == null
          ? null
          : IconButton(
              tooltip: '退出登录',
              icon: const Icon(Icons.logout),
              onPressed: onLogout,
            ),
    );
  }
}
```

- [ ] **Step 4: 写 section view**

```dart
import 'package:flutter/material.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../contracts/personal_actions.dart';
import '../controllers/personal_section_state.dart';
import 'personal_media_card.dart';

final class PersonalSectionView extends StatelessWidget {
  final String title;
  final PersonalSectionState state;
  final JellyfinImageProvider imageProvider;
  final PersonalActions actions;
  final void Function(String itemId, bool isFavorite) onFavoriteToggle;

  const PersonalSectionView({
    super.key,
    required this.title,
    required this.state,
    required this.imageProvider,
    required this.actions,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        switch (state.status) {
          PersonalSectionStatus.initial ||
          PersonalSectionStatus.loading =>
            const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            ),
          PersonalSectionStatus.failure => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(state.errorMessage ?? '加载失败'),
            ),
          PersonalSectionStatus.empty => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('暂无内容'),
            ),
          PersonalSectionStatus.loaded => SizedBox(
              height: 240,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  return SizedBox(
                    width: 150,
                    child: PersonalMediaCard(
                      imageProvider: imageProvider,
                      item: item,
                      actions: actions,
                      onFavoriteToggle: (value) {
                        onFavoriteToggle(item.id, value);
                      },
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemCount: state.items.length,
              ),
            ),
        },
      ],
    );
  }
}
```

- [ ] **Step 5: 写个人页**

```dart
import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../contracts/personal_actions.dart';
import '../contracts/personal_repository.dart';
import '../controllers/personal_controller.dart';
import '../models/personal_module_config.dart';
import '../widgets/personal_header.dart';
import '../widgets/personal_section_view.dart';

final class PersonalPage extends StatefulWidget {
  final PersonalRepository repository;
  final PersonalModuleConfig config;
  final JellyfinImageProvider imageProvider;
  final PersonalActions actions;

  const PersonalPage({
    super.key,
    required this.repository,
    required this.config,
    required this.imageProvider,
    required this.actions,
  });

  @override
  State<PersonalPage> createState() => _PersonalPageState();
}

class _PersonalPageState extends State<PersonalPage> {
  late final PersonalController _controller;
  late final Future<models.UserProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _controller = PersonalController(
      repository: widget.repository,
      config: widget.config,
    );
    _profileFuture = widget.repository.getProfile();
    _controller.loadAll();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.config.title)),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: _controller.loadAll,
            child: ListView(
              children: [
                if (widget.config.showProfileHeader)
                  FutureBuilder<models.UserProfile>(
                    future: _profileFuture,
                    builder: (context, snapshot) {
                      final profile = snapshot.data;
                      if (profile == null) {
                        return const LinearProgressIndicator();
                      }
                      return PersonalHeader(
                        profile: profile,
                        onLogout: widget.config.showLogoutAction
                            ? widget.actions.onLogout
                            : null,
                      );
                    },
                  ),
                for (final section in widget.config.sections)
                  PersonalSectionView(
                    title: section.label,
                    state: _controller.sectionState(section),
                    imageProvider: widget.imageProvider,
                    actions: widget.actions,
                    onFavoriteToggle: _controller.toggleFavorite,
                  ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 6: 跑 UI 测试**

Run:

```powershell
cd packages\features\jellyfin_personal
flutter test
```

Expected: controller 和 page 测试都通过。

---

## Task 5: 接入 `jellyfin_app`

**Files:**

- Modify: `Product/jellyfin_app/pubspec.yaml`
- Create: `Product/jellyfin_app/lib/src/data/personal_repository_adapter.dart`
- Create: `Product/jellyfin_app/lib/src/features/personal/personal_route_page.dart`
- Modify: `Product/jellyfin_app/lib/src/app/jellyfin_app.dart`
- Modify: `Product/jellyfin_app/lib/src/app/app_router.dart`
- Modify: `Product/jellyfin_app/lib/src/features/home/media_libraries_page.dart`
- Modify: `Product/jellyfin_app/test/app_router_test.dart`

- [ ] **Step 1: 增加依赖**

在 `Product/jellyfin_app/pubspec.yaml` 的 feature dependencies 中加入：

```yaml
  jellyfin_personal:
    path: ../../packages/features/jellyfin_personal
```

- [ ] **Step 2: 修正首页 fallback image provider**

当前 `MediaLibrariesPage._StubImageProvider` 还停留在旧接口形态，先改成 `JellyfinImageProvider.getPrimaryImage`。

```dart
import 'dart:typed_data';
```

把 `_StubImageProvider` 改成：

```dart
class _StubImageProvider implements JellyfinImageProvider {
  @override
  Future<Uint8List> getPrimaryImage({
    required String itemId,
    String? tag,
    int? fillWidth,
    int? fillHeight,
    int? quality,
  }) async {
    throw Exception('No image provider configured');
  }
}
```

- [ ] **Step 3: 创建 Product adapter**

`Product/jellyfin_app/lib/src/data/personal_repository_adapter.dart`

```dart
import 'package:jellyfin_api/jellyfin_api.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_personal/jellyfin_personal.dart' as personal;

import '../session/app_session.dart';
import '../session/app_session_controller.dart';
import 'legacy_jellyfin_gateway.dart';

final class JellyfinPersonalRepositoryAdapter
    implements personal.PersonalRepository {
  final LegacyJellyfinGateway gateway;
  final AppSessionController sessionController;

  JellyfinPersonalRepositoryAdapter({
    required this.gateway,
    required this.sessionController,
  });

  ApiClient get _client {
    final client = gateway.apiClient;
    if (client == null) {
      throw StateError('未登录，无法读取个人数据');
    }
    return client;
  }

  AppSession get _session {
    final session = sessionController.currentSession;
    if (session == null || !session.isValid) {
      throw StateError('登录态不存在，无法读取个人数据');
    }
    return session;
  }

  @override
  Future<models.UserProfile> getProfile() async {
    final session = _session;
    return models.UserProfile(
      id: session.userId,
      name: session.username,
      serverUrl: session.serverUrl,
    );
  }

  @override
  Future<models.MediaItemListResult> getContinueWatching(
    personal.PersonalMediaQuery query,
  ) async {
    final client = _client;
    final response = await client.jellyfinClient.getItemsApi().getResumeItems(
          userId: client.config.userId,
          startIndex: query.startIndex,
          limit: query.limit,
          includeItemTypes: _mapKinds(query.mediaKinds),
          enableUserData: true,
          enableImages: true,
        );
    return _mapResult(response.data, client.config.serverUrl);
  }

  @override
  Future<models.MediaItemListResult> getFavorites(
    personal.PersonalMediaQuery query,
  ) async {
    return _getItems(
      query: query,
      isFavorite: true,
      sortBy: const [jellyfin_dart.ItemSortBy.sortName],
      sortOrder: const [jellyfin_dart.SortOrder.ascending],
    );
  }

  @override
  Future<models.MediaItemListResult> getHistory(
    personal.PersonalMediaQuery query,
  ) async {
    return _getItems(
      query: query,
      isPlayed: true,
      sortBy: const [jellyfin_dart.ItemSortBy.datePlayed],
      sortOrder: const [jellyfin_dart.SortOrder.descending],
    );
  }

  @override
  Future<void> setFavorite({
    required String itemId,
    required bool isFavorite,
  }) async {
    final api = _client.jellyfinClient.getUserLibraryApi();
    if (isFavorite) {
      await api.markFavoriteItem(itemId: itemId, userId: _client.config.userId);
    } else {
      await api.unmarkFavoriteItem(itemId: itemId, userId: _client.config.userId);
    }
  }

  @override
  Future<void> setPlayed({
    required String itemId,
    required bool isPlayed,
  }) async {
    final api = _client.jellyfinClient.getPlaystateApi();
    if (isPlayed) {
      await api.markPlayedItem(itemId: itemId, userId: _client.config.userId);
    } else {
      await api.markUnplayedItem(itemId: itemId, userId: _client.config.userId);
    }
  }

  Future<models.MediaItemListResult> _getItems({
    required personal.PersonalMediaQuery query,
    bool? isFavorite,
    bool? isPlayed,
    List<jellyfin_dart.ItemSortBy>? sortBy,
    List<jellyfin_dart.SortOrder>? sortOrder,
  }) async {
    final client = _client;
    final response = await client.jellyfinClient.getItemsApi().getItems(
          userId: client.config.userId,
          startIndex: query.startIndex,
          limit: query.limit,
          recursive: true,
          includeItemTypes: _mapKinds(query.mediaKinds),
          isFavorite: isFavorite,
          isPlayed: isPlayed,
          sortBy: sortBy,
          sortOrder: sortOrder,
          enableUserData: true,
          enableImages: true,
          fields: const [
            jellyfin_dart.ItemFields.overview,
            jellyfin_dart.ItemFields.people,
            jellyfin_dart.ItemFields.studios,
            jellyfin_dart.ItemFields.genres,
          ],
        );
    return _mapResult(response.data, client.config.serverUrl);
  }

  models.MediaItemListResult _mapResult(
    jellyfin_dart.BaseItemDtoQueryResult? result,
    String serverUrl,
  ) {
    final items = result?.items ?? const <jellyfin_dart.BaseItemDto>[];
    return models.MediaItemListResult(
      items: items.map((dto) => _mapMediaItem(dto, serverUrl)).toList(),
      totalCount: result?.totalRecordCount,
      startIndex: result?.startIndex,
    );
  }

  List<jellyfin_dart.BaseItemKind> _mapKinds(
    List<personal.PersonalMediaKind> kinds,
  ) {
    return [
      for (final kind in kinds)
        switch (kind) {
          personal.PersonalMediaKind.movie => jellyfin_dart.BaseItemKind.movie,
          personal.PersonalMediaKind.series => jellyfin_dart.BaseItemKind.series,
          personal.PersonalMediaKind.episode => jellyfin_dart.BaseItemKind.episode,
          personal.PersonalMediaKind.audio => jellyfin_dart.BaseItemKind.audio,
          personal.PersonalMediaKind.musicAlbum =>
            jellyfin_dart.BaseItemKind.musicAlbum,
          personal.PersonalMediaKind.musicArtist =>
            jellyfin_dart.BaseItemKind.musicArtist,
        },
    ];
  }

  models.MediaItem _mapMediaItem(
    jellyfin_dart.BaseItemDto dto,
    String serverUrl,
  ) {
    final imageTags = dto.imageTags;
    final primaryImageTag = imageTags?['Primary'];
    final hasImageTag = primaryImageTag != null && primaryImageTag.isNotEmpty;
    final hasBlurHash = dto.imageBlurHashes != null;
    final hasImage = hasImageTag || hasBlurHash;
    final runTimeMinutes =
        dto.runTimeTicks != null ? (dto.runTimeTicks! / 600000000).round() : null;
    final studios = dto.studios?.map((s) => s.name ?? '').toList();

    final directors = <String>[];
    final actors = <String>[];
    final actorInfos = <models.ActorInfo>[];

    for (final person in (dto.people ?? const [])) {
      if (person.name == null) continue;
      final personImageTag = person.primaryImageTag;
      String? personImageUrl;
      if (personImageTag != null && personImageTag.isNotEmpty) {
        personImageUrl =
            '$serverUrl/Items/${person.id}/Images/Primary?tag=$personImageTag';
      }
      if (person.type == jellyfin_dart.PersonKind.director) {
        directors.add(person.name!);
      } else if (person.type == jellyfin_dart.PersonKind.actor) {
        actors.add(person.name!);
        actorInfos.add(models.ActorInfo(
          name: person.name!,
          role: person.role,
          imageUrl: personImageUrl,
          id: person.id,
        ));
      }
    }

    final backdropImageTags = dto.backdropImageTags;
    final backdropTag = dto.imageTags?['Backdrop'] ??
        (backdropImageTags != null && backdropImageTags.isNotEmpty
            ? backdropImageTags.first
            : null);

    return models.MediaItem(
      id: dto.id ?? '',
      name: dto.name ?? '未知媒体',
      type: dto.type?.name ?? 'unknown',
      serverUrl: serverUrl,
      primaryImageTag: hasImageTag ? primaryImageTag : (hasImage ? 'has_image' : null),
      backdropImageTag: backdropTag,
      productionYear: dto.productionYear,
      genres: dto.genres,
      communityRating: dto.communityRating,
      officialRating: dto.officialRating,
      runTimeTicks: dto.runTimeTicks,
      runTimeMinutes: runTimeMinutes,
      overview: dto.overview,
      studios: studios,
      directors: directors,
      actors: actors,
      actorInfos: actorInfos.isNotEmpty ? actorInfos : null,
      parentId: dto.parentId,
      isFavorite: dto.userData?.isFavorite,
      played: dto.userData?.played,
      playedPercentage: dto.userData?.playedPercentage,
    );
  }
}
```

- [ ] **Step 4: 创建个人路由页**

`Product/jellyfin_app/lib/src/features/personal/personal_route_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_personal/jellyfin_personal.dart';
import 'package:jellyfin_personal/jellyfin_personal_pages.dart';

import '../../session/app_session_controller.dart';
import '../../ui/jellyfin_app_image_provider.dart';

final class PersonalRoutePage extends StatelessWidget {
  final PersonalRepository repository;
  final AppSessionController sessionController;

  const PersonalRoutePage({
    super.key,
    required this.repository,
    required this.sessionController,
  });

  @override
  Widget build(BuildContext context) {
    final session = sessionController.currentSession;
    if (session == null) {
      return const Scaffold(
        body: Center(child: Text('登录态不存在')),
      );
    }

    return PersonalPage(
      repository: repository,
      config: const PersonalModuleConfig.full(),
      imageProvider: JellyfinAppImageProvider.fromSession(session),
      actions: PersonalActions(
        onOpenMedia: (context, item) {
          context.push('/media/items/${item.id}');
        },
        onPlayMedia: (context, item) {
          context.push('/playback/video/${item.id}');
        },
        onLogout: () {
          sessionController.clearSession();
        },
      ),
    );
  }
}
```

- [ ] **Step 5: 在 App 根部创建 adapter 并传给 router**

`Product/jellyfin_app/lib/src/app/jellyfin_app.dart`

新增 import：

```dart
import '../data/personal_repository_adapter.dart';
```

在 `createAppRouter` 中传入：

```dart
_router = createAppRouter(
  sessionController: _sessionController,
  gateway: _gateway,
  personalRepository: JellyfinPersonalRepositoryAdapter(
    gateway: _gateway,
    sessionController: _sessionController,
  ),
  audioPlaybackPort: AudioPlaybackAdapter.instance,
  rvcTaskController: _getOrCreateRvcController(),
);
```

- [ ] **Step 6: 在 router 注册个人页**

`Product/jellyfin_app/lib/src/app/app_router.dart`

新增 imports：

```dart
import 'package:jellyfin_personal/jellyfin_personal.dart';
import '../features/personal/personal_route_page.dart';
```

给 `createAppRouter` 增加参数：

```dart
PersonalRepository? personalRepository,
```

在 routes 中加入：

```dart
GoRoute(
  path: '/personal',
  builder: (context, state) {
    final repository = personalRepository;
    if (repository == null) {
      return const Scaffold(
        body: Center(child: Text('个人模块未配置')),
      );
    }
    return PersonalRoutePage(
      repository: repository,
      sessionController: sessionController,
    );
  },
),
```

- [ ] **Step 7: 在首页增加个人入口**

`Product/jellyfin_app/lib/src/features/home/media_libraries_page.dart`

给 widget 增加：

```dart
final VoidCallback? onOpenPersonal;
```

构造函数增加：

```dart
this.onOpenPersonal,
```

在 `AppBar.actions` 的用户名前增加：

```dart
if (widget.onOpenPersonal != null)
  IconButton(
    icon: const Icon(Icons.person),
    tooltip: '个人中心',
    onPressed: widget.onOpenPersonal,
  ),
```

`app_router.dart` 中创建 `MediaLibrariesPage` 时传入：

```dart
onOpenPersonal: () => context.push('/personal'),
```

- [ ] **Step 8: 更新路由测试**

`Product/jellyfin_app/test/app_router_test.dart`

在路由注册测试中加入：

```dart
expect(paths, contains('/personal'));
```

- [ ] **Step 9: 验证 `jellyfin_app`**

Run:

```powershell
cd Product\jellyfin_app
flutter pub get
flutter analyze
flutter test
```

Expected:

- `flutter pub get` 成功。
- `flutter analyze` 不新增个人模块相关错误。
- `flutter test` 通过现有 router 测试。

---

## Task 6: 接入 `jellyfin_movie_app`

**Files:**

- Modify: `Product/jellyfin_movie_app/pubspec.yaml`
- Modify: `Product/jellyfin_movie_app/lib/src/data/legacy_jellyfin_gateway.dart`
- Create: `Product/jellyfin_movie_app/lib/src/ui/jellyfin_movie_image_provider.dart`
- Create: `Product/jellyfin_movie_app/lib/src/data/personal_repository_adapter.dart`
- Create: `Product/jellyfin_movie_app/lib/src/features/personal/personal_route_page.dart`
- Modify: `Product/jellyfin_movie_app/lib/src/app/jellyfin_movie_app.dart`
- Modify: `Product/jellyfin_movie_app/lib/src/app/app_router.dart`

- [ ] **Step 1: 增加依赖**

在 `Product/jellyfin_movie_app/pubspec.yaml` 加入：

```yaml
  http: ^1.2.0
  jellyfin_personal:
    path: ../../packages/features/jellyfin_personal
```

- [ ] **Step 2: 暴露 authenticated ApiClient**

`Product/jellyfin_movie_app/lib/src/data/legacy_jellyfin_gateway.dart`

在 `_apiClient` 字段下方增加：

```dart
ApiClient? get apiClient => _apiClient;
```

- [ ] **Step 3: 创建电影 App 图片 provider**

`Product/jellyfin_movie_app/lib/src/ui/jellyfin_movie_image_provider.dart`

```dart
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../session/app_session.dart';

final class JellyfinMovieImageProvider implements JellyfinImageProvider {
  final String serverUrl;
  final String accessToken;

  JellyfinMovieImageProvider({
    required this.serverUrl,
    required this.accessToken,
  });

  factory JellyfinMovieImageProvider.fromSession(AppSession session) {
    return JellyfinMovieImageProvider(
      serverUrl: session.serverUrl,
      accessToken: session.accessToken,
    );
  }

  @override
  Future<Uint8List> getPrimaryImage({
    required String itemId,
    String? tag,
    int? fillWidth,
    int? fillHeight,
    int? quality,
  }) async {
    var url = '$serverUrl/Items/$itemId/Images/Primary';
    final params = <String, String>{};
    if (tag != null && tag.isNotEmpty) params['tag'] = tag;
    if (fillWidth != null) params['fillWidth'] = '$fillWidth';
    if (fillHeight != null) params['fillHeight'] = '$fillHeight';
    if (quality != null) params['quality'] = '$quality';
    if (params.isNotEmpty) {
      url += '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {'X-Emby-Token': accessToken},
    );
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception('图片加载失败: ${response.statusCode}');
  }
}
```

- [ ] **Step 4: 创建电影 App personal adapter**

创建电影 App adapter 文件：

```text
Product/jellyfin_movie_app/lib/src/data/personal_repository_adapter.dart
```

文件内容使用 Task 5 Step 3 的 adapter 完整代码，差异只有 import 路径仍然引用当前 App 的：

```dart
import '../session/app_session.dart';
import '../session/app_session_controller.dart';
import 'legacy_jellyfin_gateway.dart';
```

并保留 `PersonalMediaKind.movie` 到 `BaseItemKind.movie` 的完整映射，因为电影 App 的配置会传 `PersonalModuleConfig.moviesOnly()`。

- [ ] **Step 5: 创建电影个人路由页**

`Product/jellyfin_movie_app/lib/src/features/personal/personal_route_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_personal/jellyfin_personal.dart';
import 'package:jellyfin_personal/jellyfin_personal_pages.dart';

import '../../session/app_session_controller.dart';
import '../../ui/jellyfin_movie_image_provider.dart';

final class PersonalRoutePage extends StatelessWidget {
  final PersonalRepository repository;
  final AppSessionController sessionController;

  const PersonalRoutePage({
    super.key,
    required this.repository,
    required this.sessionController,
  });

  @override
  Widget build(BuildContext context) {
    final session = sessionController.currentSession;
    if (session == null) {
      return const Scaffold(
        body: Center(child: Text('登录态不存在')),
      );
    }

    return PersonalPage(
      repository: repository,
      config: const PersonalModuleConfig.moviesOnly(),
      imageProvider: JellyfinMovieImageProvider.fromSession(session),
      actions: PersonalActions(
        onOpenMedia: (context, item) {
          context.push('/movies/${item.id}');
        },
        onPlayMedia: (context, item) {
          context.push('/playback/video/${item.id}');
        },
        onLogout: () {
          sessionController.clearSession();
        },
      ),
    );
  }
}
```

- [ ] **Step 6: 在电影 App 根部传入 adapter**

`Product/jellyfin_movie_app/lib/src/app/jellyfin_movie_app.dart`

新增 import：

```dart
import '../data/personal_repository_adapter.dart';
```

创建 router 时传：

```dart
_router = createAppRouter(
  sessionController: _sessionController,
  gateway: _gateway,
  personalRepository: JellyfinPersonalRepositoryAdapter(
    gateway: _gateway,
    sessionController: _sessionController,
  ),
);
```

- [ ] **Step 7: 注册电影 App 个人路由**

`Product/jellyfin_movie_app/lib/src/app/app_router.dart`

新增 imports：

```dart
import 'package:jellyfin_personal/jellyfin_personal.dart';
import '../features/personal/personal_route_page.dart';
```

给 `createAppRouter` 增加参数：

```dart
PersonalRepository? personalRepository,
```

在 routes 中加入：

```dart
GoRoute(
  path: '/personal',
  builder: (context, state) {
    final repository = personalRepository;
    if (repository == null) {
      return const Scaffold(
        body: Center(child: Text('个人模块未配置')),
      );
    }
    return PersonalRoutePage(
      repository: repository,
      sessionController: sessionController,
    );
  },
),
```

在 `_AutoMovieLibraryPage` 的成功或错误界面 AppBar/按钮区加一个入口：

```dart
IconButton(
  icon: const Icon(Icons.person),
  tooltip: '个人中心',
  onPressed: () => context.push('/personal'),
),
```

一期入口优先保证 `/personal` 路由可访问。`_AutoMovieLibraryPage` 加载成功会自动跳到电影列表页，电影列表页顶部入口可以在电影列表模块下一轮统一补齐。

- [ ] **Step 8: 验证 `jellyfin_movie_app`**

Run:

```powershell
cd Product\jellyfin_movie_app
flutter pub get
flutter analyze
flutter test
```

Expected:

- `flutter pub get` 成功。
- `flutter analyze` 不新增个人模块相关错误。
- 如果当前没有测试文件，`flutter test` 应该至少完成空测试发现流程，不出现编译错误。

---

## Task 7: 手工验收

**Files:**

- No required file edits.

- [ ] **Step 1: 验收 `jellyfin_app` 登录后入口**

Run:

```powershell
cd Product\jellyfin_app
flutter run -d windows
```

操作：

1. 登录 Jellyfin。
2. 进入 Libraries 首页。
3. 点击个人中心图标。
4. 观察个人页是否出现用户名、服务器地址、继续观看、收藏、观看历史。

Expected:

- 登录态复用成功，不需要再次输入服务器地址。
- 图片请求使用当前 token。
- 列表请求没有 401。

- [ ] **Step 2: 验收历史记录详情跳转**

操作：

1. 在观看历史里找到一个电影或剧集卡片。
2. 点击卡片标题或封面区域。

Expected:

- `jellyfin_app` 跳转到 `/media/items/:itemId`。
- `jellyfin_movie_app` 跳转到 `/movies/:itemId`。
- 不直接进入播放页。

- [ ] **Step 3: 验收播放按钮**

操作：

1. 在个人页卡片上点击播放按钮。

Expected:

- 进入 `/playback/video/:itemId`。
- 点击播放按钮和点击卡片主体的结果不同。

- [ ] **Step 4: 验收收藏**

操作：

1. 在个人页收藏卡片上点击爱心按钮取消收藏。
2. 下拉刷新。

Expected:

- 卡片从收藏列表消失。
- Jellyfin Web 端看到同一个条目的收藏状态已经同步变化。

---

# Phase 2: 演进计划

## Task 8: 接入 `jellyfin_music_app`

二期音乐 App 使用同一个 `jellyfin_personal`，但配置为：

```dart
const PersonalModuleConfig.musicOnly()
```

跳转协议：

```dart
PersonalActions(
  onOpenMedia: (context, item) {
    switch (item.type.toLowerCase()) {
      case 'musicalbum':
        context.push('/music/albums/${item.id}');
      case 'musicartist':
        context.push('/music/artists/${item.id}');
      case 'audio':
        context.push('/playback/music?itemId=${item.id}');
      default:
        context.push('/music/items/${item.id}');
    }
  },
  onPlayMedia: (context, item) {
    context.push('/playback/music?itemId=${item.id}');
  },
)
```

验收重点：

- 收藏歌曲走音乐播放。
- 收藏专辑进入专辑详情。
- 收藏艺人进入艺人详情。
- 不把音乐条目误跳到视频播放页。

## Task 9: 抽公共 Jellyfin adapter 基础设施

一期 adapter 会在 `jellyfin_app` 和 `jellyfin_movie_app` 里重复一部分 DTO 映射。二期可以创建：

```text
packages/foundation/jellyfin_infrastructure/
  lib/
    jellyfin_infrastructure.dart
    src/
      media_item_dto_mapper.dart
      user_data_repository_adapter.dart
```

抽取后依赖方向：

```text
Product App
  -> jellyfin_infrastructure
  -> jellyfin_api
  -> jellyfin_dart
```

`jellyfin_personal` 仍然不依赖基础设施包。

## Task 10: 个人中心功能扩展

可按产品需要分批加入：

- 用户头像：读取 Jellyfin User Primary Image。
- 清除历史：接入 Jellyfin 播放状态接口，支持单条标记未看。
- 本地缓存：缓存最近一次个人页数据，弱网时先展示旧数据。
- 统计页：按 Movie / Series / Audio 统计收藏数和已看数。
- AI/RVC 历史：只展示入口和任务摘要，任务执行仍由 Product App 的 controller 管。

---

## 一期验收标准

- `packages/features/jellyfin_personal` 不出现 `go_router`、`jellyfin_dart`、`jellyfin_api` import。
- `PersonalRepository` 是个人模块唯一的数据入口。
- `PersonalActions.onOpenMedia` 是详情跳转唯一入口。
- `PersonalActions.onPlayMedia` 是播放跳转唯一入口。
- `jellyfin_app` 个人页能看到继续观看、收藏、历史。
- `jellyfin_movie_app` 个人页只出现电影相关条目。
- 点击“疯狂动物城”这类历史卡片进入详情页，不直接播放。
- `flutter analyze` 和 `flutter test` 在相关 package / app 内通过，或只剩与本任务无关的既有问题，并在执行报告里列明文件和错误。

## 建议提交顺序

1. `feat(personal): add reusable personal feature contracts`
2. `feat(personal): add personal page and controller`
3. `feat(app): wire personal page into jellyfin app`
4. `feat(movie-app): wire personal page into movie app`
