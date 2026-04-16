
<p align="center">
  <h1 align="center"> <code>video_player_ohos</code> </h1>
</p>






This project is based on [video_player@2.7.1 ](https://pub.dev/packages/video_player/versions/2.7.1)

## 1. Installation and Usage

### 1.1 Installation

Go to the project directory and add the following dependencies in pubspec.yaml

<!-- tabs:start -->

#### pubspec.yaml

```yaml
dependencies:
  video_player:
    git:
      url: https://gitcode.com/openharmony-tpc/flutter_packages.git
      path: packages/video_player/video_player
```

Execute Command

```bash
flutter pub get
```

<!-- tabs:end -->

### 1.2 Usage

For use cases [ohos/example](./example)

## 2. Constraints

### 2.1 Compatibility

This document is verified based on the following versions:

1. Flutter: 3.7.12-ohos-1.0.6; SDK: 5.0.0(12); IDE: DevEco Studio: 5.0.13.200; ROM: 5.1.0.120 SP3;

### 2.2 **Permission Requirements**

The following permissions include the `system_basic` permission, but the default application permission is `normal`. Only the `normal` permission can be used. Therefore, the error **9568289 ** may be reported during the installation of the HAP package. For details, see [Document](https://developer.huawei.com/consumer/en/doc/harmonyos-guides-V5/bm-tool-V5#EN_TOPIC_0000001884757326__安装hap时提示code9568289-error-install-failed-due-to-grant-request-permissions-failed) Change the application level to `system_basic`.

#### 2.2.1 **Add permissions to the module.json5 file in the entry directory.**

Open `entry/src/main/module.json5` and add the following information:

```diff
"requestPermissions": [
      {
        "name": "ohos.permission.INTERNET",
        "reason": "$string:network_reason",
        "usedScene": {
          "abilities": [
            "EntryAbility"
          ],
          "when": "inuse"
        }
      },
    ]
```

#### 2.2.2 **Add the reason for applying for the preceding permission to the entry directory.**

Open `entry/src/main/resources/base/element/string.json` and add the following information:

```diff
{
  "string": [
    {
      "name": "network_reason",
      "value": "use network"
    }
  ]
}
```

## 3. API

> [!TIP] If the value of **ohos Support** is **yes**, it means that the ohos platform supports this property; **no** means the opposite. The usage method is the same on different platforms and the effect is the same as that of iOS or Android.

| Name                                          | return value                      | Description                                                  | Type     | ohos Support |
| --------------------------------------------- | --------------------------------- | ------------------------------------------------------------ | -------- | ------------ |
| init()                                        | Future<void>                      | Initializes the platform interface and disposes all existing players. | function | yes          |
| dispose(int textureId)                        | Future<void>                      | Clears one video.                                            | function | yes          |
| create([DataSource](#DataSource) dataSource)  | Future<int?>                      | Creates an instance of a video player and returns its textureId. | function | yes          |
| setLooping(int textureId, bool looping)       | Future<void>                      | Sets the looping attribute of the video.                     | function | yes          |
| play(int textureId)                           | Future<void>                      | Starts the video playback.                                   | function | yes          |
| pause(int textureId)                          | Future<void>                      | Stops the video playback.                                    | function | yes          |
| setVolume(int textureId, double volume)       | Future<void>                      | Sets the volume to a range between 0.0 and 1.0.              | function | yes          |
| setPlaybackSpeed(int textureId, double speed) | Future<void>                      | Sets the playback speed to a [speed] value indicating the playback rate.On OHOS, the supported speeds are 0.125×、0.25×、0.5×、0.75×、1.0×、1.25×、1.5×、1.75×、2.0×、3.0× . | function | yes          |
| seekTo(int textureId, Duration position)      | Future<void>                      | Sets the video position to a [Duration] from the start.      | function | yes          |
| getPosition(int textureId)                    | Future<[Duration](#Duration)>     | Gets the video position as [Duration] from the start.        | function | yes          |
| videoEventsFor(int textureId)                 | Stream<[VideoEvent](#VideoEvent)> | Returns a Stream of [VideoEventType]s.                       | Stream   | yes          |
| setMixWithOthers(bool mixWithOthers)          | Future<void>                      | Sets the audio mode to mix with other sources                | function | yes          |

## 4. Properties

### DataSource 

| Name        | Description                                              | Type                              | ohos Support |
| ----------- | -------------------------------------------------------- | --------------------------------- | ------------ |
| sourceType  | The way in which the video was originally loaded.        | [DataSourceType](#DataSourceType) | yes          |
| uri         | The URI to the video file.                               | String?                           | yes          |
| formatHint  |                                                          | [VideoFormat](#VideoFormat)       | yes          |
| asset       | The name of the asset.                                   | String?                           | yes          |
| package     | The package that the asset was loaded from. Only set for | String?                           | yes          |
| httpHeaders | HTTP headers used for the request to the [uri].          | Map<String, String>               | yes          |

### DataSourceType

| Name                      | Description                                          | Type | ohos Support |
| ------------------------- | ---------------------------------------------------- | ---- | ------------ |
| DataSourceType.asset      | The video was included in the app's asset files.     | enum | yes          |
| DataSourceType.network    | The video was downloaded from the internet.          | enum | yes          |
| DataSourceType.file       | The video was loaded off of the local filesystem.    | enum | yes          |
| DataSourceType.contentUri | The video is available via contentUri. Android only. | enum | yes          |

### VideoFormat

| Name              | Description                                                  | Type | ohos Support |
| ----------------- | ------------------------------------------------------------ | ---- | ------------ |
| VideoFormat.dash  | Dynamic Adaptive Streaming over HTTP, also known as MPEG-DASH. | enum | yes          |
| VideoFormat.hls   | HTTP Live Streaming.                                         | enum | yes          |
| VideoFormat.ss    | Smooth Streaming.                                            | enum | yes          |
| VideoFormat.other | Any format other than the other ones defined in this enum.   | enum |              |

### VideoEvent

| Name               | Description                                                  | Type                              | ohos Support |
| ------------------ | ------------------------------------------------------------ | --------------------------------- | ------------ |
| eventType          | The type of the event.                                       | [VideoEventType](#VideoEventType) | yes          |
| duration           | Duration of the video.                                       | Duration?                         | yes          |
| size               | Size of the video.                                           | Size?                             | yes          |
| rotationCorrection | Degrees to rotate the video (clockwise) so it is displayed correctly. | int?                              | yes          |
| buffered           | Buffered parts of the video.                                 | List<DurationRange>?              | yes          |
| isPlaying          | Whether the video is currently playing.                      | bool?                             | yes          |

### VideoEventType

| Name                                | Description                                  | Type | ohos Support |
| ----------------------------------- | -------------------------------------------- | ---- | ------------ |
| VideoEventType.initialized          | The video has been initialized.              | enum | yes          |
| VideoEventType.completed            | The playback has ended.                      | enum | yes          |
| VideoEventType.bufferingUpdate      | Updated information on the buffering state.  | enum | yes          |
| VideoEventType.bufferingStart       | The video started to buffer.                 | enum | yes          |
| VideoEventType.bufferingEnd         | The video stopped to buffer.                 | enum | yes          |
| VideoEventType.isPlayingStateUpdate | The playback state of the video has changed. | enum | yes          |
| VideoEventType.unknown              | An unknown event has been received.          | enum | yes          |

## 5. Known Issues

## 6. **Others**

## 7. **License**

This project is licensed under [The MIT License (MIT)](https://gitcode.com/openharmony-tpc/flutter_packages/blob/master/packages/video_player/video_player_ohos/LICENSE).



> Template version: v0.0.1