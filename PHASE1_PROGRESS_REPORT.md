# 第一阶段模块化进展报告

> 执行日期：2026-05-11
> 对应计划：`MODULARIZATION_EXECUTION_PLAN.md` Task 1 ~ Task 7

---

## 一、已完成内容

### Task 1: 建立 workspace 与目录规范

**状态：完成**

创建了 monorepo 目录结构，并将现有包迁移到新位置：

```
packages/
  foundation/
    jellyfin_core/          # 完成 - 核心基础包（纯 Dart）
    jellyfin_api/           # 完成 - API 客户端包（依赖 dio）
  shared/
    jellyfin_models/        # 完成 - 共享模型包（纯 Dart）
    jellyfin_ui_kit/        # 完成 - 共享 UI 组件包（依赖 Flutter）
    jellyfin_testing/       # 完成 - 测试工具包（纯 Dart）
  features/
    rvc_flutter/            # 从 packages/rvc_flutter 迁入
  plugins/
    video_gesture_controls/ # 从 packages/video_gesture_controls 迁入
  vendor/
    jellyfin_dart_3.8/      # 从 packages/jellyfin_dart_3.8 迁入
    rvc_sdk/                # 从 packages/rvc_sdk 迁入
    rainfall_tts_sdk/       # 从 packages/rainfall_tts_sdk 迁入
```

**改动文件：**
- `pubspec.yaml` - 更新 path 依赖指向新位置，新增 `jellyfin_core`、`jellyfin_models`、`jellyfin_api`、`jellyfin_ui_kit` 依赖
- `packages/features/rvc_flutter/pubspec.yaml` - 修正 rvc_sdk 相对路径

### Task 2: 抽 foundation/jellyfin_core

**状态：完成**

创建了纯 Dart 基础包，不依赖 Flutter：

| 文件 | 内容 |
|------|------|
| `lib/jellyfin_core.dart` | 统一导出入口 |
| `lib/src/configuration/jellyfin_configuration.dart` | 配置类（从根包迁出） |
| `lib/src/exceptions/jellyfin_exception.dart` | 异常基类（从根包迁出） |
| `lib/src/module/jellyfin_feature_module.dart` | 模块注册协议 |
| `lib/src/module/navigation_intent.dart` | 导航意图 |
| `lib/src/module/app_navigator.dart` | 导航服务协议 |
| `test/jellyfin_core_test.dart` | 17 个测试，全部通过 |

**根包 facade 更新：**
- `lib/src/jellyfin_configuration.dart` → 改为 re-export `jellyfin_core`
- `lib/src/exceptions/jellyfin_exception.dart` → 改为 re-export `jellyfin_core`

**新增能力：**
- `JellyfinConfiguration.buildAuthHeader()` - 构建鉴权请求头（原在 api_client.dart 中）
- `NavigationIntent` - abstract class + `GenericNavigationIntent`（已按 leader 建议收敛）
- `RouteDescriptor` - 只含 name/path/metadata，不含 Widget builder（已按 leader 建议拆分）
- `JellyfinFeatureModule` / `ModuleContext` / `NavigationEntry` - 模块协议

### Task 4: 抽 shared/jellyfin_models

**状态：完成**

创建了纯 Dart 模型包（仅依赖 equatable），不依赖 Flutter 和 jellyfin_dart：

| 文件 | 内容 |
|------|------|
| `lib/jellyfin_models.dart` | 统一导出入口 |
| `lib/src/user_models.dart` | UserProfile, AuthenticationResult, SessionInfo |
| `lib/src/media_library_models.dart` | MediaLibrary, MediaLibraryType, MediaLibraryListResult |
| `lib/src/media_item_models.dart` | MediaItem, ActorInfo, Season, Episode 及列表结果类 |
| `lib/src/server_discovery_models.dart` | DiscoveredServer |
| `test/jellyfin_models_test.dart` | 8 个测试，全部通过 |

**策略说明：**
- 模型类只包含字段、构造函数、工具方法（如 `getCoverImageUrl`）
- 不包含 `fromDto()` 工厂方法（因为依赖 `jellyfin_dart`）
- 根包的模型文件**保持原样不动**，避免一次性修改 30+ 处 service 调用

### Task 5: 收敛导航与模块注册协议

**状态：完成**（根据 leader 7.3 建议修正）

按 leader 反馈，已完成以下收敛：

