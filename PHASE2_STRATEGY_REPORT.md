# 第二阶段模块化策略报告

> 对应进展报告：`PHASE2_PROGRESS_REPORT.md`
> 生成日期：2026-05-12
> 目标：把 Phase 2 已暴露的问题转成可执行决策、分工建议和验收策略，帮助团队继续推进业务模块解耦。

---

## 一、总体判断

Phase 2 的核心进展是正向的：`jellyfin_ai_recommendation` 和 `jellyfin_media` 已经被抽成独立 feature package，并且独立 analyze/test 都通过。当前团队遇到的问题并不是“拆不出来”，而是进入了模块化最典型的过渡期：旧根包 facade 还在，新 feature 包已经存在，两套模型、同名页面、同名 typedef 和 public export 策略开始互相挤压。

因此，接下来不建议马上无脑并行推进更多 feature。更稳的策略是先做一个短周期的 **Phase 2-C 前置收敛**：

1. 冻结跨模块公共契约。
2. 统一 `MediaItem` 的长期归属。
3. 修正 `src/` 直连 import 的临时方案。
4. 选择一条真实页面链路切到新模块，证明新包不只是“测试通过”，而是已经接入 App 行为。

完成这个收敛后，再并行推进 `jellyfin_movies`、`jellyfin_series`、`jellyfin_playback` 会更省返工。

---

## 二、Leader 需要拍板的 4 个结论

### 决策 1：`MediaItem` 统一策略

建议选择 **方案 A，但分两步落地**。

不要继续长期保留根包 `MediaItem` 与 `jellyfin_models.MediaItem` 双类型。双类型会持续污染所有 feature 的回调、列表、详情、播放和 AI 推荐链路，每个集成点都要手写转换，后面迁 `movies`、`series`、`playback`、`music` 时成本会指数级增加。

推荐落地方式：

1. 短期新增统一 DTO mapper，把 `fromDto()` 逻辑从根包模型中移到 API/data adapter 层。
2. 根包 service 逐步改为返回 `jellyfin_models.MediaItem`。
3. 根包旧 `MediaItem` 先 deprecated，Task 18 facade 收敛时删除或仅做兼容 re-export。

不建议采用长期 `MediaItemAdapter` 方案。Adapter 可以作为迁移工具，但不能成为最终架构，否则双类型会一直存在。

### 决策 2：`Person.type` 类型策略

当前 `String` 方案可以作为过渡，但建议加一层约束。

不应该让 feature 依赖 `jellyfin_dart.PersonKind`，这个判断是正确的。但裸 `String` 也容易出现 `"Actor"`、`"actor"`、`"actors"` 这类隐性错误。

推荐策略：

1. 短期保留 `"actor"` / `"director"` / `"writer"` 字符串，但集中定义常量或转换函数。
2. 中期在 `jellyfin_media` 或 `jellyfin_models` 中定义纯 Dart enum，例如 `PersonRole.actor`、`PersonRole.director`、`PersonRole.writer`、`PersonRole.unknown`。
3. `jellyfin_dart.PersonKind` 到 `PersonRole` 的转换只允许出现在根包兼容层或 API/data adapter 层。

### 决策 3：barrel export 策略

建议采用 **方案 D 的节奏**，但修正当前“直接 import `src/`”的做法。

当前 `jellyfin_media.dart` 不导出同名页面/组件可以接受，因为根包还在导出旧类，直接完整 export 会触发 `ambiguous_export`。但让使用方写：

```dart
import 'package:jellyfin_media/src/pages/media_item_detail_page.dart';
```

会破坏模块边界规则。`src/` 是包内实现细节，外部依赖后，后续文件结构就不敢调整。

推荐改为公共子入口：

```text
packages/features/jellyfin_media/lib/jellyfin_media.dart        # 仅导出不冲突 contract
packages/features/jellyfin_media/lib/jellyfin_media_pages.dart  # 导出页面
packages/features/jellyfin_media/lib/jellyfin_media_models.dart # 导出模型
packages/features/jellyfin_media/lib/jellyfin_media_widgets.dart# 导出组件
```

根包 `jellyfin_service.dart` 在 Task 18 前只 export `jellyfin_media.dart`，不 export pages/widgets 子入口。App 或迁移中的集成点如果要使用新页面，改成 import public 子入口，而不是 import `src/`。

### 决策 4：`MediaListBuilder` 迁移范围

不建议现在把 `MediaListBuilder`、4 种布局和 `ViewModeManager` 一次性搬进 `jellyfin_media`。

原因是它们当前同时牵涉：

- `JellyfinClient` 图片加载耦合。
- `shared_preferences` 视图模式持久化。
- 多个页面共享的布局行为。
- 后续 `movies`、`series`、`home` 都可能复用。

推荐拆成两层：

1. `jellyfin_ui_kit` 承载纯布局组件和 `ViewMode` UI，不持有 client，不持有持久化。
2. 根包或 App Shell 提供 `ViewModeStore` / `ViewModeManager` 适配，把 `shared_preferences` 留在装配层。

