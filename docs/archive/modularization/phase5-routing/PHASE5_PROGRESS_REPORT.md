# Phase 5 进展报告：go_router 统一路由协议

> 阶段目标：用 go_router 建立统一路由主干，业务模块通过路由意图导航，不再直接 import 其他模块页面。

## 一、完成状态

| Task | 描述 | 状态 |
|------|------|------|
| Task 1 | 路由协议（JellyfinRouteNames + RouteNavigationIntent） | ✅ 完成 |
| Task 2 | 根 go_router Shell（GoRouterAppNavigator + 路由表 + JellyfinAppShell） | ✅ 完成 |
| Task 3 | 主页面接入新导航器（MediaLibrariesPage + example） | ✅ 完成 |
| Task 4 | 后续迁移准备（边界检查 + 验证） | ⚠️ 迁移准备完成，业务迁移未完成 |

## 二、新增/修改文件清单

### 2.1 jellyfin_core 新增协议

| 文件 | 类型 | 说明 |
|------|------|------|
| `packages/foundation/jellyfin_core/lib/src/module/jellyfin_route_names.dart` | 新建 | 14 个稳定路由名常量 |
| `packages/foundation/jellyfin_core/lib/src/module/navigation_intent.dart` | 修改 | 新增 `RouteNavigationIntent` 类 |
| `packages/foundation/jellyfin_core/lib/jellyfin_core.dart` | 修改 | 导出 jellyfin_route_names |

### 2.2 根 App Shell 新增路由层

| 文件 | 类型 | 行数 | 说明 |
|------|------|------|------|
| `lib/src/app_shell/go_router_app_navigator.dart` | 新建 | 97 | `GoRouterAppNavigator` 适配器，实现 `AppNavigator` |
| `lib/src/app_shell/jellyfin_go_router.dart` | 新建 | 226 | 手工路由表 + 登录重定向 + 3 个内部辅助 Widget |
| `lib/src/app_shell/jellyfin_app_shell.dart` | 新建 | 64 | 根 `MaterialApp.router` 封装 |
| `lib/src/app_shell/app_session_controller.dart` | 修改 | — | 新增 `setSession()` 方法 |
| `lib/src/app_shell/app_shell.dart` | 修改 | — | barrel 导出 3 个新文件 |

### 2.3 接入层修改

| 文件 | 类型 | 说明 |
|------|------|------|
| `lib/src/ui/pages/media_libraries_page.dart` | 修改 | 新增可选 `navigator` / `onLogout`，优先走路由协议 |
| `example/lib/main.dart` | 修改 | 使用 `JellyfinAppShell` 替代手动 `MaterialApp` |
| `pubspec.yaml` | 修改 | 添加 `go_router` 依赖 |

### 2.4 边界检查脚本

| 文件 | 类型 | 说明 |
|------|------|------|
| `scripts/check_module_boundaries.dart` | 修改 | 新增规则 7：MaterialPageRoute 使用报告（信息性） |

## 三、架构设计

### 3.1 分层关系

```
┌─────────────────────────────────────────────────────────┐
│  Flutter App (example)                                   │
│  └── JellyfinAppShell (MaterialApp.router)               │
│       ├── AppSessionController (refreshListenable)       │
│       ├── GoRouterAppNavigator (AppNavigator 实现)       │
│       └── GoRouter (路由引擎)                             │
│            ├── /login                                    │
│            ├── /libraries                                │
│            ├── /libraries/:libraryId                     │
│            ├── /ai/recommend                             │
│            ├── /profile                                  │
│            └── /playback/video/:itemId                   │
├─────────────────────────────────────────────────────────┤
│  jellyfin_core (路由协议)                                 │
│  ├── JellyfinRouteNames (14 个稳定路由名)                 │
│  ├── RouteNavigationIntent (基于路由名的导航意图)          │
│  └── AppNavigator (导航协议接口)                          │
├─────────────────────────────────────────────────────────┤
│  Feature Modules                                         │
│  ├── 依赖 jellyfin_core 路由协议                          │
│  ├── 通过注入的 AppNavigator 发起导航                     │
│  ├── 不 import 其他 feature 页面                          │
│  └── 不 import go_router                                 │
└─────────────────────────────────────────────────────────┘
```