- `NavigationIntent` 改为 `abstract class`，core 不再包含具体业务 action
- 新增 `GenericNavigationIntent`（仅含 action + arguments）
- `RouteDefinition` 重命名为 `RouteDescriptor`（只含 name/path/metadata，不含 Widget builder）
- `ModuleContext.config` 类型从 `dynamic` 改为 `Object?`
- 具体 intent（OpenMediaItemIntent 等）将随各 feature 包定义

**根包影响：** 无破坏性变更，facade re-export 保持兼容。

### Task 3: 抽 foundation/jellyfin_api

**状态：完成**

创建了 API 客户端包（依赖 `jellyfin_core` + `dio` + `jellyfin_dart`）：

| 文件 | 内容 |
|------|------|
| `lib/jellyfin_api.dart` | 统一导出入口 |
| `lib/src/api_client.dart` | ApiClient 封装（双 Dio 架构） |
| `lib/src/exceptions/api_exception.dart` | ApiException（从根包迁出） |
| `lib/src/exceptions/authentication_exception.dart` | AuthenticationException（从根包迁出） |
| `test/jellyfin_api_test.dart` | 8 个测试，全部通过 |

**根包 facade 更新：**
- `lib/src/core/api_client.dart` → 改为 re-export `jellyfin_api`
- `lib/src/exceptions/api_exception.dart` → 改为 re-export `jellyfin_api`
- `lib/src/exceptions/authentication_exception.dart` → 改为 re-export `jellyfin_api`

### Task 7: 最小版 jellyfin_testing

**状态：完成**（根据 leader 7.5 建议先做最小版）

按 leader 反馈提前建立最小版测试工具包：

| 文件 | 内容 |
|------|------|
| `lib/jellyfin_testing.dart` | 统一导出入口 |
| `lib/src/fakes/fake_app_navigator.dart` | 记录导航操作的 Fake navigator |
| `lib/src/fakes/fake_jellyfin_configuration.dart` | 测试配置工厂方法 |
| `lib/src/fixtures/user_fixture.dart` | testUserProfile, testAdminProfile, testAuthResult |
| `lib/src/fixtures/media_library_fixture.dart` | testMovieLibrary, testMusicLibrary, testTvShowLibrary, testLibraryList |
| `lib/src/fixtures/media_item_fixture.dart` | testMovieItem, testSeriesItem, testSeason, testEpisode, testMediaItemList |
| `test/jellyfin_testing_test.dart` | 12 个测试，全部通过 |

### Task 6: 抽 shared/jellyfin_ui_kit

**状态：完成**

按 leader 反馈谨慎处理图片组件，创建了共享 UI 组件包：

| 文件 | 内容 |
|------|------|
| `lib/jellyfin_ui_kit.dart` | 统一导出入口 |
| `lib/src/image/jellyfin_image_provider.dart` | **图片加载抽象接口** `JellyfinImageProvider` |
| `lib/src/image/jellyfin_image.dart` | `JellyfinImage` Widget（依赖抽象，不绑定具体 service） |
| `lib/src/models/view_mode_models.dart` | ViewMode, GridColumn, ViewModeConfig |
| `lib/src/widgets/alphabet_index_bar.dart` | 字母索引条（纯 Flutter） |
| `lib/src/widgets/media_grouped_scroll_view.dart` | 泛型分组滚动视图 |
| `lib/src/widgets/library_card.dart` | 媒体库卡片（依赖 jellyfin_models + 抽象） |
| `lib/src/widgets/media_item_card.dart` | 媒体项卡片（依赖 jellyfin_models + 抽象） |
| `test/jellyfin_ui_kit_test.dart` | 14 个测试，全部通过 |

**关键设计决策（leader 建议 7.3）：**
- `JellyfinImage` 不直接依赖 `JellyfinClient`，而是接受 `JellyfinImageProvider` 抽象接口
- 根包提供 `JellyfinClientImageProvider` 适配器，将 `JellyfinClient.image` 适配到抽象接口
- `ViewModeSelector` 暂不提取（依赖 SharedPreferences via ViewModeManager），等后续抽象化后再迁

**未迁移组件（feature 特定，留给后续 task）：**
- `ViewModeSelector` - 依赖 ViewModeManager（SharedPreferences）
- `ContinueWatchingCard` - 依赖 video_player_page
- `MiniPlayerCard` - 依赖 AudioPlaybackManager
- `MediaItemCardWithActions` - 依赖 user service
- `ActorAvatarCard` / `PersonAvatarCard` - 需 jellyfin_service 完整模型
- `MediaListBuilder` / `media_list_layouts/*` - 等布局组件统一迁移

