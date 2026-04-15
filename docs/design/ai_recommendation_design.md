# AI 挑片 — 架构设计文档

## 一、功能概述

用户在媒体库主页点击「AI 挑片」按钮，进入对话式推荐页面。输入自然语言描述想看的内容（如"想看关于权谋的历史剧"），系统通过 AI Agent 分析意图后，从 Jellyfin 媒体库中搜索匹配内容并智能排序推荐。点击推荐卡片可跳转到已有的媒体详情页。

---

## 二、整体架构

```
┌────────────┐                 ┌──────────────┐                 ┌──────────────┐
│  Flutter    │   ① 用户提问    │   AI Agent   │   ③ 搜索策略    │              │
│  Client     │ ──────────────→ │   Server     │ ──────────────→ │  Flutter     │
│  (UI层)     │ ←────────────── │  (纯AI推理)  │ ←────────────── │  Client      │
│             │   ② 策略响应    │              │   ④ 候选数据    │  (数据层)     │
│             │                 │              │                 │              │
│             │   ⑦ 最终推荐    │              │   ⑤ 排序请求    │              │
│             │ ←────────────── │              │ ──────────────→ │              │
│             │                 │              │   ⑥ 排序结果    │              │
└────────────┘                 └──────────────┘                 └──────┬───────┘
                                                                       │
                                                                       │ Jellyfin API
                                                                       ↓
                                                               ┌──────────────┐
                                                               │   Jellyfin   │
                                                               │   Server     │
                                                               └──────────────┘
```

**核心原则：客户端是中间层，复用已有的 Jellyfin API 封装。Agent 只做 AI 推理，不碰 Jellyfin。**

---

## 三、职责划分

### 客户端（Flutter）

| 职责 | 说明 |
|------|------|
| UI 渲染 | 对话气泡、推荐卡片、加载状态 |
| 流程编排 | 两轮调用 Agent + 调 Jellyfin API |
| Jellyfin 交互 | 复用 `MediaLibraryService` 现有方法 |
| 数据解析 | 将 Agent 返回的 ItemId 映射到真实 MediaItem |

### Agent 服务端

| 职责 | 说明 |
|------|------|
| 意图分析 | 解析自然语言，提取搜索条件 |
| 搜索策略 | 返回 genres、types、keywords |
| 智能排序 | 对候选结果打分排序，生成推荐理由 |
| 无 Jellyfin 依赖 | 不需要知道 Jellyfin 的存在 |

---

## 四、数据流（两轮交互）

```
用户输入: "想看权谋历史剧"

═══════════════ 第一轮：获取搜索策略 ═══════════════

Client → Agent:
POST /api/ai/search-strategy
{
  "query": "想看权谋历史剧"
}

Agent → Client:
{
  "searchGenres": ["历史", "政治", "战争"],
  "searchTypes": ["Series", "Movie"],
  "keywords": ["权谋", "朝堂", "帝王"],
  "explanation": "正在为你搜索历史、政治、战争类型的影视作品..."
}

═══════════════ 客户端搜索 Jellyfin ═══════════════

Client 调用 MediaLibraryService.searchMediaItems(
  genres: ["历史", "政治", "战争"],
  includeItemTypes: [BaseItemKind.series, BaseItemKind.movie],
)
→ 获得候选 MediaItem 列表

═══════════════ 第二轮：AI 排序推荐 ═══════════════

Client → Agent:
POST /api/ai/rank
{
  "originalQuery": "想看权谋历史剧",
  "candidates": [
    {
      "itemId": "abc123",
      "name": "大明王朝1566",
      "overview": "明朝嘉靖年间...",
      "communityRating": 9.2,
      "genres": ["历史", "剧情"],
      "productionYear": 2007,
      "type": "Series"
    },
    ...
  ]
}

Agent → Client:
{
  "message": "为你推荐以下权谋历史剧：",
  "recommendations": [
    {
      "itemId": "abc123",
      "reason": "经典历史权谋剧，讲述明朝嘉靖年间的政治斗争",
      "relevanceScore": 0.95
    },
    ...
  ]
}

═══════════════ 渲染结果 ═══════════════

Client 用已有 MediaItem 数据 + Agent 的 reason/score 渲染卡片
点击卡片 → 跳转 MediaItemDetailPage
```

