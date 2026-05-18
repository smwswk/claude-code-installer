---
name: 内容引擎
description: >
  全链路批量摄入加速器：从提醒事项列表提取链接 + B站稍后再看列表 → 按平台路由 → 小红书SSR+视频切片ASR / 公众号Jina/url-md抓取 / B站字幕优先+无字ASR → 写深度总结 → Hand-off 给全自动总结迭代（碰撞检测+记忆写入+选题排期）。
  触发词："内容引擎"或"处理上班待分配任务"或"清理稍后再看"。
  消耗约 30-90 条链接的完整批次。本 skill 专注批量摄入，碰撞/记忆/选题/排期由全自动总结迭代统一管理。
  支持平台：小红书（xhslink.com/xiaohongshu.com）、公众号（mp.weixin.qq.com）、B站（bilibili.com/video/BV...）、知乎（zhihu.com）、小宇宙（xiaoyuzhoufm.com）、AI HOT（aihot.virxact.com）。
  多平台并行采用子 agent 分发模式，每平台/每批 1 个 agent，16 路并发。
---

# 内容引擎

## 触发

用户说以下任意一句：
- "内容引擎"
- "处理上班待分配任务"
- "把待分配的链接跑一遍"
- "清理稍后再看"
- "清理B站稍后再看"
- "处理稍后再看列表"

## 全链路概览

```
Phase 1A: 提取提醒事项链接 → Phase 1B: 提取B站稍后再看 → Phase 1C: Safari知乎标签页
→ Phase 2: 批量SSR / Phase 2W: 公众号抓取 / Phase 2B: B站字幕+下载 / Phase 2Z: 知乎抓取+预筛+关标签 / Phase 2X: 小宇宙下载+ASR / Phase 2A: AI HOT日报
→ Phase 3: 下载+切片+转录(16并发) / Phase 3B: B站无字幕ASR
→ Phase 4: 深度总结 (子agent独立写各平台summary)
→ Phase 5: Hand-off 全自动总结迭代（碰撞+记忆+选题+排期）【所有平台均须执行，含知乎】
```

**多平台并行架构**：确认分堆后，每个平台/每批启动一个子 agent，所有 agent 并行运行。子 agent 内部 16 路并发。

---

## Phase 1: 提取链接 & 分类

### 1.1 查询 Reminders SQLite

读取链路仍用 SQLite（只读不写，不影响 iCloud 同步），但需同时记下列表名和标题，供 Phase 5 用 AppleScript 标记完成。

```bash
DB=~/Library/Group\ Containers/group.com.apple.reminders/Container_v1/Stores/Data-1568038F-0A2D-44F0-9A52-369CAE55728D.sqlite

# 列出所有 list（获取 Z_PK → 列表名映射）
sqlite3 "$DB" "SELECT Z_PK, ZNAME FROM ZREMCDBASELIST;"

# 上班待分配任务 list Z_PK=57，查未完成项（Z_PK + ZTITLE 都要记录）
sqlite3 "$DB" "SELECT Z_PK, ZTITLE FROM ZREMCDREMINDER WHERE ZLIST=57 AND ZCOMPLETED=0;"
```

### 1.2 提取链接

从每个 reminder 的 ZTITLE/ZNOTES/ZURL 中提取：
- `xhslink.com/o/<id>` 短链 → **统一转成 `http://xhslink.com/o/<id>`（无 www + HTTP）再传给 fetch 脚本，不要用 `https://www.xhslink.com`**
- `xiaohongshu.com/discovery/item/<id>` 或 `/explore/<id>` 长链
- `mp.weixin.qq.com/s/<id>` 公众号文章链接
- `zhihu.com/question/<id>` 或 `zhihu.com/answer/<id>` 或 `zhuanlan.zhihu.com/p/<id>` 知乎链接
- `xiaoyuzhoufm.com/episode/<id>` 小宇宙播客链接

整理成 `Z_PK | 列表名 | 平台 | 链接 | 标题` 格式的清单。列表名和标题用于 Phase 5 通过 AppleScript 标记完成（确保 iCloud 同步）。

### 1.3 分类

将链接列表呈现给用户，按平台分组展示（小红书 / 公众号）。用户决定分几堆、每堆的主题名。等待用户确认后再进入 Phase 2。

### 1.4 按平台路由

确认分堆后，按链接平台分流：