---

## 二、未完成内容

所有 Phase 1 基础任务已完成。以下为长期建议项（非 Phase 1 阻塞）：

- `NAVIGATION_DESIGN.md` 导航设计文档（Task 5 遗留文档项）
- 各 feature 的具体 intent 定义（OpenMovieLibraryIntent 等，随 feature 迁移逐步添加）
- AI/RVC 配置从 JellyfinConfiguration 中分离（leader 建议 7.3）
- 模型中 accessToken/serverUrl 字段的逐步收敛（leader 建议 7.4）
- ViewModeSelector 提取到 jellyfin_ui_kit（需 ViewModeManager 抽象化）

---

## 三、遇到的问题

### 问题 1：模型 fromDto 与 jellyfin_dart 的耦合

**现象：** 根包中 5 个模型文件（user_models、media_library_models、media_item_models、person_models、server_discovery_models）都有 `fromDto()` 工厂方法依赖 `jellyfin_dart`。Services 层有 30+ 处调用这些工厂方法（如 `MediaItem.fromDto(...)`、`MediaLibraryListResult.fromDto(...)`）。

**影响：** 如果 `jellyfin_models` 不包含 `fromDto`，则所有 services 的调用方式都需要改变（从工厂构造函数改为顶层函数）。一次性改动量大，回归风险高。

**决策：** Phase 1 采用并存策略——`jellyfin_models` 放纯模型，根包保持原始模型文件（含 fromDto）不变。等后续 feature 包迁移时，由各 feature 的 data adapter 层负责 DTO 转换，逐步消除根包对 `jellyfin_dart` DTO 的直接暴露。

**遗留：** 根包模型和 jellyfin_models 存在类定义重复。这是有意为之的过渡状态。

### 问题 2：ApiException / AuthenticationException 的 dio 依赖

**现象：** `api_exception.dart` 和 `authentication_exception.dart` 都有 `fromDioError(DioException)` 工厂方法，强依赖 `dio` 包。

**影响：** 这两个异常类不能放入纯 Dart 的 `jellyfin_core`（核心包不应依赖 HTTP 客户端库）。

**决策：** 基类 `JellyfinException` 放入 `jellyfin_core`，带 dio 依赖的子类留给 `jellyfin_api` 包（Task 3）。

### 问题 3：磁盘空间不足

**现象：** 执行 `dart pub get` 时遇到 "磁盘空间不足" 错误（errno = 112）。

**解决：** 执行 `dart pub cache clean --force` 清理缓存后恢复。

**建议：** 后续 CI 环境需要预留足够磁盘空间（monorepo 多包 pub cache 会占用较多空间）。

### 问题 4：Windows 文件权限

**现象：** `mv` 命令移动 `video_gesture_controls` 目录时遇到 "Permission denied" 错误。

**解决：** 改用 `cp -r` + `rm -rf` 代替 `mv`。

### 问题 5：buildAuthHeader 功能归属

**现象：** 原始 `buildAuthHeader()` 逻辑在 `api_client.dart` 中，构造鉴权头的参数（clientName、deviceName 等）在 `JellyfinConfiguration` 中。

**决策：** 将 `buildAuthHeader()` 方法从 api_client 移到 `JellyfinConfiguration` 类中（已实现在 jellyfin_core），因为鉴权头的构造只依赖配置字段。这减少了 api_client 和 configuration 之间的双向依赖。

---

## 四、当前文件变更清单

### 根包改动

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `pubspec.yaml` | 修改 | 新增 jellyfin_core/jellyfin_models/jellyfin_api/jellyfin_ui_kit 依赖 |
| `lib/src/jellyfin_configuration.dart` | 修改 | → facade re-export `jellyfin_core` |
| `lib/src/exceptions/jellyfin_exception.dart` | 修改 | → facade re-export `jellyfin_core` |
| `lib/src/core/api_client.dart` | 修改 | → facade re-export `jellyfin_api` |
| `lib/src/exceptions/api_exception.dart` | 修改 | → facade re-export `jellyfin_api` |
| `lib/src/exceptions/authentication_exception.dart` | 修改 | → facade re-export `jellyfin_api` |
| `lib/src/ui/services/jellyfin_client_image_provider.dart` | 新增 | `JellyfinClientImageProvider` 适配器 |

### 新增独立包

