---
name: 商业片出图
description: >
  当用户说"商业片出图"、"商业摄影"、"广告图"、"批量出图"、"commercial photo"、"product photo"时激活。
  复用 image2 (whatai.cc) API 批量生成商业摄影风格图片。交互式问参数（赛道/张数/输出目录），
  动态加载 prompts/ 目录下赛道文件，支持 plug-in 扩展。出图完成后 open -R 打开 Finder 展示。
---

# 商业片 AI 出图

复用 image2 (whatai.cc) API，批量生成商业摄影/广告/电商/空间/餐饮等场景的高质量图片。

## 触发条件

- "商业片出图"、"商业摄影"、"广告图"、"批量出图"
- "commercial photo"、"product photo"、"ad image"

## 执行步骤

### 1. 交互式问参数

- **赛道**：扫描 `~/.claude/skills/商业片出图/prompts/` 目录下所有 `.py` 文件（排除 `__init__.py`），列出可用选项
- **张数**：默认 9 张，用户可改
- **输出目录**：默认 `~/Documents/commercial_samples/{YYYYMMDD}/`，可指定

### 2. 加载 Prompt

```python
from prompts.{赛道} import PROMPTS
```

`PROMPTS` 格式：`list[tuple[str, str]]`，每个元素为 `(name, prompt_string)`。

### 3. 批量出图

```bash
python3 ~/.claude/skills/商业片出图/generate_commercial.py \
  --preset {赛道} --count {张数} --output {目录} --workers 8
```

- 8 workers 生成 + 8 workers 下载
- safety block 自动改写 prompt 重试（抄自 当代摄影生图 skill）
- timeout 120-180s，失败项输出日志不中断整批

### 4. 交付

出图完成后：
- `open -R {目录}` 打开 Finder 展示
- 列出生成清单（成功/失败数 + 文件路径）

## Prompt 模板格式

沿用现有统一格式，prompt 字符串自然语言堆叠槽位：

```
[题材] + [光线] + [构图] + [风格] + [色板] + hyper realistic
```

## 注意事项

- image2 API endpoint: `https://api.whatai.cc/v1/images/generations`，model=`gpt-image-2`
- 动态 plug-in：新建 `prompts/fashion.py` 后无需改主脚本，自动识别为可用赛道
- 用户已有 `~/Documents/commercial_samples/`（v1/v2/v3），新批次默认接在日期目录下，不覆盖旧数据
- 输出命名：`{赛道}_{序号}_{关键词}.{ext}`