当前 `MediaItemsPage` 使用 `listBuilder` 注入布局的方案可以继续保留。它是一个好的过渡设计。

---

## 三、6 个问题的处理策略

### 问题 1：`MediaItem` 双类型冲突

这是最高优先级问题。它会影响所有后续模块。

建议新增一个小任务：**Task 10.5：MediaItem 契约收敛**。

交付内容：

- 新增统一 mapper，例如 `MediaItemDtoMapper` 或 `toSharedMediaItem()`。
- 根包集成点只允许调用统一 mapper，不再手写匿名转换函数。
- `media_libraries_page.dart` 中当前局部 `toModelsMediaItem()` 先迁到统一位置。
- 为 mapper 写单元测试，覆盖演员、导演、编剧、图片 tag、播放进度、serverUrl、accessToken。

验收标准：

- 仓库中不再新增第二个手写 `MediaItem` 转换函数。
- 后续 feature 只能接收 `jellyfin_models.MediaItem`。
- 根包旧 `MediaItem.fromDto()` 只允许作为兼容实现，不能再作为新模块契约。

### 问题 2：`Person.type` 从 `PersonKind` 解耦

这个方向正确，不要回退到 `jellyfin_dart.PersonKind`。

建议先补一个转换边界：

```text
jellyfin_dart.PersonKind -> PersonRole/String -> feature UI
```

转换只能放在 data adapter 或根包兼容层，页面和 widget 不应该知道 `jellyfin_dart`。

### 问题 3：barrel export ambiguous_export

当前“不导出同名类”能让编译通过，但会逼迫调用方 import `src/`。这会和模块化边界规则冲突。

建议采用 public sub-barrel：

- `package:jellyfin_media/jellyfin_media_pages.dart`
- `package:jellyfin_media/jellyfin_media_widgets.dart`
- `package:jellyfin_media/jellyfin_media_models.dart`

等 Task 18 删除根包旧页面后，再恢复完整 `jellyfin_media.dart` export。

### 问题 4：`MediaListBuilder` 未迁移

当前不要强迁。先保持 `listBuilder` 注入。

建议后续拆分顺序：

1. 先抽 `ViewModeStore` 抽象。
2. 再把 4 种纯布局组件迁到 `jellyfin_ui_kit`。
3. 最后由 `jellyfin_media` 或业务模块组合布局和数据。

这样不会把 `shared_preferences` 和 `JellyfinClient` 带进 `jellyfin_media`。

### 问题 5：typedef 重复定义

不要放进 `jellyfin_core`，因为 `core` 不应该依赖 `jellyfin_models`。

推荐把“数据获取型 typedef”放到更贴近模型的共享层，例如：

```text
packages/shared/jellyfin_models/lib/src/media_contracts.dart
```

可放入：

- `MediaItemDetailFetcher`
- `MediaItemsFetcher`
- `SeasonsFetcher`

不要把带 `BuildContext` 的导航回调放入 `jellyfin_models`。导航回调属于 presentation 或 App Shell 装配层。

### 问题 6：根包旧文件与新模块双轨并行

双轨可以存在，但必须可控。现在最大问题是：新模块测试通过，但真实页面仍大多走旧实现。

建议选择一条最小真实链路切换到新模块：

```text
媒体库页 -> 媒体项列表 -> 媒体详情 -> 人物详情
```

不需要一次切完所有业务。先切一条主链路，补 smoke/widget test，证明 `jellyfin_media` 的注入式设计能承载真实 App 行为。之后 `movies` 和 `series` 再复用这条链路。

---

## 四、建议的下一轮执行顺序

### 第 0 轮：半天到 1 天，先收敛契约

负责人：架构负责人或最熟悉 Phase 1/2 的开发。

任务：

- 确认本报告中的 4 个 Leader 决策。
- 新增 `Task 10.5 MediaItem 契约收敛`。
- 新增 `jellyfin_media` public sub-barrel，替代外部 `src/` import。
- 把当前 `media_libraries_page.dart` 中的手写 `toModelsMediaItem()` 迁到统一 mapper。

退出条件：

- 新增模块不再依赖 `src/` import 作为外部 API。
- 新增转换逻辑有测试。
- 后续 feature 的公共模型统一以 `jellyfin_models` 为准。

### 第 1 轮：Task 12 与 Task 13 并行

负责人 A：`jellyfin_movies`

- 迁 `movie_filter_page.dart`
- 迁 `movie_detail_page.dart`
- 迁 `movie_filter_models.dart`
- 电影模块打开详情/播放时走 intent 或回调，不直接 import playback 页面。

负责人 B：`jellyfin_series`

- 迁 `seasons_page.dart`
- 迁 `episodes_page.dart`
- 迁 `Season` / `Episode` 相关 adapter。
- Episode 播放走 `OpenVideoPlaybackIntent` 或注入回调。

共享约束：

- 两个模块都只能依赖 `jellyfin_media` 的 public API、`jellyfin_models`、`jellyfin_ui_kit`。
- 不允许互相 import。
- 不允许新增根包模型类型作为 feature public API。

### 第 2 轮：Task 14 播放模块

