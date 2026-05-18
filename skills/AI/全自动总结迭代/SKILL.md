---
name: 全自动总结迭代
description: >
  统一入口：AI资讯日报 / 小宇宙播客 / B站视频 / 小红书笔记 / 知乎回答 / 公众号文章 / 通用音视频 → 自动路由到对应摄入skill →
  观点提炼 → Memory嵌入（或审核队列）。确保"总结→提取洞察→写入记忆"这条链路每次必跑完，
  不再因上下文耗尽而断裂。同时也作为会话启动时的待审核队列检查入口。
  支持单条即时消费和批量（来自内容引擎/提醒事项处理）两种模式。
---

# 全自动总结+迭代

统一调度层。用户发来任何内容链接（单条）或批量 summary.md（来自内容引擎），走本 skill 统一入口，
保证摄入→提炼→记忆三步不断链。碰撞/记忆/选题/排期在此统一管理，不分散到子 skill。

## 核心原则

**七类内容统一入口，摄入后必须走完提炼+记忆。单条和批量两种模式，碰撞+记忆+选题+排期统一管。**

## 入口判断

加载本 skill 时先判断输入类型：

- **输入为 URL 链接** → 第一步：按路由表分发
- **输入为 summary.md 文件路径列表**（来自内容引擎 hand-off 或提醒事项处理批量结果）→ 跳过第一步和第二步，直接进入第三步（批量模式：逐篇提取洞察 → 合并去重 → 统一碰撞）

## 第一步：识别内容类型并路由

| 用户输入特征 | 内容类型 | 路由目标 |
|---|---|---|
| 说"AI日报""AI圈""AI资讯""AI HOT""最近AI"等，无链接 | AI资讯日报 | 调用 `AI资讯日报` skill |
| `xiaoyuzhoufm.com/episode/` 链接 | 小宇宙播客 | 调用 `小宇宙总结` skill |
| `bilibili.com/video/BV` 链接 | B站视频 | 调用 `B站视频总结` skill |
| `xhslink.com` / `xiaohongshu.com` 链接 / 小红书分享文本 | 小红书笔记 | 调用 `小红书总结` skill |
| `zhihu.com/question/` / `zhihu.com/answer/` 链接 | 知乎回答 | 调用 `知乎抓取` skill |
| `youtube.com` / `youtu.be` / 本地音视频文件路径 | 通用音视频 | 调用 `音视频总结` skill |
| `mp.weixin.qq.com` 链接 | 公众号文章 | 两层降级抓取：Jina Reader API → url-md (wexin-read-mcp) |

路由动作：用 Skill 工具调用对应子 skill，它会加载完整工作流指令。

### 公众号文章特殊处理（无子 skill，内联两层降级）

公众号文章没有独立子 skill，由本 skill 内联处理抓取：

1. **第一层 Jina Reader**：`curl -s https://r.jina.ai/<url>` → 获得 markdown
2. **失败则第二层 wexin-read-mcp**：调用 MCP 工具 `read_weixin_article(url)` → 返回 `{title, author, content}`
3. **两层都失败** → 标记为人工处理
4. **成功** → 写入 `~/Documents/article_summaries/summary_{日期}_wechat.md` → 继续第三步 memory 管道

## 两种模式

### 模式 A：单条即时消费

用户直接发一个链接 → 路由到子 skill → 摄入 → 第三步（提炼+记忆）。适用于日常偶发消费。

### 模式 B：批量消化（来自内容引擎/提醒事项处理）

输入为多篇 summary.md 文件路径列表（内容引擎 Phase 4 产出，或提醒事项处理批量处理结果）。本 skill 跳过路由和摄入步骤，直接进入第三步：

1. 逐篇读取 summary.md → 提取候选洞察
2. 合并去重所有批次的候选洞察
3. 统一碰撞检测（与已有 memory 体系对比）
4. 后续流程与模式 A 相同（审核队列/交互式 → 写入 → 选题 → 排期）

内容引擎 hand-off 时传入 `来源标记: "内容引擎 Batch{N}"`，帮助追踪洞察来源。

## 第二步：等待子 skill 完成摄入

子 skill 会完成：下载→转录→写 summary.md→Effie/Finder 展示。
公众号文章由上述内联处理完成后写入 summary.md。

确认子 skill 的 summary.md 已保存后，进入第三步。

## 第三步：观点提炼与 Memory 嵌入（强制，不可跳过）

这是本 skill 的核心价值——确保每个子 skill 跑完后，提炼步骤不会因上下文耗尽而被丢弃。

### 3.1 从 summary.md 提取候选洞察

读取子 skill 生成的 summary.md，识别两类内容：

