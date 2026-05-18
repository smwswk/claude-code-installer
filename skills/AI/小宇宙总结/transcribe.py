import os, json, glob, time, concurrent.futures, urllib.request, uuid

API = "https://api.siliconflow.cn/v1/audio/transcriptions"
MODEL = "TeleAI/TeleSpeechASR"

def get_key():
    for k in ("SF_KEY", "SILICONFLOW_API_KEY"):
        v = os.environ.get(k)
        if v:
            return v
    p = os.path.expanduser("~/.config/siliconflow/api_key")
    if os.path.exists(p):
        with open(p) as f:
            return f.read().strip()
    raise RuntimeError("SiliconFlow API key 未找到。请设置 SF_KEY/SILICONFLOW_API_KEY 环境变量，或写入 ~/.config/siliconflow/api_key")

KEY = get_key()

def post_multipart(path):
    boundary = "----" + uuid.uuid4().hex
    body = []
    body.append(f"--{boundary}\r\n".encode())
    body.append(b'Content-Disposition: form-data; name="model"\r\n\r\n')
    body.append(MODEL.encode() + b"\r\n")
    body.append(f"--{boundary}\r\n".encode())
    fname = os.path.basename(path)
    body.append(f'Content-Disposition: form-data; name="file"; filename="{fname}"\r\n'.encode())
    body.append(b"Content-Type: audio/wav\r\n\r\n")
    with open(path, "rb") as f:
        body.append(f.read())
    body.append(b"\r\n")
    body.append(f"--{boundary}--\r\n".encode())
    data = b"".join(body)
    req = urllib.request.Request(API, data=data, method="POST")
    req.add_header("Authorization", f"Bearer {KEY}")
    req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=600) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            err = e.read().decode("utf-8", errors="replace")
            if e.code in (429, 500, 502, 503, 504) and attempt < 3:
                time.sleep(5 * (attempt + 1))
                continue
            return {"error": f"HTTP {e.code}: {err}"}
        except Exception as e:
            if attempt < 3:
                time.sleep(5 * (attempt + 1))
                continue
            return {"error": str(e)}
    return {"error": "exhausted retries"}

def work(path):
    out = path.replace(".wav", ".txt")
    if os.path.exists(out) and os.path.getsize(out) > 0:
        return os.path.basename(path), "skip"
    res = post_multipart(path)
    text = res.get("text", "")
    if "error" in res:
        text = f"[ERROR] {res['error']}"
    with open(out, "w") as f:
        f.write(text)
    return os.path.basename(path), len(text)

if __name__ == "__main__":
    chunks = sorted(glob.glob("*.wav"))
    print(f"chunks: {len(chunks)}", flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as ex:
        futures = [ex.submit(work, c) for c in chunks]
        for fut in concurrent.futures.as_completed(futures):
            try:
                p, n = fut.result()
                print(f"done {p}: {n} chars", flush=True)
            except Exception as e:
                print(f"fail: {e}", flush=True)
