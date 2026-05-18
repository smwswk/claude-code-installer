---
name: memory-thin
description: >
  记忆体系瘦身与管道去重。MUST trigger when the user says:
  "瘦身", "清理记忆", "/thin", "记忆瘦身", "memory瘦身", "记忆减肥", "索引瘦身".
  也应在内容引擎跑完后若 MEMORY.md 净增 ≥5 条主动提醒用户是否跑瘦身。
  负责三项：CLAUDE.md↔MEMORY.md 管道去重、过期条目清理、死链接检测。
  与 neat-freak 分工：neat-freak 做代码↔文档同步，本 skill 做记忆体系内部健康。
---

# 记忆瘦身

你是**记忆体系编辑**，负责让 MEMORY.md 索引保持紧凑、准确、无冗余。和 neat-freak 分工：neat-freak 负责代码↔文档↔记忆三层同步，你只负责**记忆体系内部健康度**——索引瘦身、管道去重、过期清理。

## 核心原则

- **CLAUDE.md 锚点 > MEMORY.md 索引指针**。当同一条行为规则在 CLAUDE.md 已有锚点，MEMORY.md 里的索引行就是冗余，删索引行（保留 .md 文件本体）。
- **活跃工作区 ≤ 15条**。这是每日变动区，过期的立即清，不攒。
- **原则与规则 ≤ 30条**。偏方法论的移 REFERENCE_INDEX.md，只留真正的行为护栏。
- **不删 .md 文件本体**。本 skill 只管理 MEMORY.md 和 REFERENCE_INDEX.md 的索引行。底层 memory 文件的删改需要用户单独确认。

## 执行流程

### 第零步：读源码

```
Read ~/CLAUDE.md
Read ~/.claude/projects/-USERNAME/memory/MEMORY.md
Read ~/.claude/projects/-USERNAME/memory/REFERENCE_INDEX.md (若存在)
ls ~/.claude/projects/-USERNAME/memory/
```

### 第一步：管道去重（CLAUDE.md ↔ MEMORY.md）

**1a. 从 CLAUDE.md 提取锚点规则主题：**

定位 `## 记忆协议`、`## 输出规则`、`## 安全规则` 三个 section。
提取每条规则的**核心主题词**：

| CLAUDE.md 规则 | 主题 |
|---|---|
| 输出路径...必须 `open -R <path>` 揭示 | 输出路径揭示 |
| 展示 md 内容用 `open -a Effie <path>` | Effie打开md |
| 回复要简洁直接 | 简洁回复 |
| 删除操作：先列清单获授权... | 安全删除 |
| 不操作活跃应用缓存 | 活跃应用缓存保护 |
| 不发明 URL | 不发明URL |
| 会话启动必须读 MEMORY.md | 启动读MEMORY |
| 摄入任何内容后...完整链路 | 摄入闭环 |

**1b. 扫描 MEMORY.md「原则与规则」区**，对每条索引行，判断其对应的 feedback/methodology 文件主题是否已被 CLAUDE.md 锚点覆盖。

判定方法：读 feedback 文件的前3行（看 description 字段），与 CLAUDE.md 锚点主题比对。若说的是同一件事 → 标记冗余。

**1c. 输出查重结果：**

```
## 管道重复（CLAUDE.md 已覆盖，MEMORY.md 可删索引行）
- feedback_xxx.md — CLAUDE.md「输出规则」已覆盖"XXX"
- feedback_yyy.md — CLAUDE.md「安全规则」已覆盖"YYY"
（如无重复，输出「无重复 ✅」）
```

### 第二步：过期条目检测

扫描 MEMORY.md「活跃工作区」。

**判定规则：**
- 包含明确日期且已过去（如 `5/16-17`、`2026-05-12`），且无「进行中」「待」「blocked」「持续」等持续状态词 → 标记过期
- 包含相对时间但无绝对日期锚点（如"本周""下周"）→ 标记需确认
- 长期未更新的进度类条目（如"已发3组/待发4组"数字数月不变）→ 标记可能过期

**输出：**
```
## 过期条目
- 宁波 Solo Weekend — 日期5/16-17已过
- xxx — 最后更新日期不详，标记需确认
（如无，输出「无过期 ✅」）
```

### 第三步：死链接检测

逐一检查 MEMORY.md 中每条 `[text](file.md)` 链接。

**判定：**
- `ls memory/<file.md>` 存在 → 存活
- 不存在 → 死链
- 指向非 memory/ 目录的链接 → 跳过（那是外部引用）

**输出：**
```
## 死链接
- xxx.md — 文件不存在
（如无，输出「无死链 ✅」）
```

### 第四步：尺寸预警

`wc -l MEMORY.md`：

| 行数 | 状态 |
|---|---|
| ≤ 60 | ✅ 健康 |
| 61-80 | ⚠️ 需关注，列出所有可删项供选择 |
| 81+ | 🔴 超限，必须瘦身（只删不增直到回 60 以下） |

### 第五步：汇总报告 + 等待确认

将以上四项结果汇总为一份简洁报告。**只列有问题/可操作的条目，不列健康条目。**

用 AskUserQuestion 让用户确认要删哪些（多选），然后执行。

执行后输出最终行数对比：`92行 → 57行（-38%）`

### 第六步：更新 CLAUDE.md（如需要）

如果本次瘦身发现某条规则是 CLAUDE.md 缺失的（MEMORY.md 有但 CLAUDE.md 没有覆盖），**不自动加**，放在报告的「建议」区让用户判断是否要补到 CLAUDE.md。

## 注意事项

- **不删 .md 文件本体**，只动索引行。即使 MEMORY.md 删了指针，底层 memory 文件依然可被主动读取。
- **不碰 REFERENCE_INDEX.md 的条目**，除非用户明确要求。稳定参考的瘦身是独立操作。
- **过期项目不移入 REFERENCE_INDEX.md**。REFERENCE_INDEX.md 是稳定参考，不是归档区。
- 如果 MEMORY.md 在本次会话刚被编辑过，以当前文件状态为准，不依赖记忆。
