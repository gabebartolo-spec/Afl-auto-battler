#!/usr/bin/env python3
"""Split docs/ROADMAP.md into section files that each fit one read, plus a one-page index.

Mechanical and reproducible: every line of the source lands in exactly one file, in order, with
no content change. A section larger than the budget is split again at the next heading level
until every file fits. Links elsewhere of the form ROADMAP.md#<anchor> are rewritten to the file
that now holds that heading. Re-run it after merging main if ROADMAP.md changed upstream.

Usage: python3 tools/split_roadmap.py [--dry-run] [--source docs/ROADMAP.md]
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUDGET = 58 * 1024  # just under the must-read budget in check_doc_sizes.py


def slug(h):
    return re.sub(r"[^a-z0-9]+", "-", h.lower()).strip("-")[:56]


def anchor(h):
    s = re.sub(r"[^\w\- ]", "", h.strip().lower())
    return s.replace(" ", "-")


def size(lines):
    return sum(len(l) + 1 for l in lines)


def split(lines, level, code):
    """Return [(name, title, lines)]; split at `level` hashes while over budget. `code` is the
    numeric path (e.g. 02-20-03) that keeps every file name unique and in reading order."""
    if size(lines) <= BUDGET or level > 4:
        title = lines[0].lstrip("#").strip() if lines and lines[0].startswith("#") else "Preamble"
        return [(f"{code}-{slug(title)}", title, lines)]
    mark = "#" * level + " "
    chunks, cur = [], []
    for ln in lines:
        if ln.startswith(mark) and cur:
            chunks.append(cur)
            cur = []
        cur.append(ln)
    chunks.append(cur)
    if len(chunks) == 1:  # no headings at this level: try the next
        return split(lines, level + 1, code)
    # A heading-only stub or a tiny intro rides with the chunk after it.
    merged = []
    for ch in chunks:
        if merged and size(merged[-1]) < 1536:
            merged[-1] = merged[-1] + ch
        else:
            merged.append(ch)
    if len(merged) > 1 and size(merged[-1]) < 1536:
        last = merged.pop()
        merged[-1] = merged[-1] + last
    out = []
    for i, ch in enumerate(merged):
        out += split(ch, level + 1, f"{code}-{i:02d}")
    return out


def main():
    dry = "--dry-run" in sys.argv
    src = os.path.join(ROOT, "docs", "ROADMAP.md")
    if "--source" in sys.argv:
        src = os.path.join(ROOT, sys.argv[sys.argv.index("--source") + 1])
    out_dir = os.path.join(ROOT, "docs", "roadmap")
    text = io.open(src, encoding="utf-8", newline="").read()
    eol = "\r\n" if "\r\n" in text else "\n"
    lines = text.split(eol)
    if lines and lines[-1] == "":
        lines = lines[:-1]

    # Top level: `# ` headings.
    tops, cur = [], []
    for ln in lines:
        if ln.startswith("# ") and cur:
            tops.append(cur)
            cur = []
        cur.append(ln)
    tops.append(cur)

    files = []
    for i, ch in enumerate(tops):
        head = ch[0].lstrip("#").strip() if ch[0].startswith("#") else "preamble"
        files += split(ch, 2, f"{i:02d}")
    assert sum(len(b) for _, _, b in files) == len(lines), "lines lost in the split"

    heading_map = {}
    for name, _, body in files:
        for ln in body:
            if ln.startswith("#"):
                heading_map.setdefault(anchor(ln.lstrip("#")), name + ".md")

    index = [
        "# Roadmap index",
        "",
        "Rules: read `roadmap/open-requirements.md` in full at session start (open items, owner, status).",
        "Section files hold full wording and acceptance records; edit an item in its file. Every must-read",
        "file stays under 60 KB (`tools/check_doc_sizes.py`); `tools/split_roadmap.py` re-cuts from a merged",
        "ROADMAP.md. Item format: requirement, acceptance, status line. Implementation records go to history.",
        "A roadmap item is context, not authorisation.",
        "",
    ]
    for name, title, body in files:
        index.append(f"- [{title}](roadmap/{name}.md) ({size(body) / 1024:.0f} KB)")
    index.append("")

    if dry:
        for name, title, body in files:
            print(f"{size(body) / 1024:6.0f} KB  {name}.md")
        print(f"{len(files)} files, largest {max(size(b) for _, _, b in files) / 1024:.0f} KB")
        return 0

    os.makedirs(out_dir, exist_ok=True)
    for name, _, body in files:
        io.open(os.path.join(out_dir, name + ".md"), "w", encoding="utf-8", newline="").write(eol.join(body) + eol)
    io.open(src, "w", encoding="utf-8", newline="").write(eol.join(index) + eol)

    pat = re.compile(r"(\]\()((?:\.\./)*(?:docs/)?ROADMAP\.md)#([^)\s]+)(\))")
    for dp, dns, fns in os.walk(ROOT):
        dns[:] = [d for d in dns if d not in (".git", ".godot")]
        for fn in fns:
            if not fn.endswith(".md"):
                continue
            p = os.path.join(dp, fn)
            if os.path.abspath(p) == os.path.abspath(src):
                continue
            t = io.open(p, encoding="utf-8", newline="").read()

            def rep(m):
                target = heading_map.get(m.group(3))
                if not target:
                    return m.group(0)
                return f"{m.group(1)}{m.group(2).replace('ROADMAP.md', 'roadmap/' + target)}#{m.group(3)}{m.group(4)}"

            t2 = pat.sub(rep, t)
            if t2 != t:
                io.open(p, "w", encoding="utf-8", newline="").write(t2)
                print("relinked", os.path.relpath(p, ROOT))
    print(f"wrote {len(files)} files, largest {max(size(b) for _, _, b in files) / 1024:.0f} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
