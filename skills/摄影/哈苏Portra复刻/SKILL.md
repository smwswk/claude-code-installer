---
name: 哈苏Portra复刻
description: >
  gpt-image-2 从零生成哈苏 500C/M + Kodak Portra 400 胶片风格照片。当用户说"哈苏复刻""Portra调色""炮塔风格生图""废片变宝""哈苏美学""胶片质感生成""蜂蜜金调色"或提供照片要求改成哈苏胶片风格时触发。关键原则：NOT 修图编辑——而是用反向工程 prompt 模板从零 text-to-image 生成。文生图模型做修图必出塑料感。
---

# 哈苏 500C/M + Kodak Portra 400 AI 复刻

## 核心原则

**绝不用图像编辑/修图模型。** 从零 text-to-image 生成才能复刻参考图风格。修图=塑料感，生成=胶片感。

## Prompt 模板（最终版，2026-05-15 验证通过）

```
[场景描述]. Shot on Hasselblad 500C/M with Kodak Portra 400 120 medium format film. The square 6x6 image fills 97% of the frame — only an extremely thin dark edge (hairline, about 1% of frame width) is visible around the image as the 120 film rebate. This is NOT a wide Instagram border — it's barely visible, just a whisper of dark edge from the scanner-calibrated C-41 film base. NO sprocket holes at all — 120 film edges are completely clean. Natural daylight color balance with subtle warmth — clean whites, accurate colors, Portra 400's signature neutral-warm skin tones. Moderate contrast with open shadows that retain detail, soft highlight roll-off without blowing out. Natural saturation — colors are true to life, not artificially vivid or muted. Fine organic film grain, gentle medium format sharpness, smooth tonal transitions. Photorealistic, detailed textures, natural relaxed atmosphere.
```

### 关键事实校准

| 项目 | 错误认知 | 正确事实 |
|------|---------|---------|
| 胶卷规格 | 135 (35mm) | **120 中画幅**，宽61mm，6x6画幅56mm |
| 齿孔 | 有齿孔 | **无齿孔**，120胶卷边缘完全干净 |
| 边框宽度 | 宽边框 | **极窄**，约画面1%，发丝级 |
| 边框颜色 | 亮橙色/黑色 | **暗色**，C-41片基被扫描仪校准后接近黑 |
| 色彩 | 蜂蜜金/焦糖过暖 | **自然日光白平衡+微暖**，Portra 400中性暖调 |
| 饱和度 | 低饱和 | **自然饱和度**，色彩真实不过艳不寡淡 |

## 管线

1. **视觉模型提取场景**：用硅基流动 GLM-4.1V-9B 看原片，只描述场景内容（人物/环境/构图/动作），不描述色彩和风格
2. **套入模板**：场景描述填入上述模板
3. **gpt-image-2 生成**：`/v1/images/generations` endpoint，1024x1024，纯 text-to-image（不带原图）
4. **保存结果 + prompt 文本**，方便复用和迭代

## 参考图集

`~/creative_output/image-gen-output/sweet_water_20260508/01_日子甜得像糖水/`
—— 9 张 AI 生成的哈苏 Portra 400 糖水家常人像，"日子甜得像糖水"

## API 配置

- Endpoint: `https://api.whatai.cc/v1/images/generations`
- Model: `gpt-image-2`
- Auth: {{API_KEY}}
- Vision: `python3 ~/.claude/scripts/vision.py <image> <prompt>`

## 变体：漫展/Cosplay/剧场场景

当原片是漫展、cosplay、舞台表演等复杂场景时，标准 pipeline 会出三个问题：
- **构图太紧**：gpt-image-2 默认紧裁，多人互动场景尤其严重
- **内容失真**：标准 vision prompt 太简略，cosplay 服装/角色细节丢失
- **背景杂乱**：漫展背景被原样描述，画面不够舞台化

**增强 vision prompt**（替代标准版，仅用于复杂场景）：

```
Describe this photo for AI image generation. Be very specific: exact costume details (colors, patterns, accessories, style, any recognizable character), props being held or nearby, number of subjects and their spatial relationship (who is where, what are they doing), background setting in full detail. Note if background is cluttered — if so, describe a clean theatrical stage backdrop instead. 3-4 English sentences. No color temperature/film/camera specs.
```

**增强模板**（在标准模板基础上加两处）：

```
{scene}. This is a convention cosplay performance on a theatrical stage. Wide full-body composition with generous breathing room around the subject, showing the complete figure and surrounding stage environment. [后接标准 Portra 400 模板...]
```

**何时用哪个**：
- 简单单人+明确道具+干净背景 → 标准 pipeline 足够
- 多人互动+复杂 cosplay+杂乱漫展背景 → 增强 pipeline

## 历史验证

- 2026-05-15 Batch1：279 张飞思废片中选 5 张，反推 prompt 模板后 gpt-image-2 从零生成，用户确认
- 2026-05-15 Batch2：9 张"简单的颜色"系列，v1 色彩暗淡+黑边错误，v2 修正橙色片基边框+糖水鲜明色彩，用户确认
- 2026-05-15 Batch3：9 张漫展剧场/打印，7 好 2 构图太紧 3 内容失真 1 背景杂乱
- 2026-05-15 Batch4：6 张漫展剧场/第二批，3 好 1 构图太紧 2 内容失真
- 2026-05-15 剧场修复：8 张问题重新生成（增强 vision + 宽构图 + 舞台化），用户确认
- 教训：本地色彩科学管线（OpenCV LUT/分通道曲线）不够"胶片"；qwen-image-edit-max 编辑模型效果不稳定；gpt-image-2 从零生成是唯一正确路线；Portra 400 是 C-41 负片=橙色片基，不能写 black borders；漫展/cosplay 复杂场景需要增强版 pipeline，标准版只适合简单场景
