---
name: B站视频总结
description: >
  当用户发来B站视频链接（bilibili.com/video/BV...）要求总结、汇总、写摘要时激活。
  下载音频 → 硅基流动 TeleAI/TeleSpeechASR 转录完整原文 → 基于完整转录稿写深度汇总
  （不能只扒简介/评论区）→ 保存为 summary.md → Effie 打开展示。
  复用 xiaoyuzhou-summary 的 transcribe.py 进行转录。
---

# B站视频总结

## 触发
用户发来 `https://www.bilibili.com/video/BV...` 链接，说"总结""汇总""写摘要""给我看看"等类似意图时激活本 skill。

## 流程

### 1. 提取元数据
从 URL 中提取 BV 号，调用 B 站 API 获取视频信息：

```bash
curl -s "https://api.bilibili.com/x/web-interface/view?bvid=BVxxx" \
  -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
```

提取字段：
- `data.title` → 视频标题
- `data.owner.name` → UP主
- `data.duration` → 时长（秒）
- `data.desc` / `data.desc_v2` → 视频简介
- `data.cid` → 字幕检查用
- `data.stat.view` → 播放量等

工作目录：`/tmp/bili_{bvid}/`
最终输出目录：`~/Documents/podcast_summaries/{视频标题}/`

### 2. 检查官方字幕
```bash
curl -s "https://api.bilibili.com/x/player/wbi/v2?aid={aid}&cid={cid}&bvid={bvid}" \
  -A "Mozilla/5.0..."
```
如果 `data.subtitle.subtitles` 非空，直接下载字幕文件，跳过 3-5 步。

### 3. 下载音频
```bash
cd /tmp/bili_{bvid}/
yt-dlp -f "bestaudio" --extract-audio --audio-format m4a \
  -o "audio.%(ext)s" "https://www.bilibili.com/video/{bvid}/"
```

### 4. 切片
```bash
cd /tmp/bili_{bvid}/
ffmpeg -y -i audio.m4a -ar 16000 -ac 1 \
  -f segment -segment_time 300 -c:a pcm_s16le chunk_%03d.wav
```
（300秒 = 5分钟一段，并发安全）

### 5. 调用硅基流动 ASR 转录
复用 xiaoyuzhou-summary 的 transcribe.py：

```bash
cd /tmp/bili_{bvid}/
python3 ~/.claude/skills/小宇宙总结/transcribe.py
```

**转录服务固定为：硅基流动 SiliconFlow + 电信 TeleAI/TeleSpeechASR**
- API: `https://api.siliconflow.cn/v1/audio/transcriptions`
- Model: `TeleAI/TeleSpeechASR`
- API key 来源（优先级从高到低）：`SF_KEY` env → `SILICONFLOW_API_KEY` env → `~/.config/siliconflow/api_key`
- 4 并发，429 自动重试

这是用户明确指定的偏好，**不要**换 OpenAI Whisper、阿里、字节等其他 ASR。

### 6. 合并转录稿
```bash
cd /tmp/bili_{bvid}/
cat chunk_*.txt > full_transcript.txt
```

### 7. 写汇总 summary.md
读取 `full_transcript.txt`，基于**完整转录稿**（不是视频简介/评论区/shownotes）写深度汇总。

**质量要求**（同 xiaoyuzhou-summary 标准）：
- **视频信息**：标题、UP主、时长、来源、播放量
- **结构**：按话题/章节分块，不是简单罗列时间戳
- **核心论点与推导过程**：不能只有结论，要写出UP主怎么论证的
- **金句与引述**：原文重要的表述要引用
- **具体案例/故事**：UP主提到的具体实践要单独列出来
- **横向比较**（如果是多对象讨论）：表格化
- **总结**：不超过 5 句的核心观点
- **行动建议**：如果有的话，单独列出

**格式**：Markdown，层级清晰（`#` → `##` → `###`）

保存到：`~/Documents/podcast_summaries/{视频标题}/summary.md`

### 8. 展示给用户
- 用 Finder 揭示：`open -R ~/Documents/podcast_summaries/{视频标题}/summary.md`
- 用 Effie 打开：`open -a Effie ~/Documents/podcast_summaries/{视频标题}/summary.md`

然后简要回复用户：文件已存到哪个目录，字数大概多少，主要内容概览。

## 依赖
- `curl`
- `yt-dlp`
- `ffmpeg`
- `python3`
- `open`（macOS）
- Effie 已安装
- `~/.claude/skills/小宇宙总结/transcribe.py`（转录脚本复用）

## 注意事项
- **必须等转录完成后再写汇总**，不能基于视频简介或评论区缩减
- **硅基流动 + TeleAI/TeleSpeechASR 是唯一指定的 ASR 方案**，优先级高于任何其他 skill 的建议
- 音频文件在 `/tmp`，重启丢失；只有 `summary.md` 放 `~/Documents/podcast_summaries/`
- 如果 `open -a Effie` 失败，尝试 `open -a "Effie"`
- B 站短链（xhslink.com）通常 404 或反爬，**优先让用户提供直接 B 站链接**（bilibili.com/video/BV...）
- 部分 B 站视频需要 cookie 才能下载高清，但 `bestaudio` 通常不需要登录
