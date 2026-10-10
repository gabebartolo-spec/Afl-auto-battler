#!/usr/bin/env python3
"""Fail when a document every agent must read in full is too big to be read in one go.

The director's rule (2026-10-10): skimming the documents is a sin; agents read their memory,
handoff, skill and checklist files in full. The Read tool returns roughly 100 KB a call, so a
must-read file above the budget here cannot be read in full in one piece, and in practice gets
skimmed. On 2026-10-10 docs/ROADMAP.md was 775 KB and no agent had ever read it whole; the
director was never told. When a doc is too long, the fix is to split it, never to skim it.

Budget: 60 KB per must-read file (about 15k tokens, comfortably one read with room for the
reader's own context). Files that are reference libraries, not must-reads, are not listed.

Usage: python3 tools/check_doc_sizes.py            # exit 1 with a list of files over budget
       python3 tools/check_doc_sizes.py --report   # print every file's size, no failure
"""
import glob
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUDGET_KB = 60

# Every file an agent is expected to read in full at session start or before a task.
MUST_READ = [
    "CLAUDE.md",
    "docs/ROADMAP.md",                  # the index: one page once split
    "docs/roadmap/open-requirements.md",
    "docs/agents/STATUS.md",
]
MUST_READ_GLOBS = [
    ".claude/skills/*/SKILL.md",
    ".claude/skills/*/references/checklists.md",
    ".claude/skills/*/references/learnings.md",
]


def main() -> int:
    report = "--report" in sys.argv
    files = list(MUST_READ)
    for pattern in MUST_READ_GLOBS:
        files += sorted(glob.glob(os.path.join(ROOT, pattern)))
    over = []
    for f in files:
        path = f if os.path.isabs(f) else os.path.join(ROOT, f)
        rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
        if not os.path.exists(path):
            if report:
                print(f"  (missing) {rel}")
            continue
        kb = os.path.getsize(path) / 1024
        flag = "OVER" if kb > BUDGET_KB else "ok  "
        if report:
            print(f"{flag} {kb:6.1f} KB  {rel}")
        if kb > BUDGET_KB:
            over.append((rel, kb))
    if over:
        print(f"Documents over the {BUDGET_KB} KB must-read budget (split them; never skim):")
        for rel, kb in over:
            print(f"  {kb:6.1f} KB  {rel}")
        return 1
    if not report:
        print(f"All must-read documents are within {BUDGET_KB} KB.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