| 平台 | 路由 | 说明 |
|------|------|------|
| 小红书 | Phase 2 → Phase 3 → Phase 4 | SSR抓取 → 视频下载切片ASR → 总结 |
| 公众号 | Phase 2W → Phase 4 | 两层降级抓取 → 总结（跳过视频阶段） |
| B站 | Phase 2B → Phase 3B(按需) → Phase 4 | 字幕优先采集 → 无字下载ASR → 总结 |
| 知乎 | Phase 2Z → Phase 4 | 两层降级抓取（同公众号）→ 总结 |
| 小宇宙 | Phase 2X → Phase 4 | 页面提取元数据 → 下载m4a → 切片ASR → 总结 |
| AI HOT | Phase 2A → Phase 4 | 调用 AI资讯日报 skill → 总结 |

### 1.5 B站稍后再看列表

```bash
# 需要 SESSDATA cookie（从浏览器 DevTools → Application → Cookies → bilibili.com → SESSDATA 获取）
# 默认采集全部，可传第二个参数限制数量
python3 ~/scripts/bilibili/bilibili_data_collector.py "<SESSDATA>" [数量]
```

采集器会输出一个 JSON 文件（如 `bilibili_data_20260514_120000.json`），每条包含：
- `index` / `title` / `bvid` / `url`
- `uploader` / `duration_seconds` / `view_count` / `pubdate`
- `desc` / `tags` / `subtitle`（有字幕时非空）

整理成 `序号 | BV号 | 标题 | UP主 | 时长 | 有无字幕` 格式的清单，与提醒事项链接合并分类。

### 1.6 Safari 知乎标签页提取

当用户说"内容引擎"时，自动扫描 Safari 中所有打开的知乎标签页作为内容源：

```bash
osascript -e '
tell application "Safari"
    set out to ""
    repeat with w in windows
        repeat with t in tabs of w
            set turl to URL of t
            if turl contains "zhihu.com" then
                set out to out & name of t & " | " & turl & linefeed
            end if
        end repeat
    end repeat
    return out
end tell
'
```

提取后按 Phase 1.3 与其他平台链接合并分类展示给用户。

---

## Phase 2: 批量 SSR 抓取

### 2.1 分批调用

每批生成一个输入文件：`/tmp/xhs_batch_N_input.txt`，格式为 `Z_PK|短链|标题`（每行一条）。

```bash
python3 ~/.claude/skills/小红书总结/xhs_batch_fetch.py /tmp/xhs_batch_1_input.txt /tmp/xhs_batch_1_ssr/
```

SSR 脚本会为每个 Z_PK 输出一个 `.json` 文件到目标目录。

### 2.2 解析 SSR 提取关键字段

对于每个 SSR JSON，提取：
- `type` — "video" 或 "normal"（图文）
- `title` — 笔记标题
- `desc` — 正文
- `user.nickName` — 作者
- `interactInfo` — likedCount / collectedCount / commentCount / shareCount
- `time` — 发布时间戳（毫秒）
- `video.capa.duration` — 视频时长（秒）
- `video.media.stream.h264[0].masterUrl` — 视频下载地址
- `imageList[].infoList[].url` — 图片列表（图文笔记）

统计每批：视频数 / 图文数 / 总条数。

---

## Phase 3: 视频下载 + 切片 + 转录

### 3.1 工作目录命名

`/tmp/xhs_b<N>_<Z_PK>/`，其中 `<N>` 是批次号，`<Z_PK>` 是提醒事项主键。

### 3.2 下载策略（重要：主线 CDN 已失效）

**主线 CDN（sns-video-v6.xhscdn.com）**：curl/wget/Python requests 均返回 403 MirrorFailed。即使带 cookie、Referer、iPhone UA 也无法下载。Playwright 浏览器可触发页面自动加载但因 range 请求导致 MP4 不完整，不可用。

**备线 CDN（sns-bak-v1.xhscdn.com）**：Python urllib 直接请求返回完整文件（status 200）。只需将 masterUrl 中的 `sns-video-v6` 替换为 `sns-bak-v1`。

**下载脚本**（Python urllib，可并行多视频）：
```python
import urllib.request

UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
backup_url = master_url.replace("sns-video-v6", "sns-bak-v1")

req = urllib.request.Request(backup_url)
req.add_header("User-Agent", UA)
req.add_header("Referer", "https://www.xiaohongshu.com/")
with urllib.request.urlopen(req, timeout=120) as resp:
    body = resp.read()

with open(f"{dir}/video.mp4", "wb") as f:
    f.write(body)
```