**A. 用户项目相关的 actionable insights**（对应子 skill 各自的 A 类标准）
- 关联用户活跃项目：摄影/生图、视频/影像化、小说/文学、播客/BD、婚纱样片、工作流/自动化、创业/商业
- 提取标准：新工具/新模型/新workflow/方法论/案例/数据

**B. 能迭代 AI 成长的方法论**
- LLM 使用技巧、prompt 工程、agent/MCP 新模式
- 人与 AI 协作的工作流改进
- 能改进 Claude 执行效率的新认知

### 3.2 碰撞检测（结点成网）

提取候选洞察后，运行碰撞检测——与已有 memory 做语义匹配，发现信号重叠。

**步骤**:
1. 将候选洞察按 `insight_extract_template.md` 的 JSON 格式结构化
2. 运行 `bash ~/.claude/scripts/insight_collision.sh '<json>'` 获取 memory 文件清单
3. 对每个候选洞察，读取与其 tags 相关的 memory 文件（3-5 个最相关的），判断碰撞强度

**碰撞强度**:
- **HIGH**: 主张相同或直接相关——该洞察是对已有记忆的深化/验证/反驳
- **MEDIUM**: 主题重叠但角度不同——该洞察和已有记忆在同一个话题域但观点互补
- **LOW/无**: 标签相关但实质无关

**输出**: 每个候选洞察附加碰撞信息，格式：
```
[碰撞: HIGH → feedback_be_bold.md] 这个洞察和"胆子要大"记忆直接相关，提供了新的验证案例
[碰撞: MEDIUM → project_ai_landing_role.md] 重叠话题：AI落地，但角度不同
[碰撞: 无]
```

**碰撞信息在后续交互中展示给用户**，帮助判断哪些洞察值得深化。

### 3.3 判断上下文充足性

- **上下文充裕**（token 用量 < 60%）→ 走 3.4 交互式选择
- **上下文紧张**（token 用量 ≥ 60%）→ 走 3.5 审核队列
- **多个内容连续处理**时，每个处理完都跑一次 3.3 判断

### 3.4 交互式选择（上下文充裕时）

用 AskUserQuestion 展示候选（含碰撞信息）：
- 从 A 类筛选 4-8 条，multiSelect: true
- 选项格式：`[项目名] 观点摘要 → 建议写入 xxx.md [碰撞: HIGH → xxx.md]`
- 用户选择后立即 append 到对应 memory 文件
- 从 B 类直接输出 2-3 条"AI 成长建议"，不需要用户确认

### 3.5 审核队列（上下文紧张时）

当上下文不足时，不弹 AskUserQuestion，改为持久化到审核队列文件：

**Step 1**: 确保目录存在
```bash
mkdir -p ~/.claude/projects/-USERNAME/memory/_review_queue/
```

**Step 2**: 写入队列文件 `_review_queue/{YYYY-MM-DD}_{source}.md`
```markdown
---
type: review_queue
source: {来源描述，如"小宇宙·十字路口×李乐丁"}
date: {YYYY-MM-DD}
count: {候选数}
---

| # | 类别 | 吸收点 | 目标文件 | 碰撞 | 优先级 |
|---|------|--------|----------|------|--------|
| 1 | 摄影/生图 | 一句话要点 | aesthetic_preferences.md | HIGH→xxx.md | 高 |
| 2 | 工作流/自动化 | 一句话要点 | feedback_workflow_changes_20260511.md | 无 | 中 |
```

**Step 3**: 在 MEMORY.md 末尾追加标记
```markdown
- [待审核] _review_queue/{YYYY-MM-DD}_{source_slug}.md — {来源} {N}条候选洞察待审核
```

**Step 4**: 告知用户"已写入审核队列，下次会话启动时处理"

## 第四步：会话启动时检查待审核队列

每次会话启动时（本 skill 被调用且无新内容链接时），扫描 MEMORY.md：

```bash
grep '\[待审核\]' ~/.claude/projects/-USERNAME/memory/MEMORY.md
```

如有待审核项：
1. 按日期从早到晚逐个处理
2. 读取队列文件，用 AskUserQuestion 展示候选
3. 用户选择后写入对应 memory → 删除队列文件 → 移除 MEMORY.md 标记
4. 多个堆积时逐个处理，不要批量合并

## 第五步：创作与分发（碰撞信号 → 发布）

**⚠️ 不要在单条内容处理后立即触发选题生成。** 等整批内容全部处理完（消费→总结→提炼→碰撞），汇总所有碰撞信号后，再一次性生成选题、一次性询问用户。避免频繁打断。

碰撞检测完成后，汇总本批所有碰撞信号，进入创作分发管线。

### 5.1 选题生成

运行 `topic_generator.md` 模板，将汇总的碰撞信号转化为选题建议：

```
碰撞报告（汇总整批） → 选题生成器 →
  选题1: 标题/平台/形式/难度/理由
  选题2: ...
  选题3: ...
```

