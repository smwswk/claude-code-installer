#!/usr/bin/env python3
"""Batch fetch Xiaohongshu SSR JSON for multiple links."""
import json, subprocess, sys, re, os

UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
WORK_DIR = "/tmp/xhs_batch_fetch"
os.makedirs(WORK_DIR, exist_ok=True)

def extract_json_from_html(html):
    """Try both SSR extraction methods."""
    note = None
    method = None

    # Method 1: __SETUP_SERVER_STATE__
    pos = html.find('window.__SETUP_SERVER_STATE__=')
    if pos != -1:
        start = pos + len('window.__SETUP_SERVER_STATE__=')
        while start < len(html) and html[start] != '{':
            start += 1
        depth = 0
        end = start
        for j in range(start, len(html)):
            if html[j] == '{': depth += 1
            elif html[j] == '}':
                depth -= 1
                if depth == 0:
                    end = j + 1
                    break
        try:
            data = json.loads(html[start:end])
            note = data.get('LAUNCHER_SSR_STORE_PAGE_DATA', {}).get('noteData')
            method = 'SSR'
        except:
            pass

    # Method 2: __INITIAL_STATE__ (formula-runtime)
    if note is None:
        pos = html.find('window.__INITIAL_STATE__=')
        if pos != -1:
            start = pos + len('window.__INITIAL_STATE__=')
            while start < len(html) and html[start] != '{':
                start += 1
            depth = 0
            end = start
            for j in range(start, len(html)):
                if html[j] == '{': depth += 1
                elif html[j] == '}':
                    depth -= 1
                    if depth == 0:
                        end = j + 1
                        break
            json_str = html[start:end]
            json_str = json_str.replace(':undefined', ':null')
            try:
                data = json.loads(json_str)
                note = data.get('noteData', {}).get('data', {}).get('noteData')
                method = 'INITIAL_STATE'
            except:
                pass

    return note, method

def fetch_one(url, idx):
    """Fetch one link and extract metadata."""
    html_path = os.path.join(WORK_DIR, f"page_{idx}.html")
    result = {"idx": idx, "url": url, "status": "error", "type": None, "title": None, "author": None, "duration": None, "desc": None, "masterUrl": None, "method": None}

    # Step 1: GET the short link to resolve redirect and get final URL + HTML
    cmd = ['curl', '-sL', '-A', UA, '-o', html_path, '-w', '%{url_effective}', '--max-time', '30', url]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=35)
        final_url = proc.stdout.strip()
        result["final_url"] = final_url
    except subprocess.TimeoutExpired:
        result["error_msg"] = "timeout"
        return result
    except Exception as e:
        result["error_msg"] = str(e)
        return result

    # Step 2: Read HTML and extract SSR
    try:
        with open(html_path, 'r', encoding='utf-8', errors='ignore') as f:
            html = f.read()
    except:
        result["error_msg"] = "cannot read html"
        return result

    if len(html) < 1000:
        result["error_msg"] = f"html too short: {len(html)}"
        return result

    note, method = extract_json_from_html(html)

    if note is None:
        result["error_msg"] = "NO_SSR_DATA"
        return result

    result["method"] = method
    result["type"] = note.get('type', 'unknown')
    result["title"] = note.get('title', '')[:200]
    result["author"] = note.get('user', {}).get('nickName', 'unknown')
    result["desc"] = (note.get('desc', '') or '')[:500]

    # Interact info
    interact = note.get('interactInfo', {})
    result["likes"] = interact.get('likedCount', 0)
    result["collects"] = interact.get('collectedCount', 0)
    result["comments"] = interact.get('commentCount', 0)
    result["shares"] = interact.get('shareCount', 0)

    # Tags
    tags = note.get('tagList', [])
    result["tags"] = [t.get('name', '') for t in (tags or [])]

    # Video specific
    if result["type"] == "video":
        video = note.get('video', {})
        result["duration"] = video.get('capa', {}).get('duration', 0)
        media = video.get('media', {})
        streams = media.get('stream', {}).get('h264', [])
        if streams:
            result["masterUrl"] = streams[0].get('masterUrl', '')
        elif streams := media.get('stream', {}).get('h265', []):
            result["masterUrl"] = streams[0].get('masterUrl', '')

    # Image list for normal notes
    if result["type"] == "normal":
        images = note.get('imageList', [])
        result["image_count"] = len(images)

    result["status"] = "ok"
    return result

if __name__ == "__main__":
    # Read links from stdin (one per line: idx|url|title_hint)
    links = []
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        parts = line.split('|', 2)
        if len(parts) >= 2:
            links.append((parts[0], parts[1], parts[2] if len(parts) > 2 else ''))

    print(f"Processing {len(links)} links...", file=sys.stderr)

    results = []
    for idx, url, hint in links:
        print(f"  [{idx}] {hint[:60]}...", file=sys.stderr)
        r = fetch_one(url, idx)
        r["hint"] = hint
        results.append(r)

    print(json.dumps(results, ensure_ascii=False, indent=2))
