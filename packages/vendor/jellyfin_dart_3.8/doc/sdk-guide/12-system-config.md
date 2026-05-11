# 12 系统与配置 — SystemApi / ConfigurationApi / StartupApi / BrandingApi

---

## SystemApi — 系统信息与控制

获取方式：`client.getSystemApi()`

### getPublicSystemInfo — 获取公开系统信息（无需认证）

```
GET /System/Info/Public
返回: Response<PublicSystemInfo>
```

无参数。

**PublicSystemInfo 返回字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `localAddress` | String? | 局域网地址 |
| `serverName` | String? | 服务器名称 |
| `version` | String? | 服务器版本 |
| `productName` | String? | 产品名称 |
| `operatingSystem` | String? | 操作系统 |
| `id` | String? | 服务器 ID |
| `startupWizardCompleted` | bool? | 初始设置是否完成 |

### getSystemInfo — 获取完整系统信息（需认证）

```
GET /System/Info
返回: Response<SystemInfo>
```

无参数。包含 PublicSystemInfo 的所有字段，以及更多内部信息。

### getEndpointInfo — 获取端点信息

```
GET /System/Endpoint
返回: Response<EndPointInfo>
```

无参数。

### getPingSystem / postPingSystem — 服务器心跳检测

```
GET /System/Ping    → Response<String>
POST /System/Ping   → Response<String>
```

无参数。返回字符串 "Jellyfin Server"。

### getServerLogs — 获取服务器日志列表

```
GET /System/Logs
返回: Response<List<LogFile>>
```

无参数。

**LogFile 返回字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `dateModified` | DateTime? | 修改日期 |
| `size` | int? | 文件大小（字节） |
| `name` | String? | 文件名 |

### getLogFile — 获取日志文件内容

```
GET /System/Logs/Log
返回: Response<Uint8List>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `name` | String | query | **是** | 日志文件名 |

### getSystemStorage — 获取系统存储信息

```
GET /System/Info/Storage
返回: Response<SystemStorageDto>
```

无参数。

### restartApplication — 重启服务器

```
POST /System/Restart
返回: Response<void>
```

无参数。需要管理员权限。

### shutdownApplication — 关闭服务器

```
POST /System/Shutdown
返回: Response<void>
```

无参数。需要管理员权限。

---

## ConfigurationApi — 服务器配置

获取方式：`client.getConfigurationApi()`

### getConfiguration — 获取服务器配置

```
GET /System/Configuration
返回: Response<ServerConfiguration>
```

无参数。

**ServerConfiguration 关键字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `logFileRetentionDays` | int? | 日志保留天数 |
| `isStartupWizardCompleted` | bool? | 初始设置是否完成 |
| `cachePath` | String? | 缓存路径 |
| `previousVersion` | String? | 上一版本号 |
| `enableMetrics` | bool? | 是否启用指标 |
| `enableNormalizedItemByNameIds` | bool? | 启用名称标准化 ID |
| `metadataPath` | String? | 元数据路径 |
| `preferredMetadataLanguage` | String? | 首选元数据语言 |
| `metadataCountryCode` | String? | 元数据国家代码 |
| `sortReplaceCharacters` | List\<String\>? | 排序替换字符 |
| `sortRemoveCharacters` | List\<String\>? | 排序移除字符 |
| `sortRemoveWords` | List\<String\>? | 排序移除词 |
| `minResumePct` | int? | 最小恢复播放百分比 |
| `maxResumePct` | int? | 最大恢复播放百分比 |
| `minResumeDurationSeconds` | int? | 最小恢复播放时长 |
| `minAudiobookResume` | int? | 有声书最小恢复时长 |
| `maxAudiobookResume` | int? | 有声书最大恢复百分比 |
| `inactiveSessionThreshold` | int? | 非活跃会话超时（分钟） |
| `libraryMonitorDelay` | int? | 媒体库监控延迟 |
| `libraryScanFanoutConcurrency` | int? | 扫描并发数 |
| `imageSavingConvention` | ImageSavingConvention? | 图片保存规范 |
| `skipDeserializationForBasicTypes` | bool? | 跳过基本类型反序列化 |
| `metadataSavers` | List\<string>? | 元数据保存器 |
| `metadataFetchers` | List\<string>? | 元数据获取器 |
| `imageFetchers` | List\<string>? | 图片获取器 |

### updateConfiguration — 更新服务器配置

```
POST /System/Configuration
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `serverConfiguration` | ServerConfiguration | body | **是** | 完整的服务器配置对象 |

### getNamedConfiguration — 获取指定名称的配置

```
GET /System/Configuration/{key}
返回: Response<Object>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `key` | String | path | **是** | 配置键名（如 "encoding"、"dlna"、"networking"） |

### updateNamedConfiguration — 更新指定名称的配置

```
POST /System/Configuration/{key}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `key` | String | path | **是** | 配置键名 |
| `body` | Object | body | **是** | 配置内容 |

---

## StartupApi — 初始设置

获取方式：`client.getStartupApi()`

用于 Jellyfin 首次安装后的初始设置流程。

### getStartupConfiguration — 获取初始配置

```
GET /Startup/Configuration
返回: Response<StartupConfigurationDto>
```

无参数。

### updateInitialConfiguration — 更新初始配置

```
POST /Startup/Configuration
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `startupConfigurationDto` | StartupConfigurationDto | body | **是** | 初始配置 |

**StartupConfigurationDto 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `uiCulture` | String? | UI 语言 |
| `metadataCountryCode` | String? | 元数据国家 |
| `preferredMetadataLanguage` | String? | 首选元数据语言 |

### setRemoteAccess — 配置远程访问

```
POST /Startup/RemoteAccess
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `startupRemoteAccessDto` | StartupRemoteAccessDto | body | **是** | 远程访问配置 |

**StartupRemoteAccessDto 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `enableRemoteAccess` | bool? | 是否启用远程访问 |
| `enableAutomaticPortMapping` | bool? | 是否启用自动端口映射（UPnP） |

### getFirstUser — 获取初始用户

```
GET /Startup/User
返回: Response<StartupUserDto>
```

无参数。

### setFirstUser — 设置初始用户

```
POST /Startup/User
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `startupUserDto` | StartupUserDto | body | **是** | 初始用户信息 |

**StartupUserDto 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | String? | 用户名 |
| `password` | String? | 密码 |

### completeStartup — 完成初始设置

```
POST /Startup/Complete
返回: Response<void>
```

无参数。

---

## BrandingApi — 品牌定制

获取方式：`client.getBrandingApi()`

### getBrandingCss — 获取品牌 CSS

```
GET /Branding/Css
返回: Response<String>
```

无参数。返回自定义 CSS 字符串。

### setBrandingCss — 设置品牌 CSS

```
POST /Branding/Css
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `body` | String? | body | 否 | CSS 内容 |

### getBrandingOptions — 获取品牌选项

```
GET /Branding/Configuration
返回: Response<BrandingOptions>
```

无参数。

### setBrandingOptions — 设置品牌选项

```
POST /Branding/Configuration
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `brandingOptions` | BrandingOptions | body | **是** | 品牌选项 |

**BrandingOptions 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `loginDisclaimer` | String? | 登录页免责声明 |
| `customCss` | String? | 自定义 CSS |
| `splashscreenEnabled` | bool? | 是否启用启动画面 |