### 3.3 处理流程（每个视频）

```bash
ZP=2510; BN=1
DIR=/tmp/xhs_b${BN}_${ZP}

# 清理残留（用 Python glob 避免 zsh nomatch 报错）
python3 -c "import glob,os;[os.remove(f) for f in glob.glob('$DIR/chunk_*')]"

# 切片（-vn 去掉视频流，只要音频）
cd $DIR && ffmpeg -y -i video.mp4 -vn -ar 16000 -ac 1 -f segment -segment_time 300 -c:a pcm_s16le chunk_%03d.wav

# 转录（复用小宇宙总结 transcribe.py，内部 max_workers=16）
cd $DIR && python3 ~/.claude/skills/小宇宙总结/transcribe.py

# 合并
cat $DIR/chunk_*.txt > $DIR/full.txt
```

### 3.4 并行策略

- **批量并行**：同一批次的所有视频同时启动下载+切片+转录，16并发
- 每个视频独立目录，互不干扰
- 429 限流自动重试（transcribe.py 内置）
- 图文笔记在 Phase 2 后直接进入 Phase 4，不需要本阶段

### 3.5 验证

每个视频处理完后确认 `full.txt` 存在且非空（> 100 bytes）。

---

## Phase 2W: 公众号文章抓取（替代 Phase 2-3）

公众号文章是图文内容，不需要 SSR 抓取和视频转录。用两层降级直接抓取全文 markdown。

### 2W.1 两层降级抓取

每个公众号链接依次尝试：

```bash
# 第一层：Jina Reader API（零配置，免费 200次/天）
curl -s "https://r.jina.ai/<url>" -H "Accept: text/markdown" -o /tmp/wx_article.md

# 若第一层失败（空文件/超时/403），第二层：url-md Rust CLI
export PATH="$HOME/.url-md/bin:$PATH"
url-md md "<url>" --quiet --timeout 30 > /tmp/wx_article.md
```

url-md 输出为带 frontmatter 的 markdown，包含 title、author、publish_time、cover_url 和正文。

### 2W.2 验证

确认 `/tmp/wx_article.md` 存在且正文 > 200 bytes。两层都失败则标记为人工处理，跳过不阻塞整批。

### 2W.3 工作目录

```bash
mkdir -p /tmp/wx_b<N>_<Z_PK>/
mv /tmp/wx_article.md /tmp/wx_b<N>_<Z_PK>/article.md
```

### 2W.4 并行策略

公众号文章纯文本处理，无需 ffmpeg/ASR，同一批次所有链接并行抓取即可。无 429 限流问题。

---

## Phase 2B: B站视频数据采集

### 2B.1 采集策略：字幕优先

B站视频与小红书不同，已有采集器产出的 JSON 数据。核心决策：有字幕直接用字幕，无字幕才下载音频+ASR。

从采集器 JSON 读取每个视频的 `subtitle` 字段：
- **subtitle 非空且 > 100 chars**：字幕质量足够，跳过下载，直接进入 Phase 4
- **subtitle 为空或 < 100 chars**：进入 Phase 3B 下载+ASR

### 2B.2 字幕视频直接整理

```bash
# 从采集器 JSON 中提取有字幕视频
python3 -c "
import json
with open('bilibili_data_xxx.json') as f:
    data = json.load(f)
for v in data:
    sub = v.get('subtitle', '') or ''
    if len(sub) > 100:
        print(f\"{v['index']}|{v['bvid']}|{v['title']}|{v['uploader']}|{v['duration_seconds']}s|字幕{len(sub)}字\")
"
```

字幕视频直接进入 Phase 4，以字幕原文作为深度总结的素材。

### 2B.3 无字幕视频 → Phase 3B

统计需要下载转写的视频数，告知用户预计耗时（每个视频约 2-5 分钟处理时间）。

---

## Phase 2Z: 知乎文章抓取（替代 Phase 2-3）

知乎采用专用 API 抓取 + 批量预筛模式，不走通用的 Jina/url-md（两者均被知乎反爬拦截返回 403）。

### 2Z.1 链接来源

- 用户直接发来的链接列表（从知乎复制粘贴）
- Safari 打开的知乎标签页（Phase 1.6 自动扫描）

### 2Z.2 链接格式