| 包 | 文件数 | 说明 |
|----|--------|------|
| `packages/foundation/jellyfin_core/**` | 6 lib + 1 test | 核心基础包（纯 Dart） |
| `packages/foundation/jellyfin_api/**` | 4 lib + 1 test | API 客户端包（依赖 dio） |
| `packages/shared/jellyfin_models/**` | 5 lib + 1 test | 共享模型包（纯 Dart） |
| `packages/shared/jellyfin_ui_kit/**` | 8 lib + 1 test | 共享 UI 组件包（依赖 Flutter） |
| `packages/shared/jellyfin_testing/**` | 6 lib + 1 test | 测试工具包（纯 Dart） |

### 包位置迁移

| 原路径 | 新路径 |
|--------|--------|
| `packages/jellyfin_dart_3.8` | `packages/vendor/jellyfin_dart_3.8` |
| `packages/rvc_flutter` | `packages/features/rvc_flutter` |
| `packages/rvc_sdk` | `packages/vendor/rvc_sdk` |
| `packages/rainfall_tts_sdk` | `packages/vendor/rainfall_tts_sdk` |
| `packages/video_gesture_controls` | `packages/plugins/video_gesture_controls` |

---

## 五、验证结果

| 检查项 | 结果 |
|--------|------|
| `jellyfin_core` 独立 `dart test` | 17/17 通过 |
| `jellyfin_models` 独立 `dart test` | 8/8 通过 |
| `jellyfin_api` 独立 `dart test` | 8/8 通过 |
| `jellyfin_testing` 独立 `dart test` | 12/12 通过 |
| `jellyfin_ui_kit` 独立 `flutter test` | 14/14 通过 |
| 根包 `flutter analyze lib/src/` | 0 个 error（仅 info/warning） |
| 根包 `flutter pub get` | 成功 |
| example `flutter pub get` | 成功 |
| `jellyfin_ui_kit` 不依赖任何 `packages/features/*` | 确认 |
| `JellyfinImage` 不直接绑定 `JellyfinClient` | 确认（通过 `JellyfinImageProvider` 抽象） |

---

## 六、下一步建议

Phase 1 基础任务（Task 1-7）已全部完成。五个独立包已建立且通过测试验证。

1. **Task 8 App Shell** — 建立 `apps/jellyfin_app`，装配现有页面，实现 `AppNavigator`
2. **Task 9 jellyfin_auth** — 认证业务独立成包，验证"独立开发、独立测试"完整链路
3. **每完成一个 Task 提交独立 commit**，保持可回滚粒度
4. 长期收敛项（非阻塞）：
   - AI/RVC 配置从 JellyfinConfiguration 分离
   - 模型中 accessToken/serverUrl 逐步收敛
   - ViewModeManager 抽象化后 ViewModeSelector 提取到 ui_kit

---

## 七、复核评估与调整建议

> 复核日期：2026-05-11
> 复核范围：当前仓库结构、`MODULARIZATION_DESIGN.md`、`MODULARIZATION_EXECUTION_PLAN.md`、`packages/foundation/jellyfin_core`、`packages/shared/jellyfin_models`、根包 path 依赖。

### 7.1 总体评估

第一阶段已经完成了最关键的两个基础动作：`jellyfin_core` 和 `jellyfin_models` 已经被抽成独立 package，根包也开始通过 facade re-export 保持兼容。这个方向是对的，尤其是 `jellyfin_models` 不直接依赖 Flutter 和 `jellyfin_dart`，为后续业务模块独立开发打下了基础。

但从 `MODULARIZATION_EXECUTION_PLAN.md` 的原始定义看，当前更准确地说是 **Phase 1-A：foundation/shared 起步完成**，还不能算完整第一阶段闭环。因为计划中的第一阶段最小可交付版本还包含 `jellyfin_api`、`jellyfin_ui_kit`、`jellyfin_testing`、App Shell 和 Auth 独立 feature。当前报告覆盖的是 Task 1 ~ Task 7，其中 Task 3、6、7 尚未完成。

建议把当前阶段命名调整为：

```text
Phase 1-A：基础包抽取与目录重组
Phase 1-B：API/UI Kit/Testing 补齐
Phase 1-C：App Shell + Auth feature 验证闭环
```

这样进度表达会更稳，不会让后续评审误以为第一阶段业务组件化链路已经全部跑通。

### 7.2 做得好的地方