### 3.2 路由名清单

| 路由名 | URL 路径 | 注册状态 |
|--------|----------|----------|
| `auth.login` | `/login` | ✅ 已注册 |
| `libraries.index` | `/libraries` | ✅ 已注册 |
| `libraries.detail` | `/libraries/:libraryId` | ✅ 已注册 |
| `media.detail` | `/media/items/:itemId` | 待注册 |
| `movies.detail` | `/movies/:itemId` | 待注册 |
| `series.seasons` | `/series/:seriesId/seasons` | 待注册 |
| `series.episodes` | `/series/:seriesId/seasons/:seasonId/episodes` | 待注册 |
| `playback.video` | `/playback/video/:itemId` | ✅ 已注册 |
| `music.library` | `/music/libraries/:libraryId` | 待注册 |
| `music.album` | `/music/albums/:albumId` | 待注册 |
| `music.artist` | `/music/artists/:artistId` | 待注册 |
| `music.search` | `/music/search` | 待注册 |
| `ai.recommend` | `/ai/recommend` | ✅ 已注册 |
| `profile` | `/profile` | ✅ 已注册 |

**6/14 路由已注册**，剩余 8 个路由名已在 `JellyfinRouteNames` 声明、`GoRouterAppNavigator._pathParametersFor` 已支持路径参数映射，后续迁移只需在 `jellyfin_go_router.dart` 添加 `GoRoute` 条目。

### 3.3 登录重定向

`AppSessionController` 作为 `GoRouter.refreshListenable`，自动处理：

- 未登录访问非 `/login` → 重定向到 `/login`
- 已登录访问 `/login` → 重定向到 `/libraries`
- 登录成功只需 `setSession()`，不再由 `LoginPage` 手动 push
- 登出只需 `logout()` 清 session，路由自动跳回 `/login`

### 3.4 旧代码兼容策略

- `FeaturePageFactory` 暂时保留，作为旧页面构造适配器
- `MediaLibrariesPage` 传入 `AppNavigator` 时走新路由，未传入时保留旧 `Navigator.push`
- 旧 `Navigator.push` 不一次性全部删除，先建立新主干，再逐步迁移

## 四、测试与验证

### 4.1 验收命令结果

```powershell
# jellyfin_core 测试（需在 packages/foundation/jellyfin_core 目录下执行）
cd packages/foundation/jellyfin_core && dart test
→ 19 passed (含 JellyfinRouteNames + RouteNavigationIntent 测试)

# App Shell 测试
flutter test test/app_shell_test.dart
→ 8 passed

# 全量测试
flutter test
→ 44 passed

# 模块边界检查
dart scripts/check_module_boundaries.dart
→ ✓ 所有模块边界检查通过
→ ℹ 41 处仍使用 MaterialPageRoute（待迁移）

# 静态分析
dart analyze lib test
→ 0 errors，但仍有 warnings/info，命令返回非零
```

### 4.2 测试分布

| 测试文件 | 用例数 |
|----------|--------|
| `packages/foundation/jellyfin_core/test/jellyfin_core_test.dart` | 19 |
| `test/auth_service_test.dart` | 5 |
| `test/media_library_test.dart` | 1 |
| `test/media_item_mapper_test.dart` | 3 |
| `test/app_shell_test.dart` | 8 |
| `test/integration_smoke_test.dart` | 26 |
| `test/audio_playback_port_injection_test.dart` | 1 |
| **合计** | **63** |

## 五、迁移进度追踪（Phase 5B 目标）

### 5.1 当前 MaterialPageRoute 使用分布

边界检查规则 7 扫描 `lib/src/ui/` 目录，统计仍使用直接 `MaterialPageRoute` 的位置。

#### A 类：跨模块跳转（Phase 5B 必须迁移）— 27 处

| 文件 | 使用次数 | 说明 |
|------|----------|------|
| `feature_page_factory.dart` | 12 | 兼容桥，通过 AppNavigator 注入逐步替代 |
| `music_library_page.dart` | 9 | 音乐库内部跳转专辑/艺术家/歌词 |
| `ai_recommend_page.dart` | 4 | AI 推荐页跳转详情/专辑/艺术家 |
| `media_item_detail_page.dart` | 5 | 通用详情页跳转剧集/人物/播放 |
| `personal_page.dart` | 2 | 个人中心跳转 |
| `continue_watching_card.dart` | 1 | 继续观看跳播放 |
| `mini_player_card.dart` | 1 | 迷你播放器跳歌词 |
| **小计** | **34** | |

