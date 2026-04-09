# 五、Flutter Plugin 鸿蒙端开发

## 5.1 创建 Plugin 项目

```bash
# 创建支持 ohos 的 Plugin
flutter create --org com.example --template=plugin --platforms=android,ios,ohos hello

# 给已有 Plugin 添加 ohos 支持
cd my_plugin
flutter create . --template=plugin --platforms=ohos
```

### Plugin 项目结构

```
hello/
├── lib/
│   └── hello.dart                          # Dart API
├── android/
│   └── src/main/java/.../HelloPlugin.kt    # Android 实现
├── ios/
│   └── Classes/HelloPlugin.m               # iOS 实现
├── ohos/
│   ├── build-profile.json5
│   ├── oh-package.json5
│   └── hello/
│       ├── oh-package.json5
│       ├── Index.ets
│       └── src/main/ets/
│           └── components/plugin/
│               └── HelloPlugin.ets         # ohos 实现
├── example/
└── pubspec.yaml
```

### pubspec.yaml 配置

```yaml
flutter:
  plugin:
    platforms:
      android:
        package: com.example.hello
        pluginClass: HelloPlugin
      ios:
        pluginClass: HelloPlugin
      ohos:
        pluginClass: HelloPlugin
```

---

## 5.2 FlutterPlugin 接口实现

所有 ohos 插件都需要实现 `FlutterPlugin` 接口：

```typescript
import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';

export default class MyPlugin implements FlutterPlugin {

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    // 插件附加到引擎时调用，在此初始化 Channel
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    // 插件从引擎分离时调用，在此清理资源
  }

  getUniqueClassName(): string {
    return 'MyPlugin';
  }
}
```

### 在 EntryAbility 中注册插件

```typescript
import { FlutterAbility } from '@ohos/flutter_ohos'
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import FlutterEngine from '@ohos/flutter_ohos/src/main/ets/embedding/engine/FlutterEngine';
import BatteryPlugin from './BatteryPlugin';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    // 手动注册自定义插件
    this.addPlugin(new BatteryPlugin());
  }
}
```

---

## 5.3 MethodChannel — 方法调用

适用场景：Dart 调用原生方法并获取返回值。

### Dart 端

```dart
import 'package:flutter/services.dart';

class BatteryLevel {
  static const _channel = MethodChannel('samples.flutter.dev/battery');

  static Future<int> getBatteryLevel() async {
    try {
      final result = await _channel.invokeMethod<int>('getBatteryLevel');
      return result ?? -1;
    } on PlatformException catch (e) {
      throw Exception("Failed to get battery level: '${e.message}'");
    }
  }
}
```

### ETS 端（完整示例）

```typescript
import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodChannel,
  MethodResult,
  Log
} from '@ohos/flutter_ohos';
import { batteryInfo } from '@kit.BasicServicesKit';

const TAG = "BatteryPlugin";

export default class BatteryPlugin implements FlutterPlugin {
  private channel?: MethodChannel;

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(
      binding.getBinaryMessenger(),
      "samples.flutter.dev/battery"
    );

    let that = this;
    this.channel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult) {
        switch (call.method) {
          case "getBatteryLevel":
            let level: number = batteryInfo.batterySOC;
            Log.i(TAG, "level=" + level);
            if (level >= 0) {
              result.success(level);
            } else {
              result.error("UNAVAILABLE", "Battery level not available.", null);
            }
            break;
          default:
            result.notImplemented();
            break;
        }
      }
    });
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
  }

  getUniqueClassName(): string {
    return "BatteryPlugin";
  }
}
```

### Dart 端调用

```dart
ElevatedButton(
  onPressed: () async {
    try {
      final result = await _channel.invokeMethod<int>('getBatteryLevel');
      setState(() {
        message = 'Battery level at $result % .';
      });
    } on PlatformException catch (e) {
      setState(() {
        message = "Failed: '${e.message}'.";
      });
    }
  },
  child: const Text("getBatteryLevel"),
),
```

---

## 5.4 EventChannel — 事件流

适用场景：原生端持续向 Dart 推送事件（传感器数据、位置更新等）。