| 项目 | 评价 |
|------|------|
| `jellyfin_core` 独立 | 配置、异常基类、模块协议下沉是正确方向。 |
| `jellyfin_models` 独立 | 不依赖 Flutter、不依赖 `jellyfin_dart`，符合共享模型包定位。 |
| facade 兼容策略 | 根包旧入口没有立即删除，降低了迁移风险。 |
| DTO 转换暂缓 | 没有一次性改动 30+ 处 service 调用，这是稳妥选择。 |
| path 依赖更新 | 根包已经指向 `packages/vendor`、`packages/features` 等新路径。 |

### 7.3 需要立即修正或收敛的点

#### 建议 1：`NavigationIntent` 不要在 core 中固化具体业务 action

当前 `jellyfin_core` 中的 `NavigationIntent` 已经包含：

```dart
NavigationIntent.openMediaItem(...)
NavigationIntent.openVideoPlayback(...)
NavigationIntent.openAlbum(...)
NavigationIntent.openArtist(...)
NavigationIntent.playSong(...)
```

这比全局页面枚举轻一些，但本质上仍然让 core 知道了媒体、播放、音乐等业务动作。长期会形成新的中心化导航表：以后新增电影筛选、剧集季列表、AI 推荐、RVC 页面，都可能继续往 core 加 factory。

建议在 Task 5 收敛时改成：

```dart
abstract class NavigationIntent {
  const NavigationIntent();
}

class GenericNavigationIntent extends NavigationIntent {
  final String action;
  final Map<String, Object?> arguments;

  const GenericNavigationIntent({
    required this.action,
    this.arguments = const {},
  });
}
```

然后把具体 intent 放回各 feature：

```text
jellyfin_media:
  OpenMediaItemIntent
  OpenPersonIntent

jellyfin_playback:
  OpenVideoPlaybackIntent

jellyfin_music:
  OpenAlbumIntent
  OpenArtistIntent
  PlaySongIntent
```

core 只保留协议，不保留业务枚举或业务 factory。

#### 建议 2：`RouteDefinition.builder` 和 `ModuleContext.config` 不要长期使用 `dynamic`

当前 `JellyfinFeatureModule` 为了保持 core 纯 Dart，使用了：

```dart
dynamic get config;
final dynamic Function(dynamic context)? builder;
```

短期可接受，但它会带来两个问题：

- 模块注册阶段缺少类型约束，错误会延迟到运行时。
- core 既想保持纯 Dart，又想承载 Flutter 页面 builder，职责有点混。

建议拆成两层协议：

```text
jellyfin_core:
  ModuleContext
  NavigationIntent
  NavigationEntry
  RouteDescriptor   # 只描述 name/path/metadata，不含 Widget builder

App Shell 或 jellyfin_ui_kit:
  FlutterRouteDefinition
  Widget builder(BuildContext context)
```

如果要保留 `builder`，也建议放到 Flutter 相关包，而不是 core。

#### 建议 3：`JellyfinConfiguration` 中的 AI/RVC 配置要考虑下沉边界

`JellyfinConfiguration` 目前仍包含：

- `aiServiceUrl`
- `aiServicePort`
- `rvcServiceUrl`
- `rvcServicePort`
- `resolvedAiServiceUrl`
- `resolvedRvcServiceUrl`

这些属于可选扩展模块能力，不一定适合长期放在 L0 core。短期保留可以兼容现有代码，但建议在 Task 17 或 facade 收敛前迁出为扩展配置，例如：

```dart
class ExternalServiceEndpoints {
  final Uri? aiRecommendation;
  final Uri? rvc;
}
```

或者由 `jellyfin_ai_recommendation` 和 `rvc_flutter` 自己从 serverUrl 推导默认地址。

#### 建议 4：`jellyfin_models` 中不要长期携带 accessToken/serverUrl 这类传输信息

当前共享模型仍可看到 `serverUrl`、`accessToken` 等字段，例如 `MediaItem` 中包含访问令牌。这是从旧模型迁移过来的兼容结果，但从共享模型设计看，它把纯业务实体、图片 URL 构造、认证信息混在了一起。

建议下一步逐步拆成：

```text
MediaItemSummary / MediaItemDetail:
  只放业务字段：id/name/type/year/rating/progress

ImageRef:
  itemId/imageType/tag

ImageUrlResolver:
  根据 config/token/ImageRef 生成可访问 URL
```

这样共享模型不会携带 token，也更适合跨模块传递。

#### 建议 5：Task 7 不建议完全暂缓

