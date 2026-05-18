---
name: 公众号解析
description: >
  当用户发来微信公众号文章链接（mp.weixin.qq.com）要求"总结/汇总/讲了什么"时使用。
  用 url-md (Rust CLI) 抓取+反爬+Markdown 转换一步到位。
  保存总结到 ~/Documents/article_summaries/，用 Effie + Finder 展示。
  完整 pipeline：抓取 → 深度总结 → 提取洞察 → 写入 memory。
---

# 公众号解析

## 触发

用户发来 `mp.weixin.qq.com/s/<id>` 链接，关键词"总结/汇总/讲了什么/解析/看看"。

## 依赖

- **url-md**：Rust CLI，一站式抓取+反爬+Markdown 转换
  ```bash
  curl -fsSL https://raw.githubusercontent.com/Bwkyd/url-md/main/install.sh | bash
  ```
  安装后确保 `~/.url-md/bin/` 在 PATH 中。

## 执行步骤

### Step 1: 抓取公众号文章

```bash
export PATH="$HOME/.url-md/bin:$PATH"
url-md md "<url>" --quiet --timeout 30 > /tmp/wx_article.md
```

判断标准：/tmp/wx_article.md 存在且正文 > 200 bytes。输出含 frontmatter（title、author、cover_url、word_count 等），正文为干净 Markdown。

失败 → 告知用户"抓取失败，建议在微信内查看"，退出。

### Step 2: 深度总结

基于完整原文撰写总结，每条包含：

- **作者 / 公众号名 / 发布时间**
- **一句话概括**
- **核心观点与论证结构**（按原文逻辑分层，不流水账）
- **关键案例/数据/引述**（原文重要信息原样保留）
- **金句摘录**
- **编辑层提炼**：对用户有什么用？可迁移的框架/方法论？可关联的项目？

### Step 3: 保存

```bash
mkdir -p ~/Documents/article_summaries/
# 文件名：summary_{YYYYMMDD}_{标题关键词}.md
```

### Step 4: 展示

```bash
open -R ~/Documents/article_summaries/summary_{YYYYMMDD}_{slug}.md
open -a Effie ~/Documents/article_summaries/summary_{YYYYMMDD}_{slug}.md
```

### Step 5: 提取洞察 → 写入 memory

从总结中提取 2-5 条候选洞察，关联用户活跃项目（摄影/影像化/文学/播客/婚样/工作流/创业/AI协作）。

候选洞察写入审核队列：
```bash
mkdir -p ~/.claude/projects/-USERNAME/memory/_review_queue/
# 写入 _review_queue/{YYYY-MM-DD}_wechat_{slug}.md
```

并在 MEMORY.md 末尾追加 `[待审核]` 标记，下次会话启动时交互式处理。

## 示例

用户：https://mp.weixin.qq.com/s/1XR1wOs8LS177LnYTNjttg 总结一下

→ url-md 抓取成功
→ 获得标题"武汉影像艺术中心新展预告｜街头摄影"
→ 写深度总结（核心观点：余少龑"街头距离"、杨达"生于街头"）
→ 提取洞察：街头摄影方法论对用户摄影创作的可迁移性
→ 保存 summary.md → Effie 展示 → 审核队列
