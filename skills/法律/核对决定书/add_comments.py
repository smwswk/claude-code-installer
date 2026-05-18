#!/usr/bin/env python3
"""Add Word comments to a .docx file via OpenXML manipulation.

Usage:
    python3 add_comments.py <input.docx> <output.docx> <comments.json>

comments.json format:
[
  {"p_idx": 17, "search": "第五十五条", "comment": "【法条序号错误】..."},
  ...
]

Each comment is attached to the run containing `search` text in paragraph `p_idx`.
"""

import zipfile
import json
import sys
import shutil
from lxml import etree

W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'

def w_tag(tag):
    return '{%s}%s' % (W, tag)

def get_para_text(p_elem):
    return ''.join(t.text or '' for t in p_elem.iter(w_tag('t')))

def find_text_in_runs(p_elem, search_text):
    """Return (runs, start_run_idx, end_run_idx) or (None, None, None)."""
    runs = p_elem.findall(w_tag('r'))
    run_texts = []
    for run in runs:
        t_elem = run.find(w_tag('t'))
        text = t_elem.text if t_elem is not None and t_elem.text else ''
        run_texts.append(text)

    full_text = ''.join(run_texts)
    idx = full_text.find(search_text)
    if idx == -1:
        return None, None, None

    start_run, end_run = None, None
    pos = 0
    for i, rt in enumerate(run_texts):
        if pos <= idx < pos + len(rt):
            start_run = i
        if pos <= idx + len(search_text) - 1 < pos + len(rt):
            end_run = i
        pos += len(rt)

    if start_run is None or end_run is None:
        return None, None, None
    return runs, start_run, end_run


def add_comments(src_path, dst_path, comments_data):
    """Add comments to docx. comments_data is list of (p_idx, search, text)."""
    shutil.copy2(src_path, dst_path)

    with zipfile.ZipFile(dst_path, 'r') as z:
        all_data = {name: z.read(name) for name in z.namelist()}

    # Parse document
    doc_xml = etree.fromstring(all_data['word/document.xml'])
    body = doc_xml.find(w_tag('body'))
    all_paras = body.findall(w_tag('p'))

    # Create comments
    comments_el = etree.Element(w_tag('comments'),
                                nsmap={'w': W, 'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'})
    comment_refs = []
    cid = 0

    for p_idx, search, text in comments_data:
        p_elem = all_paras[p_idx]
        runs, s_run, e_run = find_text_in_runs(p_elem, search)
        if runs is None:
            print(f"WARN: '{search}' not found in P{p_idx}")
            continue

        cid += 1
        comment_refs.append((p_elem, runs, s_run, e_run, cid))

        ce = etree.SubElement(comments_el, w_tag('comment'))
        ce.set(w_tag('id'), str(cid))
        ce.set(w_tag('author'), '审阅人')
        ce.set(w_tag('date'), '2026-05-13T00:00:00Z')

        for line in text.split('\n'):
            if not line.strip():
                continue
            pe = etree.SubElement(ce, w_tag('p'))
            pPr = etree.SubElement(pe, w_tag('pPr'))
            ps = etree.SubElement(pPr, w_tag('pStyle'))
            ps.set(w_tag('val'), 'CommentText')
            re = etree.SubElement(pe, w_tag('r'))
            te = etree.SubElement(re, w_tag('t'))
            te.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')
            te.text = line

    # Insert comment markers (reverse order to preserve indices)
    for p_elem, runs, s_run, e_run, cid in reversed(comment_refs):
        children = list(p_elem)
        s_idx = children.index(runs[s_run])
        e_idx = children.index(runs[e_run])

        crs = etree.Element(w_tag('commentRangeStart'))
        crs.set(w_tag('id'), str(cid))
        p_elem.insert(s_idx, crs)

        cre = etree.Element(w_tag('commentRangeEnd'))
        cre.set(w_tag('id'), str(cid))
        p_elem.insert(e_idx + 1, cre)

        ref_run = etree.Element(w_tag('r'))
        rPr = etree.SubElement(ref_run, w_tag('rPr'))
        rs = etree.SubElement(rPr, w_tag('rStyle'))
        rs.set(w_tag('val'), 'CommentReference')
        cr = etree.SubElement(ref_run, w_tag('commentReference'))
        cr.set(w_tag('id'), str(cid))
        cre_idx = list(p_elem).index(cre)
        p_elem.insert(cre_idx + 1, ref_run)

    # Serialize
    doc_str = etree.tostring(doc_xml, xml_declaration=True, encoding='UTF-8', standalone=True)
    comments_str = etree.tostring(comments_el, xml_declaration=True, encoding='UTF-8', standalone=True)

    # Update Content_Types
    ct_xml = etree.fromstring(all_data['[Content_Types].xml'])
    ns_ct = ct_xml.nsmap.get(None, 'http://schemas.openxmlformats.org/package/2006/content-types')
    has_c = any(c.get('PartName') == '/word/comments.xml' for c in ct_xml)
    if not has_c:
        ov = etree.SubElement(ct_xml, '{%s}Override' % ns_ct)
        ov.set('PartName', '/word/comments.xml')
        ov.set('ContentType', 'application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml')
    ct_str = etree.tostring(ct_xml, xml_declaration=True, encoding='UTF-8', standalone=True)

    # Update relationships
    rels_xml = etree.fromstring(all_data['word/_rels/document.xml.rels'])
    ns_r = rels_xml.nsmap.get(None, 'http://schemas.openxmlformats.org/package/2006/relationships')
    has_r = any(c.get('Target') == 'comments.xml' for c in rels_xml)
    if not has_r:
        max_id = max((int(c.get('Id', 'rId0')[3:]) for c in rels_xml if c.get('Id', '').startswith('rId')), default=0)
        rel = etree.SubElement(rels_xml, '{%s}Relationship' % ns_r)
        rel.set('Id', f'rId{max_id + 1}')
        rel.set('Type', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments')
        rel.set('Target', 'comments.xml')
    rels_str = etree.tostring(rels_xml, xml_declaration=True, encoding='UTF-8', standalone=True)

    # Write output
    with zipfile.ZipFile(dst_path, 'w', zipfile.ZIP_DEFLATED) as zout:
        for name in all_data:
            if name == 'word/document.xml':
                zout.writestr(name, doc_str)
            elif name == '[Content_Types].xml':
                zout.writestr(name, ct_str)
            elif name == 'word/_rels/document.xml.rels':
                zout.writestr(name, rels_str)
            elif name == 'word/comments.xml':
                pass
            else:
                zout.writestr(name, all_data[name])
        zout.writestr('word/comments.xml', comments_str)

    return cid


if __name__ == '__main__':
    if len(sys.argv) != 4:
        print("Usage: python3 add_comments.py <input.docx> <output.docx> <comments.json>")
        sys.exit(1)

    with open(sys.argv[3], 'r') as f:
        comments = json.load(f)

    comments_data = [(c['p_idx'], c['search'], c['comment']) for c in comments]
    n = add_comments(sys.argv[1], sys.argv[2], comments_data)
    print(f"Added {n} comments → {sys.argv[2]}")
