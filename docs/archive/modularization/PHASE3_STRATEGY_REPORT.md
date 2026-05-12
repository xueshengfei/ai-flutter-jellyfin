# Phase 3 模块化改造评估与下一阶段建议

> 对应进展报告：`PHASE3_PROGRESS_REPORT.md`
> 评估日期：2026-05-12
> 评估方式：阅读 Phase 3 报告，抽查 `scripts/check_module_boundaries.dart`、`lib/jellyfin_service.dart`、`lib/src/ui/pages/media_libraries_page.dart`、`lib/src/adapters/media_item_mapper.dart`、旧页面/旧模型 deprecated 标记、`AudioPlaybackPort` 与 `AudioPlaybackManager` 实现。

---

## 一、评估结论

Phase 3 这一轮可以评价为：**完成了 Phase 2 后的第一轮收敛补丁，但还没有完成真正的 App Shell 化。**

员工这轮做对了几件重要的事：

- 把 `hide` 数量口径从 15 修正为 18。
- 补全旧页面清理分类。
- 收紧边界检查脚本，根包也不能 import feature `src/`。
- 旧页面和旧模型都加了 `@Deprecated` 标记。
- `jellyfin_music` 新增 `AudioPlaybackPort`，根包 `AudioPlaybackManager` 已实现该接口。
- 边界检查脚本执行通过。

这说明模块化改造已经从“拆包”进入“治理边界”的阶段，是正确方向。

但当前最大问题也很清楚：**根包的 `media_libraries_page.dart` 已经成为事实上的 App Shell。** 它现在负责：

- 构建电影、媒体、剧集、播放、音乐页面。
- 持有 `JellyfinClient`。
- 做 root model 与 shared/feature model 的转换。
- 创建 `PlaybackDelegate`。
- 注入所有 feature 回调。
- 继续跳转根包未迁移页面，例如 `MusicLibraryPage`、`PersonalPage`、`LoginPage`。

因此下一阶段不能继续往这个文件里堆逻辑。下一阶段方向应当是：

> 建立 App Shell / Route Composer / Adapter 层，把 `media_libraries_page.dart` 的模块装配职责迁出去。

---

## 二、关键发现

### P1：`media_libraries_page.dart` 已经过度承担编排职责

这是当前最高优先级风险。Phase 2/3 的所有好边界，最终都在这个文件里重新聚合了。短期能跑，但长期会变成新的大泥团。

典型表现：

```dart
Widget _buildNewMovieFilterPage(MediaLibrary library) { ... }
Widget _buildNewMovieDetailPage(models.MediaItem item) { ... }
Widget _buildNewMediaItemDetailPage(models.MediaItem item) { ... }
Widget _buildNewEpisodesPage(models.MediaItem series, models.Season season) { ... }
playback.PlaybackDelegate _createPlaybackDelegate(local.MediaItem localItem) { ... }
Widget _buildNewAlbumDetailPage(music.MusicAlbum album) { ... }
Widget _buildNewArtistDetailPage(music.MusicArtist artist) { ... }
```

这些方法不应该长期属于媒体库页面。它们应该迁到 App Shell 的 module composer 或 route factory 中。

### P1：Phase 3 报告内部状态有轻微不一致

报告第三节说 Task 18-B 已完成，但第四节“Leader 指出的下一步方向”仍把 adapters 豁免移除、旧模型 deprecated、`dart analyze` 标成待做。代码里看，脚本已经移除豁免，旧模型也已经 deprecated。

建议员工把第四节更新为“已完成/待继续”的最新状态，避免读者误判。

### P1：音乐主链路还没有完成模块化

`AudioPlaybackPort` 是正确第一步，但它只是播放接口层。音乐核心仍在根包：

- `MusicLibraryPage`
- `MusicSearchPage`
- `LyricsPage`
- `MusicService`
- `AudioPlaybackManager`

现在可以称为：

```text
Task 15-A：音乐详情页与播放接口抽象完成
Task 15-B：音乐主链路解耦待开始
```

不要把当前状态描述为完整 `jellyfin_music` 模块完成。