### Dart 端

```dart
final _eventChannel = const EventChannel('samples.flutter.dev/event_channel');

// 启用事件监听
_eventChannel.receiveBroadcastStream().listen((event) {
  setState(() {
    message = "EventChannel event=$event";
  });
});
```

### ETS 端

```typescript
import { EventChannel, EventSink, FlutterPlugin, FlutterPluginBinding, Log }
  from '@ohos/flutter_ohos';

const TAG = "MyEventPlugin";

export default class MyEventPlugin implements FlutterPlugin {
  private eventChannel?: EventChannel;
  private eventSink?: EventSink;

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    let that = this;
    this.eventChannel = new EventChannel(
      binding.getBinaryMessenger(),
      "samples.flutter.dev/event_channel"
    );

    this.eventChannel.setStreamHandler({
      onListen(args: Any, events: EventSink): void {
        that.eventSink = events;
        Log.i(TAG, "onListen: " + args);
      },
      onCancel(args: Any): void {
        that.eventSink = undefined;
        Log.i(TAG, "onCancel: " + args);
      }
    });
  }

  // 在需要的时候发送事件
  public sendEvent(data: string) {
    this.eventSink?.success("Success at " + new Date());
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.eventChannel?.setStreamHandler(null);
  }

  getUniqueClassName(): string {
    return "MyEventPlugin";
  }
}
```

### 通过 MethodChannel 触发事件发送

Dart 端：
```dart
await _platform.invokeMethod('callEvent');
```

ETS 端：
```typescript
case "callEvent":
  that.eventSink?.success("Success at " + new Date());
  break;
```

---

## 5.5 BasicMessageChannel — 双向消息

适用场景：Dart 与原生端简单的双向通信。

### Dart 端

```dart
int count = 0;
final _basicChannel = const BasicMessageChannel(
  "samples.flutter.dev/basic_channel",
  StandardMessageCodec(),
);

// 发送消息并获取原生端回复
Future<void> testBasicChannel() async {
  String result;
  try {
    result = await _basicChannel.send(++count) as String;
  } on PlatformException catch (e) {
    result = "Error: $e";
  }
  setState(() {
    message = result;
  });
}
```

### ETS 端

```typescript
import { BasicMessageChannel, FlutterPlugin, FlutterPluginBinding, StandardMessageCodec, Reply }
  from '@ohos/flutter_ohos';

export default class MyBasicPlugin implements FlutterPlugin {
  private basicChannel?: BasicMessageChannel<Any>;

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.basicChannel = new BasicMessageChannel(
      binding.getBinaryMessenger(),
      "samples.flutter.dev/basic_channel",
      new StandardMessageCodec()
    );

    this.basicChannel.setMessageHandler({
      onMessage(message: Any, reply: Reply<Any>) {
        if (message % 2 == 0) {
          reply.reply("run with if case.");
        } else {
          reply.reply("run with else case");
        }
      }
    });
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.basicChannel?.setMessageHandler(null);
  }

  getUniqueClassName(): string {
    return "MyBasicPlugin";
  }
}
```

---

## 5.6 三种 Channel 组合使用（完整示例）

一个插件可同时使用多种 Channel，以下为完整的 BatteryPlugin：

