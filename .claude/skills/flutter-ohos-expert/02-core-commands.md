# 二、核心命令速查

## 2.1 项目创建

```bash
# 创建仅 ohos 平台的 Flutter 项目
flutter create --platforms ohos my_app

# 创建多平台项目（android, ios, ohos）
flutter create my_app

# 给已有 Flutter 项目添加 ohos 平台支持
cd my_app
flutter create . --platforms ohos

# 创建 Flutter Module（混合开发用）
flutter create -t module flutter_module

# 创建 Plugin 项目（支持 ohos）
flutter create --org com.example --template=plugin --platforms=android,ios,ohos my_plugin

# 创建 FFI Plugin 项目（支持 ohos）
flutter create --template=plugin_ffi my_plugin --platforms android,ios,ohos

# 给已有 Plugin 添加 ohos 平台支持
cd my_plugin
flutter create . --template=plugin --platforms=ohos
```

## 2.2 构建命令

```bash
# 构建 HAP 包（Flutter 应用产物）
flutter build hap --debug
flutter build hap --release
flutter build hap --target-platform ohos-arm64 --release

# 带自定义引擎构建
flutter build hap --release \
  --local-engine=<DIR>/src/out/ohos_release_arm64 \
  --local-engine-host=<DIR>/src/out/host_release

# 构建 HAR 包（Flutter Module 混合开发产物）
flutter build har --debug
flutter build har --release
```

构建产物路径：
- HAP: `<project>/ohos/entry/build/default/outputs/default/entry-default-signed.hap`
- HAR: `<module>/build/ohos/har/debug/` 下生成三个文件

## 2.3 运行与调试

```bash
# 查看可用设备
flutter devices

# 运行到指定设备
flutter run --debug -d <deviceId>
flutter run --release -d <deviceId>

# 带自定义引擎运行
flutter run --debug \
  --local-engine=<DIR>/src/out/ohos_debug_unopt_arm64 \
  --local-engine-host=<DIR>/src/out/host_debug_unopt \
  -d <deviceId>

# 安装 HAP 到设备
hdc -t <deviceId> install <hap_file_path>
```

## 2.4 依赖管理

```bash
flutter pub get
flutter pub upgrade
```

使用 git 依赖的 ohos 适配包示例（pubspec.yaml）：
```yaml
dependencies:
  path_provider:
    git:
      url: https://gitcode.com/openharmony-tpc/flutter_packages.git
      path: packages/path_provider/path_provider
      ref: br_path_provider-v2.1.5_ohos
```

## 2.5 签名配置

所有 ohos 项目运行前必须签名：

1. 用 DevEco Studio 打开项目的 `ohos` 目录
2. 点击 `File > Project Structure > Signing Configs`
3. 勾选 `Support HarmonyOS & Automatically generate signature`
4. 登录华为开发者账号，等待签名完成，点击 OK

## 2.6 Impeller 渲染开关

Flutter ohos 支持 impeller-vulkan 渲染模式，配置文件路径：

```
ohos/entry/src/main/resources/rawfile/buildinfo.json5
```

```json5
{
  "string": [
    {
      "name": "enable_impeller",
      "value": "true"   // 改为 false 关闭 impeller
    }
  ]
}
```

新建工程默认开启 impeller。旧工程需手动复制此文件到对应路径。
