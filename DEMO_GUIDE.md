# 媒体项列表功能演示指南

## 🎬 快速开始

### 方法一：使用启动脚本（推荐）
双击运行 `start_example.bat` 文件

### 方法二：手动启动
```bash
cd example
flutter run
```

---

## 📱 演示流程

### 1️⃣ 登录页面
应用启动后会显示登录界面，预填信息：
- **服务器地址**：http://localhost:8096
- **用户名**：xue13
- **密码**：123456

点击"登录"按钮，等待认证成功。

**预期结果**：
- 显示"正在登录..."加载状态
- 认证成功后自动跳转到媒体库页面

---

### 2️⃣ 媒体库列表页面
登录成功后，会看到所有可用的媒体库卡片：

**界面元素**：
- 🎬 电影库
- 📺 电视剧库
- 🎵 音乐库
- 其他自定义媒体库

**功能**：
- 每个卡片显示封面、名称、类型、媒体项数量
- 下拉刷新媒体库列表
- 右上角显示当前用户名
- 右上角登出按钮

**操作**：
- 点击任意媒体库卡片（例如"电影"库）

---

### 3️⃣ 媒体项列表页面
点击媒体库卡片后，会进入该媒体库的媒体项列表页面：

**界面布局**：
- 3列网格卡片布局
- 每个卡片显示：
  - 封面图片
  - 媒体标题
  - 制作年份
  - 社区评分（⭐ X.X）

**功能**：
- 下拉刷新媒体项列表
- 浮动刷新按钮（右下角）
- 显示媒体项总数
- 加载指示器
- 错误处理和重试

**交互**：
- 点击媒体项卡片：显示SnackBar提示
- 下拉：刷新列表
- 点击浮动按钮：刷新列表

---

## 🎨 UI效果预览

### 媒体项卡片设计
```
┌───────────────────┐
│                   │
│    [封面图片]      │  ← 使用JellyfinImageWithClient
│                   │     带认证的图片加载
│                   │
├───────────────────┤
│ 🎬 电影标题       │
│ 2024 | ⭐ 7.8     │
└───────────────────┘
```

### 页面导航流程
```
登录页面
   ↓ (认证成功)
媒体库列表
   ↓ (点击媒体库卡片)
媒体项列表 (当前页面)
   ↓ (待实现)
媒体项详情
```

---

## 🔍 功能验证清单

### ✅ 基础功能
- [ ] 应用成功启动
- [ ] 登录成功并跳转
- [ ] 媒体库列表正常显示
- [ ] 媒体库卡片可点击

### ✅ 媒体项列表
- [ ] 媒体项列表正常加载
- [ ] 封面图片正确显示
- [ ] 媒体信息完整显示
- [ ] 总数量显示正确

### ✅ 交互功能
- [ ] 下拉刷新功能正常
- [ ] 浮动按钮刷新正常
- [ ] 点击媒体项有反馈
- [ ] 错误处理正常显示

### ✅ 性能表现
- [ ] 图片加载速度快
- [ ] 列表滚动流畅
- [ ] 内存占用正常

---

## 🐛 常见问题

### 问题1：图片无法加载
**可能原因**：
- 访问令牌未正确传递
- 网络连接问题

**解决方案**：
```dart
// 检查JellyfinImageWithClient是否正确传递了client
JellyfinImageWithClient(
  client: client,  // 确保client已认证
  itemId: item.id,
  imageTag: item.primaryImageTag,
)
```

### 问题2：媒体项为空
**可能原因**：
- 媒体库ID不正确
- 媒体库中没有内容

**解决方案**：
- 检查控制台日志
- 确认Jellyfin服务器上有内容
- 查看返回的totalCount

### 问题3：路由跳转失败
**可能原因**：
- 参数传递不正确

**解决方案**：
```dart
// 确保正确传递client和library
Navigator.pushNamed(
  context,
  '/media_items',
  arguments: {
    'client': _client,
    'library': _mediaLibraries[index],
  },
);
```

---

## 📊 日志输出示例

### 正常流程日志
```
🚀 开始登录流程...
   服务器: http://localhost:8096
   用户名: xue13
✅ 客户端创建成功
🔐 正在认证...
✅ 认证成功!
   用户: xue13
   用户ID: xxx
🔄 开始页面跳转到 /media_libraries...
✅ 页面跳转完成

📺 MediaLibrariesPage didChangeDependencies 调用
✅ 接收到参数:
   client: JellyfinClient
   user: UserProfile
📚 开始加载媒体库...
📡 调用 client.mediaLibrary.getMediaLibraries()...
✅ 媒体库获取成功!
   媒体库数量: 3

🖱️ 点击了媒体库: 电影
📺 MediaItemsPage 初始化: 电影
📡 调用 client.mediaLibrary.getMediaItems()...
✅ 媒体项获取成功!
   媒体项数量: 50
```

---

## 🎯 测试建议

### 基础测试
1. 启动应用并登录
2. 查看媒体库列表
3. 点击不同类型的媒体库（电影、剧集、音乐）
4. 验证媒体项正确显示

### 图片加载测试
1. 检查有封面的媒体项
2. 检查无封面的媒体项（显示占位符）
3. 快速滚动测试图片加载性能

### 错误处理测试
1. 断网后刷新（显示错误提示）
2. 点击重试按钮（恢复连接后）
3. 空媒体库（显示空状态）

---

## ✨ 下一步计划

### 当前已完成 ✅
- [x] 媒体项列表展示
- [x] 网格卡片布局
- [x] 认证图片加载
- [x] 下拉刷新
- [x] 错误处理

### 待实现 🚧
- [ ] 媒体项详情页面
- [ ] 滚动加载更多
- [ ] 搜索和筛选
- [ ] 媒体播放功能
- [ ] 收藏和标记

---

## 📝 代码参考

### 关键文件位置
- **业务模型**：`lib/src/models/media_item_models.dart`
- **服务方法**：`lib/src/services/media_library_service.dart`
- **UI组件**：`example/lib/media_item_card.dart`
- **列表页面**：`example/lib/media_items_page.dart`
- **路由配置**：`example/lib/main.dart`

### 核心代码片段
```dart
// 获取媒体项列表
final result = await client.mediaLibrary.getMediaItems(
  parentId: library.id,
  recursive: true,
  limit: 50,
);

// 导航到媒体项列表
Navigator.pushNamed(
  context,
  '/media_items',
  arguments: {
    'client': client,
    'library': library,
  },
);
```

---

## 🎉 享受使用！

所有功能已完成集成，现在可以体验完整的媒体库到媒体项的导航流程了！

如有问题，请查看：
- 控制台日志输出
- MEDIA_ITEMS_INTEGRATION.md 集成文档
- verify_integration.sh 验证脚本