```typescript
import {
  Any,
  BasicMessageChannel,
  EventChannel,
  FlutterPlugin,
  FlutterPluginBinding,
  Log,
  MethodCall,
  MethodChannel,
  StandardMessageCodec
} from '@ohos/flutter_ohos';
import { MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import { EventSink } from '@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel';
import { Reply } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BasicMessageChannel';
import { batteryInfo } from '@kit.BasicServicesKit';

const TAG = "BatteryPlugin";

export default class BatteryPlugin implements FlutterPlugin {
  private channel?: MethodChannel;
  private basicChannel?: BasicMessageChannel<Any>;
  private eventChannel?: EventChannel;
  private eventSink?: EventSink;

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    // === MethodChannel ===
    this.channel = new MethodChannel(
      binding.getBinaryMessenger(),
      "samples.flutter.dev/battery"
    );
    let that = this;
    this.channel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult) {
        switch (call.method) {
          case "getBatteryLevel":
            let level = batteryInfo.batterySOC;
            if (level >= 0) {
              result.success(level);
            } else {
              result.error("UNAVAILABLE", "Battery level not available.", null);
            }
            break;
          case "callEvent":
            that.eventSink?.success("Success at " + new Date());
            break;
          default:
            result.notImplemented();
            break;
        }
      }
    });

    // === BasicMessageChannel ===
    this.basicChannel = new BasicMessageChannel(
      binding.getBinaryMessenger(),
      "samples.flutter.dev/basic_channel",
      new StandardMessageCodec()
    );
    this.basicChannel.setMessageHandler({
      onMessage(message: Any, reply: Reply<Any>) {
        Log.i(TAG, "message=" + message);
        if (message % 2 == 0) {
          reply.reply("run with if case.");
        } else {
          reply.reply("run with else case");
        }
      }
    });

    // === EventChannel ===
    this.eventChannel = new EventChannel(
      binding.getBinaryMessenger(),
      "samples.flutter.dev/event_channel"
    );
    this.eventChannel.setStreamHandler({
      onListen(args: Any, events: EventSink): void {
        that.eventSink = events;
        Log.i(TAG, "onListen: " + args);
      },
      onCancel(args: Any): void {
        that.eventSink = undefined;
        Log.i(TAG, "onCancel: " + args);
      }
    });
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.eventChannel?.setStreamHandler(null);
  }

  getUniqueClassName(): string {
    return "BatteryPlugin";
  }
}
```

---

## 5.7 PlatformView — 原生视图嵌入

适用场景：将 ohos 原生 UI 组件嵌入 Flutter 页面。

### Dart 端：使用 OhosView

```dart
import 'package:flutter/services.dart';

typedef OnViewCreated = Function(CustomViewController);

class CustomOhosView extends StatefulWidget {
  final OnViewCreated onViewCreated;
  const CustomOhosView(this.onViewCreated, {Key? key}) : super(key: key);

  @override
  State<CustomOhosView> createState() => _CustomOhosViewState();
}

class _CustomOhosViewState extends State<CustomOhosView> {
  late MethodChannel _channel;

  @override
  Widget build(BuildContext context) {
    return OhosView(
      viewType: 'com.rex.custom.ohos/customView',       // 与 ETS 端注册的 ID 一致
      onPlatformViewCreated: _onPlatformViewCreated,
      creationParams: const <String, dynamic>{'initParams': 'hello world'},
      creationParamsCodec: const StandardMessageCodec(),
    );
  }

  void _onPlatformViewCreated(int id) {
    // 为每个视图实例创建独立的 Channel
    _channel = MethodChannel('com.rex.custom.ohos/customView$id');
    final controller = CustomViewController(_channel);
    widget.onViewCreated(controller);
  }
}
```

### Dart 端：Controller 封装

```dart
class CustomViewController {
  final MethodChannel _channel;
  final StreamController<String> _controller = StreamController<String>();

  CustomViewController(this._channel) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'getMessageFromOhosView':
          // 接收来自原生端的数据
          final result = call.arguments as String;
          _controller.sink.add(result);
          break;
      }
    });
  }

  Stream<String> get customDataStream => _controller.stream;

  // 发送数据给原生端
  Future<void> sendMessageToOhosView(String message) async {
    await _channel.invokeMethod('getMessageFromFlutterView', message);
  }
}
```

### Dart 端：使用

```dart
class _CustomExampleState extends State<CustomExample> {
  String receivedData = '';
  CustomViewController? _controller;

  void _onViewCreated(CustomViewController controller) {
    _controller = controller;
    _controller?.customDataStream.listen((data) {
      setState(() {
        receivedData = '来自ohos的数据：$data';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 上半部分：原生 ohos 视图
        Expanded(
          child: CustomOhosView(_onViewCreated),
        ),
        // 下半部分：Flutter 视图
        Expanded(
          child: Column(
            children: [
              TextButton(
                onPressed: () {
                  _controller?.sendMessageToOhosView('flutter - data');
                },
                child: const Text('发送数据给ohos'),
              ),
              Text(receivedData),
            ],
          ),
        ),
      ],
    );
  }
}
```