用户选择选题后，写入创作队列 `~/Documents/creation_queue.md` 的"待选题"区。

**AskUserQuestion 选项规则**：
- 选项末尾**必须**包含"都不感兴趣，全部跳过"
- 用户选择"都不感兴趣" → 本轮结束，不留待选题

**选题确认后 → 自动跑排期询问**（不可跳过）：

选题写入队列后，立即：
1. 运行 `bash ~/.claude/scripts/schedule_view.sh`（默认本周，追问用户是否看下周）
2. 估算创作时间（按选题难度：低=1天/中=2天/高=3-5天），告知用户"预计 X 天可创作完成"
3. 用 AskUserQuestion 询问：
   - 问题："是否排入本周日历？"
   - 选项：本周一~周日（7个日期槽位）+ "先不排" + "看下周"
   - 选具体日期 → 将队列条目从"待选题"移入"待发布"区，填入 `| 平台 | YYYY-MM-DD |` 列
   - 选"先不排" → 保留在待选题区，不做排期
   - 选"看下周" → 重新跑 `schedule_view.sh 1` 展示下周日历，再选日期

### 5.2 创作队列管理

`~/Documents/creation_queue.md` 维护四态流转：

```
待选题（用户确认） → 待创作（排期创作） → 待发布（排期就绪） → 已发布（归档）
```

查看排期：`bash ~/.claude/scripts/schedule_view.sh`

### 5.3 发布前质检

创作完成后、发布前，运行 `publish_qc.md` 模板进行四层检查：
1. 硬性规则（自动，FAIL 打回）
2. 风格一致性（对比过往内容）
3. 内容质量（信息差/逻辑链/废话率）
4. 活人感终审（提示用户判断）

质检通过后才进入发布。

### 5.4 发布与存档

发布后追加到 `~/Documents/publish_archive.md`，为反馈层提供数据基线。

## 第六步：反馈闭环

### 6.1 数据录入

每周提醒用户花 5 分钟填写 `~/Documents/feedback_log.md`，录入各平台本周数据。

### 6.2 反馈报告

运行 `bash ~/.claude/scripts/feedback_report.sh` 汇总发布存档+反馈日志，分析：
1. 哪个平台/选题类型数据最好？
2. 消费源的权重是否需要调整？（某些主题的资讯多拉/少拉）
3. 下周创作优先级建议

### 6.3 闭环调整

反馈报告产出后，对应调整：
- **消费层**：调整 AI HOT 关注类别、提醒事项中优先处理的链接类型
- **创作层**：选题偏好权重更新（数据好的选题类型优先排期）
- **记忆层**：将验证过的创作方法论写入 memory

---

---

## 完整示例

### 示例 1：用户发来播客链接
```
用户: https://www.xiaoyuzhoufm.com/episode/xxx 总结一下
```
执行：
1. 识别为小宇宙播客 → Skill(`小宇宙总结`)
2. 子 skill 下载音频→转录→写 summary.md→Effie 展示
3. 读 summary.md 提取候选洞察
4. 上下文充裕 → AskUserQuestion 交互选择 → 写入 memory
5. 上下文紧张 → 写入审核队列 → 追加 MEMORY.md 标记

### 示例 2：用户说看 AI 日报
```
用户: 今天 AI 圈有什么
```
执行：
1. 识别为 AI 资讯日报 → Skill(`AI资讯日报`)
2. 子 skill 拉 API→排版输出→运行 aihot_insights.py
3. 子 skill 自带观点提炼逻辑（已含 AskUserQuestion）
4. 确认子 skill 的提炼步骤已执行；如未执行（上下文不足），走 3.4 审核队列

### 示例 3：会话启动，检查待审核
```
用户: 看看有没有待处理的
```
或会话启动时自动检查 MEMORY.md 有 `[待审核]` 标记
执行：
1. 扫描 MEMORY.md → 发现待审核队列文件
2. 逐个读取队列文件 → AskUserQuestion 交互选择
3. 写入 memory → 清理队列

## 与子 skill 的关系

- 四个子 skill 各自保留内置的"观点提炼与 Memory 嵌入"章节，独立调用时也能跑完
- 本 skill 作为调度层，额外保证：即使子 skill 因上下文不足跳过了提炼步骤，审核队列也会兜底
- AI 资讯日报子 skill 的 `aihot_insights.py` 脚本正常使用，本 skill 不替代它

## 不要做

- 不要在摄入完成后就结束——必须跑第三步
- 不要在上下文紧张时强行弹 AskUserQuestion（会丢候选）——走审核队列
- 不要跳过审核队列的 MEMORY.md 标记写入（不写标记下次会话找不到）
- 不要在处理审核队列时批量合并多个队列文件——逐个处理
