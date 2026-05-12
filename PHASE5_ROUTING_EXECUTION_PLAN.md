# go_router Unified Routing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a `go_router` based unified routing spine so feature modules navigate through route intents instead of direct page imports.

**Architecture:** `jellyfin_core` owns route names and navigation intents. The root app shell owns the `GoRouter`, implements `AppNavigator`, registers route handlers manually, and injects app dependencies into feature pages. Existing `FeaturePageFactory` remains as a compatibility bridge during migration.

**Tech Stack:** Flutter, Dart, `go_router`, existing `jellyfin_core` module contracts.

---

## File Structure

- Modify: `pubspec.yaml` to add `go_router`.
- Modify: `packages/foundation/jellyfin_core/lib/src/module/navigation_intent.dart` to add `RouteNavigationIntent`.
- Create: `packages/foundation/jellyfin_core/lib/src/module/jellyfin_route_names.dart` for route name constants.
- Modify: `packages/foundation/jellyfin_core/lib/jellyfin_core.dart` to export route names.
- Create: `lib/src/app_shell/go_router_app_navigator.dart` for `AppNavigator` implementation.
- Create: `lib/src/app_shell/jellyfin_go_router.dart` for the manual `GoRoute` table.
- Create: `lib/src/app_shell/jellyfin_app_shell.dart` for `MaterialApp.router`.
- Modify: `lib/src/app_shell/app_session_controller.dart` to add `setSession`.
- Modify: `lib/src/app_shell/app_shell.dart` to export new shell files.
- Modify: `lib/src/ui/pages/media_libraries_page.dart` to accept optional `AppNavigator` and `onLogout`.
- Modify: `example/lib/main.dart` to use `JellyfinAppShell`.
- Create: `test/go_router_app_navigator_test.dart` for protocol tests.

## Task 1: Add Route Protocol

**Files:**
- Create: `packages/foundation/jellyfin_core/lib/src/module/jellyfin_route_names.dart`
- Modify: `packages/foundation/jellyfin_core/lib/src/module/navigation_intent.dart`
- Modify: `packages/foundation/jellyfin_core/lib/jellyfin_core.dart`
- Test: `packages/foundation/jellyfin_core/test/jellyfin_core_test.dart`

- [ ] **Step 1: Add route names**

Create `jellyfin_route_names.dart`:

```dart
abstract final class JellyfinRouteNames {
  static const login = 'auth.login';
  static const libraries = 'libraries.index';
  static const library = 'libraries.detail';
  static const mediaDetail = 'media.detail';
  static const movieDetail = 'movies.detail';
  static const seriesSeasons = 'series.seasons';
  static const seriesEpisodes = 'series.episodes';
  static const playbackVideo = 'playback.video';
  static const musicLibrary = 'music.library';
  static const musicAlbum = 'music.album';
  static const musicArtist = 'music.artist';
  static const musicSearch = 'music.search';
  static const aiRecommend = 'ai.recommend';
  static const profile = 'profile';
}
```

- [ ] **Step 2: Add `RouteNavigationIntent`**

Append to `navigation_intent.dart`:

```dart
class RouteNavigationIntent extends NavigationIntent {
  final String routeName;
  final Map<String, Object?> arguments;

  const RouteNavigationIntent({
    required this.routeName,
    this.arguments = const {},
  });

  T? arg<T>(String key) => arguments[key] as T?;

  @override
  String toString() =>
      'RouteNavigationIntent(routeName: $routeName, args: $arguments)';
}
```

- [ ] **Step 3: Export route names**

Add to `jellyfin_core.dart`:

```dart
export 'src/module/jellyfin_route_names.dart';
```

- [ ] **Step 4: Add tests**

Add tests in `jellyfin_core_test.dart`:

```dart
test('JellyfinRouteNames exposes stable route names', () {
  expect(JellyfinRouteNames.login, 'auth.login');
  expect(JellyfinRouteNames.playbackVideo, 'playback.video');
});

test('RouteNavigationIntent carries route name and arguments', () {
  const intent = RouteNavigationIntent(
    routeName: JellyfinRouteNames.playbackVideo,
    arguments: {'itemId': 'item-1'},
  );

  expect(intent.routeName, JellyfinRouteNames.playbackVideo);
  expect(intent.arg<String>('itemId'), 'item-1');
});
```

- [ ] **Step 5: Verify**

