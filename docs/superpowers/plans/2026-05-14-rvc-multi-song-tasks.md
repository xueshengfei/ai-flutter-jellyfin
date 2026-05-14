# RVC Multi Song Tasks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let each song keep its own in-memory RVC conversion state during the current app run, while the RVC page defaults to the song path passed from the music playback page.

**Architecture:** Replace the single `currentTask` state in `RvcTaskController` with a `Map<String, RvcTaskSnapshot>` keyed by source audio identity. `RvcPage` receives an `audioPath`, activates that source key, shows only that source task, and exposes a task-center button for all active tasks. The app keeps the existing app-level controller lifecycle, so state survives route changes but resets when the app process exits.

**Tech Stack:** Flutter, Dart, `ChangeNotifier`, `go_router`, `rvc_sdk`, `flutter_test`.

---

### Task 1: Controller Source-Key Model

**Files:**
- Modify: `packages/features/rvc_flutter/lib/src/models/rvc_task.dart`
- Modify: `packages/features/rvc_flutter/lib/src/controllers/rvc_task_controller.dart`
- Test: `packages/features/rvc_flutter/test/rvc_task_controller_test.dart`

- [ ] **Step 1: Write the failing controller test**

Create `packages/features/rvc_flutter/test/rvc_task_controller_test.dart` with a local `HttpServer` that delays `/cover` responses. The test starts cover conversion for song A, switches active source to song B, starts song B, then verifies both task snapshots exist and remain independent.

Expected assertions:
- `controller.taskForSource('/music/a.flac')?.status == RvcTaskStatus.running`
- `controller.taskForSource('/music/b.flac')?.status == RvcTaskStatus.running`
- after both responses complete, both tasks are `succeeded`
- `controller.tasks.length == 2`

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test/rvc_task_controller_test.dart
```

from `packages/features/rvc_flutter`.

Expected: FAIL because `taskForSource`, `tasks`, `activateSource`, and source-key task storage do not exist.

- [ ] **Step 3: Implement source-key task storage**

Update `RvcTaskSnapshot` to include:

```dart
final String sourceKey;
final String? sourcePath;
```

Update `RvcTaskController` to hold:

```dart
final Map<String, RvcTaskSnapshot> _tasksBySourceKey = {};
String? _activeSourceKey;
String? _playingTaskId;
```

Add semantic APIs:

```dart
String activateSource({String? inputPath, String? audioFilename});
RvcTaskSnapshot? taskForSource(String? sourceKey);
List<RvcTaskSnapshot> get tasks;
RvcTaskSnapshot? get activeTask;
bool hasRunningTaskForSource(String? sourceKey);
void clearTaskForSource(String? sourceKey);
```

`startConvert` and `startCover` must resolve a source key before starting, store the running snapshot under that key, and update the same map entry when the request completes. Completion checks must compare the map entry id for that source key, not a global current task id.

- [ ] **Step 4: Run controller test to verify it passes**

Run:

```powershell
flutter test test/rvc_task_controller_test.dart
```

Expected: PASS.

### Task 2: RVC Page Current-Source Binding

**Files:**
- Modify: `packages/features/rvc_flutter/lib/src/rvc_page.dart`
- Test: `packages/features/rvc_flutter/test/rvc_page_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create a widget test that opens `RvcPage(audioPath: '/music/a.flac')`, uses a fake local RVC service for status and models, and verifies:
- the input section shows `/music/a.flac`
- after starting a conversion, reopening another `RvcPage(audioPath: '/music/b.flac')` does not show A as B's current result
- returning to A shows A's running/completed state

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test/rvc_page_test.dart
```

Expected: FAIL because the page still reads `controller.currentTask`.

- [ ] **Step 3: Bind page to the active source key**

In `RvcPage.initState`, call:

```dart
_sourceKey = controller.activateSource(
  inputPath: widget.audioPath,
  audioFilename: _selectedFileName,
);
```

Replace all `controller.currentTask` reads with `controller.taskForSource(_sourceKey)`. Replace `controller.hasRunningTask` with `controller.hasRunningTaskForSource(_sourceKey)`. Replace mode switching `controller.clearTask()` with `controller.clearTaskForSource(_sourceKey)`.

When a user picks a manual audio file, activate or update the source key for that file before starting conversion.

- [ ] **Step 4: Run page test to verify it passes**

Run:

```powershell
flutter test test/rvc_page_test.dart
```

Expected: PASS.

### Task 3: Task Center Entry

**Files:**
- Modify: `packages/features/rvc_flutter/lib/src/rvc_page.dart`
- Test: `packages/features/rvc_flutter/test/rvc_page_test.dart`

- [ ] **Step 1: Write the failing task-center test**

Extend the widget test to create two source tasks, tap an AppBar task button, and verify a bottom sheet or dialog lists both source names and their statuses.

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test/rvc_page_test.dart
```

