---
name: 音视频总结
description: >
  当用户提供本地音频文件、YouTube链接、腾讯会议录音、或其他非特定平台的音视频内容，
  要求总结/转录/写摘要时激活。自动识别来源类型，下载/转录→写summary.md→Effie打开。
  复用 xiaoyuzhou-summary 的 transcribe.py。
---

# 通用音视频内容总结

## 触发
用户发来以下任一内容时激活：
- 本地音频/视频文件路径（如 `$HOME/Downloads/meeting.m4a`）
- YouTube 链接（`youtube.com/watch?v=` 或 `youtu.be/`）
- 腾讯会议录音文件路径
- 其他在线音频/视频链接（非B站、非小宇宙）
- "给我总结这个录音"、"转录这段音频"、"把这个视频转成文字"

## 自动来源识别

根据用户提供的内容自动判断来源类型：

| 来源类型 | 识别特征 | 处理方式 |
|---|---|---|
| **本地音频文件** | 以 `/` 或 `~` 开头的文件路径，后缀 `.m4a/.mp3/.wav/.mp4/.mov` | 直接用 ffmpeg 切片 |
| **YouTube** | URL 含 `youtube.com` 或 `youtu.be` | yt-dlp 下载 bestaudio |
| **腾讯会议** | 文件路径含 `腾讯会议` 或 `wemeet` | 直接 ffmpeg 切片 |
| **其他在线** | 其他 URL，返回 audio/video content-type | 尝试 yt-dlp 或 curl 下载 |
| **B站** | URL 含 `bilibili.com` | **转发给 `bilibili-summary` skill，不处理** |
| **小宇宙播客** | URL 含 `xiaoyuzhoufm.com` | **转发给 `xiaoyuzhou-summary` skill，不处理** |

## 通用流程

### 1. 识别来源
- 用户输入是文件路径 → 检查文件存在性和格式
- 用户输入是URL → 解析域名，判断来源类型
- B站/小宇宙 → 转给对应专用 skill

### 2. 创建工作目录
```
/tmp/audio_summary_{timestamp}/
```

### 3. 获取音频

**本地文件**：
```bash
# 复制到工作目录
cp "{filepath}" /tmp/audio_summary_{timestamp}/audio.m4a
# 如果是视频，提取音频
ffmpeg -y -i "{filepath}" -vn -acodec copy /tmp/audio_summary_{timestamp}/audio.m4a
```

**YouTube**：
```bash
cd /tmp/audio_summary_{timestamp}/
yt-dlp -f "bestaudio" --extract-audio --audio-format m4a \
  -o "audio.%(ext)s" "{youtube_url}"
```

**其他在线**：
```bash
# 尝试 yt-dlp（支持多数平台）
yt-dlp -f "bestaudio" --extract-audio --audio-format m4a \
  -o "audio.%(ext)s" "{url}"
# 如果 yt-dlp 失败，尝试 curl + ffmpeg 转换
```

### 4. 切片
```bash
cd /tmp/audio_summary_{timestamp}/
ffmpeg -y -i audio.m4a -ar 16000 -ac 1 \
  -f segment -segment_time 300 -c:a pcm_s16le chunk_%03d.wav
```

### 5. 转录
复用 xiaoyuzhou-summary 的 transcribe.py：
```bash
cd /tmp/audio_summary_{timestamp}/
python3 ~/.claude/skills/小宇宙总结/transcribe.py
```

**ASR 固定配置**：
- API: `https://api.siliconflow.cn/v1/audio/transcriptions`
- Model: `TeleAI/TeleSpeechASR`
- API key: `SF_KEY` env → `SILICONFLOW_API_KEY` env → `~/.config/siliconflow/api_key`
- 并发: 4 workers

### 6. 合并
```bash
cd /tmp/audio_summary_{timestamp}/
cat chunk_*.txt > full_transcript.txt
```

### 7. 写总结
基于完整转录稿写深度汇总：

**质量要求**：
- 内容信息：标题/来源/时长、主讲人、核心主题
- 结构：按话题/章节分块
- 核心论点与推导过程
- 金句与引述
- 具体案例/故事
- 横向比较（表格化，如适用）
- 总结：不超过5句核心观点
- 行动建议（如适用）

**格式**：Markdown，层级清晰

保存到：`~/Documents/podcast_summaries/{标题}/summary.md`
（如果已有同名目录，追加编号区分）

### 8. 展示
- `open -R ~/Documents/podcast_summaries/{标题}/summary.md`
- `open -a Effie ~/Documents/podcast_summaries/{标题}/summary.md`

## 依赖
- `yt-dlp`
- `ffmpeg`
- `python3`
- `curl`
- `open`（macOS）
- Effie 已安装
- `~/.claude/skills/小宇宙总结/transcribe.py`

## 注意事项
- **必须等转录完成后再写汇总**，不能基于文件名或简介缩减
- 硅基流动 + TeleSpeechASR 是唯一指定的 ASR 方案
- 音频文件在 `/tmp`，重启丢失；只有 `summary.md` 持久保存
- B站和小宇宙有专用 skill，本 skill 不覆盖
- 如果 `open -a Effie` 失败，尝试 `open -a "Effie"`
- 对于超长音频（>1小时），切片后会生成较多 chunk，注意转录时间