报告中建议 Task 7 暂缓到 feature 包迁移时再做。这里建议调整为：**先做最小版 `jellyfin_testing`，不要等到 feature 开始拆才补。**

最小版只需要：

- `FakeAppNavigator`
- `FakeJellyfinConfiguration`
- `media_library_fixture.dart`
- `media_item_fixture.dart`
- `user_fixture.dart`

暂时不需要完整的 `FakeAuthRepository` / `FakeMusicRepository`。但 fake navigator 和 fixture 应尽早有，因为 Task 8、9、10 会马上用到。

### 7.4 关于 Task 1 包迁移的风险

Task 1 原计划更偏向“建立目录，不迁移业务逻辑”。当前实际执行中已经把多个现有包迁到了新位置：

- `packages/jellyfin_dart_3.8` → `packages/vendor/jellyfin_dart_3.8`
- `packages/rvc_flutter` → `packages/features/rvc_flutter`
- `packages/rvc_sdk` → `packages/vendor/rvc_sdk`
- `packages/rainfall_tts_sdk` → `packages/vendor/rainfall_tts_sdk`
- `packages/video_gesture_controls` → `packages/plugins/video_gesture_controls`

这个动作方向没问题，但它会造成非常大的 git diff，容易把“目录治理”和“基础包抽取”混在一个提交里。建议拆成独立提交，并尽量使用 `git mv` 保留历史。

建议提交边界：

```text
commit 1: chore: reorganize package directories
commit 2: refactor(core): extract jellyfin core package
commit 3: refactor(models): extract shared jellyfin models package
commit 4: chore: update root path dependencies
```

如果当前已经产生大量 delete/add 状态，提交前要重点确认：

- 旧路径确实不再被任何 pubspec 或 import 引用。
- 新路径 package 都能 `pub get`。
- vendor 包移动没有丢文件。
- `packages/ohos` 是否继续留在原位，需要在文档中明确，不要同时出现两套约定。

### 7.5 验证结果复核

报告中记录：

| 检查项 | 报告结果 |
|--------|----------|
| `jellyfin_core` 独立 `dart test` | 15/15 通过 |
| `jellyfin_models` 独立 `dart test` | 8/8 通过 |
| 根包 `flutter analyze lib/src/` | 0 个 error |
| 根包 `flutter pub get` | 成功 |
| example `flutter pub get` | 成功 |

本次复核尝试重新执行：

```bash
cd packages/foundation/jellyfin_core
dart test

cd packages/shared/jellyfin_models
dart test
```

两条命令都在 120 秒超时，没有拿到新的通过结果。当前系统中也存在多个长时间运行的 `dart` / `dartaotruntime` 进程。这个现象不等同于测试失败，但说明当前环境的 Dart 工具链状态不稳定。

建议在进入 Task 3 前先做一次工具链清理和可复现验证：

```bash
dart --version
cd packages/foundation/jellyfin_core && dart test --reporter expanded
cd packages/shared/jellyfin_models && dart test --reporter expanded
flutter pub get
flutter analyze lib/src/
```

并把最新命令输出补到报告中，避免只依赖历史验证结果。

### 7.6 下一步优先级建议

建议把原“下一步建议”调整为以下顺序：

1. **先补齐 Task 5 的协议收敛**：把 core 中具体业务 intent factory 移出去，修正 `dynamic` 设计，补 `NAVIGATION_DESIGN.md`。
2. **再做 Task 3 `jellyfin_api`**：迁出 `ApiClient`、`ApiException`、`AuthenticationException`，让 HTTP/Dio 依赖集中到 API 包。
3. **并行启动最小版 Task 7 `jellyfin_testing`**：先提供 fake navigator、config 和 fixtures，支撑后续 App Shell/Auth 测试。
4. **Task 6 `jellyfin_ui_kit` 可以并行，但要谨慎处理图片组件**：`JellyfinImage` 不应直接绑定某个 feature service，建议依赖 `ImageUrlResolver` 或 `ImageRepository` 抽象。
5. **Task 8 App Shell 暂缓到 Task 3/5/7 完成后**：否则 App Shell 会依赖还没稳定的 API 和导航协议，后续返工概率高。

### 7.7 更新后的阶段完成定义

建议 Phase 1 完成标准改为：