- `zhihu.com/question/<id>/answer/<aid>` — 回答页 → 调知乎 Answers API
- `zhihu.com/question/<id>` — 问题页 → 无答案ID，无法API抓取，标记跳过
- `zhuanlan.zhihu.com/p/<id>` — 专栏文章 → API/HTML/WebFetch三层均被反爬挡，标记跳过

### 2Z.3 API 抓取

使用 `知乎抓取` skill 的 `batch_fetch.py`，通过知乎公开 JSON API 直接获取答案正文（无需登录、不触发反爬）：

```bash
# 输入格式：标题一行，URL下一行，空行分隔
python3 ~/.claude/skills/知乎抓取/batch_fetch.py < /tmp/zh_fetch_input.txt > /tmp/zh_data.jsonl
```

API 端点：`https://www.zhihu.com/api/v4/answers/{ANSWER_ID}?include=content,voteup_count,comment_count`

输出 JSONL，每条含 `idx/type/url/title/voteup/comment/content/skip_reason`。

**已知限制**：
- 答案正文默认截断约500字（`content_need_truncated: true`），适合预筛非全文
- 请求间隔 0.4s，避免频率限制

### 2Z.4 预筛评分（三维度）

```
综合分 = 认知 × 0.5 + 兴趣域 × 0.3 + 反共识 × 0.2
```

| 维度 | 权重 | 标准 |
|------|------|------|
| 认知含量 | 50% | 一手信息/数据/具体经验/结构化论证 |
| 兴趣域 | 30% | 摄影/AI/司法体制/虚构创作 |
| 反共识 | 20% | 独立判断而非迎合情绪 |

### 2Z.5 预筛后输出分级

- **强推**（综合≥6.0）：推荐点开读全文
- **值得看**（5.0-6.0）：可快速浏览
- **过滤**（<5.0）：关闭标签页，不浪费时间
- **未获取**：因缺答案ID/反爬/403/404等原因无法抓取正文——不评分、不关闭标签页，留待用户手动处理或换方式重试

### 2Z.6 自动关闭低密度标签页

预筛完成后，对评为"过滤"级别的知乎标签页，直接通过 AppleScript 关闭：

```bash
osascript << 'EOF'
tell application "Safari"
    set closeIDs to {/* 过滤项的 question/answer ID 列表 */}
    set tabsToClose to {}
    repeat with w in windows
        repeat with i from (count of tabs of w) to 1 by -1
            set t to tab i of w
            set turl to URL of t
            repeat with pid in closeIDs
                if turl contains pid then
                    set end of tabsToClose to t
                    exit repeat
                end if
            end repeat
        end repeat
    end repeat
    repeat with t in tabsToClose
        close t
    end repeat
end tell
EOF
```

**关闭标准**（满足任一即关）：
- 纯话题流量/时事八卦/无认知增量
- 正文极短（<200字）信息密度极低
- 同一问题两篇答案已抓一篇，另一篇重复可关

**禁止关闭的情况**（即使看起来低价值也不关）：
- **未成功抓取的内容**：包括但不限于专栏反爬、API 403/404/500、只有问题ID无答案ID、不识别的URL模式等——没读到内容根本不知道值不值，关了就丢了
- 应在预筛总结末尾的"未获取"表中列出，留待用户手动处理或换方式重试

**注意**：先收集后关闭（倒序遍历），避免索引偏移导致报错。

### 2Z.7 并行策略

`batch_fetch.py` 内部串行（每次间隔 0.4s），完成后 Phase 4 写分组总结。自动关闭标签页在 Phase 4 完成后执行。

---

## Phase 2X: 小宇宙播客处理（替代 Phase 2-3）

对标 Phase 3 视频管线，但音频下载来自 xyzcdn CDN。

### 2X.1 提取元数据

```bash
curl -sL "https://www.xiaoyuzhoufm.com/episode/<eid>" \
  -A "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15"
```

从 HTML 中提取：
- `og:title` → 节目标题
- `og:description` → 简介/shownotes
- `transcriptMediaId` → CDN 路径，拼接为 `https://media.xyzcdn.net/{transcriptMediaId}`

### 2X.2 下载音频

```bash
curl -sL -o /tmp/xyz_<Z_PK>/episode.m4a "https://media.xyzcdn.net/{transcriptMediaId}" \
  -A "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)" \
  -H "Referer: https://www.xiaoyuzhoufm.com/" --max-time 600
```

