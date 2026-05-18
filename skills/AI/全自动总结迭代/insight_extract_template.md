# 洞察提取模板

在消费 skill 完成总结后，基于 summary.md 运行此模板。

## Prompt

```
读取以上总结内容，提取 1-3 个可行动洞察。严格按以下 JSON 格式输出，不要输出其他内容：

{
  "source": "内容标题",
  "source_type": "podcast|bilibili|xhs|aihot|article",
  "date": "YYYY-MM-DD",
  "insights": [
    {
      "claim": "一句话核心主张（可被验证或反驳的判断，不是事实描述）",
      "category": "AI产业|创作方法|商业策略|社会趋势|个人成长|其他",
      "confidence": "high|medium|low",
      "related_tags": ["关键词1", "关键词2"]
    }
  ]
}

规则：
1. claim 必须是可争论的主张。坏："AI发展很快"；好："AI中间件层正在消失，应用层直接调用基础模型"
2. 如果内容没有新洞察，insights 输出空数组 []
3. 每个 insight 独立不重叠
4. related_tags 用于后续和 memory 做碰撞匹配，选最相关的 2-4 个中文标签
5. confidence: high=有数据/案例支撑的明确判断；medium=有道理的观察但不够确凿；low=推测或观点

## 示例

输入：一篇关于追觅和俞浩的深度分析
输出：
{
  "source": "追觅俞浩百条视频给谁看的",
  "source_type": "xhs",
  "date": "2026-05-14",
  "insights": [
    {
      "claim": "创始人IP化在硬件赛道是双刃剑——短期聚流量，长期让品牌和一个人绑定",
      "category": "商业策略",
      "confidence": "high",
      "related_tags": ["创始人IP", "品牌建设", "硬件创业"]
    }
  ]
}
```
