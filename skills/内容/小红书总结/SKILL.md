---
name: 小红书总结
description: >
  当用户发来小红书链接（xhslink.com 短链、xiaohongshu.com / m.xiaohongshu.com 长链，或包含"复制后打开【小红书】查看笔记"的分享文本）
  并要求"总结/汇总/讲了什么"时使用。
  视频笔记必须下载 mp4 并用硅基流动 TeleAI/TeleSpeechASR 完整转录（不能只扒 desc/hashtag）；
  图文笔记基于 desc + 图片信息写。最终保存为 summary.md 到 ~/Documents/xhs_summaries/，
  用 Finder 揭示 + Effie 打开。多条链接合并成一份文件，每条独立成节。
  注意：本 skill 是"消费/总结别人发布的小红书内容"，与「小红书发布」skill（管理自己的发布队列）不冲突——别混用。
---

# 小红书笔记汇总

## 触发

用户消息中包含以下任意特征 + "总结 / 汇总 / 讲了什么 / 看看 / 帮我看下" 这类意图：

- `xhslink.com/o/<id>` 短链
- `xiaohongshu.com/discovery/item/<id>` 或 `xiaohongshu.com/explore/<id>` 长链
- `m.xiaohongshu.com` 移动端链接
- 文本里有"复制后打开【小红书】查看笔记"

如果用户连续发了多个链接，**合并到一个 summary.md**，每条独立成一节。

## 流程

### 1. 抓页面 & 解析 SSR JSON

短链不能用 HEAD（返回 404），必须 GET，且要带 **iPhone UA**（PC UA 会拿不到完整 SSR）：

```bash
curl -sL -A "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1" "<url>" -o /tmp/xhs_<n>.html
```

然后用 Python 提取 SSR JSON——关键 script 标签是 **`window.__SETUP_SERVER_STATE__=`**：

```python
import json
with open('/tmp/xhs_1.html') as f:
    html = f.read()

# 定位 marker，然后括号计数法提取完整 JSON（不用正则，嵌套 JSON 会令 .+? 提前截断）
marker = 'window.__SETUP_SERVER_STATE__='
pos = html.find(marker)
assert pos != -1, 'SSR JSON marker not found'
start = pos + len(marker)

# 跳过等号后的空白，找到第一个 {
while start < len(html) and html[start] != '{':
    start += 1

# 括号计数，处理嵌套
depth = 0; end = start
for j in range(start, len(html)):
    if html[j] == '{':
        depth += 1
    elif html[j] == '}':
        depth -= 1
        if depth == 0:
            end = j + 1
            break

data = json.loads(html[start:end])
note = data['LAUNCHER_SSR_STORE_PAGE_DATA']['noteData']
```

`noteData` 关键字段：

| 字段 | 用途 |
|---|---|
| `type` | "video" 或 "normal"（图文） |
| `title` | 笔记标题 |
| `desc` | 正文（图文笔记的主要信息源；视频笔记通常只有 hashtags） |
| `user.nickName` | 作者 |
| `interactInfo` | likedCount / collectedCount / commentCount / shareCount |
| `tagList` | 话题标签 |
| `time` | 发布时间戳（毫秒） |
| `imageList` | 图片列表 |
| `video.capa.duration` | 视频时长（秒） |
| `video.media.stream.h264[0].masterUrl` | **下载视频用**（h264 兼容性最好） |

注意：`description` 这种字段在 HTML meta 里只有 hashtags，**绝对不能拿来当总结依据**——必须用 SSR JSON 里的 `desc` + 视频转录稿。

### 2. 视频笔记 → 下载 + 切片 + 转录

工作目录：`/tmp/xhs_v<n>/`

```bash
mkdir -p /tmp/xhs_v1
rm -f /tmp/xhs_v1/chunk_*.txt /tmp/xhs_v1/full.txt   # ⚠️ 清理上次残留转录稿，否则 transcribe.py 看到已有 .txt 会跳过
curl -sL -o /tmp/xhs_v1/video.mp4 "<masterUrl>"
cd /tmp/xhs_v1 && ffmpeg -y -i video.mp4 -vn -ar 16000 -ac 1 -f segment -segment_time 300 -c:a pcm_s16le chunk_%03d.wav
```

