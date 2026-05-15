# jellyfin_personal

Jellyfin 个人中心 Feature 模块，提供用户资料展示、继续观看、收藏列表、观看历史等个人媒体管理能力。

本模块为纯 UI + 协议层，不依赖 Jellyfin API 或路由框架。Product App 通过实现 `PersonalRepository` 注入数据，通过 `PersonalActions` 注入跳转逻辑。

## 功能清单

- 用户资料头部（头像、用户名、服务器地址、退出登录）
- 继续观看区块（横幅卡片，带播放进度条）
- 我的收藏区块（海报卡片，带收藏切换按钮）
- 观看历史区块（海报卡片，带已观看标记）
- 视频/音乐类型过滤 Tab（配置同时包含视频和音乐时自动显示）
- 下拉刷新
- 三种预设配置：`full()`（全功能）、`moviesOnly()`（仅电影）、`musicOnly()`（仅音乐）

## 核心类一览

### 协议层

| 类名 | 文件 | 说明 |
|------|------|------|
| `PersonalRepository` | `lib/src/contracts/personal_repository.dart` | 数据仓库接口，定义 getProfile / getContinueWatching / getFavorites / getHistory / setFavorite / setPlayed |
| `PersonalActions` | `lib/src/contracts/personal_actions.dart` | 跳转协议，定义 onOpenMedia（详情）/ onPlayMedia（播放）/ onLogout / onOpenSettings 回调 |

### 模型层

| 类名 | 文件 | 说明 |
|------|------|------|
| `PersonalModuleConfig` | `lib/src/models/personal_module_config.dart` | 模块配置：标题、区块列表、媒体类型、是否显示头像/退出按钮。提供 `.full()` / `.moviesOnly()` / `.musicOnly()` 预设构造 |
| `PersonalMediaQuery` | `lib/src/models/personal_media_query.dart` | 查询参数：分页 + 媒体类型列表 |
| `PersonalMediaKind` | `lib/src/models/personal_media_query.dart` | 媒体类型枚举：movie / series / episode / audio / musicAlbum / musicArtist |
| `PersonalMediaKindSets` | `lib/src/models/personal_media_query.dart` | 媒体类型预设集合：all / video / moviesOnly / music |
| `PersonalMediaTypeFilter` | `lib/src/models/personal_media_query.dart` | 过滤选项：all / video / music，用于过滤 Tab |
| `PersonalSection` | `lib/src/models/personal_module_config.dart` | 区块枚举：continueWatching / favorites / history |

### 控制器

| 类名 | 文件 | 说明 |
|------|------|------|
| `PersonalController` | `lib/src/controllers/personal_controller.dart` | ChangeNotifier，管理区块加载状态、类型过滤切换、收藏/已看状态变更 |
| `PersonalSectionState` | `lib/src/controllers/personal_section_state.dart` | 单个区块的状态：status（initial/loading/loaded/empty/failure）+ items + errorMessage |

### 页面与组件

| 类名 | 文件 | 说明 |
|------|------|------|
| `PersonalPage` | `lib/src/pages/personal_page.dart` | 个人中心页面入口，接收 Repository + Config + ImageProvider + Actions |
| `PersonalHeader` | `lib/src/widgets/personal_header.dart` | 用户资料头部组件 |
| `PersonalSectionView` | `lib/src/widgets/personal_section_view.dart` | 区块视图：标题 + 横向滚动卡片列表 |
| `PersonalMediaCard` | `lib/src/widgets/personal_media_card.dart` | 媒体卡片：封面图 + 标题 + 播放按钮 + 收藏按钮 + 进度条 + 已观看标记 |

### 导出结构

```
jellyfin_personal.dart        → 协议、控制器、模型（业务层）
jellyfin_personal_pages.dart  → PersonalPage（页面层）
```

## 依赖关系

```
jellyfin_personal
  ├── jellyfin_models        (MediaItem / UserProfile / MediaItemListResult)
  ├── jellyfin_ui_kit        (JellyfinImage / JellyfinImageProvider)
  ├── equatable              (值对象相等性)
  └── flutter                (SDK)
```

不依赖 `jellyfin_api`、`jellyfin_dart`、`go_router` 或其他 feature 包。

## 使用示例

### 1. 实现 PersonalRepository

在 Product App 的 `data/` 层创建 adapter：

```dart
import 'package:jellyfin_personal/jellyfin_personal.dart';
import 'package:jellyfin_models/jellyfin_models.dart';

final class MyPersonalRepository implements PersonalRepository {
  final MyApiClient _client;

  MyPersonalRepository(this._client);

  @override
  Future<UserProfile> getProfile() async {
    final dto = await _client.getCurrentUser();
    return UserProfile(id: dto.id, name: dto.name, serverUrl: dto.serverUrl);
  }

  @override
  Future<MediaItemListResult> getContinueWatching(PersonalMediaQuery query) async {
    final items = await _client.getResumeItems(
      startIndex: query.startIndex,
      limit: query.limit,
      types: query.mediaKinds.map((k) => k.jellyfinTypeName).toList(),
    );
    return MediaItemListResult(items: items.map(mapMediaItem).toList());
  }

  // getFavorites / getHistory / setFavorite / setPlayed 类似实现
}
```

### 2. 选择模块配置

```dart
// 全功能 App（电影 + 剧集 + 音乐）
const config = PersonalModuleConfig.full();

// 电影专用 App
const config = PersonalModuleConfig.moviesOnly();

// 音乐专用 App
const config = PersonalModuleConfig.musicOnly();

// 自定义配置
const config = PersonalModuleConfig(
  title: '我的空间',
  sections: [PersonalSection.favorites, PersonalSection.history],
  mediaKinds: PersonalMediaKindSets.video,
  showProfileHeader: true,
  showLogoutAction: false,
);
```

### 3. 路由接入

在 Product App 的 route page 中注入依赖：

```dart
// personal_route_page.dart
GoRoute(
  path: '/personal',
  builder: (context, state) => PersonalPage(
    repository: myPersonalRepository,
    config: const PersonalModuleConfig.full(),
    imageProvider: myImageProvider,
    actions: PersonalActions(
      onOpenMedia: (context, item) => context.push('/media/${item.id}'),
      onPlayMedia: (context, item) => context.push('/playback/video/${item.id}'),
      onLogout: () => sessionController.logout(),
    ),
  ),
),
```

### 4. Barrel 导入

```dart
// 只用业务类
import 'package:jellyfin_personal/jellyfin_personal.dart';

// 用页面
import 'package:jellyfin_personal/jellyfin_personal_pages.dart';
```

## 测试

```bash
# 运行本模块测试
cd packages/features/jellyfin_personal && flutter test
```

共 5 个测试：

- `personal_controller_test.dart`（3 个）：加载配置区块、类型过滤切换、收藏状态变更
- `personal_page_test.dart`（2 个）：卡片点击跳转详情（非播放）、卡片布局无溢出

测试使用 `_FakePersonalRepository` 和 `_FakeImageProvider`，无外部依赖。
