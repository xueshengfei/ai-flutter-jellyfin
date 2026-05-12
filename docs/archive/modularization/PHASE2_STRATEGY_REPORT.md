# Phase 2 模块化改造评估与下一步建议

> 对应进展报告：`PHASE2_PROGRESS_REPORT.md`
> 评估日期：2026-05-12
> 评估方式：阅读最新进展报告，抽查 `lib/jellyfin_service.dart`、`media_libraries_page.dart`、`MediaItemMapper`、`PlaybackDelegate`、`AudioPlaybackPort`、旧页面 deprecated 标记，并运行模块边界检查脚本。

---

## 一、总体结论

Phase 2 可以认可为 **feature package 抽取阶段完成**。媒体、电影、剧集、播放、音乐详情、AI 推荐都已经形成独立包，主入口 `media_libraries_page.dart` 也已经切到新模块页面。`MediaItemMapper`、`media_contracts.dart`、子 barrel、`PlaybackDelegate`、`AudioPlaybackPort` 这些补丁说明团队已经开始处理真实边界问题，而不是只做文件搬迁。

但还不能说“模块化完成”。当前架构仍是：

```text
feature 包已抽出
根包仍负责 facade、旧页面兼容、模型转换、播放服务包装、首页编排、音乐主链路
App Shell/Auth 仍未进入闭环
```

所以本轮判断是：

> 本阶段可以进入下一轮，但下一轮必须优先做 App Shell/Auth 和 facade 收敛，否则根包会继续变成新的编排中心。

---

## 二、代码核查结果

### 已验证通过

1. `dart scripts/check_module_boundaries.dart` 通过，feature 包没有反向 import 根包，也没有跨 feature import 其它包的 `src/`。
2. `MediaItemMapper` 已经改为 import `package:jellyfin_media/jellyfin_media_models.dart`，不再直连 `jellyfin_media/src`。
3. 根包旧页面已经加了 `@Deprecated` 标记，例如旧 `VideoPlayerPage`、`MediaItemDetailPage`、`MovieFilterPage`、`AlbumDetailPage` 等。
4. `AudioPlaybackManager` 已实现 `jellyfin_music` 的 `AudioPlaybackPort`，音乐播放抽象已经开始落地。
5. `jellyfin_playback` 通过 `PlaybackDelegate` 隔离了根包 `PlaybackService`，播放页不再直接依赖 `JellyfinClient`。

### 仍需修正

1. **hide 数量统计不准确。**
   `PHASE2_PROGRESS_REPORT.md` 第 13.1 节写 hide 类型共 15 个，但 `lib/jellyfin_service.dart` 实际隐藏：
   - `jellyfin_movies`：3 个
   - `jellyfin_playback`：4 个
   - `jellyfin_playback_pages`：1 个
   - `jellyfin_music`：8 个
   - `jellyfin_music_pages`：2 个

   实际合计是 **18 个**。报告需要修正，避免后续清理计划对不上。

2. **旧文件清理表不完整。**
   报告第 13.2 节列了 11 个旧页面，但根包仍保留 `MusicLibraryPage`、`MusicSearchPage`、`LyricsPage`、`PersonalPage`、`LoginPage`、`TestApiPage` 等未拆或未标记页面。建议把表拆成两类：
   - 已有新包替代且 deprecated 的旧页面。
   - 尚无新包替代、仍属于根包职责的页面。

3. **AI 推荐依赖说明过期。**
   报告早期章节仍写 AI 模块依赖 `dio`、`flutter_markdown`、`equatable` 等，但实际 `jellyfin_ai_recommendation/pubspec.yaml` 已包含 `just_audio` 和 `rainfall_tts_sdk`。这应该补进报告，并明确 TTS 是 AI 推荐模块内聚能力还是可选扩展。

4. **根包仍是事实上的 App Shell。**
   `media_libraries_page.dart` 现在集中创建电影、媒体、剧集、播放、音乐页面，并负责大量 mapper、delegate、callback 装配。这个文件正在承担 App Shell/router 的职责。短期可接受，但下一阶段必须迁出，否则业务模块越拆，根包越像调度中心。

5. **边界检查脚本规则可以更严格。**
   脚本目前给 `lib/src/adapters` 留了 import feature `src/` 的豁免。虽然当前代码已经不用这个豁免，但建议删除豁免，防止后续 adapter 再次绕过 public barrel。

---

## 三、对各模块的评估

### `jellyfin_media`

完成度高。Task 10.5 补上统一 contracts 和 mapper 后，已经具备作为后续电影、剧集、播放入口底座的条件。

