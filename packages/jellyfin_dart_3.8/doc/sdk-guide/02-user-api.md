# 02 用户管理 — UserApi

获取方式：`client.getUserApi()`

---

## authenticateUserByName — 用户名密码登录

```
POST /Users/AuthenticateByName
返回: Response<AuthenticationResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `authenticateUserByName` | AuthenticateUserByName | body | **是** | 登录请求体 |

**AuthenticateUserByName 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `username` | String? | 用户名 |
| `pw` | String? | 密码 |

**AuthenticationResult 返回字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `user` | UserDto? | 用户信息 |
| `accessToken` | String? | 访问令牌（设置到 client.setToken） |
| `serverId` | String? | 服务器 ID |

---

## authenticateWithQuickConnect — 快速连接登录

```
POST /Users/AuthenticateWithQuickConnect
返回: Response<AuthenticationResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `quickConnectDto` | QuickConnectDto | body | **是** | 快速连接请求体 |

**QuickConnectDto 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `secret` | String? | 快速连接密钥 |

---

## getCurrentUser — 获取当前用户

```
GET /Users/Me
返回: Response<UserDto>
```

无额外参数。需要已设置 Token。

---

## getUsers — 获取所有用户

```
GET /Users
返回: Response<List<UserDto>>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `isHidden` | bool? | query | 否 | 是否包含隐藏用户 |
| `isDisabled` | bool? | query | 否 | 是否包含已禁用用户 |

---

## getUserById — 按 ID 获取用户

```
GET /Users/{userId}
返回: Response<UserDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userId` | String | path | **是** | 用户 ID |

---

## getPublicUsers — 获取公开用户列表

```
GET /Users/Public
返回: Response<List<UserDto>>
```

无额外参数。无需认证即可调用。

---

## createUserByName — 创建用户

```
POST /Users/New
返回: Response<UserDto>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `createUserByName` | CreateUserByName | body | **是** | 创建用户请求体 |

**CreateUserByName 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | String? | 用户名 |
| `password` | String? | 密码 |

---

## deleteUser — 删除用户

```
DELETE /Users/{userId}
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userId` | String | path | **是** | 要删除的用户 ID |

---

## updateUser — 更新用户信息

```
POST /Users
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userDto` | UserDto | body | **是** | 完整的用户信息对象 |
| `userId` | String? | query | 否 | 用户 ID |

---

## updateUserConfiguration — 更新用户配置

```
POST /Users/Configuration
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userConfiguration` | UserConfiguration | body | **是** | 用户配置对象 |
| `userId` | String? | query | 否 | 用户 ID |

---

## updateUserPassword — 更新用户密码

```
POST /Users/Password
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `updateUserPassword` | UpdateUserPassword | body | **是** | 密码更新请求体 |
| `userId` | String? | query | 否 | 用户 ID |

**UpdateUserPassword 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `currentPw` | String? | 当前密码 |
| `newPw` | String? | 新密码 |
| `resetPassword` | bool? | 是否重置密码 |

---

## updateUserPolicy — 更新用户策略（权限）

```
POST /Users/{userId}/Policy
返回: Response<void>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `userId` | String | path | **是** | 用户 ID |
| `userPolicy` | UserPolicy | body | **是** | 用户策略对象（控制访问权限、媒体库访问等） |

---

## forgotPassword — 忘记密码

```
POST /Users/ForgotPassword
返回: Response<ForgotPasswordResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `forgotPasswordDto` | ForgotPasswordDto | body | **是** | 忘记密码请求体 |

**ForgotPasswordDto 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `enteredUsername` | String? | 用户名 |

---

## forgotPasswordPin — 使用 PIN 重置密码

```
POST /Users/ForgotPassword/Pin
返回: Response<PinRedeemResult>
```

| 参数 | 类型 | 位置 | 必填 | 说明 |
|------|------|------|------|------|
| `forgotPasswordPinDto` | ForgotPasswordPinDto | body | **是** | PIN 码请求体 |

**ForgotPasswordPinDto 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `pin` | String? | 收到的 PIN 码 |