### P2：旧页面 deprecated 做得好，但清理策略还需要可执行

当前已经标记了 11 个旧页面和多个旧模型，这是好事。下一步需要把 deprecated 从“提醒”变成“可清理计划”。

建议为每个旧入口记录：

- 当前仍有哪些文件引用它。
- 何时迁移。
- 迁移后删除哪个 export。
- 对应 hide 能否移除。

### P2：边界脚本已经能守住 feature 反向依赖，但还可以扩展

当前脚本检查：

- feature import 根包。
- feature import 其他 feature `src/`。
- 根包 import feature `src/`。

建议下一步新增：

- 禁止 `shared` import `features`。
- 禁止 `foundation` import `shared/features`，除非明确白名单。
- 检查根 `lib/jellyfin_service.dart` 的 `hide` 数量是否超过阈值。
- 检查 feature public API 是否暴露 `jellyfin_dart` 类型名。

---

## 三、阶段任务评价

### Task 18-A：小步收敛

评价：通过。

边界检查脚本已经跑通，旧页面 deprecated 也已经落到代码里。这个任务达到了治理目标。

建议补充：

- 把 `check_module_boundaries.dart` 加入统一验证脚本，例如 `scripts/verify_integration.sh`。
- 在报告中贴出最新脚本输出或命令摘要。

### Task 15-A：`AudioPlaybackPort`

评价：方向正确，但只是音乐解耦的第一刀。

优点：

- `AudioTrack` 避免 feature 直接绑定根包 `MusicSong`。
- `AudioPlaybackPort` 让页面可以依赖抽象播放器。
- `AudioPlaybackManager implements AudioPlaybackPort` 证明旧实现可以作为 adapter。

风险：

- `AudioPlaybackPort extends ChangeNotifier` 把 Flutter UI 状态机制带进接口层。这对 Flutter feature 包可以接受，但未来如果想做纯 Dart domain，会有一点耦合。
- `AudioTrack.streamUrl` 是必填，这要求调用方在播放前已经能生成 stream URL。若后续播放地址需要鉴权、刷新 token 或按平台选择流，可能需要改成 `AudioTrackRequest` + resolver。

短期不需要推翻，但下一阶段要注意。

### Task 18-B：旧模型 deprecated + 接口扩展

评价：可接受。

旧模型加 deprecated 是必要动作。`AudioPlaybackPort` 补齐 loading/error/playMode/position stream 也符合 `MusicLibraryPage` 迁移需求。

建议：

- 把 deprecated 的旧模型分成“已替代可迁移”和“仍作为 adapter 中间态”的两类。
- 不要因为 deprecated info 太多就忽略 analyze，后面需要按包逐步消除。

---

## 四、下一阶段方向

建议下一阶段命名为：

```text
Phase 4：App Shell 与兼容层收敛
```

目标不是继续拆更多页面，而是把已经拆出来的 feature 通过 App Shell 正式组装起来，让根包从“页面/服务聚合体”退到“兼容 facade”。

### Phase 4-A：建立 App Shell

目标：

- 新建正式 `apps/jellyfin_app` 或 `lib/src/app_shell/` 过渡层。
- 把 `media_libraries_page.dart` 中的 `_buildNewXxxPage()` 方法迁到 shell/router/composer。
- 让页面只负责展示媒体库列表，不负责知道所有 feature 的构造细节。

建议文件结构：

```text
apps/jellyfin_app/
  lib/
    main.dart
    src/
      app.dart
      shell/
        jellyfin_app_shell.dart
        app_route_composer.dart
        module_adapters.dart
      session/
        app_session.dart
      routing/
        app_routes.dart
```

如果暂时不建 `apps/`，也可以先在根包建过渡目录：

```text
lib/src/app_shell/
  app_route_composer.dart
  app_module_context.dart
  feature_page_factory.dart
```

### Phase 4-B：Auth 独立闭环

目标：

- `LoginPage` 不再直接 new/持有后续首页页面。
- 登录成功后交给 App Shell 保存 session 并进入 home。
- 为 Task 11 `jellyfin_home` 解锁。

