---
name: 小宇宙总结
description: >
  当用户发来小宇宙播客单期链接（xiaoyuzhoufm.com/episode/）时使用。
  必须下载音频并用硅基流动 TeleAI/TeleSpeechASR 免费转录完整原文，
  然后基于**完整转录稿**写深度汇总（不能只扒 shownotes），
  最终保存为 summary.md 到 ~/Documents/podcast_summaries/，
  并用 Effie 打开展示给用户。
  同时用 open -R 在 Finder 里揭示文件位置。
---

# 小宇宙播客汇总

## 触发
用户发了一个 `https://www.xiaoyuzhoufm.com/episode/<id>` 链接，说"汇总""总结一下""给我看看"等类似意图时，激活本 skill。

## 流程

### 1. 提取信息 & 创建工作目录
```bash
curl -sL "<episode_url>" -A "Mozilla/5.0..." -H "Accept: text/html"
```
从返回的 HTML 中提取：
- `og:title` → 节目标题
- `og:description` 或 `shownotes` 字段 → 嘉宾、时长、简介
- `transcriptMediaId` → 音频 m4a 的 CDN 路径（拼接为 `https://media.xyzcdn.net/{transcriptMediaId}`）
- 从 URL 提取 `episode_id`，作为目录名的一部分

工作目录：`/tmp/podcast_{episode_id}/`
最终输出目录：`~/Documents/podcast_summaries/{episode_title}/`

### 2. 下载音频
```bash
curl -sL -o /tmp/podcast_{episode_id}/episode.m4a "https://media.xyzcdn.net/{transcriptMediaId}"
```

### 3. 切片
```bash
ffmpeg -y -i episode.m4a -ar 16000 -ac 1 -f segment -segment_time 300 -c:a pcm_s16le chunk_%03d.wav
```
（300 秒 = 5 分钟一段，并发安全）

### 4. 调用硅基流动 ASR 转录
运行本 skill 目录下的 `transcribe.py`：
```bash
cd /tmp/podcast_{episode_id} && python3 ~/.claude/skills/小宇宙总结/transcribe.py
```

**API key 来源顺序**（优先级从高到低）：
1. 环境变量 `SF_KEY`
2. 环境变量 `SILICONFLOW_API_KEY`
3. 文件 `~/.config/siliconflow/api_key`（权限 600）
4. 如果都没有，问用户要 key

### 5. 合并转录稿
```bash
cat /tmp/podcast_{episode_id}/chunk_*.txt > /tmp/podcast_{episode_id}/full_transcript.txt
```

### 6. 写汇总 summary.md
读取 `full_transcript.txt`，基于**完整转录稿**（不是 shownotes）写深度汇总。

**质量要求**：
- 节目信息：标题、节目名、嘉宾、时长、来源
- 结构：按话题/章节分块，不是简单罗列时间戳
- 核心论点与推导过程：不能只有结论，要写出嘉宾怎么论证的
- 金句与引述：原文重要的表述要引用
- Q&A 完整还原（如果有的话）：这是 shownotes 通常覆盖不全的
- 个人案例/故事：嘉宾提到的具体实践要单独列出来
- 横向比较（如果是多对象讨论）：表格化
- 总结：不超过 5 句的核心观点

**格式**：Markdown，层级清晰（# → ## → ###）

保存到：`~/Documents/podcast_summaries/{episode_title}/summary.md`

### 7. 展示给用户
- 用 Finder 揭示：`open -R ~/Documents/podcast_summaries/{episode_title}/summary.md`
- 用 Effie 打开：`open -a Effie ~/Documents/podcast_summaries/{episode_title}/summary.md`

然后简要回复用户：文件已存到哪个目录，字数大概多少，主要内容概览。

## 依赖
- `curl`
- `ffmpeg`
- `python3`
- `open`（macOS）
- Effie 已安装

## 注意事项
- **必须等转录完成后再写汇总**，不能基于 shownotes 缩减
- 硅基流动 ASR 模型固定用 `TeleAI/TeleSpeechASR`
- 音频文件在 `/tmp`，重启丢失；只有 `summary.md` 放 `~/Documents/podcast_summaries/`
- 如果 `open -a Effie` 失败，尝试 `open -a "Effie"`
- 默认 4 并发转录，如果遇到 429 超限会自动重试

