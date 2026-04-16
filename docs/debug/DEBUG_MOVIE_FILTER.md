# 电影过滤页面调试指南

## 问题：电影列表显示为空白

### 📋 调试步骤

#### 1. 打开浏览器控制台查看日志

当你在Chrome中运行应用时：
1. 按 `F12` 打开开发者工具
2. 切换到 "Console" 标签
3. 刷新页面，查看控制台输出

你应该能看到类似这样的日志：
```
🎬 MovieFilterPage initState
   Library ID: xxx
   Library Name: 电影
   Client: JellyfinClient(...)
   Filter created: MovieFilter(...)
🔄 开始加载电影...
   Library ID: xxx
   Filter: MovieFilter(...)
📡 调用 client.mediaLibrary.getMovies()...
```

#### 2. 检查常见问题

**问题A: 看不到日志**
- 可能原因：页面没有正确加载
- 解决：检查浏览器控制台是否有错误信息

**问题B: API调用失败**
- 日志会显示：`❌ 加载失败: ...`
- 可能原因：
  - 网络连接问题
  - Jellyfin服务器未运行
  - 认证token过期
  - 媒体库ID不正确

**问题C: API返回成功但列表为空**
- 日志会显示：`✅ API调用成功! 返回电影数量: 0`
- 可能原因：
  - 媒体库中没有电影
  - 权限问题
  - 过滤条件过于严格

#### 3. 手动测试API

在浏览器控制台中输入：
```javascript
// 查看当前的client和filter
console.log('Client:', window.flutter_app_client);
```

#### 4. 检查网络请求

在开发者工具中：
1. 切换到 "Network" 标签
2. 刷新页面
3. 查找对 `/Users/{userId}/Items` 的请求
4. 检查：
   - 请求状态码（应该是 200）
   - 响应内容（应该包含电影列表）

### 🔧 快速修复建议

#### 修复1: 检查媒体库ID

```dart
// 在main.dart中添加调试
MediaLibraryPage 中添加：
print('📚 点击媒体库: ${library.name}');
print('   ID: ${library.id}');
print('   Type: ${library.type}');
```

#### 修复2: 确保用户已登录

```dart
// 在跳转前检查认证状态
if (!client.isAuthenticated) {
  print('❌ 用户未认证!');
  return;
}
```

#### 修复3: 测试基础API调用

创建一个简单的测试页面：

```dart
// 测试页面
class TestPage extends StatelessWidget {
  final JellyfinClient client;

  const TestPage({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API测试')),
      body: FutureBuilder<void>(
        future: _testApi(),
        builder: (context, snapshot) {
          return Center(
            child: Text('测试完成，请查看控制台'),
          );
        },
      ),
    );
  }

  Future<void> _testApi() async {
    try {
      print('🧪 开始API测试...');

      // 测试1: 获取媒体库
      print('\n📚 测试1: 获取媒体库');
      final libraries = await client.mediaLibrary.getMediaLibraries();
      print('✅ 找到 ${libraries.libraries.length} 个媒体库');
      for (final lib in libraries.libraries) {
        print('   - ${lib.name} (${lib.type.name})');
      }

      // 测试2: 获取电影
      if (libraries.libraries.isNotEmpty) {
        final movieLib = libraries.libraries.first;
        print('\n🎬 测试2: 获取电影 from ${movieLib.name}');

        final filter = MovieFilter.defaultFilter(parentId: movieLib.id);
        print('   Filter: $filter');

        final movies = await client.mediaLibrary.getMovies(filter);
        print('✅ 找到 ${movies.items.length} 部电影');

        if (movies.items.isNotEmpty) {
          print('   第一部电影: ${movies.items.first.name}');
        }
      }

      print('\n✅ 所有测试完成!');
    } catch (e) {
      print('❌ 测试失败: $e');
    }
  }
}
```

### 🐛 常见错误和解决方案

#### 错误1: 401 Unauthorized
**原因**: 认证失败或token过期
**解决**: 重新登录

#### 错误2: 404 Not Found
**原因**: 媒体库ID不存在
**解决**: 检查媒体库列表，确认ID正确

#### 错误3: 空列表
**原因**: 媒体库为空或权限不足
**解决**:
1. 检查Jellyfin媒体库设置
2. 确认用户有访问权限
3. 尝试其他筛选条件

#### 错误4: 网络错误
**原因**: 无法连接到Jellyfin服务器
**解决**:
1. 确认服务器地址正确
2. 检查网络连接
3. 确认服务器正在运行

### 📝 调试日志说明

当你运行应用时，控制台会显示：

**正常流程**:
```
🎬 MovieFilterPage initState
   Library ID: 3227ce1e069754c594af25ea66d69fc7
   Library Name: 电影
   Client: JellyfinClient(...)
🔄 开始加载电影...
📡 调用 client.mediaLibrary.getMovies()...
✅ API调用成功!
   返回电影数量: 20
   总记录数: 150
   第一部电影: 阿凡达
✅ UI更新完成，显示 20 部电影
```

**错误流程**:
```
🔄 开始加载电影...
📡 调用 client.mediaLibrary.getMovies()...
❌ 加载失败: type 'Null' is not a subtype of type 'String'
```

### 🚀 下一步

1. 运行应用并查看控制台日志
2. 根据日志信息确定问题所在
3. 应用对应的修复方案
4. 重新测试

如果问题仍然存在，请：
1. 截图控制台日志
2. 复制完整的错误信息
3. 提供你的Jellyfin服务器信息