> **CDN 链接有效期注意**：xyzcdn 直链可能过期返回 404 NoSuchKey。若全部失败，需回到 episode 页面实时提取最新 mediaId。

### 2X.3 切片 + 转录 + 合并

```bash
ZP=2598; DIR=/tmp/xyz_${ZP}

# 清理残留
python3 -c "import glob,os;[os.remove(f) for f in glob.glob('$DIR/chunk_*')]"

# 切片（-vn 去掉视频流，只要音频）
cd $DIR && ffmpeg -y -i episode.m4a -ar 16000 -ac 1 -f segment -segment_time 300 -c:a pcm_s16le chunk_%03d.wav

# 转录（复用 transcribe.py，内部 max_workers=16）
cd $DIR && python3 ~/.claude/skills/小宇宙总结/transcribe.py

# 合并
cat $DIR/chunk_*.txt > $DIR/full.txt
```

### 2X.4 并行策略

所有小宇宙 episode 同时启动下载+切片+转录，每个独立目录，16 并发。注意 xyzcdn 可能有速率限制。

### 2X.5 验证

full.txt > 100 bytes 即成功。

---

## Phase 2A: AI HOT 日报获取（替代 Phase 2-3）

无需抓取网页，直接调用 AI资讯日报 skill 拉取当日/近期 AI 行业动态。

### 2A.1 触发方式

```bash
Skill(AI资讯日报)
```

传入参数：
- `type`: `daily`（当日日报）/ `weekly`（一周精选）/ `featured`（精选条目）
- 默认为 `daily`

### 2A.2 输出

AI资讯日报返回中文 markdown 简报，包含：
- 模型发布 / 产品发布 / 行业动态 / 论文 / 技巧与观点
- 每条含标题、摘要、来源链接

### 2A.3 保存

```bash
mkdir -p ~/Documents/aihot_summaries/
# 保存日报 markdown 到该目录
```

### 2A.4 并行策略

单次 API 调用，与其他平台 agent 并行运行。

---

## Phase 3B: B站无字幕视频下载 + 切片 + 转录

对标 Phase 3（小红书视频处理），复用同一套 transcribe.py。

### 3B.1 工作目录

`/tmp/bili_batch_<BV号>/`

### 3B.2 处理流程（每个视频）

```bash
BV=BVxxx
DIR=/tmp/bili_batch_${BV}

# 清理残留（用 Python glob 避免 zsh nomatch 报错）
python3 -c "import glob,os;[os.remove(f) for f in glob.glob('$DIR/chunk_*')]"

# 下载音频（yt-dlp，只需音频流）
cd $DIR && yt-dlp -f "bestaudio" --extract-audio --audio-format m4a \
  -o "audio.%(ext)s" "https://www.bilibili.com/video/${BV}/"

# 切片（-vn 去掉视频流，只要音频）
cd $DIR && ffmpeg -y -i audio.m4a -ar 16000 -ac 1 \
  -f segment -segment_time 300 -c:a pcm_s16le chunk_%03d.wav

# 转录（复用 transcribe.py，内部 max_workers=16）
cd $DIR && python3 ~/.claude/skills/小宇宙总结/transcribe.py

# 合并
cat $DIR/chunk_*.txt > $DIR/full.txt
```

### 3B.3 并行策略

所有无字幕视频同时启动下载+切片+转录，每个视频独立目录，互不干扰。

### 3B.4 验证

每个视频处理完后确认 `full.txt` 存在且非空（> 100 bytes）。

---

## Phase 4: 深度总结

### 4.1 质量标准

每条必须包含：

**小红书**：
- 作者、类型（视频/图文）、时长（视频）/ 图片数（图文）
- 互动数据（赞/收藏/评论/分享）
- 原链接 `https://www.xiaohongshu.com/discovery/item/<id>`
- **一句话概括**（最先给出）
- **核心内容**（按实际章节/论点的结构分段，不是流水账）
- **金句/引述**（原文重要表述原样引用）
- **编辑层提炼**（创作启发、框架可迁移性、潜在软广提醒、信息密度判断）

**公众号**：
- 作者、公众号名、发布时间
- 原链接
- **一句话概括**
- **核心观点/论证结构**（按原文逻辑分段）
- **金句/引述**
- **编辑层提炼**（创作启发、可迁移框架、信息密度判断）