---

## 五、数据模型

### 5.1 请求/响应模型

```dart
// ─── 第一轮：搜索策略 ───

class AiSearchStrategyRequest {
  String query;  // 用户原始提问
}

class AiSearchStrategyResponse {
  List<String> searchGenres;   // ["历史", "政治", "战争"]
  List<String> searchTypes;    // ["Series", "Movie"]
  List<String> keywords;       // ["权谋", "朝堂"]
  String explanation;          // 给用户的提示文案
}

// ─── 第二轮：排序推荐 ───

class AiCandidateItem {
  String itemId;
  String name;
  String? overview;
  double? communityRating;
  List<String>? genres;
  int? productionYear;
  String? type;
}

class AiRankRequest {
  String originalQuery;
  List<AiCandidateItem> candidates;
}

class AiRecommendResponse {
  String message;                    // Agent 回复文案
  List<AiRecommendedItem> recommendations;
}

class AiRecommendedItem {
  String itemId;                     // Jellyfin ItemId
  String reason;                     // 推荐理由
  double? relevanceScore;            // 相关度 0-1
}

// ─── UI 模型 ───

class AiChatMessage {
  String content;
  bool isUser;
  DateTime timestamp;
  List<AiRecommendedItem> recommendations;
  List<MediaItem>? resolvedItems;    // 已解析的真实媒体项
}
```

---

## 六、服务层设计（解耦）

### 6.1 抽象接口

```dart
/// Agent 客户端抽象（解耦具体实现）
abstract class AiAgentClient {
  Future<AiSearchStrategyResponse> getSearchStrategy(
    AiSearchStrategyRequest request,
  );
  Future<AiRecommendResponse> rankResults(AiRankRequest request);
}
```

### 6.2 实现类

| 类名 | 用途 |
|------|------|
| `MockAiAgentClient` | Mock 实现，验证 UI 流程 |
| `HttpAiAgentClient` | 真实 HTTP 调用（后端就绪后启用） |

### 6.3 编排服务

```dart
class AiRecommendationService {
  final AiAgentClient agentClient;

  /// 完整推荐流程（客户端编排两轮交互）
  Future<AiRecommendResponse> recommend({
    required String query,
    required Future<List<MediaItem>> Function({
      required List<String> genres,
      required List<String> types,
    }) searchMedia,
  });
}
```

`searchMedia` 回调由调用方（页面）注入，服务层完全不知道 Jellyfin 的存在。

---

## 七、目录结构

```
lib/src/
├── models/
│   └── ai_recommendation_models.dart    ← 数据模型
├── services/
│   └── ai_recommendation_service.dart   ← 抽象接口 + 编排服务 + Mock/HTTP 实现
├── ui/
│   └── pages/
│       ├── ai_recommend_page.dart       ← AI 挑片页面
│       └── media_libraries_page.dart    ← 入口按钮（已改）
└── jellyfin_service.dart                ← 导出（已改）
```

---

## 八、UI 设计

### 8.1 入口

媒体库主页 AppBar 左侧添加 `auto_awesome` 图标按钮，tooltip 为「AI 挑片」。

### 8.2 AI 挑片页面

```
┌──────────────────────────────┐
│  ← AI 挑片            🗑️    │  AppBar
├──────────────────────────────┤
│                              │
│    ✨                        │
│    告诉我你想看什么           │  空状态
│    例如："想看关于权谋的历史剧"│
│                              │
│  [历史权谋剧] [职场提升]     │  快捷标签
│  [高分经典]   [轻松解压]     │
│                              │
├──────────────────────────────┤
│                              │
│         ┌──────────────┐     │
│         │ 想看权谋历史剧│     │  用户气泡（右对齐）
│         └──────────────┘     │
│ ┌──────────────────────┐     │
│ │ 正在搜索历史/政治类型 │     │  Agent 策略提示
│ └──────────────────────┘     │
│ ┌──────────────────────┐     │
│ │ 为你推荐：           │     │
│ │ ┌────┐ ┌────┐ ┌────┐│     │  Agent 回复 + 卡片
│ │ │封面│ │封面│ │封面││     │
│ │ │名字│ │名字│ │名字││     │
│ │ │理由│ │理由│ │理由││     │
│ │ └────┘ └────┘ └────┘│     │
│ └──────────────────────┘     │
├──────────────────────────────┤
│ [想看点什么？          ] [➤] │  输入区域
└──────────────────────────────┘
```