播放模块应该在音乐模块之前完成。它负责把视频播放、画质切换、播放进度上报从根包独立出来，也为 `series`、`movies` 和 `media` 提供统一播放入口。

重点不是先追求 UI 完整迁移，而是先把播放协议定稳：

- `PlaybackInfo`
- `PlaybackSession`
- `VideoQuality`
- `PlaybackRepository`
- `OpenVideoPlaybackIntent`

### 第 3 轮：Task 15 音乐模块

音乐模块体量最大，建议等播放协议稳定后再做。否则 `AudioPlaybackManager`、专辑页、歌手页、歌词页、MiniPlayer 会一边迁移一边追着播放边界改。

音乐模块特别注意：

- `AudioPlaybackManager` 不要继续是全局单例式核心依赖，至少要留出可注入接口。
- 音乐模型留在 `jellyfin_music`，不要把 `MusicSong`、`MusicAlbum` 全塞进 `jellyfin_models`。
- AI 推荐里的 `onPlaySong` 后续应接入音乐模块公开契约，而不是根包音乐模型。

### 第 4 轮：Task 8/9 与 Task 11 的关系

`jellyfin_home` 依赖 Auth 和 App Shell。当前 Phase 2 已经提前做了 AI 和 Media，这是可以接受的实验顺序，但不建议继续绕过 App Shell 太久。

建议：

- 如果团队目标是尽快完成业务包拆分：先做 Task 12/13/14，再回补 Task 8/9。
- 如果团队目标是尽快形成可运行的模块化 App：优先回补 Task 8/9，再做 Task 11。

不建议在 Auth/App Shell 未稳定前强行迁 `jellyfin_home`。

---

## 五、给开发同学的执行建议

### 写新 feature 前先问 5 个问题

1. 这个模块 public API 是否暴露了根包旧模型？
2. 是否 import 了其它 feature 的页面或 `src/`？
3. 页面跳转是回调/intent，还是直接 `Navigator.push(OtherFeaturePage)`？
4. 图片加载是否通过 `JellyfinImageProvider` 或 URL，而不是直接拿 `JellyfinClient`？
5. 这个模块能不能在自己的目录单独 `flutter test`？

只要有一个答案不符合，就先停下来收边界，不要继续搬页面。

### Review 时重点看 6 类风险

| 风险 | 表现 | 处理 |
|---|---|---|
| 双模型扩散 | 又出现新的 `toModelsXxx()` 局部转换 | 收敛到统一 mapper |
| 跨 feature import | `package:jellyfin_xxx/src/...` 或直接 import 其它 feature 页面 | 改 public API、回调或 intent |
| barrel 冲突 | `ambiguous_export` | 根包 facade 暂时 hide/show，feature 提供子入口 |
| core 污染 | `jellyfin_core` 出现具体业务 action | 业务 intent 放 feature，不放 core |
| UI Kit 污染 | `jellyfin_ui_kit` 依赖 client/service/shared_preferences | 抽接口，由 App Shell 注入 |
| 测试空转 | 只测 package，不测真实集成链路 | 至少切一条 App 主链路到新模块 |

### 每个 feature 完成定义

一个 feature 包完成，不只是“文件搬过去”。

必须同时满足：

- 有独立 `pubspec.yaml`、公共导出入口、README 或模块说明。
- `flutter analyze` 0 error。
- `flutter test` 独立通过。
- public API 不暴露 `jellyfin_dart` DTO。
- 不直接 import 其它 feature 页面。
- 至少一个根包/App 集成点能实际使用新模块。
- 根包旧入口要么保留兼容，要么明确 deprecated，不允许无说明删除。

---

## 六、建议新增任务卡

### Task 10.5：Media 契约与集成收敛

**目标：** 在继续 Task 12/13/14 前，把通用媒体契约从临时态收敛成可复用基础。

**建议改动：**

- 新增统一 `MediaItem` DTO mapper。
- 新增 `jellyfin_media` public sub-barrel。
- 修正外部 `src/` import。
- 选择媒体库到媒体详情的一条真实链路切到新 `jellyfin_media`。
- 给 mapper 和集成点补测试。

**完成后收益：**

- `movies`、`series`、`playback` 不再重复处理双模型。
- export 策略清晰，后续不会继续扩大 `src/` 依赖。
- 新模块从“独立测试可用”升级为“真实 App 链路可用”。

---

## 七、最终建议

建议团队接下来采用 **先收敛契约，再并行业务** 的节奏。

当前最不该做的是继续同时开 `movies`、`series`、`playback`、`music` 四条线，然后让每条线自己处理 `MediaItem` 转换、barrel export 和页面跳转。那会把 Phase 2 的临时问题复制四份。

当前最该做的是用 1 天左右完成 Task 10.5，把 `jellyfin_media` 真正变成后续业务模块的稳定底座。底座稳定后，Task 12/13 可以放心并行，Task 14 顺势接上，Task 15 再处理音乐这个最大模块。

一句话策略：

> 不要让每个 feature 都带一套自己的过渡方案；先把过渡方案产品化成共享契约，再继续拆业务。
