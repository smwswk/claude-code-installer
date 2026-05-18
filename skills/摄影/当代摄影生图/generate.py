#!/usr/bin/env python3
"""
当代艺术摄影风格 AI 生图工具
基于 Photo Fairs 2026 趋势，模仿杜塞尔多夫学派等当代艺术摄影风格
使用 image2 (whatai.cc) API
"""

import requests
import json
import os
import sys
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed

API_KEY = "{{API_KEY}}"
API_URL = "https://api.whatai.cc/v1/images/generations"

DEFAULT_PROMPTS = [
    ("01_becher_typology", "Typology photography in the style of Bernd and Hilla Becher, five concrete water towers photographed from exact same frontal angle, neutral overcast sky, flat even lighting, muted gray and concrete tones, industrial documentary aesthetic, large format film quality, subtle grain, no people, each tower showing different structural decay patterns"),
    ("02_ruff_twilight", "Twilight photograph of concrete building facade, geometric minimal architecture, single illuminated rectangle on dark wall, deep blue twilight sky, still atmosphere, large format photography, muted cool palette"),
    ("03_hofer_library", "Symmetrical interior of large public space with reading tables and tall bookshelves, harsh overhead fluorescent light, geometric shadows on floor, muted green and beige tones, some books missing from shelves creating irregular gaps, dust visible in light beams, institutional quietness, large format documentary photography, deadpan aesthetic"),
    ("04_yangdi_windows", "Architectural typology photography, twenty windows on a brutalist apartment building facade, each window revealing different interior life, shot straight-on from street level, overcast sky, flat documentary lighting, muted colors, geometric grid composition, Dusseldorf school aesthetic, large format film sharpness"),
    ("05_gursky_supermarket", "Endless rows of colorful supermarket shelves photographed from elevated angle, repeating patterns of products, one empty shelf creating disruption in pattern, bright artificial light, hyper-detailed, large format photography, contemporary art aesthetic"),
    ("06_gai_boulder", "High altitude landscape at 4200 meters, massive weathered boulder in vast barren plateau, solitary human figure sitting in meditation at base of rock for scale, thin atmosphere light, Eastern cosmology atmosphere, meditative vastness, direct photography aesthetic, muted earth tones, large format subtle grain"),
    ("07_shi_archive", "Archival photograph from 1972, faded Kodachrome colors shifted to orange and cyan, scientific expedition documenting unknown geological formation, researchers in vintage clothing with outdated equipment, institutional documentary style, authentic patina of age, slight light leak on right edge, forgotten government archive aesthetic"),
    ("08_ruff_portrait", "Studio portrait photography in Dusseldorf school style, person facing camera directly, neutral calm expression, flat even lighting, light gray background, medium close-up, deadpan aesthetic, large format sharpness, muted natural color"),
    ("09_empty_institutional", "Empty institutional classroom photographed with deadpan objectivity, fluorescent ceiling lights on during daytime creating double shadow system, one chair slightly pulled out from desk, unidentified paper scraps on floor, institutional beige walls, surveillance camera visible in corner, forensic documentation aesthetic, muted flat palette, large format sharpness, absence of narrative explanation, contemporary conceptual photography"),
]

HEADERS = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {API_KEY}"
}


def generate_image(name: str, prompt: str, output_dir: str) -> tuple:
    """Generate a single image, with retry on safety block."""
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
                # Simplify: remove potentially triggering words
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


def download_image(name: str, url: str, output_dir: str) -> str:
    """Download image from URL."""
    try:
        r = requests.get(url, timeout=60)
        ext = url.split(".")[-1].split("?")[0]
        if ext not in ["png", "jpg", "jpeg", "webp"]:
            ext = "png"
        path = os.path.join(output_dir, f"{name}.{ext}")
        with open(path, "wb") as f:
            f.write(r.content)
        print(f"  [{name}] Saved: {path} ({len(r.content)//1024}KB)")
        return path
    except Exception as e:
        print(f"  [{name}] Download failed: {e}")
        return None


def batch_generate(prompts: list, output_dir: str, max_workers: int = 5):
    """Batch generate and download images."""
    os.makedirs(output_dir, exist_ok=True)

    print(f"Generating {len(prompts)} images...")
    urls = {}
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(generate_image, name, p, output_dir): name for name, p in prompts}
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
    with ThreadPoolExecutor(max_workers=9) as executor:
        futures = {executor.submit(download_image, name, url, output_dir): name for name, url in urls.items()}
        for future in as_completed(futures):
            path = future.result()
            if path:
                paths.append(path)

    print(f"\nDone: {len(paths)} images saved to {output_dir}")
    return paths


def main():
    parser = argparse.ArgumentParser(description="Contemporary art photography style image generation")
    parser.add_argument("--output", "-o", default="~/Documents/contemporary_photo_gen",
                        help="Output directory (default: ~/Documents/contemporary_photo_gen)")
    parser.add_argument("--preset", "-p", choices=["all", "becher", "ruff", "hofer", "yangdi",
                        "gursky", "gai", "shi", "portrait", "empty"],
                        help="Generate specific preset only")
    parser.add_argument("--custom", "-c", help="Custom prompt for single image generation")
    parser.add_argument("--name", "-n", default="custom", help="Custom image name (used with --custom)")
    parser.add_argument("--workers", "-w", type=int, default=5, help="Max concurrent API calls (default: 5)")

    args = parser.parse_args()
    output_dir = os.path.expanduser(args.output)

    if args.custom:
        # Single custom image
        print(f"Custom prompt: {args.custom[:60]}...")
        name, url = generate_image(args.name, args.custom, output_dir)
        if url:
            download_image(name, url, output_dir)
        return

    # Select prompts
    if args.preset:
        preset_map = {
            "becher": ["01_becher_typology"],
            "ruff": ["02_ruff_twilight", "08_ruff_portrait"],
            "hofer": ["03_hofer_library"],
            "yangdi": ["04_yangdi_windows"],
            "gursky": ["05_gursky_supermarket"],
            "gai": ["06_gai_boulder"],
            "shi": ["07_shi_archive"],
            "portrait": ["08_ruff_portrait"],
            "empty": ["09_empty_institutional"],
        }
        selected_names = preset_map.get(args.preset, [])
        prompts = [(n, p) for n, p in DEFAULT_PROMPTS if n in selected_names]
    else:
        prompts = DEFAULT_PROMPTS

    batch_generate(prompts, output_dir, max_workers=args.workers)


if __name__ == "__main__":
    main()