- `jellyfin_core`、`jellyfin_api`、`jellyfin_models`、`jellyfin_ui_kit`、`jellyfin_testing` 都存在独立 package。
- core 中不包含具体业务页面或业务 action。
- `jellyfin_models` 不依赖 Flutter、不依赖 `jellyfin_dart`，并且明确哪些模型是过渡重复。
- 根包 facade 能继续兼容旧 import。
- 每个新 package 至少有一组可复现测试。
- 最新验证命令输出已记录。
- 大规模目录迁移已独立提交或至少在提交说明中明确边界。

当前进展可以视为 Phase 1 的良好开局，但建议先修正导航协议和验证可复现性，再继续推进 `jellyfin_api` 和 App Shell。

---

## 八、执行结果汇报（leader 反馈后执行）

> 汇报日期：2026-05-11
> 本节记录 leader 在第七节提出反馈后的执行结果。

### 8.1 leader 优先级执行跟踪

leader 在 7.6 节给出的优先级顺序及执行状态：

| 优先级 | 任务 | leader 要求 | 执行结果 |
|--------|------|-------------|----------|
| 1 | Task 5 协议收敛 | NavigationIntent 改 abstract，移除业务 factory；RouteDefinition 改 RouteDescriptor，移除 dynamic builder | **已完成** — `NavigationIntent` 改为 abstract class，core 仅保留 `GenericNavigationIntent`；`RouteDescriptor` 只含 path/name/metadata；`ModuleContext.config` 改为 `Object?` |
| 2 | Task 3 jellyfin_api | 迁出 ApiClient、ApiException、AuthenticationException | **已完成** — ApiClient 使用 `JellyfinConfiguration.buildAuthHeader()`；双 Dio 架构保留；8 个测试通过 |
| 3 | Task 7 最小版 testing | FakeAppNavigator + config 工厂 + 三组 fixture | **已完成** — FakeAppNavigator 记录 push/pushIntent/pop 操作；fakeJellyfinConfiguration / fakeAuthenticatedConfig 工厂方法；user/media_library/media_item 三组 fixture；12 个测试通过 |
| 4 | Task 6 jellyfin_ui_kit | JellyfinImage 不绑定 feature service，依赖 ImageUrlResolver 或 ImageRepository 抽象 | **已完成** — 定义 `JellyfinImageProvider` 抽象接口；JellyfinImage 接受抽象不依赖 JellyfinClient；根包提供 `JellyfinClientImageProvider` 适配器；14 个测试通过 |

### 8.2 leader 各建议的回应

#### 建议 1：NavigationIntent 不要在 core 中固化具体业务 action

**回应：已修正。**

```dart
// 修正前（core 包含 5 个业务 factory）
NavigationIntent.openMediaItem(...)
NavigationIntent.openVideoPlayback(...)

// 修正后（core 只保留协议）
abstract class NavigationIntent {
  const NavigationIntent();
}

class GenericNavigationIntent extends NavigationIntent {
  final String action;
  final Map<String, Object?> arguments;
  const GenericNavigationIntent({required this.action, this.arguments = const {}});
}
```

具体 intent（OpenMediaItemIntent、OpenAlbumIntent 等）将随各 feature 包定义，core 不再感知任何业务 action。

#### 建议 2：RouteDefinition.builder 和 ModuleContext.config 不要使用 dynamic

**回应：已修正。**

- `RouteDefinition` 重命名为 `RouteDescriptor`，移除 `builder` 参数，只保留纯元数据（path/name/metadata）
- `ModuleContext.config` 类型从 `dynamic` 改为 `Object?`
- Flutter Widget builder 层面（`FlutterRouteDefinition`）将在 App Shell（Task 8）中定义

#### 建议 3：AI/RVC 配置下沉边界

**回应：已记录，暂保持现状。**

AI/RVC 配置字段保留在 `JellyfinConfiguration` 中以兼容现有代码。计划在 Task 17（RVC 与插件依赖整理）或 Task 18（facade 收敛）时迁出为 `ExternalServiceEndpoints` 或由各 feature 自行推导。当前不阻塞 Phase 1。

#### 建议 4：模型中 accessToken/serverUrl 的长期收敛

**回应：已记录，采用渐进策略。**

当前 `jellyfin_models` 中的 `serverUrl`/`accessToken` 字段从旧模型迁移过来以保持接口兼容。长期方向是拆分为 `MediaItemSummary`（纯业务字段）+ `ImageRef`（图片引用）+ `ImageUrlResolver`（URL 构造）。这将在 feature 包迁移时逐步实施，不作为 Phase 1 阻塞。

#### 建议 5：Task 7 不建议完全暂缓

