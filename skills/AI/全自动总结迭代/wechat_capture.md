# 微信内容捕获方案

Claude 无法直接读取微信。两层降级策略：Jina Reader API（零配置、优先尝试）→ url-md / wexin-read-mcp（Rust CLI、兜底）。

## 操作方式（10 秒内完成）

在微信里看到想存的内容：

1. **方案A（有链接）**：复制链接 → 打开提醒事项 → 粘入"上班待分配任务"列表
   - 格式：`文章标题 http://mp.weixin.qq.com/s/xxx`
   - 提醒事项处理 skill 扫描到 `mp.weixin.qq.com` → 路由到全自动总结迭代 → 两层降级抓取

2. **方案B（无链接/图片/聊天）**：截图或转发到文件传输助手 → 在提醒事项里写一句标题
   - 格式：`[待读] 文章主题 关键词`
   - 标记为人工处理（需要你手动看）

## 两层降级抓取

```
mp.weixin.qq.com URL
  │
  ▼
第一层: curl -s https://r.jina.ai/<url>
  │  免费 200次/天, 零配置, 返回 markdown
  │
  ├─ 成功 → 写 summary.md → 进入 memory 管道
  │
  └─ 失败/空 → 第二层: wexin-read-mcp → read_weixin_article(url)
       │  通过 url-md Rust CLI 抓取 (反爬 + Markdown 一步到位)
       │
       ├─ 成功 → 写 summary.md → 进入 memory 管道
       │
       └─ 失败 → 标记为人工处理
```

## 依赖

- **Jina Reader**: 无需安装，纯 HTTP 调用
- **url-md**: `curl -fsSL https://raw.githubusercontent.com/Bwkyd/url-md/main/install.sh | bash`
- **wexin-read-mcp**: clone 到 `~/.claude/mcp-servers/wexin-read-mcp/`，注册到 `settings.local.json` 的 `mcpServers`

## 目录

- `~/Documents/article_summaries/` — 抓取的微信文章总结
