#!/usr/bin/env python3
"""
商业摄影 AI 生图工具
复用 image2 (whatai.cc) API，动态加载 prompts/ 目录下赛道
支持 plug-in 扩展：新增 prompts/xxx.py 即自动识别
"""

import requests
import os
import sys
import argparse
import importlib.util
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

API_KEY = "{{API_KEY}}"
API_URL = "https://api.whatai.cc/v1/images/generations"

HEADERS = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {API_KEY}"
}

SKILL_DIR = Path(__file__).parent.resolve()
PROMPTS_DIR = SKILL_DIR / "prompts"


def load_prompts(preset: str) -> list:
    """动态加载 prompts/{preset}.py 的 PROMPTS 列表"""
    module_path = PROMPTS_DIR / f"{preset}.py"
    if not module_path.exists():
        available = [f.stem for f in PROMPTS_DIR.glob("*.py") if f.name != "__init__.py"]
        raise FileNotFoundError(
            f"赛道 '{preset}' 不存在。可用赛道: {', '.join(available)}"
        )

    spec = importlib.util.spec_from_file_location(f"prompts_{preset}", module_path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    prompts = getattr(mod, "PROMPTS", None)
    if prompts is None:
        raise ValueError(f"{module_path} 未定义 PROMPTS 变量")
    return prompts


def generate_image(name: str, prompt: str) -> tuple:
    """生成单图，带 safety retry + timeout retry"""
    payload = {
        "model": "gpt-image-2",
        "prompt": prompt,
        "n": 1,
        "size": "1024x1024"
    }

    try:
        resp = requests.post(API_URL, headers=HEADERS, json=payload, timeout=120)
        data = resp.json()

        if "error" in data:
            err_msg = data["error"].get("message", "")
            if "safety" in err_msg.lower() or "rejected" in err_msg.lower():
                print(f"  [{name}] Safety blocked, trying simplified prompt...")
                simple_prompt = prompt.replace("absence", "empty").replace("isolation", "quiet")
                payload["prompt"] = simple_prompt
                resp = requests.post(API_URL, headers=HEADERS, json=payload, timeout=120)
                data = resp.json()
                if "error" in data:
                    print(f"  [{name}] Retry also failed: {data['error'].get('message', 'unknown')}")
                    return name, None
            else:
                print(f"  [{name}] API error: {err_msg}")
                return name, None

        url = data["data"][0]["url"]
        print(f"  [{name}] Generated: {url[:50]}...")
        return name, url
    except requests.exceptions.Timeout:
        print(f"  [{name}] Timeout, will retry once...")
        try:
            resp = requests.post(API_URL, headers=HEADERS, json=payload, timeout=180)
            data = resp.json()
            if "error" in data:
                print(f"  [{name}] Retry error: {data['error'].get('message', 'unknown')}")
                return name, None
            url = data["data"][0]["url"]
            return name, url
        except Exception as e:
            print(f"  [{name}] Retry failed: {e}")
            return name, None
    except Exception as e:
        print(f"  [{name}] Exception: {e}")
        return name, None


def download_image(name: str, url: str, output_dir: Path) -> Path:
    """下载图片"""
    try:
        r = requests.get(url, timeout=60)
        ext = url.split(".")[-1].split("?")[0]
        if ext not in ["png", "jpg", "jpeg", "webp"]:
            ext = "png"
        path = output_dir / f"{name}.{ext}"
        with open(path, "wb") as f:
            f.write(r.content)
        print(f"  [{name}] Saved: {path} ({len(r.content)//1024}KB)")
        return path
    except Exception as e:
        print(f"  [{name}] Download failed: {e}")
        return None


def batch_generate(prompts: list, output_dir: Path, max_workers: int = 8, count: int = None):
    """批量生成并下载"""
    os.makedirs(output_dir, exist_ok=True)

    if count and count < len(prompts):
        prompts = prompts[:count]
        print(f"Selected first {count} prompts from {len(prompts)} total.")
    else:
        print(f"Generating {len(prompts)} images...")

    urls = {}
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(generate_image, name, p): name for name, p in prompts}
        for future in as_completed(futures):
            name, url = future.result()
            if url:
                urls[name] = url

    print(f"\nGenerated: {len(urls)}/{len(prompts)}")
    if not urls:
        print("No images generated successfully.")
        return []

    print("Downloading...")
    paths = []
    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = {executor.submit(download_image, name, url, output_dir): name for name, url in urls.items()}
        for future in as_completed(futures):
            path = future.result()
            if path:
                paths.append(path)

    print(f"\nDone: {len(paths)} images saved to {output_dir}")
    return paths


def list_presets() -> list:
    """列出可用赛道"""
    return sorted([f.stem for f in PROMPTS_DIR.glob("*.py") if f.name != "__init__.py"])


def main():
    parser = argparse.ArgumentParser(description="商业摄影 AI 生图工具")
    parser.add_argument("--preset", "-p", required=True, help="赛道名称")
    parser.add_argument("--count", "-n", type=int, help="出图张数（默认全部）")
    parser.add_argument("--output", "-o", default="~/Documents/commercial_samples/output",
                        help="输出目录")
    parser.add_argument("--workers", "-w", type=int, default=8, help="并发数（默认 8）")
    parser.add_argument("--list-presets", action="store_true", help="列出可用赛道")

    args = parser.parse_args()

    if args.list_presets:
        print("可用赛道:")
        for p in list_presets():
            print(f"  - {p}")
        return

    output_dir = Path(os.path.expanduser(args.output))
    prompts = load_prompts(args.preset)
    batch_generate(prompts, output_dir, max_workers=args.workers, count=args.count)


if __name__ == "__main__":
    main()