注意 **`-vn`**（去掉视频流，只要音轨）—— 否则 ffmpeg 会试图重新编码视频，浪费时间。

转录直接复用「小宇宙总结」的脚本（同样按 cwd 找 `chunk_*.wav`）：

```bash
cd /tmp/xhs_v1 && python3 ~/.claude/skills/小宇宙总结/transcribe.py
```

合并：
```bash
cat /tmp/xhs_v1/chunk_*.txt > /tmp/xhs_v1/full.txt
```

**API key 来源顺序**（与小宇宙总结一致）：
1. 环境变量 `SF_KEY`
2. 环境变量 `SILICONFLOW_API_KEY`
3. 文件 `~/.config/siliconflow/api_key`
4. 都没有就问用户

### 3. 图文笔记 → 直接基于 desc

`type == "normal"` 时没有视频可转录。基于：
- `desc`（小红书文案）
- `tagList`（话题）
- `imageList[].infoList[].url`（图片 URL，可选 OCR）

写一个**篇幅适中**的总结，不要把 desc 原样复制粘贴——要提炼、结构化。

### 4. 写 summary.md

输出位置：
- 单条：`~/Documents/xhs_summaries/{清洗过的标题}/summary.md`
- 多条：`~/Documents/xhs_summaries/{第一条标题}_等N条/summary.md` 或 `~/Documents/xhs_summaries/小红书汇总_{YYYYMMDD}/summary.md`（自由选择，但要清晰）

标题清洗：去掉/替换文件系统不允许的字符（`/ \ : * ? " < > |`），保留中文。

**质量要求**（必做）：

- **节目信息节**：作者、类型（视频/图文）、时长（视频）/ 字数（图文）、发布时间、互动数据（赞/收藏/评论/分享）、话题标签、原链接
- **一句话概括**：先给出，让用户决定要不要继续读
- **核心论点 / 内容结构**：按视频里的实际章节分块，不是简单复读
- **金句 / 引述**：原文重要表述要原样引用
- **个人案例 / 故事 / 关卡剧情**（如果有）：单独成节
- **编辑层提炼**：作为收尾——如果视频里有软广、夸大、幸存者偏差，**必须明确指出**，不要替它隐藏；如果是怀旧/解说类，提炼"真正打动人的点是什么"
- **多条情况**：在末尾加跨条对照表

**格式**：Markdown，标题层级清晰（`#` → `##` → `###`），表格 / 列表 / 引用块灵活使用。

### 5. 展示给用户

```bash
open -R "~/Documents/xhs_summaries/<dir>/summary.md"
open -a Effie "~/Documents/xhs_summaries/<dir>/summary.md"
```

回复用户：

- 文件位置 + 大小
- 每条 1-3 句的核心要点（让用户在 Effie 没自动跳出来时也能直接消化）

## 依赖

- `curl`、`ffmpeg`、`python3`、`open`（macOS）
- Effie 已安装
- 复用 `~/.claude/skills/小宇宙总结/transcribe.py`

## 注意事项

- **必须基于完整转录稿写汇总**，绝不能只用 hashtag / desc 凑数（视频笔记的 desc 通常只有 `#话题[话题]#` 一串 tag）
- iPhone UA 必带，PC UA 拿不到完整 SSR
- ffmpeg 切音频要加 `-vn`，否则会试图编码视频
- 多个视频要分别建工作目录（`/tmp/xhs_v1`、`/tmp/xhs_v2`），因为 `transcribe.py` 是按 cwd 找 chunks 的
- 默认 4 并发转录；遇到 429 自动重试
- 如果用户对内容里的论点有质疑（"对策听起来不靠谱"），**站在用户这边复盘**，不要替原视频背书
- 与「小红书发布」skill 严格分工：本 skill = 消费别人的内容；小红书发布 = 管理用户自己的发布队列
- 不要乱触发：用户只是粘了链接但没说"总结"时，先确认意图