### Phase 4-C：Facade 清理第一轮

目标：

- 移除已经无实际引用的旧页面 export。
- 降低 `hide` 数量。
- 建立 deprecated 清理进度表。

### Phase 4-D：音乐主链路

目标：

- `MusicLibraryPage` 改依赖 `AudioPlaybackPort`。
- `MusicSearchPage`、`LyricsPage` 改依赖 port。
- 再评估是否把 `MusicLibraryPage` 迁入 `jellyfin_music`。

---

## 五、建议设计改动与代码示例

以下代码是建议方向，不要求一次性照搬。重点是把 App Shell、adapter、route composer 的边界定下来。

### 1. App Session

把 `JellyfinClient` 和当前用户放入 session，而不是让各页面层层传。

```dart
class AppSession {
  final JellyfinClient client;
  final UserProfile user;

  const AppSession({
    required this.client,
    required this.user,
  });

  String get serverUrl => client.configuration.serverUrl;
  String? get accessToken => client.configuration.accessToken;
}
```

### 2. Feature Page Factory

把 `media_libraries_page.dart` 里的页面构造迁出去。

```dart
class FeaturePageFactory {
  final AppSession session;

  const FeaturePageFactory(this.session);

  Widget movieFilterPage(MediaLibrary library) {
    return movies_pages.MovieFilterPage(
      libraryId: library.id,
      libraryName: library.name,
      fetchMovies: _fetchMovies,
      onNavigateToMovie: (context, item) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => movieDetailPage(item)),
        );
      },
      listBuilder: _buildMovieList,
    );
  }

  Future<movies.MovieFilterResult> _fetchMovies(movies.MovieFilter filter) async {
    final rootFilter = MovieFilterAdapter.toRoot(filter);
    final result = await session.client.mediaLibrary.getMovies(rootFilter);

    return movies.MovieFilterResult(
      movies: result.items
          .map((item) => MediaItemMapper.toShared(
                item,
                serverUrl: session.serverUrl,
                accessToken: session.accessToken,
              ))
          .toList(),
      totalCount: result.totalCount,
      startIndex: result.startIndex,
    );
  }
}
```

### 3. Movie Filter Adapter

`_convertMovieFilter()` 不应长期留在页面类里，建议迁成 adapter。

```dart
class MovieFilterAdapter {
  static root.MovieFilter toRoot(movies.MovieFilter filter) {
    return root.MovieFilter(
      parentId: filter.parentId,
      startIndex: filter.startIndex,
      limit: filter.limit,
      genres: filter.genres,
      tags: filter.tags,
      years: filter.years,
      nameStartsWith: filter.nameStartsWith,
      studios: filter.studios,
      productionLocations: filter.productionLocations,
      minCommunityRating: filter.minCommunityRating,
      isHD: filter.isHD,
      is4K: filter.is4K,
      recursive: filter.recursive,
      filters: filter.isUnplayed == true
          ? const [jellyfin_dart.ItemFilter.isUnplayed]
          : null,
      sortBy: filter.sortBy?.map(_sortField).toList(),
      sortOrder: filter.sortOrder?.map(_sortOrder).toList(),
    );
  }

  static jellyfin_dart.ItemSortBy _sortField(movies.MovieSortField field) {
    return switch (field) {
      movies.MovieSortField.dateCreated => jellyfin_dart.ItemSortBy.dateCreated,
      movies.MovieSortField.sortName => jellyfin_dart.ItemSortBy.sortName,
      movies.MovieSortField.productionYear => jellyfin_dart.ItemSortBy.productionYear,
      movies.MovieSortField.premiereDate => jellyfin_dart.ItemSortBy.premiereDate,
      movies.MovieSortField.random => jellyfin_dart.ItemSortBy.random,
      movies.MovieSortField.communityRating => jellyfin_dart.ItemSortBy.communityRating,
    };
  }

  static jellyfin_dart.SortOrder _sortOrder(movies.MovieSortOrder order) {
    return switch (order) {
      movies.MovieSortOrder.ascending => jellyfin_dart.SortOrder.ascending,
      movies.MovieSortOrder.descending => jellyfin_dart.SortOrder.descending,
    };
  }
}
```

