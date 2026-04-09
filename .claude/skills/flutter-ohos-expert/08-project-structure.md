# 八、工程结构与关键文件

## 8.1 ohos 工程目录规范

```
ohos/
├── AppScope/
│   ├── app.json5               # 应用全局配置（包名、版本、图标等）
│   └─ resources/
├── build-profile.json5         # 构建配置（签名、SDK版本、产品定义）
├── oh-package.json5            # 项目级依赖配置
├── hvigorfile.ts               # 构建脚本入口
├── hvigor/                     # Hvigor 构建系统
│   └── hvigor-config.json5
├── entry/                      # 主模块（Flutter 应用入口）
│   ├── build-profile.json5     # 模块构建配置
│   ├── oh-package.json5        # 模块依赖
│   ├── hvigorfile.ts           # 模块构建脚本
│   └── src/
│       └── main/
│           ├── ets/            # ArkTS 代码
│           │   ├── entryability/
│           │   │   └── EntryAbility.ets    # 入口 Ability
│           │   ├── pages/
│           │   │   └── Index.ets           # 主页面
│           │   └── plugins/
│           │       └── GeneratedPluginRegistrant.ets  # 自动生成的插件注册
│           ├── module.json5    # 模块声明（权限、Ability注册等）
│           └── resources/
│               ├── base/
│               │   ├── element/
│               │   │   └── string.json     # 字符串资源
│               │   ├── media/              # 图片资源
│               │   └── profile/
│               │       └── main_pages.json # 页面路由配置
│               └── rawfile/
│                   └── buildinfo.json5     # Impeller 渲染开关
└── har/                        # HAR 依赖文件（混合开发时）
    ├── flutter.har
    ├── flutter_embedding_debug.har
    └── arm64_v8a_debug.har
```

---

## 8.2 Plugin 工程目录规范

```
<plugin_name>/
├── lib/
│   └── <plugin_name>.dart      # Dart API 接口
├── android/                    # Android 原生实现
├── ios/                        # iOS 原生实现
├── ohos/                       # ohos 原生实现
│   ├── build-profile.json5
│   ├── oh-package.json5        # 外层依赖（不含 flutter.har）
│   ├── <plugin_name>/          # 插件静态库模块
│   │   ├── oh-package.json5    # 含 @ohos/flutter_ohos 依赖
│   │   ├── Index.ets           # 导出入口
│   │   ├── libs/
│   │   │   └── flutter.har     # Flutter 引擎 HAR
│   │   └── src/main/ets/
│   │       └── <package_path>/
│   │           └── <PluginClass>.ets  # 插件实现
│   └── entry/                  # 示例应用的 entry 模块（可删）
├── example/                    # 示例应用
│   ├── lib/
│   ├── ohos/
│   └── pubspec.yaml
└── pubspec.yaml
```

---

## 8.3 关键配置文件说明

### app.json5 — 应用全局配置

```json5
{
  "app": {
    "bundleName": "com.example.myapp",
    "vendor": "example",
    "versionCode": 1000000,
    "versionName": "1.0.0",
    "icon": "$media:app_icon",
    "label": "$string:app_name"
  }
}
```

### build-profile.json5 — 构建配置

```json5
{
  "app": {
    "signingConfigs": [],
    "products": [
      {
        "name": "default",
        "signingConfig": "default",
        "compatibleSdkVersion": "5.0.0(12)",
        "runtimeOS": "HarmonyOS"
      }
    ]
  },
  "modules": [
    {
      "name": "entry",
      "srcPath": "./entry",
      "targets": [
        {
          "name": "default",
          "applyToProducts": ["default"]
        }
      ]
    }
  ]
}
```

### module.json5 — 模块声明

定义模块的 Abilities、权限等：

```json5
{
  "module": {
    "name": "entry",
    "type": "entry",
    "description": "$string:module_desc",
    "mainElement": "EntryAbility",
    "deviceTypes": ["default", "tablet"],
    "deliveryWithInstall": true,
    "installationFree": false,
    "pages": "$profile:main_pages",
    "abilities": [
      {
        "name": "EntryAbility",
        "srcEntry": "./ets/entryability/EntryAbility.ets",
        "description": "$string:EntryAbility_desc",
        "icon": "$media:icon",
        "label": "$string:EntryAbility_label",
        "startWindowIcon": "$media:icon",
        "startWindowBackground": "$color:start_window_background",
        "exported": true,
        "skills": [
          {
            "entities": ["entity.system.home"],
            "actions": ["action.system.home"]
          }
        ]
      }
    ]
  }
}
```

### main_pages.json — 页面路由

```json
{
  "src": [
    "pages/Index",
    "pages/FlutterIndex"
  ]
}
```

### oh-package.json5 — 依赖管理

项目级（使用 overrides 管理版本）：

```json5
{
  "name": "my_project",
  "version": "1.0.0",
  "overrides": {
    "@ohos/flutter_ohos": "file:./har/flutter_embedding_debug.har",
    "flutter_native_arm64_v8a": "file:./har/arm64_v8a_debug.har"
  },
  "devDependencies": {
    "@ohos/hypium": "1.0.6"
  }
}
```

模块级（声明依赖）：

```json5
{
  "name": "entry",
  "version": "1.0.0",
  "dependencies": {
    "@ohos/flutter_ohos": "",
    "flutter_native_arm64_v8a": ""
  }
}
```

---

## 8.4 可安全删除的过时文件

| 文件/目录 | 说明 |
|-----------|------|
| `ohos/har/har_product/*` | 从 flutter_flutter 模板直接复制，不再需要 |
| `ohos/har/flutter_embedding.har` | 已替换为 `ohos/har/flutter.har` |
| `ohos/dta/icudtl.dat` | 从 flutter_flutter 模板直接复制 |