**B站**：
- UP主、标题、时长、播放量、发布时间
- 原链接 `https://www.bilibili.com/video/<BV号>`
- **一句话概括**（最先给出）
- **核心内容**（按视频章节/论点结构分段，基于字幕或转录稿）
- **金句/引述**（原文重要表述原样引用）
- **编辑层提炼**（创作启发、框架可迁移性、与用户B站频道「搞艺术的小明」的关联度判断）

**知乎**：
- 作者、问题标题、回答/文章链接
- **一句话概括**
- **核心观点/论证结构**（按原文逻辑分段）
- **金句/引述**
- **编辑层提炼**（创作启发、可迁移框架、信息密度判断）

**小宇宙**：
- 节目名、嘉宾、时长
- 原链接 `https://www.xiaoyuzhoufm.com/episode/<eid>`
- **一句话概括**（最先给出）
- **核心内容**（按话题/章节分块，不是简单罗列时间戳）
- **核心论点与推导过程**（不能只有结论）
- **金句/引述**（原文重要表述引用）
- **Q&A 完整还原**（如有）
- **编辑层提炼**

**AI HOT**：
- 日期、条目总数
- **精选条目（Top 5-10）**：标题 + 一句话概括
- **全文条目**：全文保留在 summary.md 中
- **编辑层提炼**：本期最重要的信号 + 对用户的关联度判断

### 4.2 输出文件

小红书每批一个 summary.md：
```
~/Documents/xhs_summaries/{YYYYMMDD}_batch{N}_{主题}/summary.md
```

公众号每批一个 summary.md：
```
~/Documents/article_summaries/summary_{YYYYMMDD}_wechat_batch{N}.md
```

B站每批一个 summary.md：
```
~/Documents/podcast_summaries/bilibili_watchlater_{YYYYMMDD}/summary.md
```

知乎每批一个 summary.md：
```
~/Documents/article_summaries/summary_{YYYYMMDD}_zhihu_batch{N}.md
```

小宇宙每批一个 summary.md（注意：单条用小宇宙总结 skill → podcast_summaries/，批量用内容引擎 → xyz_summaries/）：
```
~/Documents/xyz_summaries/{YYYYMMDD}_batch{N}_{主题}/summary.md
```

AI HOT 日报：
```
~/Documents/aihot_summaries/aihot_{YYYYMMDD}.md
```

文件结构：
```
# {主题} · 深度总结（Batch {N}）

> 本批{X}条，基于完整转录稿深度处理。

---

## {子主题1}

### 1. {标题}
...（每条完整条目）

---

## {子主题2}
...

---

## 编辑层总评

（本批质量最高的3-5条 + 跨条共振点 + 对用户的价值判断）
```

### 4.3 展示

```bash
open -R "~/Documents/xhs_summaries/{dir}/summary.md"
open -a Effie "~/Documents/xhs_summaries/{dir}/summary.md"
```

---

## Phase 5: Hand-off 全自动总结迭代

Phase 4 所有 summary.md 写完后（含小红书、B站、知乎、公众号、小宇宙等所有平台），本 skill 的批量摄入工作完成。后续碰撞检测、记忆写入、选题排期由全自动总结迭代统一管理。知乎与小红书、B站同等对待，必须经过碰撞检测环节。

```bash
# Hand-off: 调用全自动总结迭代
Skill(全自动总结迭代)
```

传入上下文：
- 本批所有 summary.md 的文件路径列表
- 来源标记："内容引擎 Batch{N} — {平台}"

全自动总结迭代接管后执行：
1. 逐篇提取候选洞察 → 合并去重
2. 碰撞检测（与现有 memory 体系对比）
3. 审核队列（上下文紧张时）或交互式选择（上下文充裕时）
4. 写入 memory → 选题生成 → 排期

### 5.1 标记完成

Hand-off 后，回到本 skill 收尾。

**提醒事项标记**：

通过 AppleScript 走 EventKit 标记完成，确保触发 iCloud 同步到手机：

```bash
# 逐条标记（使用 Phase 1 记录的列表名和标题）
~/.claude/skills/提醒事项处理/reminders.sh complete "<列表名>" "<标题>"
```

> 不再用 SQLite 直接写 `ZCOMPLETED=1` —— 绕过 EventKit 会导致 cloudd 无感知，手机端不更新。

**B站稍后再看清理**：
B站 API 没有直接清空稍后再看的公开接口，需告知用户手动清理：
- 桌面端：bilibili.com → 稍后再看 → 批量管理 → 移除已处理视频
- 或：在 B站 APP 中逐条移除

