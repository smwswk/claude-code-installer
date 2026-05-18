---
name: 知乎抓取
description: 通过知乎答案 API 批量抓取高赞回答，绕过反爬验证
tags: [zhihu, api, scrape]
author: hermes-agent
license: MIT
---

# 知乎 API 批量抓取

## 核心发现

知乎的答案页面有 JSON API 可直接访问，无需登录、不触发反爬：

```
https://www.zhihu.com/api/v4/answers/{ANSWER_ID}?include=content,voteup_count,comment_count
```

返回结构化 JSON，包含：
- `content` — HTML 正文（需 strip tags）
- `voteup_count` — 点赞数
- `comment_count` — 评论数

## 请求头

```bash
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36
```

无需 Cookie。

## Python 示例

```python
import urllib.request, re, json

def fetch_answer(aid):
    url = f"https://www.zhihu.com/api/v4/answers/{aid}?include=content,voteup_count,comment_count"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'})
    with urllib.request.urlopen(req, timeout=10) as r:
        d = json.loads(r.read())
        content = re.sub(r'<[^>]+>', '', d.get('content', ''))
        content = content.replace('&amp;','&').replace('&lt;','<').replace('&gt;','>').replace('&quot;','"').replace('&#39;',"'")
        return d.get('voteup_count', 0), d.get('comment_count', 0), content
```

## HTML 实体解码对照

| 实体 | 字符 |
|------|------|
| `&amp;` | `&` |
| `&lt;` | `<` |
| `&gt;` | `>` |
| `&quot;` | `"` |
| `&#39;` | `'` |

## 反爬说明

- 浏览器直接访问 `zhihu.com/question/...` 会被反爬（返回密文 JS 校验）
- API 端点直接调则返回 JSON，不走浏览器检测，但**内容截断约 500 字**
- WebFetch、curl 页面、Playwright headless 均被拦截
- 建议每次 API 请求间隔 0.3s 以上，避免触发频率限制

## 问题页面的答案 ID 从哪来

用户分享的链接格式通常是：
```
https://www.zhihu.com/question/{QUESTION_ID}/answer/{ANSWER_ID}
```

答案 ID 就是链接最后那段数字。

---

## 批量筛选模式

当用户给出一批知乎链接并要求"筛选值得看的"、"过滤情绪和低认知"时，触发此模式。

### 触发词
- "筛一下这批知乎链接"
- "哪个值得看"
- "过滤情绪化"
- "低认知过滤"
- "帮我排一下这堆回答的优先级"

### 工具链

| 步骤 | 文件 | 作用 |
|------|------|------|
| 抓取 | `batch_fetch.py` (同目录) | 批量调 answers API，解析用户输入的 markdown 风格列表（标题+URL），输出 JSONL |
| 评分 | Claude 在对话中读 JSONL | 按三维度打分 |
| 输出 | `~/Documents/zhihu_filter/result_YYYY-MM-DD.html` | 卡片化 HTML，浏览器打开 |

### batch_fetch.py 用法

```bash
# 方式1：从文件
python3 batch_fetch.py < urls.txt > data.jsonl

# 方式2：从剪贴板
pbpaste | python3 batch_fetch.py > data.jsonl

# 输入格式：markdown 风格（与用户从知乎直接粘贴的列表一致）
标题A - 知乎
https://www.zhihu.com/question/123/answer/456

标题B - 知乎
https://www.zhihu.com/question/789/answer/101
```

输出字段：
- `idx` — 顺序号
- `type` — answer / article / unknown
- `title` — 从用户输入或 API 获取
- `url` — 原始链接
- `voteup` / `comment` — 计数
- `content` — HTML 已 strip，连续空白合并
- `skip_reason` — 专栏/未知 URL 的跳过说明

### 评分维度（用户已对齐的优先级，**不可擅自更改**）

三个维度 0–10，权重固定：

```
综合分 = 认知 × 0.5 + 兴趣域 × 0.3 + 反共识 × 0.2
```

