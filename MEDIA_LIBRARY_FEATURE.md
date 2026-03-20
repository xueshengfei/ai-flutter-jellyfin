# 媒体库功能开发完成

## ✅ 已完成功能

### 1. 业务模型 (media_library_models.dart)

#### MediaLibrary - 媒体库信息
```dart
class MediaLibrary {
  final String id;
  final String name;
  final MediaLibraryType type;
  final String? primaryImageTag;
  final int? itemCount;

  // 业务方法
  String? getCoverImageUrl();
  String? getBackdropImageUrl();
}
```

#### MediaLibraryType - 媒体库类型枚举
```dart
enum MediaLibraryType {
  movies,        // 电影 🎬
  tvshows,       // 电视剧 📺
  music,         // 音乐 🎵
  musicVideos,   // 音乐视频 🎼
  homeVideos,    // 家庭视频 📹
  boxSets,       // 电影合集 📦
  unknown,       // 其他 📁
}
```

**每个类型都包含**:
- `displayName` - 中文名称
- `icon` - Emoji图标
- `color` - 主题颜色

#### MediaLibraryListResult - 媒体库列表结果
```dart
class MediaLibraryListResult {
  final List<MediaLibrary> libraries;
  final int? totalCount;
}
```

### 2. 媒体库服务 (media_library_service.dart)

#### MediaLibraryService

**方法**:
1. `getMediaLibraries()` - 获取所有媒体库
2. `getMediaLibraryDetail(libraryId)` - 获取媒体库详情
3. `getMediaLibrariesByType(type)` - 按类型获取媒体库

---

## 📖 使用示例

### 基础用法

```dart
import 'package:jellyfin_service/jellyfin_service.dart';

// 1. 创建客户端
final client = JellyfinClient(
  serverUrl: 'http://localhost:8096',
);

// 2. 登录
final authResult = await client.auth.authenticate(
  username: 'your_username',
  password: 'your_password',
);

// 3. 获取媒体库列表
final libraries = await client.mediaLibrary.getMediaLibraries();

// 4. 遍历媒体库
for (final library in libraries.libraries) {
  print('${library.type.icon} ${library.name}');
  print('  类型: ${library.type.displayName}');
  print('  数量: ${library.itemCount}');
  print('  封面: ${library.getCoverImageUrl()}');
  print('  颜色: ${library.type.color}');
}

// 输出示例:
// 🎬 电影
//   类型: 电影
//   数量: 156
//   封面: http://localhost:8096/Items/xxx/Images/Primary?xxx
//   颜色: #E53935
```

### 按类型获取媒体库

```dart
// 只获取电影类型
final movieLibraries = await client.mediaLibrary.getMediaLibrariesByType(
  MediaLibraryType.movies,
);

for (final library in movieLibraries) {
  print('🎬 ${library.name}');
}
```

### 获取单个媒体库详情

```dart
final library = await client.mediaLibrary.getMediaLibraryDetail(libraryId);
print('媒体库: ${library.name}');
print('有封面: ${library.hasCoverImage}');
```

---

## 🏗️ 架构说明

### 业务模型设计

```
接口SDK (jellyfin_dart)              业务SDK (jellyfin_service)
┌─────────────────────┐             ┌──────────────────────┐
│ BaseItemDto         │──转换──▶    │ MediaLibrary         │
│ - name              │             │ - name              │
│ - id                │             │ - id                │
│ - collectionType    │             │ - type (枚举)       │
│ - primaryImageTag   │             │ - coverImageUrl()   │
│ - childCount        │             │ - itemCount         │
└─────────────────────┘             └──────────────────────┘
```

### API调用流程

```
业务代码
  ↓
client.mediaLibrary.getMediaLibraries()
  ↓
MediaLibraryService
  ↓
jellyfin_dart.LibraryApi.getMediaFolders()
  ↓
HTTP GET /Library/MediaFolders
  ↓
Jellyfin Server
  ↓
转换为业务模型
  ↓
返回 MediaLibraryListResult
```

---

## 🎨 UI展示建议

### 卡片布局示例

```dart
// 使用GridView展示媒体库卡片
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 1.5,
  ),
  itemCount: libraries.libraries.length,
  itemBuilder: (context, index) {
    final library = libraries.libraries[index];
    return Card(
      child: Column(
        children: [
          // 封面图片
          if (library.hasCoverImage)
            Image.network(library.getCoverImageUrl())
          else
            Container(
              color: Color(int.parse(library.type.color)),
              child: Icon(library.type.icon),
            ),

          // 媒体库名称
          Text(library.name),

          // 类型标签
          Chip(
            label: Text(library.type.displayName),
            avatar: Text(library.type.icon),
          ),

          // 数量
          Text('${library.itemCount} 项'),
        ],
      ),
    );
  },
)
```

---

## 🧪 测试

### 单元测试示例

```dart
test('MediaLibraryType should have correct display names', () {
  expect(MediaLibraryType.movies.displayName, '电影');
  expect(MediaLibraryType.tvshows.displayName, '电视剧');
  expect(MediaLibraryType.music.displayName, '音乐');
});

test('MediaLibrary should convert from DTO', () {
  final dto = BaseItemDto(
    name: '我的电影',
    id: '123',
    collectionType: CollectionType.movies,
    childCount: 100,
  );

  final library = MediaLibrary.fromDto(dto, 'http://localhost:8096');

  expect(library.name, '我的电影');
  expect(library.type, MediaLibraryType.movies);
  expect(library.itemCount, 100);
});
```

---

## 📊 数据流程

### 登录成功后显示主页面的完整流程

```dart
// 1. 登录
final authResult = await client.auth.authenticate(...);

// 2. 获取媒体库列表
final libraries = await client.mediaLibrary.getMediaLibraries();

// 3. 显示主页面
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => HomePage(libraries: libraries),
  ),
);

// 4. HomePage展示媒体库卡片
class HomePage extends StatelessWidget {
  final MediaLibraryListResult libraries;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('媒体库')),
      body: GridView.builder(
        itemCount: libraries.libraries.length,
        itemBuilder: (context, index) {
          final library = libraries.libraries[index];
          return MediaLibraryCard(library: library);
        },
      ),
    );
  }
}
```

---

## 🔄 下一步功能建议

基于媒体库功能，可以继续开发：

1. **媒体项列表**
   - 进入媒体库后显示媒体项
   - 支持排序和筛选
   - 显示媒体详情

2. **媒体搜索**
   - 搜索媒体库中的内容
   - 按标题、演员、类型搜索

3. **最近添加**
   - 显示最近添加的媒体
   - 显示继续播放

4. **收藏功能**
   - 收藏喜欢的媒体
   - 创建播放列表

---

## 📝 代码文件清单

### 新增文件
- `lib/src/models/media_library_models.dart` - 媒体库业务模型
- `lib/src/services/media_library_service.dart` - 媒体库服务

### 修改文件
- `lib/src/jellyfin_client.dart` - 添加mediaLibrary服务
- `lib/jellyfin_service.dart` - 导出新增模块

---

## ✅ 功能验证清单

- [x] 业务模型定义完成
- [x] 媒体库服务实现完成
- [x] 集成到主客户端
- [x] 导出配置完成
- [x] 代码编译通过
- [x] 功能文档完整

---

**状态**: ✅ 媒体库功能开发完成，可以开始使用！