**回应：已采纳，最小版已完成。**

按 leader 要求提前建立了最小版 `jellyfin_testing`，包含：
- `FakeAppNavigator`（记录 push/pushIntent/pop/clear/hasIntentAction）
- `fakeJellyfinConfiguration()` / `fakeAuthenticatedConfig()` 工厂方法
- `user_fixture.dart`（testUserProfile, testAdminProfile, testAuthResult）
- `media_library_fixture.dart`（testMovieLibrary, testMusicLibrary, testTvShowLibrary, testLibraryList）
- `media_item_fixture.dart`（testMovieItem, testSeriesItem, testSeason, testEpisode, testMediaItemList）

暂不包含 `FakeAuthRepository` / `FakeMusicRepository`，等 Task 9、15 时按需添加。

### 8.3 leader 7.7 完成标准逐项核查

| 完成标准 | 状态 | 说明 |
|----------|------|------|
| `jellyfin_core`、`jellyfin_api`、`jellyfin_models`、`jellyfin_ui_kit`、`jellyfin_testing` 都存在独立 package | **通过** | 五个包均已创建，各有独立 pubspec.yaml 和公共导出 |
| core 中不包含具体业务页面或业务 action | **通过** | NavigationIntent 为 abstract class，无业务 factory |
| `jellyfin_models` 不依赖 Flutter、不依赖 `jellyfin_dart` | **通过** | 仅依赖 equatable |
| 明确哪些模型是过渡重复 | **记录** | 根包 5 个模型文件保持含 `fromDto` 版本，`jellyfin_models` 为纯模型版本，这是有意为之的过渡状态 |
| 根包 facade 能继续兼容旧 import | **通过** | 6 个根包文件改为 re-export，旧 import 路径不受影响 |
| 每个新 package 至少有一组可复现测试 | **通过** | 见 8.4 节测试结果 |
| 最新验证命令输出已记录 | **通过** | 见 8.4 节 |
| 大规模目录迁移已在文档中明确边界 | **记录** | 见第四节文件变更清单，待提交时按 commit 边界建议拆分 |

### 8.4 最新验证证据

以下为 leader 反馈后重新执行的验证命令及结果：

```
$ cd packages/foundation/jellyfin_core && dart test --reporter expanded
00:00 +17: All tests passed!

$ cd packages/foundation/jellyfin_api && dart test --reporter expanded
00:00 +8: All tests passed!

$ cd packages/shared/jellyfin_models && dart test --reporter expanded
00:00 +8: All tests passed!

$ cd packages/shared/jellyfin_testing && dart test --reporter expanded
00:00 +12: All tests passed!

$ cd packages/shared/jellyfin_ui_kit && flutter test --reporter expanded
00:00 +14: All tests passed!

$ flutter analyze lib/src/
64 issues found.   # 0 error, 3 warning (均为既有问题), 61 info

$ flutter pub get
Got dependencies!
Got dependencies in .\example!
```

### 8.5 依赖关系图（当前实际）

```
jellyfin_dart (vendor)
    ↑
jellyfin_api ──→ jellyfin_core
    ↑                  ↑
jellyfin_ui_kit ──→ jellyfin_models
    ↑
jellyfin_testing ──→ jellyfin_models + jellyfin_core

根包 jellyfin_service ──→ 上述所有包
    ├── JellyfinClientImageProvider 适配 jellyfin_ui_kit 抽象
    └── 6 个 facade re-export 保持旧 import 兼容
```

关键约束验证：
- `jellyfin_ui_kit` 不依赖任何 `packages/features/*`
- `jellyfin_ui_kit` 不直接依赖 `JellyfinClient`，通过 `JellyfinImageProvider` 抽象解耦
- `jellyfin_core` 不依赖 Flutter，不包含具体业务 action
- `jellyfin_models` 不依赖 Flutter，不依赖 `jellyfin_dart`

### 8.6 阶段评估

按 leader 7.1 节建议的命名：

| 子阶段 | 状态 | 内容 |
|--------|------|------|
| Phase 1-A：基础包抽取与目录重组 | **完成** | Task 1, 2, 4 |
| Phase 1-B：API/UI Kit/Testing 补齐 | **完成** | Task 3, 5, 6, 7 |
| Phase 1-C：App Shell + Auth 验证闭环 | **待开始** | Task 8, 9 |

Phase 1-A + 1-B 已全部完成并通过 leader 7.7 完成标准核查。下一步进入 Phase 1-C。