### ETS 端：CustomPlugin — 注册 PlatformView

```typescript
import { FlutterPlugin, FlutterPluginBinding }
  from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import StandardMessageCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/StandardMessageCodec';
import { CustomFactory } from './CustomFactory';

export class CustomPlugin implements FlutterPlugin {
  getUniqueClassName(): string {
    return 'CustomPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    // 注册 PlatformView 工厂，viewType 需与 Dart 端一致
    binding.getPlatformViewRegistry()?.registerViewFactory(
      'com.rex.custom.ohos/customView',
      new CustomFactory(binding.getBinaryMessenger(), StandardMessageCodec.INSTANCE)
    );
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {}
}
```

### ETS 端：CustomFactory — 创建视图实例

```typescript
import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import MessageCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/MessageCodec';
import PlatformViewFactory from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformViewFactory';
import { CustomView } from './CustomView';
import common from '@ohos.app.ability.common';
import PlatformView from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';

export class CustomFactory extends PlatformViewFactory {
  message: BinaryMessenger;

  constructor(message: BinaryMessenger, createArgsCodes: MessageCodec<Object>) {
    super(createArgsCodes);
    this.message = message;
  }

  public create(context: common.Context, viewId: number, args: Object): PlatformView {
    return new CustomView(context, viewId, args, this.message);
  }
}
```

### ETS 端：CustomView — 原生视图实现

```typescript
import MethodChannel, { MethodCallHandler, MethodResult }
  from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import PlatformView, { Params }
  from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';
import common from '@ohos.app.ability.common';
import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import StandardMethodCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/StandardMethodCodec';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';

@Component
struct ButtonComponent {
  @ObjectLink params: Params
  customView: CustomView = this.params.platformView as CustomView
  @StorageLink('numValue') storageLink: string = "first"
  @State bkColor: Color = Color.Red

  build() {
    Column() {
      Button("发送数据给Flutter")
        .backgroundColor(this.bkColor)
        .onClick((event: ClickEvent) => {
          this.customView.sendMessage();
        })

      Text(`来自Flutter的数据 : ${this.storageLink}`)
    }
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }
}

@Builder
function ButtonBuilder(params: Params) {
  ButtonComponent({ params: params })
}

AppStorage.setOrCreate('numValue', 'test')

@Observed
export class CustomView extends PlatformView implements MethodCallHandler {
  numValue: string = "test";
  methodChannel: MethodChannel;
  index: number = 1;

  constructor(context: common.Context, viewId: number, args: ESObject, message: BinaryMessenger) {
    super();
    // 每个视图实例有独立的 Channel（通过 viewId 区分）
    this.methodChannel = new MethodChannel(
      message,
      `com.rex.custom.ohos/customView${viewId}`,
      StandardMethodCodec.INSTANCE
    );
    this.methodChannel.setMethodCallHandler(this);
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'getMessageFromFlutterView':
        // 接收 Flutter 端发来的数据
        let value: ESObject = call.args;
        this.numValue = value;
        let link: SubscribedAbstractProperty<number> = AppStorage.link('numValue');
        link.set(value);
        result.success(true);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  public sendMessage = () => {
    // 向 Flutter 端发送数据
    this.methodChannel.invokeMethod('getMessageFromOhosView', 'native - ' + this.index++);
  }

  getView(): WrappedBuilder<[Params]> {
    return new WrappedBuilder(ButtonBuilder);
  }

  dispose(): void {}
}
```

---

## 5.8 FFI Plugin

```bash
flutter create --template=plugin_ffi hello --platforms=android,ios,ohos
```

pubspec.yaml：
```yaml
plugin:
  platforms:
    android:
      ffiPlugin: true
    ohos:
      ffiPlugin: true
    ios:
      ffiPlugin: true
```

绑定原生代码：
```bash
dart run ffigen --config ffigen.yaml
```
