# 一、环境搭建

## 1.1 必备工具清单

| 工具 | 用途 | 下载地址 |
|------|------|----------|
| DevEco Studio | OpenHarmony IDE | https://developer.huawei.com/consumer/cn/download/ |
| JDK 17 | Java 运行环境 | https://www.oracle.com/cn/java/technologies/downloads/#java17 |
| Flutter OH SDK | 鸿蒙版 Flutter 引擎 | https://gitcode.com/openharmony-tpc/flutter_flutter |

验证 JDK：
```bash
java -version
# 确认输出为 17.x.x
```

## 1.2 下载 Flutter OH SDK

```bash
git clone https://gitcode.com/openharmony-tpc/flutter_flutter.git
cd flutter_flutter
git checkout -b dev origin/dev
```

## 1.3 Mac/Linux 环境变量

编辑 `~/.zshrc`：

```bash
# JDK 17
export JAVA_HOME=<JAVA_HOME path>/Contents/Home
export PATH=$JAVA_HOME/bin:$PATH

# OpenHarmony SDK, ohpm, hvigor, node
export TOOL_HOME=/Applications/DevEco-Studio.app/Contents
export DEVECO_SDK_HOME=$TOOL_HOME/sdk
export PATH=$TOOL_HOME/tools/ohpm/bin:$PATH
export PATH=$TOOL_HOME/tools/hvigor/bin:$PATH
export PATH=$TOOL_HOME/tools/node/bin:$PATH

# Flutter
export PUB_CACHE=~/PUB
export PATH=<flutter_flutter path>/bin:$PATH
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

生效配置：
```bash
source ~/.zshrc
```

## 1.4 Windows 环境变量

通过 **此电脑 → 属性 → 高级系统设置 → 环境变量** 配置：

**JDK 17：**

| 变量 | 值 | 作用域 |
|------|-----|--------|
| `JAVA_HOME` | `<JDK path>` | 系统变量 |
| `Path` | `%JAVA_HOME%\bin` | 追加到 Path |

**OpenHarmony SDK：**

| 变量 | 值 | 作用域 |
|------|-----|--------|
| `TOOL_HOME` | `<DevEco Studio Path>` | 系统变量 |
| `DEVECO_SDK_HOME` | `%TOOL_HOME%\sdk` | 系统变量 |
| `Path` | `%TOOL_HOME%\tools\ohpm\bin` | 追加到 Path |
| `Path` | `%TOOL_HOME%\tools\hvigor\bin` | 追加到 Path |
| `Path` | `%TOOL_HOME%\tools\node\bin` | 追加到 Path |

**Flutter：**

| 变量 | 值 | 作用域 |
|------|-----|--------|
| `PATH` | `<flutter_flutter path>\bin` | 追加到 Path |
| `PUB_CACHE` | `<PUB path>` | 系统变量 |
| `PUB_HOSTED_URL` | `https://pub.flutter-io.cn` | 系统变量 |
| `FLUTTER_STORAGE_BASE_URL` | `https://storage.flutter-io.cn` | 系统变量 |

## 1.5 验证环境

```bash
flutter doctor -v
```

确认输出中 **Flutter** 和 **HarmonyOS toolchain** 都显示 `[√]`。

## 1.6 常见环境问题

**问题：`No Hmos SDK found`**

```bash
# 配置 ohos-sdk 路径
flutter config --ohos-sdk "D:\Huawei\DevEco Studio\sdk"

# 验证配置
git config --list
# 应看到: ohos-sdk: D:\Huawei\DevEco Studio\sdk
```

**问题：pub upgrade 耗时长**

- 方案一：删除 `flutter_flutter/bin/cache` 后重试
- 方案二：更换镜像源
  ```bash
  export PUB_HOSTED_URL=https://mirrors.tuna.tsinghua.edu.cn/dart-pub
  export FLUTTER_STORAGE_BASE_URL=https://mirrors.tuna.tsinghua.edu.cn/flutter
  ```
