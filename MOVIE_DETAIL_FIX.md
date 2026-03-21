# 电影详情页修复 - 完整元数据获取

## 🔧 问题原因

之前的 API 调用没有指定 `fields` 参数，导致返回的数据不完整，缺少：
- ❌ Genres（类型）
- ❌ Studios（工作室）
- ❌ People（人员：导演、作者等）
- ❌ Overview（剧情简介）

## ✅ 修复方案

### 1. 添加 Fields 参数

在 `getMediaItemDetail()` 方法中添加 `fields` 参数：

```dart
final response = await itemsApi.getItems(
  userId: _apiClient.config.userId,
  ids: [itemId],
  fields: const [
    jellyfin_dart.ItemFields.genres,              // 类型
    jellyfin_dart.ItemFields.studios,             // 工作室
    jellyfin_dart.ItemFields.people,              // 人员
    jellyfin_dart.ItemFields.overview,            // 剧情简介
    jellyfin_dart.ItemFields.productionLocations, // 制作地点
  ],
);
```

### 2. 修复背景图片解析

支持两种背景图片标签格式：
- `ImageTags['Backdrop']`
- `BackdropImageTags` 数组

```dart
String? backdropTag;
if (backdropImageTags?['Backdrop'] != null) {
  backdropTag = backdropImageTags!['Backdrop'];
} else if (backdropTagsList != null && backdropTagsList.isNotEmpty) {
  backdropTag = backdropTagsList.first;
}
```

### 3. 添加调试日志

在服务和页面中添加详细的调试日志，方便排查问题。

## 🧪 测试方法

### 重启应用
```bash
flutter run -d web-server --web-port 9996
```

### 测试步骤
1. 登录
2. 点击"电影"媒体库
3. 点击任意电影（如"X战警：天启"）
4. 查看详情页，应该显示：
   - ✅ 背景海报图片
   - ✅ 电影标题、年份、评级、时长
   - ✅ 剧情简介
   - ✅ 类型标签（动作、科幻等）
   - ✅ 导演列表
   - ✅ 作者列表
   - ✅ 工作室列表

### 查看日志

在浏览器控制台（F12 → Console）会看到：
```
📄 MovieDetailPage: 显示电影详情
   名称: X战警：天启
   年份: 2016
   评分: 6.5
   类型数量: 3
   导演数量: 1
   作者数量: 2
   工作室数量: 2
```

## 📊 API 响应示例

修复后的 API 调用会返回完整数据：

```json
{
  "Name": "X战警：天启",
  "Overview": "在二十世纪六十年代...",
  "Genres": ["动作", "科幻", "冒险"],
  "Studios": [
    {"Name": "20世纪福克斯", "Id": "..."}
  ],
  "People": [
    {"Name": "布莱恩·辛格", "Type": "Director"},
    {"Name": "西蒙·金伯格", "Type": "Writer"}
  ],
  "ProductionYear": 2016,
  "OfficialRating": "PG-13",
  "CommunityRating": 6.5,
  "RunTimeTicks": 88400000000
}
```

## 🎯 预期结果

详情页应该显示完整的电影信息，与用户要求的"爱乐之城"示例一致：

```
┌─────────────────────────────────────┐
│    [背景海报图片]                   │
│    X战警：天启                      │
├─────────────────────────────────────┤
│ [海报]  X战警：天启                 │
│        2016 | PG-13 | 2小时27分钟   │
│                                      │
│ [▶ 播放]                            │
│                                      │
│ 剧情简介                             │
│ 在二十世纪六十年代...                │
│                                      │
│ 类型                                 │
│ [动作] [科幻] [冒险]                │
│                                      │
│ 评分                                 │
│ ⭐ 6.5                             │
│                                      │
│ 导演                                 │
│ [👤 布莱恩·辛格]                   │
│                                      │
│ 作者                                 │
│ [✏️ 西蒙·金伯格]                   │
│                                      │
│ 工作室                               │
│ [🏢 20世纪福克斯]                   │
└─────────────────────────────────────┘
```

## 🔍 故障排查

如果某些字段仍然不显示：

1. **检查浏览器控制台日志**
   - 查看 API 返回的原始数据
   - 确认字段是否为空

2. **检查 Jellyfin 元数据**
   - 在 Jellyfin 后台确认电影元数据已刮削
   - 使用元数据管理器刷新电影信息

3. **检查人员类型**
   - Jellyfin 使用 `Type` 字段区分人员角色
   - 可能的类型：`Director`, `Writer`, `Actor` 等

## ✅ 状态

- ✅ 代码已修复
- ✅ API 调用已优化
- ✅ 背景图片解析已修复
- ✅ 调试日志已添加
- ✅ 可以测试

立即重启应用即可看到完整信息！🎉
