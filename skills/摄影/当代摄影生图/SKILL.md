---
name: 当代摄影生图
description: 当代艺术摄影风格 AI 生图。当用户说"当代艺术生图"、"模仿摄影风格生图"、"杜塞尔多夫风格生图"、"Photo Fairs 风格"、"当代摄影模仿"、"类型学生图"、"档案风生图"、"艺术博览会风格生图"、"contemporary photo gen"、"art fair style image"、"Dusseldorf school style"等时触发。基于全球摄影博览会（影像上海/Photo London/巴黎摄影展/MIA）趋势，使用 image2(whatai.cc) API 批量生成。
---

# 当代艺术摄影风格生图 Skill

基于 2026 年全球摄影博览会趋势，模仿杜塞尔多夫学派、档案摄影、心理空镜等当代艺术风格，使用 image2 API 批量生成 AI 图像。

## 触发条件

用户说以下关键词时激活：
- "当代艺术生图"、"当代摄影风格生图"
- "模仿摄影风格生图"、"艺术博览会风格"
- "杜塞尔多夫风格"、"Dusseldorf school style"
- "类型学生图"、"档案风生图"
- "Photo Fairs 风格"、"contemporary photo gen"
- "art fair style image"
- 任何提到"当代艺术"+"生图/AI 图/生成图片"的组合

## 核心能力

### 1. 一键批量生成 9 张验证过的当代艺术风格图

内置 9 个已验证可用的 prompt，覆盖：

| 编号 | 风格 | 参考艺术家 |
|------|------|-----------|
| 01 | 类型学工业建筑 | 贝歇夫妇 (Becher) |
| 02 | 中性夜景 | 托马斯·鲁夫 (Ruff) |
| 03 | 空寂档案空间 | 康迪达·赫弗 (Hofer) |
| 04 | 建筑立面类型学 | 杨迪 |
| 05 | 消费景观重复 | 古尔斯基 (Gursky) |
| 06 | 高原精神性 | 盖少华 |
| 07 | 伪档案质感 | 史阳琨 |
| 08 | 冷静肖像 | 托马斯·鲁夫 (Ruff) |
| 09 | 空无心理空镜 | 当代概念摄影 |

### 2. 自动处理安全过滤重试

部分 prompt 会被 API 安全系统拦截（如"isolation"、特定人物描述等），脚本内置自动简化重试逻辑。

### 3. 支持自定义 prompt 单图生成

用户可以提供自定义 prompt，以当代艺术风格生成单张图片。

## 使用方式

### 方式一：对话触发（推荐）

直接说：
```
/当代艺术生图
当代艺术生图来一套
模仿杜塞尔多夫风格生 9 张图
Photo Fairs 风格生图
```

### 方式二：命令行脚本

```bash
# 生成全部 9 张
python3 ~/.claude/skills/当代摄影生图/generate.py

# 只生成特定风格
python3 ~/.claude/skills/当代摄影生图/generate.py --preset becher   # 只生成贝歇式
python3 ~/.claude/skills/当代摄影生图/generate.py --preset gursky   # 只生成古尔斯基式
python3 ~/.claude/skills/当代摄影生图/generate.py --preset ruff     # 鲁夫风格（夜景+肖像）

# 自定义 prompt 单图
python3 ~/.claude/skills/当代摄影生图/generate.py --custom "your prompt here" --name my_image
```

### 预设参数对应表

| --preset | 生成的图 |
|----------|---------|
| `all` (默认) | 全部 9 张 |
| `becher` | 01 水塔类型学 |
| `ruff` | 02 夜景 + 08 肖像 |
| `hofer` | 03 空寂图书馆 |
| `yangdi` | 04 窗户类型学 |
| `gursky` | 05 超市消费景观 |
| `gai` | 06 高原巨石 |
| `shi` | 07 伪档案 |
| `portrait` | 08 冷静肖像 |
| `empty` | 09 空镜 |

## 工作流程（对话模式）

当用户触发时，按以下步骤执行：

### Step 1: 确认需求

问用户：
- "要生成全部 9 张，还是指定某几张？"
- "保存到哪个目录？（默认 ~/Documents/contemporary_photo_gen/）"

### Step 2: 调用 Python 脚本批量生成

```bash
python3 ~/.claude/skills/当代摄影生图/generate.py \
  --preset all \
  --output ~/Documents/contemporary_photo_gen/YYYY-MM-DD/
```

### Step 3: 展示结果

- 列出成功/失败的数量
- 用 `open -R` 打开 Finder 展示文件
- 如果有失败的，说明原因（安全过滤/超时）并询问是否重试

### Step 4: 微调（如用户要求）

如果用户说"某张味道不够当代"：
1. 分析具体哪张的问题（太抒情？太正常？缺少观念性？）
2. 调整 prompt：加入档案废墟感、法医记录美学、消费批判、监控视角等元素
3. 重新生成该张
4. 更新指南中的 prompt 记录

## Prompt 设计原则（当代感强化）

### 必须包含的元素
- **deadpan aesthetic** — 面无表情的客观性
- **large format photography** — 大画幅质感
- **muted palette** — 低饱和、克制色调
- **institutional / documentary** — 机构/档案气质
- **absence / absence of people** — 空无、缺席

### 避免的元素（会削弱当代感）
- ❌ "beautiful"、"stunning"、"breathtaking" — 过于抒情
- ❌ golden hour、warm sunset — 浪漫化光线
- ❌ "serene"、"peaceful"、"meditative" — 情绪形容词（换成"stillness"）
- ❌ "perfect"、"flawless" — 完美主义
- ❌ 过多描述性形容词，缺少观念性

### 当代感强化词库
| 效果 | 关键词 |
|------|--------|
| 档案废墟 | dust, gaps, peeling paint, fluorescent light, institutional green |
| 法医记录 | forensic documentation, evidence, surveillance, objective |
| 消费批判 | repetition, identical, disruption in pattern, overwhelming scale |
| 监控视角 | overhead angle, CCTV aesthetic, double shadow system |
| 类型学 | typology, grid, exact same angle, neutral background |

## API 配置

- **Endpoint**: `https://api.whatai.cc/v1/images/generations`
- **Model**: `gpt-image-2`
- **Size**: `1024x1024`
- **Key**: 从用户 memory 中读取 (`reference_image2_backend.md`)
- **Cost**: ~$0.04/张

## 注意事项

1. **安全过滤**：部分 prompt 会被 API 安全系统拦截（约 20-30% 概率），脚本已内置自动重试
2. **超时**：复杂场景可能超时（120s），脚本会自动重试一次（180s）
3. **并发**：默认 5 并发，避免触发 429
4. **图片格式**：返回 PNG，保存在指定目录
5. **版本管理**：v2 标记的是经过微调后的 prompt（当代感更强）