Run:

```powershell
flutter test packages/foundation/jellyfin_core/test/jellyfin_core_test.dart
```

Expected: PASS.

## Task 2: Add Root go_router Shell

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/src/app_shell/go_router_app_navigator.dart`
- Create: `lib/src/app_shell/jellyfin_go_router.dart`
- Create: `lib/src/app_shell/jellyfin_app_shell.dart`
- Modify: `lib/src/app_shell/app_session_controller.dart`
- Modify: `lib/src/app_shell/app_shell.dart`

- [ ] **Step 1: Add dependency**

Run:

```powershell
flutter pub add go_router
```

Expected: `go_router` added to `pubspec.yaml` and lockfile updated.

- [ ] **Step 2: Add `setSession`**

Add to `AppSessionController`:

```dart
void setSession(AppSession session) {
  _currentSession = session;
  notifyListeners();
}
```

- [ ] **Step 3: Implement `GoRouterAppNavigator`**

Create `go_router_app_navigator.dart` with an attachable `GoRouter` adapter. It must implement `push`, `pushIntent`, `replace`, and `pop`.

- [ ] **Step 4: Implement route table**

Create `jellyfin_go_router.dart` with:

```dart
GoRouter createJellyfinGoRouter({
  required AppSessionController sessionController,
  required AppNavigator appNavigator,
});
```

Register `/login`, `/libraries`, `/libraries/:libraryId`, `/ai/recommend`, `/profile`, and `/playback/video/:itemId`.

- [ ] **Step 5: Implement `JellyfinAppShell`**

Create a `StatefulWidget` that owns:

```dart
late final AppSessionController _sessionController;
late final GoRouterAppNavigator _appNavigator;
late final GoRouter _router;
```

Build:

```dart
MaterialApp.router(routerConfig: _router)
```

- [ ] **Step 6: Verify**

Run:

```powershell
flutter pub get
flutter test test/app_shell_test.dart
```

Expected: PASS.

## Task 3: Wire Main Page Into New Navigator

**Files:**
- Modify: `lib/src/ui/pages/media_libraries_page.dart`
- Modify: `example/lib/main.dart`

- [ ] **Step 1: Add optional dependencies to `MediaLibrariesPage`**

Add:

```dart
final AppNavigator? navigator;
final Future<void> Function()? onLogout;
```

- [ ] **Step 2: Route AI/profile/logout through protocol when available**

When `navigator != null`, use:

```dart
widget.navigator!.push(JellyfinRouteNames.aiRecommend);
widget.navigator!.push(JellyfinRouteNames.profile);
await widget.onLogout?.call();
```

Keep legacy fallback for existing direct usage.

- [ ] **Step 3: Route media library tap through protocol when available**

Use:

```dart
widget.navigator!.push(
  JellyfinRouteNames.library,
  arguments: {'libraryId': library.id, 'library': library},
);
```

- [ ] **Step 4: Use `JellyfinAppShell` in example**

Replace `MaterialApp(home: LoginPage())` with:

```dart
return JellyfinAppShell(
  title: 'Jellyfin Example',
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    useMaterial3: true,
  ),
);
```

- [ ] **Step 5: Verify**

Run:

```powershell
flutter test
dart scripts/check_module_boundaries.dart
```

Expected: PASS.

## Task 4: Employee Follow-Up Migration

**Files:**
- Modify gradually: root UI pages that still call `Navigator.push`.
- Modify gradually: feature pages that still receive direct navigation callbacks.
- Add tests per migrated route.

- [ ] **Step 1: Fix analyze blocker**

Fix or delete `lib/src/ui/pages/seasons_page.dart` so `dart analyze lib test` no longer fails on missing `EpisodesPage`.

- [ ] **Step 2: Migrate old `Navigator.push` calls**

For each old direct push, replace target page construction with either:

```dart
widget.navigator?.push(JellyfinRouteNames.mediaDetail, arguments: {'itemId': id});
```

or a callback that emits `RouteNavigationIntent`.

- [ ] **Step 3: Add structural grep check**

Add checks to `scripts/check_module_boundaries.dart` to report root UI pages still using direct cross-module `MaterialPageRoute`.

- [ ] **Step 4: Verify**

Run:

```powershell
flutter test
dart scripts/check_module_boundaries.dart
dart analyze lib test
```

Expected: tests and boundary checks pass; analyze has no error.

