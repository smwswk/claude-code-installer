---
name: 旅行攻略生成
description: >
  当用户提供目的地信息（公众号文章/分享文本/链接）并要求"排攻略""排行程""安排路线""几天几夜"
  "周末去哪"时激活。解析源材料提取POI → 收集约束条件 → 生成结构化行程HTML（桌面版+移动版）
  → 输出PDF。适用于城市散步、展会活动、美食路线等场景。
---

# 旅行攻略生成

## 触发

用户提供源材料（文章、分享文本、链接） + 目的地信息，说"排个攻略""帮我安排行程""两天一夜怎么玩""学一下这篇文章给我排路线"等。

典型触发语：攻略、行程、安排、路线、几天几夜、周末去哪、帮我排一下。

## 流程

### Step 1: 收集信息

从用户消息中提取，不够则追问：
- **目的地**：城市/区域
- **日期/天数**：具体日期或天数
- **抵达/离开时间**：尤其是首日晚到的情况
- **人数**：solo trip / 双人 / 多人
- **偏好**：摄影/美食/看展/咖啡/散步/购物
- **源材料**：用户粘贴的文章或链接，从中提取 POI

### Step 2: 解析源材料

从文章中提取：
- 地点名称、地址、营业时间
- 活动/展览名称、时间段
- 特色描述和金句（保留原文表达）
- 注意事项（需预约、排队、限时开放等）
- 出片点位标记

### Step 3: 编排行程

遵循以下原则：
- 按时间段编排，每 1-2 小时一个节点
- 空间逻辑闭合——不走回头路，每天路线自然流动
- 保持松弛感——不塞太满，留自由时间
- 区分「必去」和「选配」
- 餐饮穿插在动线上，不过桥不过河
- 标注出片点位和注意事项

### Step 4: 生成 HTML（桌面版）

文件名：`{目的地}_{行程主题}_desktop.html` 或 `{目的地}_{行程主题}.html`
路径：`~/Documents/`

#### CSS 设计系统（宁波攻略验证版）

```css
:root {
  --bg: #f7f5f0;
  --card: #ffffff;
  --text: #2c2c2c;
  --muted: #8c8c8c;
  --accent: #c75b3a;       /* 主色，可用于单日行程 */
  --accent2: #3a7ca5;      /* 辅色，用于次日或备选 */
  --tag-bg: #f0ebe3;
  --border: #e8e3db;
  --day1: #c75b3a;
  --day2: #3a7ca5;
}
body {
  font-family: -apple-system, "Noto Serif SC", "PingFang SC", "Hiragino Sans GB", serif;
  background: var(--bg); color: var(--text); line-height: 1.6;
  padding: 40px 20px;
}
.container { max-width: 720px; margin: 0 auto; }
```

#### 组件库

**卡片**（核心组件）：
```css
.card {
  background: var(--card);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 18px 20px;
  margin-bottom: 10px;
  display: flex;
  gap: 16px;
  align-items: flex-start;
}
```

**时间胶囊**：
```css
.time-pill {
  flex-shrink: 0;
  font-weight: 600; font-size: 12px;
  padding: 3px 10px; border-radius: 20px;
  min-width: 72px; text-align: center;
}
/* 按天/时段分色 */
.tp-day1 { background: #fdf2ee; color: var(--day1); }
.tp-day2 { background: #eef5f9; color: var(--day2); }
.tp-night { background: #f5f5f5; color: #666; }
```

**日期标题**：
```css
.day-title {
  font-size: 15px; font-weight: 700; letter-spacing: 1px;
  margin: 36px 0 14px; padding: 6px 14px; border-radius: 6px;
  display: inline-block;
}
.day0 { background: #f5f5f5; color: #888; }
.day1 { background: #fdf2ee; color: var(--day1); }
.day2 { background: #eef5f9; color: var(--day2); }
```

**备注条**（三种色调）：
- 黄色高亮（重要提示）：`background: #fff8e1; color: #b05a00;`
- 蓝色提示（小贴士）：`background: #f0f7fb; color: #2c6a8a;`
- 红色警告（限时/名额）：`background: #fff0f0; color: #a04040;`

**出片标签**：
```css
.photo-tag {
  display: inline-block; font-size: 11px;
  background: #2c2c2c; color: #fff;
  padding: 1px 7px; border-radius: 3px; margin-left: 4px;
}
```

**选配区块**（虚线边框）：
```css
.opt-block {
  margin: 8px 0 12px 18px; padding-left: 14px;
  border-left: 2px solid #e0dcd5;
}
```

**地图/空间逻辑**（底部总览）：
```css
.map-note {
  background: #fafaf8; border: 1px solid var(--border);
  border-radius: 10px; padding: 18px; margin-top: 36px;
  font-size: 13px; color: #777; line-height: 1.9;
}
```

### Step 5: 生成 HTML（移动版）

文件名：`{目的地}_{行程主题}_mobile.html`

移动版适配改动：
- `body { font-size: 18px; padding: 36px 14px; }` — 基础字号从 14px 跳到 18px
- `.container { max-width: 410px; }` — 窄容器模拟手机屏幕
- `.card { padding: 18px 18px; gap: 14px; }` — 略收紧间距
- `.card-title { font-size: 20px; }` — 标题加大
- `.card-desc { font-size: 17px; line-height: 1.8; }` — 正文加大
- `.time-pill { font-size: 16px; }` — 时间标签加大
- `.card-note { font-size: 16px; line-height: 1.7; }` — 备注加大
- `.map-note { font-size: 16px; line-height: 2.1; }` — 底部总览加大
- 所有间距和圆角略微放大

### Step 6: 生成 PDF

从移动版（或桌面版）HTML 生成 PDF：
```bash
# 方法1: 用 Chrome headless（推荐，保真度最高）
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --headless --disable-gpu --print-to-pdf=/path/to/output.pdf \
  --no-margins --print-to-pdf-no-header \
  file://$HOME/Documents/{html_filename}.html

# 方法2: 如果 Chrome 不可用，用 Safari
# 但 Safari headless 不支持 print-to-pdf，需手动提醒用户用浏览器打印
```

PDF 文件名：与 HTML 同名，`.html` → `.pdf`
输出路径：`~/Documents/`

### Step 7: 展示

```bash
open -R ~/Documents/{文件名}.pdf
open -R ~/Documents/{文件名}.html
open -R ~/Documents/{文件名}_mobile.html
```

## 输出清单

每次生成至少产出：
1. `{name}.html` — 桌面版行程（可直接在浏览器打开，也可打印）
2. `{name}_mobile.html` — 移动版（手机浏览器打开效果最佳）
3. `{name}.pdf` — PDF 版（微信/手机分发）

## 设计原则

- **卡片即时间块**：每个 card 是一个时间节点，用户扫一眼就懂
- **颜色即日子**：多日行程用不同颜色区分，视觉上不迷路
- **选配留白**：不替用户做所有决定，虚线边框的 optional block 让用户自己选
- **地图收底**：所有卡片走完后，底部空间逻辑图帮用户建立整体方向感
- **出片标签**：摄影向用户的核心需求，用 `photo-tag` 在小标题旁标注

## 注意事项

- 源材料中的金句保留原文，不要改写（如"中年叔叔浓度极高"）
- 地点名+地址必须准确，不确定的标记 `（待确认）`
- 时间逻辑要自洽：A 点到 B 点打车/步行时间要合理
- 5 月中/8 月等季节信息要在提醒里体现（带水、防晒、好走的鞋等）
- 移动版不是简单 responsive CSS，是独立文件——字号和间距为手机屏幕单独调过
