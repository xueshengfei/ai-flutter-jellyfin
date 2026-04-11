# 七、混合开发（OpenHarmony 应用集成 Flutter）

适用场景：已有 OpenHarmony 原生应用，需要嵌入 Flutter 页面。

## 7.1 创建 Flutter Module

在 OH 项目根目录下执行：

```bash
flutter create -t module flutter_module
```

---

## 7.2 构建 HAR 包

```bash
cd flutter_module
flutter build har --debug
# 或
flutter build har --release
```

构建产物在 `flutter_module/build/ohos/har/debug/` 下：

```
debug/
├── arm64_v8a_debug.har        # 原生引擎库
├── flutter_embedding_debug.har # Flutter 嵌入层
└── flutter_module.har          # Flutter 业务模块
```

> **重要**：需要将 HAR 文件拷贝到 OH 项目根目录的 `har/` 下，避免多个 module 重复引入导致包体积膨胀。

---

## 7.3 配置 OH 项目依赖

### 项目级 oh-package.json5（Project/oh-package.json5）

添加 `overrides` 节点，指定 HAR 文件路径：

```json5
{
  "name": "my_oh_project",
  "version": "1.0.0",
  "overrides": {
    "@ohos/flutter_ohos": "file:./har/flutter_embedding_debug.har",
    "flutter_native_arm64_v8a": "file:./har/arm64_v8a_debug.har",
    "@ohos/flutter_module": "file:./har/flutter_module.har"
  }
}
```

### 模块级 oh-package.json5（Project/entry/oh-package.json5）

添加 `dependencies`：

```json5
{
  "name": "entry",
  "version": "1.0.0",
  "description": "Entry module",
  "main": "",
  "author": "",
  "license": "",
  "dependencies": {
    "@ohos/flutter_ohos": "",
    "flutter_native_arm64_v8a": "",
    "@ohos/flutter_module": ""
  }
}
```

### 安装依赖

```bash
# 在项目根目录执行（不是在 entry 下）
ohpm install
```

验证：`entry/` 下出现 `oh_modules/` 目录即成功。

---

## 7.4 集成代码

### 步骤 1：修改 EntryAbility

将 `EntryAbility` 继承 `UIAbility`，并集成 FlutterManager：

```typescript
import { FlutterManager } from '@ohos/flutter_ohos';
import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import Want from '@ohos.app.ability.Want';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';

export default class EntryAbility extends UIAbility {

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 注册 Ability 到 FlutterManager
    FlutterManager.getInstance().pushUIAbility(this);
  }

  onDestroy(): void | Promise<void> {
    // 反注册 Ability
    FlutterManager.getInstance().popUIAbility(this);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.getMainWindowSync().setWindowLayoutFullScreen(true);
    // 注册 WindowStage 到 FlutterManager
    FlutterManager.getInstance().pushWindowStage(this, windowStage);
    windowStage.loadContent('pages/Index');
  }

  onWindowStageDestroy(): void {
    FlutterManager.getInstance().popWindowStage(this);
  }
}
```

### 步骤 2：实现 FlutterEntry 类

`entry/src/main/ets/MyFlutterEntry.ets`：

```typescript
import { FlutterEntry, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';

export default class MyFlutterEntry extends FlutterEntry {
  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    super.configureFlutterEngine(flutterEngine);
    // 注册自动生成的插件
    GeneratedPluginRegistrant.registerWith(flutterEngine);
    // 注册自定义插件
    // this.addPlugin(new CustomPlugin());
  }
}
```

### 步骤 3：创建 Flutter 页面

`entry/src/main/ets/pages/FlutterIndex.ets`：

```typescript
import { FlutterEntry, FlutterView, FlutterPage } from '@ohos/flutter_ohos';
import MyFlutterEntry from '../MyFlutterEntry';

@Entry
@Component
struct FlutterIndex {
  private flutterEntry: FlutterEntry | null = null;
  private flutterView?: FlutterView;

  aboutToAppear() {
    // 初始化 FlutterEntry
    this.flutterEntry = new MyFlutterEntry(getContext(this));
    this.flutterEntry.aboutToAppear();
    this.flutterView = this.flutterEntry.getFlutterView();
  }

  aboutToDisappear() {
    this.flutterEntry?.aboutToDisappear();
  }

  onPageShow() {
    this.flutterEntry?.onPageShow();
  }

  onPageHide() {
    this.flutterEntry?.onPageHide();
  }

  build() {
    Stack() {
      // 嵌入 Flutter 页面
      FlutterPage({ viewId: this.flutterView?.getId() })
    }
  }

  onBackPress(): boolean {
    this.flutterEntry?.onBackPress();
    return true;
  }
}
```

### 步骤 4：注册页面路由

`entry/src/main/resources/base/profile/main_pages.json`：

```json
{
  "src": [
    "pages/Index",
    "pages/FlutterIndex"
  ]
}
```

### 步骤 5：从原生页面跳转到 Flutter

`entry/src/main/ets/pages/Index.ets`：

```typescript
import router from '@ohos.router';

@Entry
@Component
struct Index {
  build() {
    Column() {
      Text('OpenHarmony Native Page')
        .fontSize(24)

      Button('打开 Flutter 页面')
        .onClick(() => {
          router.push({
            url: 'pages/FlutterIndex',
          });
        });
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
```

---

## 7.5 更新 Flutter Module

修改 `flutter_module` 中的业务代码后，需要重新构建 HAR：

```bash
cd flutter_module
flutter build har --debug
```

然后将新生成的 HAR 文件拷贝到 `Project/har/` 下覆盖旧文件。

---

## 7.6 多模块项目注意事项

当项目有多个 OH Module 都使用 Flutter 时：

1. 所有 HAR 文件统一放到项目根目录 `Project/har/` 下
2. 各模块通过 `oh-package.json5` 的 `dependencies` 引用
3. 项目根 `oh-package.json5` 的 `overrides` 统一管理版本
4. 避免每个模块各自引入 HAR 导致包体积膨胀
