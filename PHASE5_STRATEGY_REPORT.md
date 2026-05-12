# Phase 5 统一路由协议评审与下一阶段策略报告

评审对象：`PHASE5_PROGRESS_REPORT.md` 及当前代码实现  
评审时间：2026-05-12  
结论级别：Phase 5 主干方向正确，可以作为后续模块路由解耦的基础；但当前只能认定为“统一路由协议与 go_router 主壳已建立”，不能认定为“业务路由迁移完成”。

---

## 1. 总体结论

员工本阶段做对了最关键的一件事：没有让 feature 模块直接依赖 `go_router`，而是把 `go_router` 放在根包 AppShell 层，由 `jellyfin_core` 暴露稳定的路由协议。

当前形成的依赖方向是正确的：

```text
feature modules
  -> jellyfin_core
      -> AppNavigator / NavigationIntent / JellyfinRouteNames

root package
  -> go_router
  -> GoRouterAppNavigator
  -> JellyfinAppShell
  -> concrete pages / module adapters
```

这符合我们之前讨论的目标：类似鸿蒙 ZRouter 的“统一路由协议”，业务模块只发起一个语义化导航请求，不直接知道目标页面是谁创建的，也不直接依赖 `go_router`。

但是，当前实现仍处在“路由主干搭建完成 + 首批页面接入”的阶段。代码里还有大量 `MaterialPageRoute`，`PHASE5_PROGRESS_REPORT.md` 中“Task 4 完成”的表述偏乐观，需要改成“Task 4 完成迁移准备，业务页面迁移未完成”。

---

## 2. 已完成内容评价

### 2.1 `jellyfin_core` 的协议层设计是正确的

已新增：

- `JellyfinRouteNames`
- `RouteNavigationIntent`
- `AppNavigator.pushIntent`

这部分是 Phase 5 最有价值的产物。它让业务模块可以这样表达跳转：

```dart
navigator.pushIntent(
  RouteNavigationIntent(
    JellyfinRouteNames.library,
    arguments: {'libraryId': libraryId},
  ),
);
```

而不是：

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => SomePage()),
);
```

设计意义不是“多封装一层”，而是把页面构造权从业务模块收回到根包路由表。这样后面拆电影、剧集、AI 推荐、播放页时，模块之间不会互相 import 页面。

### 2.2 根包 `go_router` 适配层位置正确

当前 `GoRouterAppNavigator` 放在根包 `lib/src/app_shell/`，而不是放进 `jellyfin_core`，这个方向是对的。

原因：

- `jellyfin_core` 不应该依赖 Flutter 路由实现细节。
- feature 模块不应该知道 `go_router`。
- `go_router` 是 App 组装层的技术选型，将来即使换 AutoRoute、Beamer 或自研路由，也不应该影响 feature 包。

这正是“统一路由协议”的核心。

### 2.3 `JellyfinAppShell` 已经具备应用级路由主壳

当前主壳已经做了几件正确的事：

- 使用 `MaterialApp.router`
- 由 `AppSessionController` 驱动登录态
- 使用 `go_router` redirect 处理登录页与主页跳转
- 将 `GoRouterAppNavigator` 注入页面

这说明 Phase 5 的基础框架已经搭起来了，后续员工可以在这个框架内做机械迁移。

### 2.4 `MediaLibrariesPage` 的过渡方式可以接受

`MediaLibrariesPage` 同时支持：

- 新路径：通过 `AppNavigator` 发起命名路由跳转
- 老路径：没有 navigator 时继续用 `Navigator.push`

这在迁移期是合理的。它允许 example 和旧调用方不被一次性打断。

但这只能是过渡状态。最终目标应该是：

- 根包 AppShell 路径全部走 `AppNavigator`
- feature 模块内部不再直接构造跨业务页面
- 老的 `Navigator.push` 只保留在局部页面内部流程，或者完全清理

---

## 3. 当前报告中需要修正的地方

### 3.1 “Task 4 完成”需要降级表述

`PHASE5_PROGRESS_REPORT.md` 中提到 Task 4 已完成，但边界脚本已经报告仍有 41 处 `MaterialPageRoute` 使用。

这说明当前状态不是“迁移完成”，而是：

```text
统一路由主干完成；
首个业务入口 MediaLibrariesPage 已接入；
存量页面迁移清单已暴露；
后续需要逐步把跨模块跳转迁移到统一路由协议。
```

建议员工修改报告措辞，避免后续误判进度。

### 3.2 Rule 7 目前只是提示，不是边界约束

`scripts/check_module_boundaries.dart` 当前会报告 `MaterialPageRoute` 使用，但不会失败。

这适合第一阶段盘点，但不适合作为长期架构守门。

建议下一阶段改成“基线守卫”：

```dart
const materialPageRouteBaseline = 41;