（待后续调研是否有可用的 API 端点自动清理。）

### 5.2 汇报

向用户输出本批摄入统计：
- 总链接数 → 成功处理数 → 失败数
- 各平台产出 summary.md 路径
- 提醒事项：已标记完成 X 条 / B站：已处理 Y 个视频（字幕 Z 个 + ASR W 个）
- 已移交全自动总结迭代做碰撞+记忆

---

## 关键参数速查

| 参数 | 值 |
|------|-----|
| 上班待分配任务 Z_PK | 57 |
| 暂缓 Z_PK | 93 |
| 人工处理 Z_PK | 94 |
| Reminders DB | `~/Library/Group Containers/group.com.apple.reminders/Container_v1/Stores/Data-1568038F-0A2D-44F0-9A52-369CAE55728D.sqlite` |
| B站采集器 | `python3 ~/scripts/bilibili/bilibili_data_collector.py <SESSDATA> [数量]` |
| B站 SESSDATA | 从浏览器 DevTools → Application → Cookies → bilibili.com 获取 |
| B站字幕阈值 | subtitle > 100 chars 直接用，否则下载ASR |
| SSR fetch | `python3 ~/.claude/skills/小红书总结/xhs_batch_fetch.py <input> <outdir>` |
| ASR transcribe | `python3 ~/.claude/skills/小宇宙总结/transcribe.py`（cwd 找 chunk_*.wav） |
| ffmpeg slice | `-vn -ar 16000 -ac 1 -segment_time 300` |
| 下载方式 | 小红书：Python urllib + 备线CDN (sns-bak-v1 替换 sns-video-v6) / B站：yt-dlp bestaudio |
| 下载 UA | iPhone Safari（小红书）/ yt-dlp bestaudio（B站） |
| 视频源 | 小红书 `h264[0].masterUrl` → 备线CDN / B站 yt-dlp 自动选流 |
| 小红书CDN注意 | 主线 sns-video-v6 全线 403，必须替换为 sns-bak-v1；curl 无法下载，必须用 Python urllib。**短链格式**：统一 `http://xhslink.com/o/` (无www+HTTP) |
| API key | SF_KEY → SILICONFLOW_API_KEY → `~/.config/siliconflow/api_key` |
| 并行数 | 16（小红书+B站视频下载+切片+转录）/ 不限（公众号纯文本） |
| 输出目录 | 小红书 `~/Documents/xhs_summaries/` / 公众号 `~/Documents/article_summaries/` / B站 `~/Documents/podcast_summaries/bilibili_watchlater_{date}/` / 知乎 `~/Documents/article_summaries/` / 小宇宙 `~/Documents/xyz_summaries/` / AI HOT `~/Documents/aihot_summaries/` |
| url-md | `~/.url-md/bin/url-md`（PATH 已配置在 .zshrc） |
| Jina Reader | `https://r.jina.ai/<url>`（免费 200次/天，纯 HTTP） |
| Hand-off 目标 | `全自动总结迭代` skill（碰撞+记忆+选题+排期） |
| 子 agent 架构 | 确认分堆后，每平台/每批启动 1 个独立子 agent，所有 agent 并行运行 |
| 子 agent 类型 | general-purpose（全工具访问，包括 Bash/Read/Write） |
| 并发模型 | agent 间并行（不同平台），agent 内 16 路并发（同平台同批） |

## 复用工具

- `~/.claude/skills/小红书总结/xhs_batch_fetch.py` — 批量SSR抓取
- `~/.claude/skills/小宇宙总结/transcribe.py` — ASR转录（内部 max_workers=16）
- `~/.claude/skills/小红书总结/SKILL.md` — 单条总结质量标准（Phase 4 参考）
- `~/.claude/skills/B站视频总结/SKILL.md` — 单条B站总结质量标准（Phase 4 参考）
- `~/scripts/bilibili/bilibili_data_collector.py` — B站稍后再看列表采集（Phase 1B）
- `url-md` (Rust CLI) — 公众号文章抓取+反爬+Markdown转换
- Jina Reader API — 公众号文章抓取（第一层降级，零配置）
- `全自动总结迭代` skill — 碰撞检测+记忆写入+选题生成+排期（Phase 5 hand-off 目标）
- `yt-dlp` — B站音频下载（比 ffmpeg 直接拉流更稳定，自动处理 cookie/UA）
- `AI资讯日报` skill — AI HOT 日报获取（Phase 2A 调用）
- `知乎抓取` skill — 单条知乎回答/文章抓取（单条即时消费用；批量为内容引擎 Phase 2Z）
- `小宇宙总结` skill — 单条小宇宙播客下载+ASR+总结（单条用小宇宙总结→podcast_summaries/；批量为内容引擎 Phase 2X→xyz_summaries/）