### 4. Playback Delegate Factory

`_createPlaybackDelegate()` 也不应长期留在页面类里。

```dart
class PlaybackDelegateFactory {
  final JellyfinClient client;

  const PlaybackDelegateFactory(this.client);

  playback.PlaybackDelegate create(local.MediaItem item) {
    final service = PlaybackService(client: client)..setCurrentItem(item);

    return playback.PlaybackDelegate(
      getPlaybackUrl: ({required itemId, startTimeTicks, maxStreamingBitrate}) async {
        final info = await service.getPlaybackUrl(
          itemId: itemId,
          startTimeTicks: startTimeTicks,
          maxStreamingBitrate: maxStreamingBitrate,
        );
        return _toPlaybackInfo(info);
      },
      startSession: ({required itemId, required sessionIds}) {
        return service.startPlaybackSession(itemId: itemId, sessionIds: sessionIds);
      },
      switchQuality: ({required itemId, required quality, required currentPosition}) async {
        final info = await service.switchQuality(
          itemId: itemId,
          quality: _toRootQuality(quality),
          currentPosition: currentPosition,
        );
        return _toPlaybackInfo(info);
      },
      stopEncoding: service.stopActiveEncodings,
      stopSession: service.stopPlaybackSession,
      dispose: service.dispose,
    );
  }

  playback.PlaybackInfo _toPlaybackInfo(root.PlaybackInfo info) {
    return playback.PlaybackInfo(
      url: info.url,
      playSessionId: info.playSessionId,
      isTranscoded: info.isTranscoded,
      actualBitrate: info.actualBitrate,
    );
  }

  root.VideoQuality _toRootQuality(playback.VideoQuality quality) {
    return root.VideoQuality.values.firstWhere((q) => q.name == quality.name);
  }
}
```

### 5. Music Playback Adapter

`MusicLibraryPage` 后续应依赖 `AudioPlaybackPort`。

```dart
class MusicPlaybackAdapter {
  final music.AudioPlaybackPort playback;

  const MusicPlaybackAdapter(this.playback);

  Future<void> playSongs(
    List<music.MusicSong> songs,
    int startIndex,
  ) {
    final tracks = songs.map(_toTrack).toList();
    return playback.playSong(tracks[startIndex], tracks, startIndex);
  }

  music.AudioTrack _toTrack(music.MusicSong song) {
    return music.AudioTrack(
      id: song.id,
      name: song.name,
      streamUrl: song.getStreamUrl(),
      coverUrl: song.getCoverImageUrl(),
      artistText: song.artistName,
      albumName: song.albumName,
      trackNumber: song.trackNumber,
      isFavorite: song.isFavorite,
      duration: song.runTimeSeconds != null
          ? Duration(seconds: song.runTimeSeconds!)
          : null,
    );
  }
}
```

### 6. Media Libraries Page 简化目标

最终 `MediaLibrariesPage` 应只保留页面职责。

```dart
class MediaLibrariesPage extends StatefulWidget {
  final AppSession session;
  final FeaturePageFactory pages;

  const MediaLibrariesPage({
    super.key,
    required this.session,
    required this.pages,
  });
}
```

点击媒体库时只分派：

```dart
void _openLibrary(MediaLibrary library) {
  final page = widget.pages.pageForLibrary(library);
  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}
```

### 7. 边界检查脚本增强

建议新增 shared/foundation 规则。

```dart
void checkSharedDoesNotImportFeatures(File file, List<String> lines) {
  for (var i = 0; i < lines.length; i++) {
    final match = RegExp(r'''import\s+['"]package:(jellyfin_\w+)/''')
        .firstMatch(lines[i]);
    if (match == null) continue;

    final packageName = match.group(1)!;
    final isFeature = Directory('packages/features/$packageName').existsSync();
    if (isFeature) {
      throw BoundaryViolation(
        file: file.path,
        line: i + 1,
        message: 'shared 包禁止 import feature 包：$packageName',
      );
    }
  }
}
```

