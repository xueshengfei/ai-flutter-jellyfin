# 08 图片管理 — ImageApi

获取方式：`client.getImageApi()`

ImageApi 是方法最多的 API 之一，涵盖媒体条目、艺术家、用户等多种实体的图片操作。

---

## 通用图片参数说明

以下参数在大多数图片 GET 方法中通用：

| 参数 | 类型 | 说明 |
|------|------|------|
| `maxWidth` | int? | 最大宽度（像素），超出则等比缩放 |
| `maxHeight` | int? | 最大高度（像素），超出则等比缩放 |
| `width` | int? | 固定宽度（强制拉伸） |
| `height` | int? | 固定高度（强制拉伸） |
| `quality` | int? | 图片质量（1-100），仅对有损格式有效 |
| `fillWidth` | int? | 填充宽度（不足则加黑边） |
| `fillHeight` | int? | 填充高度（不足则加黑边） |
| `tag` | String? | 图片标签（用于缓存控制） |
| `format` | ImageFormat? | 输出格式：`jpg`、`png`、`webp`、`gif` |
| `percentPlayed` | double? | 播放百分比（叠加播放进度条） |
| `unplayedCount` | int? | 未播放数量（叠加数字角标） |
| `blur` | int? | 模糊半径（像素） |
| `backgroundColor` | String? | 背景色（十六进制，如 FFFFFF） |
| `foregroundLayer` | String? | 前景层图片 URL |
| `imageIndex` | int? | 图片索引（同一类型有多张时使用） |

---

## 条目图片 (Item)

### getItemImageInfos — 获取条目的所有图片信息

```
GET /Items/{itemId}/Images
返回: Response<List<ImageInfo>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |

### getItemImage — 获取条目图片

```
GET /Items/{itemId}/Images/{imageType}
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |
| `imageType` | ImageType | path | **是** | 图片类型 |
| 其余为通用图片参数 | | | | |

**ImageType 枚举值：**

| 值 | 说明 |
|----|------|
| `primary` | 主图/海报 |
| `art` | 艺术图 |
| `backdrop` | 背景图 |
| `banner` | 横幅 |
| `logo` | Logo |
| `thumb` | 缩略图 |
| `disc` | 光盘图 |
| `box` | 包装盒 |
| `screenshot` | 截图 |
| `menu` | 菜单 |
| `chapter` | 章节 |
| `boxRear` | 包装盒背面 |
| `profile` | 用户头像 |

### setItemImage — 设置条目图片

```
POST /Items/{itemId}/Images/{imageType}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |
| `imageType` | ImageType | path | **是** | 图片类型 |
| `imageIndex` | int? | query | 否 | 图片索引 |

请求体为图片二进制数据。

### deleteItemImage — 删除条目图片

```
DELETE /Items/{itemId}/Images/{imageType}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |
| `imageType` | ImageType | path | **是** | 图片类型 |
| `imageIndex` | int? | query | 否 | 图片索引 |

### deleteItemImageByIndex — 删除指定索引的条目图片

```
DELETE /Items/{itemId}/Images/{imageType}/{imageIndex}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `itemId` | String | path | **是** | 条目 ID |
| `imageType` | ImageType | path | **是** | 图片类型 |
| `imageIndex` | int | path | **是** | 图片索引 |

---

## 用户头像 (User)

### getUserImage — 获取用户头像

```
GET /UserImage
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userId` | String? | query | 否 | 用户 ID（不传则使用当前认证用户） |
| 其余为通用图片参数 | | | | |

### setUserImage — 设置用户头像

```
POST /UserImage
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userId` | String? | query | 否 | 用户 ID |

请求体为图片二进制数据。

### deleteUserImage — 删除用户头像

```
DELETE /UserImage
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userId` | String? | query | 否 | 用户 ID |

---

## 艺术家图片 (Artist)

### getArtistImage — 获取艺术家图片

```
GET /Artists/{name}/Images/{imageType}/{imageIndex}
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `name` | String | path | **是** | 艺术家名称 |
| `imageType` | ImageType | path | **是** | 图片类型 |
| `imageIndex` | int | path | **是** | 图片索引 |
| 其余为通用图片参数 | | | | |

---

## 品牌启动画面 (Splashscreen)

### getSplashscreen — 获取启动画面

```
GET /Branding/Splashscreen
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `tag` | String? | query | 否 | 缓存标签 |
| `format` | ImageFormat? | query | 否 | 输出格式 |
| `maxWidth` | int? | query | 否 | 最大宽度 |
| `maxHeight` | int? | query | 否 | 最大高度 |
| `width` | int? | query | 否 | 固定宽度 |
| `height` | int? | query | 否 | 固定高度 |
| `fillWidth` | int? | query | 否 | 填充宽度 |
| `fillHeight` | int? | query | 否 | 填充高度 |
| `blur` | int? | query | 否 | 模糊半径 |
| `backgroundColor` | String? | query | 否 | 背景色 |
| `foregroundLayer` | String? | query | 否 | 前景层 |

### updateCustomSplashscreen — 上传自定义启动画面

```
POST /Branding/Splashscreen
返回: Response<void>
```

无参数，请求体为图片二进制数据。需要管理员权限。

### deleteCustomSplashscreen — 删除自定义启动画面

```
DELETE /Branding/Splashscreen
返回: Response<void>
```

无参数。

---

## 其他实体图片

以下实体的图片方法模式完全相同，只是 URL 路径不同：

| 实体 | 获取图片路径 | 说明 |
|------|-------------|------|
| Genre | `GET /Genres/{name}/Images/{imageType}/{imageIndex}` | 流派图片 |
| MusicGenre | `GET /MusicGenres/{name}/Images/{imageType}/{imageIndex}` | 音乐流派图片 |
| Person | `GET /Items/{name}/Images/{imageType}/{imageIndex}` | 人物图片 |
| Studio | `GET /Studios/{name}/Images/{imageType}/{imageIndex}` | 工作室图片 |
| User (带索引) | `GET /Users/{userId}/Images/{imageType}/{imageIndex}` | 用户图片（带索引） |
| Year | `GET /Years/{year}/Images/{imageType}/{imageIndex}` | 年份图片 |

每种实体都支持相同的通用图片参数（maxWidth、maxHeight、width、height、quality、fillWidth、fillHeight、tag、format、percentPlayed、unplayedCount、blur、backgroundColor、foregroundLayer）。

设置和删除方法也遵循相同的模式（POST 设置、DELETE 删除）。
