# ImageApi API 文档

> Jellyfin Dart 客户端 - ImageApi 类完整参考文档

## 概述

`ImageApi` 类提供了与 Jellyfin 媒体服务器图片管理相关的所有功能，包括获取、上传、删除和更新各种类型的图片资源。

**类路径**: `lib/src/api/image_api.dart`

**总函数数**: 35 个

---

## 目录

- [删除操作](#删除操作)
- [获取图片操作](#获取图片操作)
- [HEAD 请求操作](#head-请求操作)
- [上传/设置操作](#上传设置操作)
- [通用参数说明](#通用参数说明)
- [使用示例](#使用示例)

---

## 删除操作

### deleteCustomSplashscreen

删除自定义启动画面。

**方法签名**:
```dart
Future<Response<void>> deleteCustomSplashscreen({
  CancelToken? cancelToken,
  Map<String, dynamic>? headers,
  Map<String, dynamic>? extra,
  ValidateStatus? validateStatus,
  ProgressCallback? onSendProgress,
  ProgressCallback? onReceiveProgress,
})
```

**HTTP 方法**: `DELETE`
**端点**: `/Branding/Splashscreen`
**认证**: 需要认证 (ApiKey)

---

### deleteItemImage

删除媒体项的指定类型图片。

**方法签名**:
```dart
Future<Response<void>> deleteItemImage({
  required String itemId,      // 媒体项 ID
  required ImageType imageType, // 图片类型
  int? imageIndex,              // 图片索引
  CancelToken? cancelToken,
  Map<String, dynamic>? headers,
  Map<String, dynamic>? extra,
  ValidateStatus? validateStatus,
  ProgressCallback? onSendProgress,
  ProgressCallback? onReceiveProgress,
})
```

**HTTP 方法**: `DELETE`
**端点**: `/Items/{itemId}/Images/{imageType}`
**认证**: 需要认证 (ApiKey)

---

### deleteItemImageByIndex

通过索引删除媒体项的图片。

**方法签名**:
```dart
Future<Response<void>> deleteItemImageByIndex({
  required String itemId,        // 媒体项 ID
  required ImageType imageType,  // 图片类型
  required int imageIndex,       // 图片索引（必填）
  CancelToken? cancelToken,
  Map<String, dynamic>? headers,
  Map<String, dynamic>? extra,
  ValidateStatus? validateStatus,
  ProgressCallback? onSendProgress,
  ProgressCallback? onReceiveProgress,
})
```

**HTTP 方法**: `DELETE`
**端点**: `/Items/{itemId}/Images/{imageType}/{imageIndex}`
**认证**: 需要认证 (ApiKey)

---

### deleteUserImage

删除用户头像。

**方法签名**:
```dart
Future<Response<void>> deleteUserImage({
  String? userId,                 // 用户 ID（可选）
  CancelToken? cancelToken,
  Map<String, dynamic>? headers,
  Map<String, dynamic>? extra,
  ValidateStatus? validateStatus,
  ProgressCallback? onSendProgress,
  ProgressCallback? onReceiveProgress,
})
```

**HTTP 方法**: `DELETE`
**端点**: `/UserImage`
**认证**: 需要认证 (ApiKey)

---

## 获取图片操作

### getArtistImage

按名称获取艺术家图片。

**方法签名**:
```dart
Future<Response<Uint8List>> getArtistImage({
  required String name,            // 艺术家名称
  required ImageType imageType,    // 图片类型
  required int imageIndex,         // 图片索引
  String? tag,                     // 缓存标签
  ImageFormat? format,             // 输出格式 (original, gif, jpg, png)
  int? maxWidth,                   // 最大宽度
  int? maxHeight,                  // 最大高度
  double? percentPlayed,           // 播放百分比覆盖层
  int? unplayedCount,              // 未播放计数覆盖层
  int? width,                      // 固定宽度
  int? height,                     // 固定高度
  int? quality,                    // 图片质量 (0-100, 默认 90)
  int? fillWidth,                  // 填充宽度
  int? fillHeight,                 // 填充高度
  int? blur,                       // 模糊程度
  String? backgroundColor,         // 背景颜色
  String? foregroundLayer,         // 前景图层
  CancelToken? cancelToken,
  Map<String, dynamic>? headers,
  Map<String, dynamic>? extra,
  ValidateStatus? validateStatus,
  ProgressCallback? onSendProgress,
  ProgressCallback? onReceiveProgress,
})
```

**HTTP 方法**: `GET`
**端点**: `/Artists/{name}/Images/{imageType}/{imageIndex}`
**返回值**: `Uint8List` (图片二进制数据)

---

### getGenreImage

按名称获取类型（Genre）图片。

**方法签名**:
```dart
Future<Response<Uint8List>> getGenreImage({
  required String name,            // 类型名称
  required ImageType imageType,    // 图片类型
  String? tag,
  ImageFormat? format,
  int? maxWidth,
  int? maxHeight,
  double? percentPlayed,
  int? unplayedCount,
  int? width,
  int? height,
  int? quality,
  int? fillWidth,
  int? fillHeight,
  int? blur,
  String? backgroundColor,
  String? foregroundLayer,
  int? imageIndex,
  // ... 其他通用参数
})
```

**HTTP 方法**: `GET`
**端点**: `/Genres/{name}/Images/{imageType}`
**返回值**: `Uint8List`

---

### getGenreImageByIndex

按名称和索引获取类型图片。

**方法签名**:
```dart
Future<Response<Uint8List>> getGenreImageByIndex({
  required String name,
  required ImageType imageType,
  required int imageIndex,
  // ... 图片处理参数
})
```

**HTTP 方法**: `GET`
**端点**: `/Genres/{name}/Images/{imageType}/{imageIndex}`
**返回值**: `Uint8List`

---

### getItemImage

获取媒体项的图片。

**方法签名**:
```dart
Future<Response<Uint8List>> getItemImage({
  required String itemId,          // 媒体项 ID
  required ImageType imageType,    // 图片类型
  int? maxWidth,
  int? maxHeight,
  int? width,
  int? height,
  int? quality,
  String? tag,
  ImageFormat? format,
  double? percentPlayed,
  int? unplayedCount,
  int? fillWidth,
  int? fillHeight,
  int? blur,
  String? backgroundColor,
  String? foregroundLayer,
  int? imageIndex,
  // ... 其他通用参数
})
```

**HTTP 方法**: `GET`
**端点**: `/Items/{itemId}/Images/{imageType}`
**返回值**: `Uint8List`

---

### getItemImage2

获取媒体项的图片（重载版本）。

**方法签名**:
```dart
Future<Response<Uint8List>> getItemImage2({
  required String itemId,
  required ImageType imageType,
  // ... 参数与 getItemImage 相同
})
```

**HTTP 方法**: `GET`
**端点**: `/Items/{itemId}/Images/{imageType}`
**返回值**: `Uint8List`

---

### getItemImageByIndex

通过索引获取媒体项的图片。

**方法签名**:
```dart
Future<Response<Uint8List>> getItemImageByIndex({
  required String itemId,
  required ImageType imageType,
  required int imageIndex,
  int? maxWidth,
  int? maxHeight,
  int? width,
  int? height,
  int? quality,
  String? tag,
  // ... 其他通用参数
})
```

**HTTP 方法**: `GET`
**端点**: `/Items/{itemId}/Images/{imageType}/{imageIndex}`
**返回值**: `Uint8List`

---

### getItemImageInfos

获取媒体项的所有图片信息列表。

**方法签名**:
```dart
Future<Response<List<ImageInfo>>> getItemImageInfos({
  required String itemId,          // 媒体项 ID
  CancelToken? cancelToken,
  Map<String, dynamic>? headers,
  Map<String, dynamic>? extra,
  ValidateStatus? validateStatus,
  ProgressCallback? onSendProgress,
  ProgressCallback? onReceiveProgress,
})
```

**HTTP 方法**: `GET`
**端点**: `/Items/{itemId}/Images`
**返回值**: `List<ImageInfo>` (图片信息列表)

---

### getMusicGenreImage

按名称获取音乐类型图片。

**方法签名**:
```dart
Future<Response<Uint8List>> getMusicGenreImage({
  required String name,
  required ImageType imageType,
  // ... 图片处理参数
})
```

**HTTP 方法**: `GET`
**端点**: `/MusicGenres/{name}/Images/{imageType}`
**返回值**: `Uint8List`

---

### getMusicGenreImageByIndex

按名称和索引获取音乐类型图片。

**方法签名**:
```dart
Future<Response<Uint8List>> getMusicGenreImageByIndex({
  required String name,
  required ImageType imageType,
  required int imageIndex,
  // ... 图片处理参数
})
```

**HTTP 方法**: `GET`
**端点**: `/MusicGenres/{name}/Images/{imageType}/{imageIndex}`
**返回值**: `Uint8List`

---

### getPersonImage

按名称获取人物图片。

**方法签名**:
```dart
Future<Response<Uint8List>> getPersonImage({
  required String name,
  required ImageType imageType,
  // ... 图片处理参数
})
```

**HTTP 方法**: `GET`
**端点**: `/Persons/{name}/Images/{imageType}`
**返回值**: `Uint8List`

---

### getPersonImageByIndex

按名称和索引获取人物图片。

**方法签名**:
```dart
Future<Response<Uint8List>> getPersonImageByIndex({
  required String name,
  required ImageType imageType,
  required int imageIndex,
  // ... 图片处理参数
})
```

**HTTP 方法**: `GET`
**端点**: `/Persons/{name}/Images/{imageType}/{imageIndex}`
**返回值**: `Uint8List`

---

### getSplashscreen

生成或获取启动画面。

**方法签名**:
```dart
Future<Response<Uint8List>> getSplashscreen({
  String? tag,
  ImageFormat? format,
  // ... 图片处理参数
})
```

**HTTP 方法**: `GET`
**端点**: `/Branding/Splashscreen`
**返回值**: `Uint8List`

---

### getStudioImage

按名称获取制片厂图片。

**方法签名**:
```dart
Future<Response<Uint8List>> getStudioImage({
  required String name,
  required ImageType imageType,
  // ... 图片处理参数
})
```

**HTTP 方法**: `GET`
**端点**: `/Studios/{name}/Images/{imageType}`
**返回值**: `Uint8List`

---

### getStudioImageByIndex

按名称和索引获取制片厂图片。

**方法签名**:
```dart
Future<Response<Uint8List>> getStudioImageByIndex({
  required String name,
  required ImageType imageType,
  required int imageIndex,
  // ... 图片处理参数
})
```

**HTTP 方法**: `GET`
**端点**: `/Studios/{name}/Images/{imageType}/{imageIndex}`
**返回值**: `Uint8List`

---

### getUserImage

获取用户头像。

**方法签名**:
```dart
Future<Response<Uint8List>> getUserImage({
  String? userId,                 // 用户 ID（可选）
  String? tag,
  ImageFormat? format,
  int? maxWidth,
  int? maxHeight,
  int? width,
  int? height,
  int? quality,
  // ... 其他通用参数
})
```

**HTTP 方法**: `GET`
**端点**: `/UserImage`
**返回值**: `Uint8List`

---

## HEAD 请求操作

HEAD 请求用于检查资源是否存在或获取元数据，不下载实际内容，适用于缓存验证和资源检查。

### headArtistImage

HEAD 请求检查艺术家图片。

**方法签名**:
```dart
Future<Response<Uint8List>> headArtistImage({
  required String name,
  required ImageType imageType,
  required int imageIndex,
  // ... 图片处理参数
})
```

**HTTP 方法**: `HEAD`
**端点**: `/Artists/{name}/Images/{imageType}/{imageIndex}`

---

### headGenreImage

HEAD 请求检查类型图片。

**方法签名**:
```dart
Future<Response<Uint8List>> headGenreImage({
  required String name,
  required ImageType imageType,
  // ... 图片处理参数
})
```

**HTTP 方法**: `HEAD`
**端点**: `/Genres/{name}/Images/{imageType}`

---

### headGenreImageByIndex

HEAD 请求检查类型图片（按索引）。

**方法签名**:
```dart
Future<Response<Uint8List>> headGenreImageByIndex({
  required String name,
  required ImageType imageType,
  required int imageIndex,
  // ... 图片处理参数
})
```

**HTTP 方法**: `HEAD`
**端点**: `/Genres/{name}/Images/{imageType}/{imageIndex}`

---

### headItemImage

HEAD 请求检查媒体项图片。

**方法签名**:
```dart
Future<Response<Uint8List>> headItemImage({
  required String itemId,
  required ImageType imageType,
  // ... 图片处理参数
})
```

**HTTP 方法**: `HEAD`
**端点**: `/Items/{itemId}/Images/{imageType}`

---

### headItemImage2

HEAD 请求检查媒体项图片（重载版本）。

**方法签名**:
```dart
Future<Response<Uint8List>> headItemImage2({
  required String itemId,
  required ImageType imageType,
  // ... 图片处理参数
})
```

**HTTP 方法**: `HEAD`
**端点**: `/Items/{itemId}/Images/{imageType}`

---

### headItemImageByIndex

HEAD 请求检查媒体项图片（按索引）。

**方法签名**:
```dart
Future<Response<Uint8List>> headItemImageByIndex({
  required String itemId,
  required ImageType imageType,
  required int imageIndex,
  // ... 图片处理参数
})
```

**HTTP 方法**: `HEAD`
**端点**: `/Items/{itemId}/Images/{imageType}/{imageIndex}`

---

### headMusicGenreImage

HEAD 请求检查音乐类型图片。

**方法签名**:
```dart
Future<Response<Uint8List>> headMusicGenreImage({
  required String name,
  required ImageType imageType,
  // ... 图片处理参数
})
```

**HTTP 方法**: `HEAD`
**端点**: `/MusicGenres/{name}/Images/{imageType}`

---

### headMusicGenreImageByIndex

HEAD 请求检查音乐类型图片（按索引）。

**方法签名**:
```dart
Future<Response<Uint8List>> headMusicGenreImageByIndex({
  required String name,
  required ImageType imageType,
  required int imageIndex,
  // ... 图片处理参数
})
```

**HTTP 方法**: `HEAD`
**端点**: `/MusicGenres/{name}/Images/{imageType}/{imageIndex}`

---

### headPersonImage

HEAD 请求检查人物图片。

**方法签名**:
```dart
Future<Response<Uint8List>> headPersonImage({
  required String name,
  required ImageType imageType,
  // ... 图片处理参数
})
```

**HTTP 方法**: `HEAD`
**端点**: `/Persons/{name}/Images/{imageType}`

---

### headPersonImageByIndex

HEAD 请求检查人物图片（按索引）。

**方法签名**:
```dart
Future<Response<Uint8List>> headPersonImageByIndex({
  required String name,
  required ImageType imageType,
  required int imageIndex,
  // ... 图片处理参数
})
```

**HTTP 方法**: `HEAD`
**端点**: `/Persons/{name}/Images/{imageType}/{imageIndex}`

---

### headStudioImage

HEAD 请求检查制片厂图片。

**方法签名**:
```dart
Future<Response<Uint8List>> headStudioImage({
  required String name,
  required ImageType imageType,
  // ... 图片处理参数
})
```

**HTTP 方法**: `HEAD`
**端点**: `/Studios/{name}/Images/{imageType}`

---

### headStudioImageByIndex

HEAD 请求检查制片厂图片（按索引）。

**方法签名**:
```dart
Future<Response<Uint8List>> headStudioImageByIndex({
  required String name,
  required ImageType imageType,
  required int imageIndex,
  // ... 图片处理参数
})
```

**HTTP 方法**: `HEAD`
**端点**: `/Studios/{name}/Images/{imageType}/{imageIndex}`

---

### headUserImage

HEAD 请求检查用户头像。

**方法签名**:
```dart
Future<Response<Uint8List>> headUserImage({
  String? userId,
  String? tag,
  ImageFormat? format,
  // ... 其他参数
})
```

**HTTP 方法**: `HEAD`
**端点**: `/UserImage`

---

## 上传/设置操作

### postUserImage

设置用户头像。

**方法签名**:
```dart
Future<Response<void>> postUserImage({
  String? userId,
  String? tag,
  ImageFormat? format,
  int? maxWidth,
  int? maxHeight,
  int? width,
  int? height,
  int? quality,
  // ... 其他通用参数
})
```

**HTTP 方法**: `POST`
**端点**: `/UserImage`

---

### setItemImage

设置媒体项图片。

**方法签名**:
```dart
Future<Response<void>> setItemImage({
  required String itemId,
  required ImageType imageType,
  // ... 其他参数
})
```

**HTTP 方法**: `POST`
**端点**: `/Items/{itemId}/Images/{imageType}`

---

### setItemImageByIndex

通过索引设置媒体项图片。

**方法签名**:
```dart
Future<Response<void>> setItemImageByIndex({
  required String itemId,
  required ImageType imageType,
  required int imageIndex,
  // ... 其他参数
})
```

**HTTP 方法**: `POST`
**端点**: `/Items/{itemId}/Images/{imageType}/{imageIndex}`

---

### updateItemImageIndex

更新媒体项图片索引。

**方法签名**:
```dart
Future<Response<void>> updateItemImageIndex({
  required String itemId,
  required ImageType imageType,
  required int imageIndex,
  int? newIndex,
  // ... 其他参数
})
```

**HTTP 方法**: `POST`
**端点**: `/Items/{itemId}/Images/{imageType}/{imageIndex}/Index`

---

### uploadCustomSplashscreen

上传自定义启动画面。

**方法签名**:
```dart
Future<Response<void>> uploadCustomSplashscreen({
  // ... 参数
})
```

**HTTP 方法**: `POST`
**端点**: `/Branding/Splashscreen`

---

## 通用参数说明

### 图片处理参数

所有获取图片的方法都支持以下可选参数：

| 参数 | 类型 | 说明 |
|------|------|------|
| `tag` | `String?` | 缓存标签，用于强缓存验证 |
| `format` | `ImageFormat?` | 输出格式：`original`, `gif`, `jpg`, `png` |
| `maxWidth` | `int?` | 最大图片宽度 |
| `maxHeight` | `int?` | 最大图片高度 |
| `width` | `int?` | 固定图片宽度 |
| `height` | `int?` | 固定图片高度 |
| `quality` | `int?` | 图片质量 (0-100)，默认 90 |
| `percentPlayed` | `double?` | 播放百分比覆盖层 |
| `unplayedCount` | `int?` | 未播放计数覆盖层 |
| `fillWidth` | `int?` | 填充宽度 |
| `fillHeight` | `int?` | 填充高度 |
| `blur` | `int?` | 模糊程度 |
| `backgroundColor` | `String?` | 背景颜色（用于透明图片） |
| `foregroundLayer` | `String?` | 前景图层 |
| `imageIndex` | `int?` | 图片索引 |

### Dart 通用参数

所有方法都支持以下 Dio HTTP 客户端参数：

| 参数 | 类型 | 说明 |
|------|------|------|
| `cancelToken` | `CancelToken?` | 用于取消操作的令牌 |
| `headers` | `Map<String, dynamic>?` | 额外的请求头 |
| `extra` | `Map<String, dynamic>?` | 额外的请求标志 |
| `validateStatus` | `ValidateStatus?` | 自定义状态验证回调 |
| `onSendProgress` | `ProgressCallback?` | 上传进度回调 |
| `onReceiveProgress` | `ProgressCallback?` | 下载进度回调 |

---

## 返回值类型

| 类型 | 说明 | 使用场景 |
|------|------|----------|
| `Uint8List` | 图片二进制数据 | 所有获取图片的方法 |
| `void` | 无返回值 | 删除、上传、设置操作 |
| `List<ImageInfo>` | 图片信息列表 | `getItemImageInfos` |

---

## 使用示例

### 基本使用

```dart
import 'package:jellyfin_dart/jellyfin_dart.dart';

// 创建客户端实例
final api = JellyfinDart(
  basePathOverride: 'https://your-jellyfin-server.com',
);

// 设置认证
api.setApiKey('CustomAuthentication', 'your-api-key');

// 获取 ImageApi 实例
final imageApi = api.getImageApi();
```

### 获取媒体项图片

```dart
// 获取电影海报
final response = await imageApi.getItemImage(
  itemId: '12345',
  imageType: ImageType.primary,
  maxWidth: 400,
  quality: 90,
);

final imageBytes = response.data;
// 使用 imageBytes 显示或保存图片
```

### 获取用户头像

```dart
// 获取当前用户头像
final response = await imageApi.getUserImage(
  maxWidth: 200,
  maxHeight: 200,
  format: ImageFormat.png,
);

final avatarBytes = response.data;
```

### 上传自定义启动画面

```dart
// 上传自定义启动画面
await imageApi.uploadCustomSplashscreen();
```

### 删除图片

```dart
// 删除媒体项的背景图
await imageApi.deleteItemImage(
  itemId: '12345',
  imageType: ImageType.backdrop,
  imageIndex: 0,
);
```

### 获取图片信息

```dart
// 获取媒体项的所有图片信息
final response = await imageApi.getItemImageInfos(
  itemId: '12345',
);

final imageInfos = response.data;
for (var info in imageInfos) {
  print('图片类型: ${info.imageType}');
  print('图片宽度: ${info.width}');
  print('图片高度: ${info.height}');
}
```

### 使用 HEAD 请求验证缓存

```dart
// 检查图片是否有更新
final response = await imageApi.headItemImage(
  itemId: '12345',
  imageType: ImageType.primary,
  tag: 'cache-tag-from-previous-request',
);

// 检查 ETag 或 Last-Modified 头
final etag = response.headers.value('etag');
```

### 处理上传进度

```dart
// 设置用户头像并显示上传进度
await imageApi.postUserImage(
  userId: 'user-id',
  onSendProgress: (sent, total) {
    final progress = (sent / total * 100).toStringAsFixed(2);
    print('上传进度: $progress%');
  },
);
```

---

## 认证说明

所有 ImageApi 方法都需要认证。使用以下方式设置认证：

### API Key 认证

```dart
api.setApiKey('CustomAuthentication', 'your-api-key');
```

### Bearer Token 认证

```dart
api.setBearerAuth('bearerAuth', 'your-access-token');
```

---

## 错误处理

所有方法都可能抛出 `DioException`：

```dart
try {
  final response = await imageApi.getItemImage(
    itemId: '12345',
    imageType: ImageType.primary,
  );
} on DioException catch (e) {
  print('请求失败: ${e.message}');
  print('状态码: ${e.response?.statusCode}');
  // 处理错误
}
```

---

## 相关类型

### ImageType 枚举

```dart
enum ImageType {
  primary,      // 主图（海报）
  backdrop,     // 背景图
  banner,       // 横幅
  logo,         // 标志
  thumb,        // 缩略图
  disc,         // 光盘
  box,          // 盒子
  boxRear,      // 盒子背面
  screenshot,   // 截图
  menu,         // 菜单
  chapter,      // 章节
}
```

### ImageFormat 枚举

```dart
enum ImageFormat {
  original,     // 原始格式
  gif,          // GIF
  jpg,          // JPEG
  png,          // PNG
}
```

### ImageInfo 类

```dart
class ImageInfo {
  final String? path;
  final ImageType? imageType;
  final int? width;
  final int? height;
  // ... 其他属性
}
```

---

## 性能优化建议

1. **使用缓存**: 通过 `tag` 参数实现强缓存验证
2. **HEAD 请求**: 在下载前使用 HEAD 请求检查资源是否有更新
3. **合理尺寸**: 根据实际需求设置 `maxWidth`/`maxHeight`，避免传输过大图片
4. **质量设置**: 调整 `quality` 参数平衡图片质量和文件大小
5. **格式选择**: 优先使用 `jpg` 格式以获得更好的压缩比

---

## 版本信息

- **Jellyfin 版本**: 10.11.0
- **API 生成方式**: OpenAPI Generator
- **生成日期**: 自动生成

---

## 更多资源

- [Jellyfin 官方文档](https://jellyfin.org/docs/)
- [Jellyfin API 文档](https://api.jellyfin.org/)
- [Dart Dio 文档](https://pub.dev/packages/dio)

---

**注意**: 本文档由 ImageApi 自动生成代码分析得出，所有方法签名和参数可能与实际代码略有差异，请以实际代码为准。