下一步不是继续扩功能，而是减少根包对旧媒体页面的 public export，准备 Task 18 清理。

### `jellyfin_movies` / `jellyfin_series`

拆分方向正确，回调注入和纯 Dart 枚举替代 vendor enum 是好选择。当前风险主要不在包内，而在根包集成层仍需做大量转换和页面编排。

下一步建议补一个真实集成 smoke test：从媒体库进入电影筛选、电影详情、剧集季/集、再到播放页。

### `jellyfin_playback`

当前不是完整播放服务模块，而是 **播放页面 + 播放 UI 协议模块**。这个定位可以接受。`PlaybackService` 深度依赖 `jellyfin_dart`，保留在根包并用 `PlaybackDelegate` 包装是合理中间态。

下一步不要急着把 `PlaybackService` 硬搬进包里。优先把播放入口从根包页面编排迁到 App Shell，再评估播放 service 是否适合下沉到 `jellyfin_api`/data adapter。

### `jellyfin_music`

当前完成的是专辑详情、艺术家详情、部分模型和 `AudioPlaybackPort`。音乐主链路仍未完成：`MusicLibraryPage`、`MusicSearchPage`、`LyricsPage`、`AudioPlaybackManager`、`MusicService` 仍在根包。

报告中“Task 15 完成”可以保留，但必须写清楚范围：

```text
Task 15-A 完成：音乐详情子链路抽取
Task 15-B 待办：音乐主库、搜索、歌词、音频播放状态解耦
```

### `jellyfin_ai_recommendation`

模块本身已经解耦，但 TTS 并行开发已经改变依赖结构。建议先同步依赖说明，再决定 TTS 是否留在 AI 包内，还是拆为可选扩展。

---

## 四、给员工的下一步建议

### 第一优先级：补齐 Phase 1-C

下一轮建议先做：

1. Task 8：App Shell
2. Task 9：Auth

原因：现在 `media_libraries_page.dart` 已经承担了 App Shell 的职责。如果继续在根包里接更多 feature，后续再迁 App Shell 会更痛。

### 第二优先级：Task 18 小步收敛

不要等所有事情都做完才清理 facade。建议先做一版小步收敛：

1. 修正 `PHASE2_PROGRESS_REPORT.md` 的 hide 数量和旧文件清理表。
2. 删除边界检查脚本里 adapters 的 feature `src/` 豁免。
3. 给旧模型也加 deprecated 策略，不只旧页面。
4. 为 `lib/jellyfin_service.dart` 的 hide 列表建立清理 issue/task。
5. 跑一次边界检查 + 根包 analyze，确认 deprecated 不影响当前集成。

### 第三优先级：音乐主链路单独立项

建议新增：

```text
Task 15-B：音乐主链路解耦
```

推荐拆分顺序：

1. 让 `MusicLibraryPage` 依赖 `AudioPlaybackPort`，而不是直接依赖 `AudioPlaybackManager`。
2. 把 `MusicSearchPage`、`LyricsPage` 的播放依赖也改成 port。
3. 把 `MusicService` 的 DTO 转换逻辑下沉为 adapter，减少根包模型依赖。
4. 最后再判断是否迁移完整 `MusicLibraryPage` 到 `jellyfin_music`。

### 第四优先级：补集成验证

目前报告里的测试主要是包级测试。下一步至少补 2 条集成级验证：

1. 媒体库 → 电影筛选 → 电影详情 → 播放页
2. 媒体库 → 剧集 → 季 → 集 → 播放页

如果暂时不做 integration test，也要有 smoke test 或手工验证清单。

---

## 五、可以给员工的回复

> Phase 2 的 feature 包抽取整体通过，尤其是 Task 10.5、`PlaybackDelegate`、`AudioPlaybackPort` 这几个补点说明你不是只搬文件，而是在处理真实边界。边界检查脚本跑通，说明 feature 反向依赖根包的问题目前控制住了。
>
> 但报告还有几处要修：hide 数量实际是 18，不是 15；旧文件清理表只覆盖了已替代页面，未拆的音乐主库/搜索/歌词等也要单独列出来；AI 推荐模块的 TTS 新依赖要同步到报告。下一步不要继续往 `media_libraries_page.dart` 塞编排逻辑，优先做 App Shell/Auth，把这个文件承担的模块装配职责迁出去。
>
> 结论：Phase 2 可执行 feature 抽取完成，可以进入下一轮；但下一轮重点不是继续拆更多页面，而是 App Shell、facade 收敛和音乐主链路。