| 维度 | 权重 | 评价标准 |
|------|------|----------|
| **认知含量** | 50% | 一手信息 / 数据 / 具体经验 / 结构化论证；排除口号/金句/情绪宣泄 |
| **兴趣域** | 30% | 与用户的画像域交集：摄影 / AI / 司法体制 / 虚构创作（小说/影像） |
| **反共识** | 20% | 不是迎合大众情绪的安慰剂；提供独立判断或反直觉视角 |

### 评分后输出格式

```
强推 · 综合 ≥ 6.0  →  卡片列表，每卡附 rank / 三维条形 / 推荐理由 / 原文 hook / 知乎链接
值得看 · 5.0–6.0  →  同上
未抓取 · zhuanlan  →  标题命中度高则提醒手动点开
过滤 · < 5.0       →  折叠列表，附具体过滤原因
```

HTML 写到 `~/Documents/zhihu_filter/result_YYYY-MM-DD.html`，`open` 浏览器打开，并用 `open -R` 揭示 Finder。

### 已知限制

1. **内容截断**：答案 API 默认返回约 500 字预览（`content_need_truncated: true`）。此筛选器只做"是否值得点开看"的预筛。如需全文，见下方「全文获取模式」。
2. **专栏无法抓**：`zhuanlan.zhihu.com/p/{id}` 在 API、HTML、WebFetch 三层均被反爬挡。脚本会标记 `skip_reason` 为 `"zhuanlan 反爬未抓正文"`；如果标题命中用户兴趣域（AI/摄影/创作），应单独提醒手动读。
3. **认知 ≠ voteup**：高赞回答常有情绪共鸣，不代表信息密度高。评分时不得把 voteup 当作加分项，甚至高赞+短内容可能应扣分。
4. **维度权重不可调**：用户已明确权重优先级（认知 > 兴趣域 > 反共识），后续不可随意改动。如用户要求改权重，先确认再执行。

---

## 全文获取模式（单篇深度消费）

当用户需要某篇回答的完整全文（而非批量筛选）时，API 截断不可绕过。需走以下路径：

### 触发条件
- 用户指定单篇知乎回答并要求"总结/碰撞/提取洞察"
- 内容引擎处理知乎链接时，评分 ≥ 6.0 的强推项需全文

### 五层尝试结论

| 方法 | 结果 |
|------|------|
| 答案 API (`/api/v4/answers/{id}`) | 截断 ~500 字，`content_need_truncated: true`，无参数可绕过 |
| segments API (`/api/v4/answers/{id}/segments`) | 仅返回用户高亮片段，非全文，可用于拼凑关键段落 |
| curl / WebFetch / Googlebot UA | 均触发 JS 挑战页面（zse_ck） |
| Playwright headless | 40362 异常访问限制 |
| **Chrome AppleScript** | **唯一可行方案** |

### 唯一可行方案：Chrome AppleScript

前提：Chrome 有知乎登录态（用户日常使用 Chrome 刷知乎即满足）。

```applescript
tell application "Google Chrome"
    tell window 1
        set newTab to make new tab with properties {URL:"目标URL"}
        delay 5  -- 等待页面加载
        execute active tab javascript "document.body.innerText"
    end tell
end tell
```

注意事项：
- Safari 的 `do JavaScript` 有 AppleScript 返回值 bug（"变量未定义"），**不可用**
- 需 `delay 5` 等页面渲染完成，网络慢时可加长
- 返回的是 `body.innerText`，包含页面 UI 文字（导航、推荐等），需手动分离正文
- 用完后可 `close tab` 清理

### segments API 辅助拼凑

当 Chrome 不可用时，segments API 可以获取用户高亮的关键段落（按 `global_offset` 排序），虽非全文但覆盖核心论点。结合截断正文 + segments 可还原约 60-70% 的内容结构。详见 [reference_zhihu_fulltext_bypass.md](../../.claude/projects/-USERNAME/memory/reference_zhihu_fulltext_bypass.md)。