if (materialPageRouteUsages.length > materialPageRouteBaseline) {
  hasErrors = true;
  print('新增 MaterialPageRoute 使用，必须改用 AppNavigator 或说明豁免原因');
}
```

更好的做法是维护 allowlist，只允许局部页面内部流程继续使用 `MaterialPageRoute`，跨业务模块跳转一律禁止。

### 3.3 `dart analyze lib test` 的结果描述不够准确

当前 analyze 确实没有 error，但仍然有 warnings/info，并且命令返回非零退出码。

报告中写“232 warnings/info 均为 deprecated 使用”不准确。当前问题还包括：

- `unused_import`
- `unused_element`
- `unnecessary_non_null_assertion`
- `unnecessary_type_check`

建议报告改成：

```text
dart analyze lib test：0 errors，但仍有 warnings/info，命令返回非零。
本阶段未清理全部历史 lint，后续应逐步降低数量。
```

### 3.4 `jellyfin_core` 测试命令需要写清楚工作目录

报告中写：

```text
dart test packages/foundation/jellyfin_core/test/jellyfin_core_test.dart
```

这个命令如果从根目录执行并不准确。正确写法应是：

```powershell
Push-Location packages/foundation/jellyfin_core
dart test
Pop-Location
```

或者在 CI 中单独进入 package 执行。

---

## 4. 当前代码的主要架构问题

### P1：路由表只覆盖了少量页面，协议名多于实际路由

`JellyfinRouteNames` 中已经定义了 14 个路由名，但 `createJellyfinGoRouter` 当前只落了部分路由。

这不是错误，但需要明确为“协议先行”。下一阶段要把这些 route name 逐步落到真实页面：

- `movieDetail`
- `mediaDetail`
- `seriesSeasons`
- `seriesEpisodes`
- `musicLibrary`
- `musicAlbum`
- `musicArtist`
- `musicSearch`

否则业务模块虽然能引用 route name，但实际跳转会在运行时失败。

### P1：缺少 go_router 行为测试

目前测试主要覆盖了 `jellyfin_core` 的协议对象，缺少根包路由行为测试。

必须补的测试：

- 未登录访问 `/libraries` 是否重定向到 `/login`
- 登录后访问 `/login` 是否重定向到 `/libraries`
- `JellyfinRouteNames.library` 是否正确转换为 `/libraries/:libraryId`
- `JellyfinRouteNames.playbackVideo` 缺少 `itemId` 时是否有明确错误
- `RouteNavigationIntent` 是否能通过 `GoRouterAppNavigator` 到达目标 route

建议为了测试方便，给 `createJellyfinGoRouter` 增加可选参数：

```dart
GoRouter createJellyfinGoRouter({
  required AppSessionController sessionController,
  required GoRouterAppNavigator navigator,
  String initialLocation = '/login',
})
```

这样测试可以直接从 `/libraries`、`/playback/video/xxx` 等位置启动。

### P1：`GenericNavigationIntent.action` 直接当 route name 有运行时风险

`GoRouterAppNavigator.pushIntent` 当前兼容了 `GenericNavigationIntent`：

```dart
return push(intent.action, args: intent.arguments);
```

这个兼容性有用，但也有隐患：老的 action 字符串不一定是合法 route name，出错会发生在运行时。

建议下一阶段收敛策略：

- 新代码必须使用 `RouteNavigationIntent`
- `GenericNavigationIntent` 只保留给历史代码
- 对历史 action 建立显式映射表，而不是默认当 route name

示例：

```dart
static const _legacyActionToRouteName = {
  'open_library': JellyfinRouteNames.library,
  'open_ai_recommend': JellyfinRouteNames.aiRecommend,
};
```

### P2：`extra` 只能作为优化，不应成为深链必需数据

当前 `/libraries/:libraryId` 可以从 `state.extra` 里取完整 `BaseItemDto`，也可以通过 id 再加载。这个方向是对的。

但后续所有路由都要遵守一条规则：

```text
URL path/query 中的信息必须足够恢复页面；
extra 只能用于减少一次请求，不能作为页面可用性的前提。
```

否则外部链接、浏览器刷新、冷启动恢复都会失效。

### P2：`FeaturePageFactory` 仍是过渡桥，不应继续扩张

当前 `/libraries/:libraryId` 和 `/ai/recommend` 仍通过 `FeaturePageFactory` 构造页面。

迁移期可以接受，因为它避免一次性大改。但下一阶段不要继续往 `FeaturePageFactory` 里加新业务。正确方向是：

- 路由表直接绑定稳定页面入口
- feature 包暴露页面构建入口或 route registrar
- 根包负责把 route name、path、页面 builder 组装起来

也就是说，`FeaturePageFactory` 应该逐步缩水，而不是继续变成新的大中台。

---

## 5. 下一阶段建议：把 Phase 5 拆成 5B / 5C

### Phase 5B：完成核心业务跳转迁移

目标：把跨业务模块跳转全部迁到统一路由协议。

优先级建议：

1. 详情页跳播放页
2. 电影列表跳电影详情
3. 剧集详情跳季列表
4. 季列表跳集列表
5. 集列表跳播放页
6. 媒体库跳音乐库、音乐专辑、音乐艺术家
7. AI 推荐页跳详情页或播放页

员工执行方式：

- 每次只迁一类跳转
- 先在 `JellyfinRouteNames` 确认 route name
- 再在 `jellyfin_go_router.dart` 补 route
- 最后把页面里的 `Navigator.push(MaterialPageRoute(...))` 改成 `AppNavigator.push(...)`
- 每迁完一类，运行边界脚本，确保 `MaterialPageRoute` 数量下降

### Phase 5C：建立路由边界守卫

目标：不再允许新增跨业务 `MaterialPageRoute`。

建议修改 `scripts/check_module_boundaries.dart`：

1. 记录当前 `MaterialPageRoute` 基线数量
2. 新增数量超过基线时失败
3. 给允许保留的局部页面跳转写 allowlist
4. 报告中区分：
   - 跨模块跳转，必须迁移
   - 模块内部页面流，可以暂缓
   - Flutter 内部弹窗/临时页面，允许豁免

### Phase 5D：移除旧兼容入口

当根包路由覆盖主要业务后，再做清理：

- `LoginPage` 默认 fallback 到 `MediaLibrariesPage` 的逻辑降级为 example-only
- `MediaLibrariesPage` 中无 `navigator` 时的旧跳转 fallback 删除或迁入 demo
- `FeaturePageFactory` 只保留短期兼容入口，最终迁出主链路

---

## 6. 给员工的具体任务清单

### 任务 1：修正 `PHASE5_PROGRESS_REPORT.md`

需要改：

- Task 4 状态改为“迁移准备完成，业务迁移未完成”
- `dart analyze` 结果描述改为“0 errors，但仍有 warnings/info，命令返回非零”
- `jellyfin_core` 测试命令写明工作目录
- 明确 41 处 `MaterialPageRoute` 是下一阶段迁移清单，不是已解决问题

### 任务 2：补路由行为测试

建议新增测试文件：

```text
test/app_shell/go_router_app_navigator_test.dart
test/app_shell/jellyfin_go_router_test.dart
```

至少覆盖：

- 登录态 redirect
- route name 到 path 参数映射
- 缺少必填参数时抛出明确异常
- `RouteNavigationIntent` 可以完成一次真实跳转

### 任务 3：把 `MaterialPageRoute` 清单分类

把 41 处使用分成三类：

```text
A. 跨业务模块跳转：必须迁移
B. 模块内部流程跳转：可以暂缓
C. 弹窗、临时页、测试代码：允许豁免或单独处理
```

只有 A 类是 Phase 5B 必须完成的内容。

### 任务 4：优先迁移播放链路

播放链路是最值得先迁的，因为它天然会被电影、剧集、AI 推荐等多个模块调用。

目标调用方式：

```dart
await navigator.push(
  JellyfinRouteNames.playbackVideo,
  args: {
    'itemId': itemId,
    'title': title,
  },
);
```

业务模块不应该 import 播放页，也不应该知道播放页构造函数。

### 任务 5：迁移详情链路

详情页是第二优先级。

建议先统一为：

```dart
JellyfinRouteNames.mediaDetail
JellyfinRouteNames.movieDetail
JellyfinRouteNames.seriesSeasons
JellyfinRouteNames.seriesEpisodes
```

不要让电影模块直接 import 剧集页面，也不要让 AI 推荐模块直接 import 电影详情页。

---

## 7. 设计改动建议

### 7.1 给 `createJellyfinGoRouter` 增加测试友好参数

建议调整：

```dart
GoRouter createJellyfinGoRouter({
  required AppSessionController sessionController,
  required GoRouterAppNavigator navigator,
  String initialLocation = '/login',
})
```

然后：

```dart
return GoRouter(
  initialLocation: initialLocation,
  refreshListenable: sessionController,
  redirect: ...,
  routes: ...,
);
```

这样测试不需要通过复杂操作才能进入目标页面。

### 7.2 给 `RouteNavigationIntent` 增加命名构造或 helper

现在业务侧仍需要手写 `arguments` key，后续容易写错。

可以增加轻量 helper，不要引入复杂 factory：

```dart
class JellyfinRouteIntents {
  const JellyfinRouteIntents._();

