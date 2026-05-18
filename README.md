# Claude Code 一键安装工具

**品牌：小明老师 AI 落地咨询**

把 Claude Code 从零安装 + 行业技能包配置变成一个 5 分钟的交互式流程，非技术用户也能操作。

## 快速开始

### macOS / Linux

```bash
# 解压后进入目录
cd claude-code-installer

# 运行安装
bash install.sh
```

### Windows

```powershell
# 在 PowerShell 中运行
.\install.ps1
```

> **推荐**：Windows 用户如果有 WSL2，建议在 WSL 终端中运行 `bash install.sh`（Linux 版功能更完整）。

## 安装流程

安装器会按顺序引导你完成：

1. **环境检测** — 自动检测系统、架构、已安装工具
2. **安装 Claude Code CLI** — 官方原生安装器 / Homebrew / WinGet
3. **选择行业方案** — 根据你的行业安装对应的专业工具集（技能包）
4. **配置 AI 接口** — DeepSeek / Anthropic / 自定义 API
5. **安装技能包** — 复制选中技能到 `~/.claude/skills/`
6. **部署配置** — 生成 `settings.json` + `CLAUDE.md`
7. **验证安装** — 检查 claude 命令、技能数量、配置语法

## 行业方案

| 方案 | 包含技能 | 适合人群 |
|------|----------|----------|
| 🏛️ 法律/行政复议 | 案件全流程管理、OCR、决定书核对、证据目录、物流单打印 | 行政复议/法律工作者 |
| 📷 摄影/视觉创作 | 当代摄影生图、哈苏胶片复刻、商业片出图、旅行攻略 | 摄影师/视觉创作者 |
| ✍️ 内容创作/自媒体 | 小红书发布&总结、小说影像化、选题拷问、B站总结、公众号解析 | 自媒体运营/内容创作者 |
| 🤖 AI 落地/创业 | 全自动总结迭代、AI日报、播客/视频总结、知乎抓取 | AI创业者/知识工作者 |
| 🔧 通用工具 | 记忆管理、数字日记、系统清理、调试 | 所有人（始终安装） |

## 选项

```bash
bash install.sh --dry-run          # 试运行，不修改文件
bash install.sh --skip-confirm     # 跳过所有确认（自动化部署）
bash install.sh --add-industry     # 追加行业方案（保留已有配置）
bash install.sh --help             # 显示帮助
```

## API 后端

推荐中国大陆用户使用 **DeepSeek API**（国内直连，无需代理）：

1. 访问 [platform.deepseek.com](https://platform.deepseek.com/api_keys)
2. 注册/登录后创建 API Key
3. 安装时粘贴 Key 即可

也支持 Anthropic 官方 API、硅基流动、OpenRouter 等兼容接口。

## 构建分发包

如果你是小明老师本人，需要更新技能后重新打包：

```bash
bash scripts/build_package.sh          # 完整流程：同步技能 → 构建 → 打包 zip
bash scripts/build_package.sh --sync   # 仅同步最新技能
bash scripts/build_package.sh --zip    # 仅打包
```

## 目录结构

```
claude-code-installer/
├── install.sh              # macOS/Linux 入口
├── install.ps1             # Windows 入口
├── README.md               # 本文件
├── lib/                    # 功能模块
│   ├── common.sh           # 颜色/日志/OS检测
│   ├── platform_detect.sh  # 平台诊断
│   ├── install_claude.sh   # Claude Code CLI 安装
│   ├── select_industry.sh  # 行业选择菜单
│   ├── configure_api.sh    # API 配置
│   ├── deploy_skills.sh    # 技能部署
│   ├── deploy_config.sh    # 配置模板渲染
│   ├── install_plugins.sh  # Superpowers 插件
│   └── verify.sh           # 安装验证
├── skills/                 # 按行业分组的技能包
├── commands/               # 按行业分组的命令
├── templates/              # 配置模板
├── scripts/                # 构建工具
│   ├── build_package.sh    # 打包脚本
│   └── sync_skills.py      # 技能同步+脱敏
└── assets/                 # 欢迎界面等
```

## 联系

小明老师 AI 落地咨询