## 注意事项

- Phase 1 分类必须等用户确认，不自行决定分堆
- 404 链接跳过并记录在 summary.md 末尾，不阻塞整批
- **小红书视频下载必须用备线 CDN**：主线 `sns-video-v6.xhscdn.com` 全线 403，将 masterUrl 中 `sns-video-v6` 替换为 `sns-bak-v1`，用 Python urllib（非 curl）下载
- **清理残留用 Python glob，不用 zsh rm -f chunk_***：zsh nomatch 选项会导致 `rm -f chunk_*.wav` 在没有匹配文件时报错退出。改用 `python3 -c "import glob,os;[os.remove(f) for f in glob.glob('$DIR/chunk_*')]"`
- 视频下载前必须清理上次残留的 chunk_*.txt，否则 transcribe.py 会跳过已完成 chunk
- 图文笔记没有视频不进入 Phase 3，直接到 Phase 4
- 公众号链接进入 Phase 2W（两层降级抓取），跳过 Phase 2-3，直接到 Phase 4 总结
- 公众号两层抓取：Jina Reader 优先（零配置），失败则 url-md 兜底，两层都失败标记人工处理
- 公众号文章正文 > 200 bytes 才算成功抓取
- B站视频字幕 > 100 chars 即可直接用于深度总结，无需下载ASR
- **B站字幕采集注意**：采集器的 subtitle 字段可能匹配到完全不相关的视频字幕（如 TED 演讲标题但字幕是健身/电竞内容），使用前需人工抽样验证字幕是否与标题匹配
- B站 SESSDATA cookie 需定期更新（浏览器登录过期后需重新获取）
- B站稍后再看暂无自动清空 API，Phase 5 会提醒用户手动清理
- B站音频下载用 yt-dlp 而非直接 curl（yt-dlp 自动处理 cookie/UA/流选择）
- 与「小红书总结」/「B站视频总结」skill 分工：单条/少量链接即时消费用对应 skill；内容引擎 = 大批量批量摄入
- 与「小宇宙总结」skill 分工：单条用小宇宙总结 → `podcast_summaries/`；批量为内容引擎 Phase 2X → `xyz_summaries/`
- 与「知乎抓取」skill 分工：单条用知乎抓取；批量为内容引擎 Phase 2Z
- **知乎抓取注意**：Jina Reader 对知乎支持较好，优先第一层；url-md 对知乎专栏兼容性更佳
- **小宇宙 CDN 时效性**：xyzcdn 直链可能过期返回 404，批量处理时需从 episode 页面实时提取 mediaId，不可缓存
- **小宇宙音频提取注意**：不要用 `transcriptMediaId` 字段（可能是旧 CDN 路径已失效），应用 `re.findall(r'https://media\.xyzcdn\.net/[^"\s]+\.m4a', html)` 直接从页面提取当前有效的 m4a URL。优先匹配 enclosure JSON 中的 url 字段
- **AI HOT 日报去重**：若同日已手动查过日报，跳过 Phase 2A 避免重复
- **小红书反爬注意**：xhslink.com 有两个解析路径——`https://www.xhslink.com` 可能 connection timeout（CDN 不稳定），但 `http://xhslink.com`（无 www + HTTP）可正常 302 重定向到 `xiaohongshu.com/discovery/item/` 并返回完整 SSR 页面。**解决方案**：将用户提供的 `xhslink.com/o/` 短链统一转成 `http://xhslink.com/o/`（去掉 www，HTTP 协议）再传给 xhs_batch_fetch.py，不要用 `https://www.xhslink.com`。同时 xiaohongshu.com `/explore/` 直链返回空壳页面（10KB no SSR data），不可用
- **子 agent 分发**：确认分堆后一次性分发所有 agent，不等结果之间有依赖。agent 间完全独立、互不阻塞
- 碰撞检测、记忆写入、选题排期已移交全自动总结迭代，不在本 skill 中重复
