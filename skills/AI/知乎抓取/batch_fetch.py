#!/usr/bin/env python3
"""
批量抓取知乎链接的正文 + 计数，输出 JSONL 到 stdout。

输入格式（任选其一）：
  1) markdown 风格：标题在一行，URL 在下一行，空行分隔（与用户消息粘贴风格一致）
  2) 纯 URL：每行一个 URL

  $ batch_fetch.py < urls.txt
  $ pbpaste | batch_fetch.py

URL 类型：
  - https://www.zhihu.com/question/{qid}/answer/{aid}  → 调 answers API，拿 title/voteup/comment/content
  - https://zhuanlan.zhihu.com/p/{aid}                  → 反爬挡，标记 skip_reason，不抓正文

输出（JSONL）：
  {"idx", "type", "url", "title", "voteup", "comment", "content", "skip_reason"}
  content 是 HTML 已 strip，连续空白合并为一个空格。
"""

import json
import re
import sys
import time
import urllib.request
import urllib.error

UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
ANSWER_RE = re.compile(r'https?://(?:www\.)?zhihu\.com/question/(\d+)/answer/(\d+)')
ARTICLE_RE = re.compile(r'https?://zhuanlan\.zhihu\.com/p/(\d+)')

HTML_ENTITIES = {
    '&amp;': '&', '&lt;': '<', '&gt;': '>',
    '&quot;': '"', '&#39;': "'", '&nbsp;': ' ',
}


def strip_html(s: str) -> str:
    s = re.sub(r'<br\s*/?>', '\n', s)
    s = re.sub(r'</p>', '\n', s)
    s = re.sub(r'<li[^>]*>', '\n- ', s)
    s = re.sub(r'<[^>]+>', '', s)
    for k, v in HTML_ENTITIES.items():
        s = s.replace(k, v)
    s = re.sub(r'\n{3,}', '\n\n', s)
    s = re.sub(r'[ \t]+', ' ', s)
    return s.strip()


def fetch_answer(qid: str, aid: str) -> dict:
    url = (f'https://www.zhihu.com/api/v4/answers/{aid}'
           f'?include=content,voteup_count,comment_count,question')
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    with urllib.request.urlopen(req, timeout=15) as r:
        d = json.loads(r.read())
    if 'error' in d:
        raise RuntimeError(f'API error: {d["error"]}')
    return {
        'title': (d.get('question') or {}).get('title') or '',
        'voteup': d.get('voteup_count', 0),
        'comment': d.get('comment_count', 0),
        'content': strip_html(d.get('content') or ''),
    }


def parse_input(text: str):
    """Return list of (title_hint, url). title_hint may be empty."""
    lines = [ln.rstrip() for ln in text.splitlines()]
    items = []
    prev_nonempty = ''
    for ln in lines:
        url_match = re.search(r'https?://\S+', ln)
        if url_match:
            url = url_match.group(0).rstrip(').,;')
            items.append((prev_nonempty.strip() if prev_nonempty != ln else '', url))
            prev_nonempty = ''
        else:
            if ln.strip():
                prev_nonempty = ln
            else:
                prev_nonempty = ''
    # dedupe by url, keep first
    seen = set()
    uniq = []
    for t, u in items:
        if u in seen:
            continue
        seen.add(u)
        uniq.append((t, u))
    return uniq


def main():
    text = sys.stdin.read()
    items = parse_input(text)
    if not items:
        print('No URLs found in input.', file=sys.stderr)
        sys.exit(1)
    for idx, (title_hint, url) in enumerate(items, start=1):
        record = {
            'idx': idx,
            'url': url,
            'type': None,
            'title': title_hint,
            'voteup': None,
            'comment': None,
            'content': '',
            'skip_reason': '',
        }
        m = ANSWER_RE.search(url)
        if m:
            qid, aid = m.group(1), m.group(2)
            record['type'] = 'answer'
            try:
                data = fetch_answer(qid, aid)
                record['title'] = data['title'] or record['title']
                record['voteup'] = data['voteup']
                record['comment'] = data['comment']
                record['content'] = data['content']
            except Exception as e:
                record['skip_reason'] = f'fetch_error: {e}'
            time.sleep(0.4)
        elif ARTICLE_RE.search(url):
            record['type'] = 'article'
            record['skip_reason'] = 'zhuanlan 反爬未抓正文'
        else:
            record['type'] = 'unknown'
            record['skip_reason'] = '不识别的 URL 模式'
        print(json.dumps(record, ensure_ascii=False))
        sys.stdout.flush()


if __name__ == '__main__':
    main()