### 8.3 交互细节

- 输入框 `TextInputAction.send`，回车直接发送
- 快捷标签点击直接发送
- 推荐卡片横向滚动，显示封面 + 标题 + 推荐理由 + 相关度进度条
- 点击卡片跳转到 `MediaItemDetailPage`
- 右上角清空按钮重置对话
- 加载中显示 "正在为你挑选..." 带动画

---

## 九、后端 Agent API 契约

### 9.1 获取搜索策略

```
POST /api/ai/search-strategy
Content-Type: application/json

Request:
{
  "query": "想看权谋历史剧"
}

Response 200:
{
  "searchGenres": ["历史", "政治", "战争"],
  "searchTypes": ["Series", "Movie"],
  "keywords": ["权谋", "朝堂", "帝王"],
  "explanation": "正在为你搜索历史、政治、战争类型的影视作品..."
}
```

### 9.2 排序推荐

```
POST /api/ai/rank
Content-Type: application/json

Request:
{
  "originalQuery": "想看权谋历史剧",
  "candidates": [
    {
      "itemId": "abc123",
      "name": "大明王朝1566",
      "overview": "...",
      "communityRating": 9.2,
      "genres": ["历史", "剧情"],
      "productionYear": 2007,
      "type": "Series"
    }
  ]
}

Response 200:
{
  "message": "为你推荐以下权谋历史剧：",
  "recommendations": [
    {
      "itemId": "abc123",
      "reason": "经典历史权谋剧，讲述明朝嘉靖年间的政治斗争",
      "relevanceScore": 0.95
    }
  ]
}
```

---

## 十、MediaLibraryService 新增方法

```dart
/// 跨媒体库通用搜索（供 AI 推荐使用）
///
/// 按 genres 和 includeItemTypes 在所有媒体库中递归搜索
Future<MediaItemListResult> searchMediaItems({
  List<String>? genres,
  List<String>? includeItemTypes,  // "Movie", "Series" 等
  String? searchTerm,
  int? limit,
})
```

底层调用 Jellyfin `getItems` API，不指定 `parentId` 即跨库搜索。

---

## 十一、Mock 模式说明

当前 `MockAiAgentClient` 根据 query 关键词模拟返回：

| 关键词 | 返回的搜索策略 |
|--------|---------------|
| 历史/权谋/王朝 | genres: ["历史", "政治", "战争"], types: ["Series", "Movie"] |
| 职场/认知/提升 | genres: ["剧情", "纪录片"], types: ["Movie", "Series"] |
| 默认 | genres: ["剧情"], types: ["Movie", "Series"] |

Mock 的第二轮 `rankResults` 会对传入的 candidates 直接返回前几个，附加通用推荐理由。

后端就绪后，替换为 `HttpAiAgentClient(agentApiUrl: 'http://your-agent:8000')` 即可。

---

## 十二、集成指南（后端就绪时）

### 步骤

1. **Agent 部署**：启动 Agent 服务，暴露 `/api/ai/search-strategy` 和 `/api/ai/rank`
2. **替换客户端**：
   ```dart
   // 从 Mock 切换到 HTTP
   final agentClient = HttpAiAgentClient(agentApiUrl: 'http://your-agent:8000');
   final service = AiRecommendationService(agentClient: agentClient);
   ```
3. **验证**：输入测试 query，确认两轮交互正常
4. **调优**：根据 Agent 返回的 genres 和 Jellyfin 实际媒体库的 genres 做映射对齐

### 注意事项

- Agent 返回的 `searchGenres` 需要与 Jellyfin 媒体库中实际配置的 genres 名称一致
- Agent 返回的 `searchTypes` 值为 Jellyfin 的 `BaseItemKind` 枚举名称（Movie, Series, Episode 等）
- `itemId` 必须是 Jellyfin 中的真实 ItemId，客户端用此 ID 获取详情和封面
