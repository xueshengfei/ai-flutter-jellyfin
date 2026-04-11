# 九、常见问题与解决方案

## 环境相关

### Q: `flutter doctor` 报 `No Hmos SDK found`

```bash
# 配置 ohos-sdk 路径
flutter config --ohos-sdk "D:\Huawei\DevEco Studio\sdk"

# 验证
git config --list
# 应看到: ohos-sdk: D:\Huawei\DevEco Studio\sdk
```

### Q: pub upgrade / pub get 耗时过长

- 方案一：首次加载需拉取大量文件，耐心等待
- 方案二：删除 `flutter_flutter/bin/cache` 后重试
- 方案三：更换镜像源
  ```bash
  export PUB_HOSTED_URL=https://mirrors.tuna.tsinghua.edu.cn/dart-pub
  export FLUTTER_STORAGE_BASE_URL=https://mirrors.tuna.tsinghua.edu.cn/flutter
  ```

---

## 构建相关

### Q: `flutter build hap` 失败

- 确认已签名：DevEco Studio > File > Project Structure > Signing Configs
- 确认环境：`flutter doctor -v` 全部 OK
- 确认依赖：`flutter pub get` 无报错
- 清理缓存重试：删除 `build/` 目录后重新构建

### Q: `ohpm install` 后 entry 下没有 oh_modules

必须在**项目根目录**执行 `ohpm install`，不是在 `entry/` 目录下。

### Q: 修改了 flutter_module 代码后未生效

需要重新构建 HAR：
```bash
cd flutter_module
flutter build har --debug
```
然后将新 HAR 拷贝到项目 `har/` 目录覆盖。

---

## 签名相关

### Q: 签名失败 / 无法自动签名

1. 确保使用**实名认证**的华为开发者账号
2. DevEco Studio: `File > Project Structure > Signing Configs`
3. 勾选 `Support HarmonyOS & Automatically generate signature`
4. 登录账号后等待完成

---

## 模拟器相关

### Q: 无法创建模拟器

使用实名制认证的华为开发者账号登录 DevEco Studio。

### Q: Windows 或 Mac x86 无法运行模拟器

模拟器当前仅支持 **Mac ARM 架构**。Windows 和 Mac x86 环境建议使用真机调试。

---

## 包体积相关

### Q: 多模块项目包体积过大

将所有 HAR 文件统一放到项目根目录 `Project/har/` 下，通过 `oh-package.json5` 的 `overrides` 管理，避免多个 module 各自引入导致重复打包。

---

## 运行相关

### Q: flutter run 找不到设备

```bash
flutter devices
# 如果看不到设备，检查：
# 1. 真机：USB 连接是否正常，是否开启开发者模式
# 2. 模拟器：DevEco Studio 中模拟器是否启动
# 3. hdc 工具：确认 hdc 命令可用
```

### Q: HAP 安装失败

```bash
# 确认设备连接
hdc list targets

# 手动安装 HAP
hdc -t <deviceId> install <hap_file_path>

# 如果签名不对，重新在 DevEco Studio 中签名
```

---

## 代码相关

### Q: Platform.isOhos 编译报错

确保使用的是 Flutter OH SDK（不是官方 Flutter SDK）：
```bash
flutter --version
# 应显示 OpenHarmony 相关版本信息
```

### Q: 导入 `@ohos/flutter_ohos` 报错

确认 `oh-package.json5` 中已添加依赖：
```json5
"dependencies": {
  "@ohos/flutter_ohos": "file:libs/flutter.har"
}
```
并确认 `flutter.har` 文件存在于 `libs/` 目录。

### Q: GeneratedPluginRegistrant 找不到

这个文件是 Flutter 构建时自动生成的，需要先执行：
```bash
flutter pub get
flutter build hap --debug
```

---

## 参考资源

- 环境搭建完整文档: `ohos/docs/03_environment/OpenHarmony-flutter环境搭建指导.md`
- 构建指导: `ohos/docs/04_development/OpenHarmony-flutter应用构建指导.md`
- 混合开发: `ohos/docs/04_development/OpenHarmony应用如何集成Flutter.md`
- 三方库适配: `ohos/docs/07_plugin/ohos平台适配flutter三方库指导.md`
- 插件开发: `ohos/docs/07_plugin/developing-an-ohos-plugin-using-flutter.md`
- 常见问题汇总: `ohos/docs/08_FAQ/`
- Flutter OH SDK: https://gitcode.com/openharmony-tpc/flutter_flutter
- 已适配三方库: https://gitcode.com/openharmony-tpc/