> 注：`feature_page_factory.dart` 属于 app_shell 层但位于 `lib/src/ui/` 扫描范围外，12 处计入 A 类。

#### B 类：模块内部/已迁移回退 — 6 处

| 文件 | 使用次数 | 说明 |
|------|----------|------|
| `media_libraries_page.dart` | 4 | 已有 navigator 分支，旧路径回退 |

#### C 类：Deprecated/测试页 — 13 处

| 文件 | 使用次数 | 说明 |
|------|----------|------|
| `movie_filter_page.dart` | 2 | @Deprecated |
| `album_detail_page.dart` | 2 | @Deprecated |
| `artist_detail_page.dart` | 1 | @Deprecated |
| `episodes_page.dart` | 1 | @Deprecated |
| `music_search_page.dart` | 3 | @Deprecated |
| `media_items_page.dart` | 1 | @Deprecated |
| `person_detail_page.dart` | 1 | @Deprecated |
| `seasons_page.dart` | 1 | @Deprecated |
| `login_page.dart` | 2 | 已由 go_router 重定向接管 |
| `test_api_page.dart` | 1 | 测试页面 |
| **小计** | **15** | 随 deprecated 页面自然退出 |

| 文件 | 使用次数 | 状态 |
|------|----------|------|
| `music_library_page.dart` | 9 | 待迁移 |
| `media_item_detail_page.dart` | 5 | 待迁移 |
| `feature_page_factory.dart` | 12 | 保留（兼容桥） |
| `ai_recommend_page.dart` | 4 | 待迁移 |
| `media_libraries_page.dart` | 4 | 已迁移（旧路径回退） |
| `movie_filter_page.dart` | 2 | @Deprecated |
| `album_detail_page.dart` | 2 | @Deprecated |
| `personal_page.dart` | 2 | 待迁移 |
| `login_page.dart` | 2 | 已由 go_router 重定向接管 |
| `music_search_page.dart` | 3 | @Deprecated |
| `episodes_page.dart` | 1 | @Deprecated |
| `seasons_page.dart` | 1 | @Deprecated |
| `artist_detail_page.dart` | 1 | @Deprecated |
| `media_items_page.dart` | 1 | @Deprecated |
| `person_detail_page.dart` | 1 | @Deprecated |
| `continue_watching_card.dart` | 1 | 待迁移 |
| `mini_player_card.dart` | 1 | 待迁移 |
| `test_api_page.dart` | 1 | 测试页面 |
| **合计** | **41** | |

### 5.2 优先迁移建议

**P0 - 活跃页面（通过 go_router 入口可达）：**
- `continue_watching_card.dart` — 首页继续观看卡片，点击跳详情
- `mini_player_card.dart` — 迷你播放器，点击跳歌词

**P1 - 根页面（直接被路由表引用）：**
- `ai_recommend_page.dart` — AI 推荐页内部跳转
- `personal_page.dart` — 个人中心内部跳转
- `media_item_detail_page.dart` — 媒体详情页内部跳转

**P2 - 兼容桥（长期保留）：**
- `feature_page_factory.dart` — 旧页面构造适配器，随 deprecated 页面逐步退出

**P3 - 已废弃页面：**
- 带 `@Deprecated` 标记的 8 个页面，最终随版本移除

## 六、下一步迁移规则

1. 新增跨模块跳转时，只能新增 route name 和 route handler
2. feature 页面需要跳转时，只能调用注入的 `AppNavigator` 或回调
3. 页面内部不得直接 import 目标模块页面
4. root shell 可以 import 所有 feature 页面（应用编排层）
5. 每迁移一个旧 `Navigator.push`，补一个路由测试或 widget smoke test
6. `GoRouterAppNavigator._pathParametersFor` 已支持全部 14 个路由的路径参数映射，新增路由只需在 `jellyfin_go_router.dart` 添加 `GoRoute`
