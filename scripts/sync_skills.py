#!/usr/bin/env python3
"""
sync_skills.py — 从 ~/.claude/skills/ 同步技能到打包目录

功能：
1. 读取 skills/manifest.json 获取映射
2. 从 ~/.claude/skills/ 复制技能到包目录对应行业子目录
3. 路径脱敏：/Users/sunminwen/ → $HOME/
4. 密钥剥离：移除 API Key、Token 等敏感模式
5. 跳过 personal_only 标记的技能
"""

import json
import os
import re
import shutil
import sys
from pathlib import Path

# ── 配置 ──────────────────────────────────────────────────
SKILLS_SRC = Path.home() / ".claude" / "skills"
COMMANDS_SRC = Path.home() / ".claude" / "commands"
PACKAGE_DIR = Path(__file__).resolve().parent.parent
SKILLS_DST = PACKAGE_DIR / "skills"
COMMANDS_DST = PACKAGE_DIR / "commands"
MANIFEST_PATH = SKILLS_DST / "manifest.json"

# 脱敏规则（顺序重要：更具体的模式放在前面）
# 注意：使用当前用户名动态生成，不在代码中硬编码用户名
_CURRENT_USER = os.environ.get("USER", os.environ.get("USERNAME", ""))

SANITIZE_PATTERNS = [
    # 绝对路径替换（当前用户 + 通用兜底）
    (re.compile(rf"/Users/{re.escape(_CURRENT_USER)}/"), "$HOME/") if _CURRENT_USER else None,
    (re.compile(r"/Users/\w+/"), "$HOME/"),
    # Claude Code 项目目录命名
    (re.compile(rf"-Users-{re.escape(_CURRENT_USER)}"), "-USERNAME") if _CURRENT_USER else None,
    (re.compile(r"-Users-\w+"), "-USERNAME"),
    # API Key 模式
    (re.compile(r"(sk-ant-[a-zA-Z0-9_-]{20,})"), "{{ANTHROPIC_API_KEY}}"),
    (re.compile(r"(sk-[a-zA-Z0-9]{30,})"), "{{API_KEY}}"),
    (re.compile(r"(AKID[a-zA-Z0-9]{30,})"), "{{API_KEY}}"),
    # Token 模式
    (re.compile(r"(eyJ[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]{20,})"), "{{JWT_TOKEN}}"),
    # 手机号
    (re.compile(r"1[3-9]\d{9}"), "{{PHONE}}"),
    # 个人标识（GitHub用户名等）
    (re.compile(r"\bsmwswk\b"), "{{GITHUB_USERNAME}}"),
    (re.compile(r"smwswk\.github\.io"), "{{GITHUB_PAGES_DOMAIN}}"),
]

# 不分发的技能（在 manifest.excluded_skills 中定义）
EXCLUDED_SKILLS = set()
EXCLUDED_COMMANDS = set()


def load_manifest():
    with open(MANIFEST_PATH) as f:
        return json.load(f)


def sanitize_content(content):
    for pattern, replacement in SANITIZE_PATTERNS:
        if pattern is None or replacement is None:
            continue
        content = pattern.sub(replacement, content)
    return content


def sanitize_file(filepath):
    """脱敏单个文件内容"""
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
        sanitized = sanitize_content(content)
        if sanitized != content:
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(sanitized)
            return True
    except (UnicodeDecodeError, IsADirectoryError):
        pass  # 跳过二进制文件和目录
    return False


def sync_skill(skill_name, src_dir, dst_dir):
    """复制单个技能目录，脱敏处理"""
    src = SKILLS_SRC / src_dir
    dst = dst_dir / src_dir

    if not src.exists():
        print(f"  ⚠ {skill_name}: 源目录不存在 {src}")
        return False

    if dst.exists():
        shutil.rmtree(dst)

    shutil.copytree(src, dst, ignore=shutil.ignore_patterns(
        "__pycache__", "*.pyc", ".DS_Store", ".git"
    ))

    # 脱敏所有文本文件
    sanitized_count = 0
    for root, dirs, files in os.walk(dst):
        # 跳过符号链接（原 print-pdf 等）
        dirs[:] = [d for d in dirs if not Path(root, d).is_symlink()]
        for fname in files:
            fpath = Path(root) / fname
            if sanitize_file(fpath):
                sanitized_count += 1

    if sanitized_count > 0:
        print(f"    🔒 脱敏 {sanitized_count} 处")
    return True


def sync_commands():
    """复制命令文件到包目录"""
    manifest = load_manifest()
    cmds_manifest = manifest.get("industries", {}).get("法律", {}).get("commands", [])
    excluded = set(manifest.get("excluded_commands", {}).keys())

    legal_dst = COMMANDS_DST / "法律"
    legal_dst.mkdir(parents=True, exist_ok=True)

    synced = 0
    for cmd_name in cmds_manifest:
        if cmd_name in excluded:
            print(f"  ⏭ 跳过 /{cmd_name}（已在排除列表）")
            continue

        src_file = COMMANDS_SRC / f"{cmd_name}.md"
        dst_file = legal_dst / f"{cmd_name}.md"

        if src_file.exists():
            shutil.copy2(src_file, dst_file)
            sanitize_file(dst_file)
            print(f"  ✅ /{cmd_name}")
            synced += 1
        else:
            print(f"  ⚠ /{cmd_name}: 源文件不存在 {src_file}")

    return synced


def main():
    if not SKILLS_SRC.exists():
        print(f"错误：技能源目录不存在 {SKILLS_SRC}")
        sys.exit(1)

    manifest = load_manifest()
    excluded = set(manifest.get("excluded_skills", {}).keys())

    print("=" * 60)
    print("技能同步工具 — 从 ~/.claude/skills/ → 打包目录")
    print("=" * 60)
    print()

    # 同步各行业技能
    total = 0
    for ind_id, ind_data in manifest.get("industries", {}).items():
        skills = ind_data.get("skills", {})
        dst_dir = SKILLS_DST / ind_id
        dst_dir.mkdir(parents=True, exist_ok=True)

        for skill_name, skill_info in skills.items():
            if skill_name in excluded:
                print(f"  ⏭ 跳过 {skill_name}（已在排除列表：{excluded[skill_name]}）")
                continue

            src_dir = skill_info.get("source", skill_name)
            print(f"  📋 {ind_data.get('label', ind_id)} / {skill_name}")
            if sync_skill(skill_name, src_dir, dst_dir):
                total += 1

    print()
    print(f"技能同步完成：{total} 个")
    print()

    # 同步命令
    print("命令同步：")
    cmd_count = sync_commands()
    print(f"命令同步完成：{cmd_count} 个")
    print()

    # 清理空目录
    for d in SKILLS_DST.iterdir():
        if d.is_dir() and d.name != "_archived" and not any(d.iterdir()):
            print(f"  清理空目录: {d.name}")
            d.rmdir()

    print("=" * 60)
    print("全部同步完成！")
    print("=" * 60)


if __name__ == "__main__":
    main()