Expected: FAIL because no task-center button exists.

- [ ] **Step 3: Add static task-center button**

Add an AppBar `IconButton` with `Icons.task_alt` and tooltip `RVC 任务`. It opens a bottom sheet that renders `controller.tasks` sorted by `createdAt` descending. Each row shows source name, mode, model name, status text, and a small progress indicator for running tasks.

- [ ] **Step 4: Run page test to verify it passes**

Run:

```powershell
flutter test test/rvc_page_test.dart
```

Expected: PASS.

### Task 4: Route Path Pass-Through Guard

**Files:**
- Modify: `Product/jellyfin_app/lib/src/app/app_router.dart`
- Test: `Product/jellyfin_app/test/app_router_test.dart`

- [ ] **Step 1: Write or extend route test**

Verify `/rvc?audioPath=...` decodes and passes `audioPath` to `RvcRoutePage`.

- [ ] **Step 2: Run test to verify current behavior**

Run:

```powershell
flutter test test/app_router_test.dart
```

Expected: PASS if the previous RVC route fix already covers path pass-through; otherwise FAIL and fix route parsing.

### Task 5: Verification

**Files:**
- All changed files above.

- [ ] **Step 1: Format changed Dart files**

Run:

```powershell
dart format packages/features/rvc_flutter/lib/src/models/rvc_task.dart packages/features/rvc_flutter/lib/src/controllers/rvc_task_controller.dart packages/features/rvc_flutter/lib/src/rvc_page.dart packages/features/rvc_flutter/test/rvc_task_controller_test.dart packages/features/rvc_flutter/test/rvc_page_test.dart Product/jellyfin_app/lib/src/app/app_router.dart Product/jellyfin_app/test/app_router_test.dart
```

- [ ] **Step 2: Run focused tests**

Run:

```powershell
flutter test test/rvc_task_controller_test.dart
flutter test test/rvc_page_test.dart
```

from `packages/features/rvc_flutter`.

Run:

```powershell
flutter test test/app_router_test.dart
```

from `Product/jellyfin_app`.

- [ ] **Step 3: Run focused analysis**

Run:

```powershell
flutter analyze lib/src/controllers/rvc_task_controller.dart lib/src/models/rvc_task.dart lib/src/rvc_page.dart test/rvc_task_controller_test.dart test/rvc_page_test.dart
```

from `packages/features/rvc_flutter`.

Run:

```powershell
flutter analyze lib/src/app/app_router.dart test/app_router_test.dart
```

from `Product/jellyfin_app`.

- [ ] **Step 4: Review git diff**

Run:

```powershell
git diff -- packages/features/rvc_flutter Product/jellyfin_app/lib/src/app/app_router.dart Product/jellyfin_app/test/app_router_test.dart docs/superpowers/plans/2026-05-14-rvc-multi-song-tasks.md
```

Expected: only RVC multi-task and plan changes are present.
