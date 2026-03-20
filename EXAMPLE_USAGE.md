# Example应用使用说明

## 🎯 业务流程

Example应用实现了完整的Jellyfin媒体库业务流程：

### 1. 登录页面 → 2. 媒体库列表页面 → 3. 媒体库卡片展示

## 🚀 启动应用

### 方法1：使用启动脚本（推荐）
```bash
cd example
.\start.bat
```

### 方法2：手动启动
```bash
cd example
flutter run -d web-server --web-port 9996
```

### 方法3：使用媒体库测试脚本
```bash
cd example
.\start_media_library_test.bat
```

启动后访问：**http://localhost:9996**

## 📱 页面功能

### 🔐 登录页面 (LoginPage)

**功能：**
- 连接Jellyfin服务器
- 用户身份验证
- 登录成功后自动跳转

**输入字段：**
- 服务器地址（默认：http://localhost:8096）
- 用户名
- 密码

**业务逻辑：**
```dart
// 1. 创建客户端
final client = JellyfinClient(serverUrl: serverUrl);

// 2. 执行登录
final result = await client.auth.authenticate(
  username: username,
  password: password,
);

// 3. 跳转到媒体库页面
Navigator.pushReplacementNamed(
  context,
  '/media_libraries',
  arguments: {
    'client': client,
    'user': result.user,
  },
);
```

### 📚 媒体库列表页面 (MediaLibrariesPage)

**功能：**
- 显示所有媒体库的网格布局
- 自动加载媒体库列表
- 下拉刷新支持
- 登出功能

**UI特性：**
- AppBar显示用户名和登出按钮
- 浮动刷新按钮
- 网格布局（2列）
- 加载状态指示器
- 错误处理和重试机制

**业务逻辑：**
```dart
// 加载媒体库列表
final result = await client.mediaLibrary.getMediaLibraries();
setState(() {
  _mediaLibraries = result.libraries;
});
```

### 🎴 媒体库卡片 (MediaLibraryCard)

**显示内容：**
- 封面图片（通过API获取）
- 媒体库名称
- 类型图标（🎬📺🎵等）
- 类型名称（电影、电视剧、音乐等）
- 媒体项数量

**图片API：**
```dart
// 获取封面图片URL
String? coverUrl = library.getCoverImageUrl();
// 返回格式: http://localhost:8096/Items/{id}/Images/Primary?{tag}

// 获取背景图片URL
String? backdropUrl = library.getBackdropImageUrl();
// 返回格式: http://localhost:8096/Items/{id}/Images/Backdrop?{tag}
```

**卡片特性：**
- 如果有封面图片，显示网络图片
- 如果没有封面，显示彩色占位图（带图标和类型名称）
- 点击卡片有交互反馈
- 错误图片自动回退到占位图

## 🎨 UI设计

### 颜色方案
每个媒体库类型都有独特的颜色：
- 🎬 电影：#E53935 (红色)
- 📺 电视剧：#1E88E5 (蓝色)
- 🎵 音乐：#43A047 (绿色)
- 🎼 音乐视频：#FB8C00 (橙色)
- 📹 家庭视频：#8E24AA (紫色)
- 📦 电影合集：#F4511E (深橙色)
- 📁 其他：#757575 (灰色)

### 布局特点
- Material Design 3风格
- 响应式网格布局
- 卡片悬停效果
- 流畅的页面切换动画
- 渐变背景登录页面

## 🔄 数据流程

```
用户输入凭据
    ↓
调用 client.auth.authenticate()
    ↓
登录成功
    ↓
跳转到 /media_libraries
    ↓
调用 client.mediaLibrary.getMediaLibraries()
    ↓
获取媒体库列表
    ↓
每个MediaLibrary调用 getCoverImageUrl()
    ↓
渲染媒体库卡片（带图片）
```

## 📋 测试步骤

### 1. 准备环境
- ✅ 确保Jellyfin服务器运行在 http://localhost:8096
- ✅ 确保有有效的用户凭据

### 2. 启动应用
```bash
cd example
.\start.bat
```

### 3. 测试登录
1. 浏览器打开 http://localhost:9996
2. 输入服务器地址：`http://localhost:8096`
3. 输入用户名和密码
4. 点击"登录"按钮
5. 验证登录成功并跳转到媒体库页面

### 4. 测试媒体库功能
1. 查看媒体库网格布局
2. 验证每个卡片显示：
   - 封面图片（如果有）
   - 媒体库名称
   - 类型图标和名称
   - 数量信息
3. 点击卡片验证交互
4. 测试下拉刷新
5. 测试登出功能

## 🛠️ 技术实现

### 页面路由
```dart
// 路由配置
routes: {
  '/': (context) => const LoginPage(),
  '/media_libraries': (context) => const MediaLibrariesPage(),
}

// 页面跳转
Navigator.pushReplacementNamed(
  context,
  '/media_libraries',
  arguments: {'client': client, 'user': user},
);
```

### 图片加载
```dart
Image.network(
  library.getCoverImageUrl(),
  fit: BoxFit.cover,
  errorBuilder: (context, error, stackTrace) {
    return _buildPlaceholder(context);
  },
)
```

### 网格布局
```dart
GridView.builder(
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 1.2,
    crossAxisSpacing: 16,
    mainAxisSpacing: 16,
  ),
  itemCount: libraries.length,
  itemBuilder: (context, index) {
    return MediaLibraryCard(library: libraries[index]);
  },
)
```

## 🎯 下一步扩展

可以继续添加的功能：

1. **媒体项列表页面**
   - 点击媒体库卡片跳转到媒体项列表
   - 显示媒体项的详细信息

2. **搜索功能**
   - 搜索媒体库
   - 搜索媒体项

3. **播放功能**
   - 视频播放
   - 音乐播放

4. **用户偏好**
   - 收藏功能
   - 播放历史
   - 继续播放

## 📝 注意事项

1. **网络图片加载**：确保设备可以访问Jellyfin服务器
2. **错误处理**：应用已包含完整的错误处理机制
3. **性能优化**：图片加载使用了缓存和错误回退机制
4. **响应式设计**：支持不同屏幕尺寸

## 🎉 总结

Example应用展示了完整的业务流程：

✅ **登录认证** → **媒体库列表** → **卡片展示** → **图片加载**

这是一个完整的、可运行的Jellyfin媒体库管理应用示例！