  static RouteNavigationIntent playbackVideo(String itemId) {
    return RouteNavigationIntent(
      JellyfinRouteNames.playbackVideo,
      arguments: {'itemId': itemId},
    );
  }

  static RouteNavigationIntent library(String libraryId, {Object? library}) {
    return RouteNavigationIntent(
      JellyfinRouteNames.library,
      arguments: {
        'libraryId': libraryId,
        if (library != null) 'library': library,
      },
    );
  }
}
```

这不是后端式 Factory，而是路由协议的类型安全辅助层。它可以减少字符串参数错误。

### 7.3 路由参数规则要写进设计文档

建议补充到 `PHASE5_ROUTING_DESIGN.md`：

```text
1. path 参数用于页面身份，例如 itemId、libraryId、seasonId。
2. query 参数用于可分享的展示状态，例如 tab、sort、filter。
3. extra 只用于传递已有对象，不能作为页面恢复的唯一数据源。
4. feature 模块只能依赖 JellyfinRouteNames / RouteNavigationIntent / AppNavigator。
5. feature 模块不得 import go_router，也不得 import 其他 feature 的页面。
```

---

## 8. 本阶段验收口径

我建议把 Phase 5 当前验收结论写成：

```text
通过，带后续动作。
```

原因：

- 统一路由协议方向正确。
- `go_router` 被限制在根包 AppShell，依赖方向正确。
- `jellyfin_core` 承担协议层职责，边界清晰。
- example 已切到 `JellyfinAppShell`，说明主路径能跑起来。
- 但业务页面迁移不完整，不能关闭路由解耦主题。
- 测试覆盖还没有覆盖 go_router 行为，存在回归风险。

下一阶段不要再讨论“要不要统一路由”，这个问题已经明确：要。  
下一阶段只需要执行迁移、补测试、设边界守卫。

---

## 9. 给负责人的建议

建议把员工下一步目标写得非常具体：

```text
不要继续扩设计。
先把 41 处 MaterialPageRoute 分类。
优先迁移播放链路和详情链路。
每迁移一类，MaterialPageRoute 数量必须下降，或者写明为什么保留。
go_router 只能留在根包 app_shell。
feature 模块只能使用 jellyfin_core 暴露的 AppNavigator + RouteNavigationIntent。
```

这套方向能避免两个常见偏差：

1. 把 `go_router` 扩散到每个 feature 模块，导致新一轮耦合。
2. 把 `FeaturePageFactory` 做成新的万能中心，形式上模块化，实际上只是换了一个耦合点。

真正的目标是：业务模块只说“我要去哪里”，根包路由表决定“谁来创建页面”。