### 8. 集成 smoke test 伪代码

建议先从 widget/smoke 层建立两个链路测试。

```dart
testWidgets('movies flow opens playback through shell factory', (tester) async {
  final fakeSession = FakeAppSession.withMovieLibrary();
  final pages = FeaturePageFactory(fakeSession);

  await tester.pumpWidget(TestApp(
    child: MediaLibrariesPage(
      session: fakeSession,
      pages: pages,
    ),
  ));

  await tester.tap(find.text('电影'));
  await tester.pumpAndSettle();

  expect(find.byType(movies_pages.MovieFilterPage), findsOneWidget);

  await tester.tap(find.text('测试电影'));
  await tester.pumpAndSettle();

  expect(find.byType(movies_pages.MovieDetailPage), findsOneWidget);

  await tester.tap(find.text('播放'));
  await tester.pumpAndSettle();

  expect(find.byType(playback_pages.VideoPlayerPage), findsOneWidget);
});
```

---

## 六、下一阶段任务拆分

### Task 20：App Shell 过渡层

目标：把 `media_libraries_page.dart` 中的 feature 页面构建迁出。

交付：

- `AppSession`
- `FeaturePageFactory`
- `PlaybackDelegateFactory`
- `MovieFilterAdapter`
- `MusicPlaybackAdapter`

验收：

- `media_libraries_page.dart` 行数明显下降。
- 不再包含 `_buildNewMovieFilterPage`、`_createPlaybackDelegate` 等方法。
- 原有测试通过。

### Task 21：Auth + Login Shell 化

目标：登录成功后不直接跳根包首页，由 App Shell 接管 session。

交付：

- `AppSessionController`
- `LoginResultHandler`
- Auth 页面下一步拆包设计。

### Task 22：音乐主链路解耦

目标：让音乐主库、搜索、歌词依赖 `AudioPlaybackPort`。

交付：

- `MusicLibraryPage` 注入 `AudioPlaybackPort`
- `MusicSearchPage` 注入 `AudioPlaybackPort`
- `LyricsPage` 注入 `AudioPlaybackPort`
- 根包 `AudioPlaybackManager` 只作为实现注入

### Task 23：Facade 清理第一轮

目标：减少 `lib/jellyfin_service.dart` 的 hide/export 压力。

交付：

- hide 清理列表。
- 删除无引用旧页面 export。
- deprecated 使用统计。
- 边界检查脚本进入统一验证流程。

---

## 七、建议给员工的回复

可以这样反馈员工：

> Phase 3 的方向是对的：你已经把 Phase 2 的几个治理缺口补上了，尤其是旧页面/旧模型 deprecated、边界检查脚本收紧、`AudioPlaybackPort` 和 `AudioPlaybackManager implements`，这些都说明边界开始真正收住。
>
> 但现在最大的风险已经从 feature 包内部转移到根包编排层。`media_libraries_page.dart` 正在承担 App Shell、router、adapter、delegate factory 的全部职责，下一步不要继续往这个文件加东西。请把下一轮重点放在 App Shell 过渡层，把页面构建、模型转换、播放委托工厂迁出去。
>
> 音乐模块也请拆成 Task 15-A / 15-B 两个口径：现在完成的是音乐详情子链路和播放接口抽象，音乐主库、搜索、歌词、`MusicService` 仍是待解耦任务。
>
> 下一阶段建议优先做 Task 20 App Shell 过渡层，其次做 Auth/Login Shell 化，再做音乐主链路和 facade 清理。

---

## 八、最终判断

Phase 3 可以通过，但通过条件是：

1. 承认它是 **治理补丁阶段完成**，不是 App Shell 完成。
2. 下一阶段必须迁走 `media_libraries_page.dart` 的装配职责。
3. 音乐主链路不能继续以“已完成”口径混在 Task 15 里。
4. 边界检查脚本应进入常规验证流程。

如果下一阶段继续在根包页面里拼装 feature，前面拆出的模块会逐渐被根包重新耦合；如果下一阶段建立 Shell/Factory/Adapter 层，这次模块化改造就会真正进入可维护状态。
