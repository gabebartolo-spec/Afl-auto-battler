#!/usr/bin/env python3
"""Row 34 card audit: the static pass over data/stories/*.json, joined to the seeded
careers of tools/audit/cards_impl.gd, written as docs/research/event_card_audit_<date>.md.

  python tools/audit/card_audit_report.py static
  python tools/audit/card_audit_report.py report RUN_DIR [RUN_DIR ...] --out docs/research/x.md --date 2026-10-12

Each RUN_DIR holds one audit-cards_impl artifact (the cards_impl log). The judgements a person
makes (premises a trigger does not check, promises not kept, copy proposals) live in
tools/audit/card_copy_proposals.py, keyed by card id; this script adds what it can compute.
Measurement only: it never edits a data file.
"""
import collections
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.join(HERE, "..", "..")
CATS = ["training", "health", "family", "media", "contracts", "leadership", "community", "rivals", "board", "members", "selection"]

# Post-match press questions (scripts/sim/MediaConference.gd): key, journalist, the question in short.
# Every question has the same three answers: accountable (board +1, players -1), tactical (0, 0),
# protective (board -1, players +1).
PRESS = [
    ("injury", "Kev Pollard", "Tough blow losing X. How much did that hurt you out there?"),
    ("heavy_loss", "Gary Haddon", "X beat you by N. Was that acceptable? (Or, if you called your method the standard after a big win this season: where was it today?)"),
    ("big_win", "Trish Lomax", "That was a clinic against X. Is this the best side in the competition?"),
    ("close_game", "Dev Mehta", "A true number from the match, then: what went wrong, how, or what decided it?"),
    ("star", "Kev Pollard", "X had a huge night. Is there a better player in the comp right now?"),
    ("young_side", "Margaret Ashby", "N of your side today were 21 or younger. Is this the club you're building?"),
]


def load_deck():
    deck = []
    for cat in CATS:
        p = os.path.join(ROOT, "data", "stories", cat + ".json")
        if os.path.exists(p):
            deck.extend(json.load(open(p, encoding="utf-8")))
    return deck


def vec(c):
    """A crude size of what a choice does, to spot a choice that loses to another on every lever."""
    v = collections.Counter()
    for e in c.get("effects", []):
        op, d, who = e["op"], e.get("d", 0), e.get("who", "subject")
        if op == "morale":
            v["morale_subject" if who == "subject" else "morale_group"] += d
        elif op in ("board", "trust", "xp"):
            v[op] += d
        elif op == "heavy_legs":
            v["legs"] -= 1
        elif op == "fresh":
            v["legs"] += 1
        elif op == "rest":
            v["plays"] -= 1
        elif op == "sore":
            v["risk"] -= 1
        elif op in ("expects_game", "start_backing", "extend_early", "promise_win"):
            # A binding promise, or money: never comparable with a choice that has neither.
            v["binds_" + op] += 1
    return v


def weak(c):
    """Nothing but a morale nudge of 2 or less (one player) or 1 (a group)."""
    es = c.get("effects", [])
    if not es:
        return False
    for e in es:
        if e["op"] != "morale":
            return False
        lim = 2 if e.get("who", "subject") == "subject" else 1
        if abs(e.get("d", 0)) > lim:
            return False
    return True


def static_flags(deck):
    needed = {t["needs"]["flag"] for t in deck if t.get("needs")}
    out = {}
    for t in deck:
        fl = []
        ch = t["choices"]
        for c in ch:
            es = c.get("effects", [])
            lasting = [e for e in es if e["op"] not in ("flag", "talk_note")]
            if not lasting:
                fl.append("ZERO-EFFECT %s" % c["key"])
            net = collections.Counter()
            for e in es:
                if "d" in e:
                    net[(e["op"], e.get("who", "subject"), e.get("scale", ""))] += e["d"]
            if es and net and all(v == 0 for v in net.values()):
                fl.append("CANCELS %s" % c["key"])
            if weak(c):
                fl.append("WEAK %s" % c["key"])
            for e in es:
                if e["op"] == "flag" and e["name"] not in needed:
                    fl.append("DEAD-FLAG %s:%s" % (c["key"], e["name"]))
        vs = [vec(c) for c in ch]
        for i, a in enumerate(vs):
            for j, b in enumerate(vs):
                if i != j and not any(k.startswith("binds_") for k in set(a) | set(b)):
                    keys = set(a) | set(b)
                    if all(a[k] >= b[k] for k in keys) and any(a[k] > b[k] for k in keys):
                        fl.append("DOMINATED %s by %s" % (ch[j]["key"], ch[i]["key"]))
        # The board's mood said in the result, and again by the line the engine adds after it.
        for c in ch:
            board = sum(e.get("d", 0) for e in c.get("effects", []) if e["op"] == "board")
            if board and re.search(r"\bboard\b", c.get("result", ""), re.I):
                fl.append("BOARD-SAID-TWICE %s" % c["key"])
        # A cost the coach would know (a tired body, a missed game, a sore player) with no stakes line.
        if not t.get("stakes"):
            for c in ch:
                ops = sorted({e["op"] for e in c.get("effects", []) if e["op"] in ("heavy_legs", "sore", "rest")})
                if ops:
                    fl.append("COST-UNSTATED %s:%s" % (c["key"], "+".join(ops)))
        out[t["id"]] = fl
    return out


def repeats(deck):
    """Phrases that come round on more than one card."""
    labels = collections.defaultdict(list)
    for t in deck:
        for c in t["choices"]:
            labels[re.sub(r"\{[a-z_]+\}", "X", c["label"]).lower()].append(t["id"])
    wants = [t["id"] for t in deck if re.search(r"\bwants?\b", t["title"][0], re.I)]
    return {"labels": {k: v for k, v in labels.items() if len(v) > 1}, "wants": wants}


def parse_runs(dirs):
    """One entry per career: its card, trigger, choice and press counts, weeks and seasons."""
    out = []
    for d in dirs:
        txt = ""
        for f in sorted(glob.glob(os.path.join(d, "*"))):
            if os.path.isfile(f):
                txt += open(f, encoding="utf-8", errors="replace").read() + "\n"
        c = {"card": collections.Counter(), "cond": collections.Counter(), "choice": collections.Counter(),
             "press": collections.Counter(), "weeks": 0, "seasons": 0, "label": "", "names": "", "dir": os.path.basename(d)}
        for line in txt.splitlines():
            line = line.strip()
            m = re.search(r"^(CARD|COND|PRESS) (\S+) (\d+)$", line)
            if m:
                c[m.group(1).lower()][m.group(2)] += int(m.group(3))
                continue
            m = re.search(r"^CHOICE (\S+) (\S+) (\d+)$", line)
            if m:
                c["choice"][(m.group(1), m.group(2))] += int(m.group(3))
                continue
            m = re.search(r"^WEEKS (\d+)$", line)
            if m:
                c["weeks"] = int(m.group(1))
            m = re.search(r"^SEASONS (\d+)$", line)
            if m:
                c["seasons"] = int(m.group(1))
            m = re.search(r"SUMMARY seed (\d+) (\w+) (\w+) names (\w+)", line)
            if m:
                c["label"] = "%s %s %s names" % (m.group(2), m.group(3), m.group(4))
                c["names"] = m.group(4)
        out.append(c)
    return out


def pool(careers):
    t = {"card": collections.Counter(), "cond": collections.Counter(), "choice": collections.Counter(),
         "press": collections.Counter(), "weeks": 0, "seasons": 0, "n": len(careers)}
    for c in careers:
        for k in ("card", "cond", "choice", "press"):
            t[k].update(c[k])
        t["weeks"] += c["weeks"]
        t["seasons"] += c["seasons"]
    return t


def per10(t, key):
    return 10.0 * t["card"][key] / t["seasons"] if t["seasons"] else 0.0


def trig(t, key):
    return 100.0 * t["cond"][key] / t["weeks"] if t["weeks"] else 0.0


def why_rare(card, real, fict, deck):
    """Why a card is rare or absent, from its trigger and the counts."""
    cid = card["id"]
    bits = []
    if real["cond"][cid] == 0 and fict["cond"][cid] == 0:
        bits.append("its trigger was never true in %d weeks" % (real["weeks"] + fict["weeks"]))
    else:
        bits.append("trigger true in %.0f%% of weeks" % trig(real, cid))
    if card.get("private"):
        bits.append("private card: a real-named player is never picked, drawn %.1f per 10 seasons with fictional names" % per10(fict, cid))
    needs = card.get("needs")
    if needs:
        parent = None
        for t in deck:
            for c in t["choices"]:
                for e in c.get("effects", []):
                    if e["op"] == "flag" and e["name"] == needs["flag"]:
                        parent = (t["id"], c["key"])
        if parent:
            took = real["choice"][parent] + fict["choice"][parent]
            bits.append("follow-up of %s/%s, taken %d times in all" % (parent[0], parent[1], took))
    cd = card.get("cooldown")
    if cd:
        bits.append("cooldown %d weeks" % cd)
    if card.get("per_season"):
        bits.append("limited to %d a season" % card["per_season"])
    return "; ".join(bits)


def card_block(t, fl, real, fict, allp, proposals):
    cid = t["id"]
    p = proposals.get(cid, {"flags": [], "copy": []})
    taken = []
    for c in t["choices"]:
        taken.append("%s %d" % (c["key"], allp["choice"][(cid, c["key"])]))
    flags = [f for f in fl[cid] if not f.startswith(("COST-UNSTATED", "DOMINATED", "WEAK", "BOARD-SAID-TWICE"))]
    extra = []
    for f in fl[cid]:
        if f.startswith("WEAK"):
            extra.append(f)
        elif f.startswith("DOMINATED"):
            extra.append("NO-TRADE-OFF " + f.split(" ", 1)[1])
    flags = flags + [x for x in extra if not any(h.startswith("NO-TRADE-OFF") for h in p["flags"])]
    flags += p["flags"]
    if any(f.startswith("BOARD-SAID-TWICE") for f in fl[cid]):
        flags.append("board mood said in the result and again by the engine (%s)" % ", ".join(f.split()[1] for f in fl[cid] if f.startswith("BOARD-SAID-TWICE")))
    title = t["title"][0]
    lines = ['- **%s** "%s": %.1f per 10 seasons (fictional names %.1f), trigger true %.0f%% of weeks. Taken: %s.' % (
        cid, title, per10(real, cid), per10(fict, cid), trig(real, cid), ", ".join(taken))]
    for f in flags:
        lines.append("  - flag: " + f)
    for field, now, better, why in p["copy"]:
        lines.append('  - %s: "%s" -> "%s" (%s)' % (field, now, better, why))
    return lines


def write_report(deck, fl, careers, out_path, date, run_ids):
    from card_copy_proposals import PROPOSALS
    real = pool([c for c in careers if c["names"] == "real"])
    fict = pool([c for c in careers if c["names"] == "fictional"])
    allp = pool(careers)
    rep = repeats(deck)
    nchoice = sum(len(t["choices"]) for t in deck)
    rare = [t["id"] for t in deck if per10(real, t["id"]) < 1.0]
    zero = [t["id"] for t in deck if real["card"][t["id"]] == 0]
    kinds = collections.Counter()
    for t in deck:
        for f in fl[t["id"]] + PROPOSALS[t["id"]]["flags"]:
            kinds[f.split()[0]] += 1
    ncopy = sum(len(v["copy"]) for v in PROPOSALS.values())
    no_trade = [t["id"] for t in deck if any(f.startswith(("NO-TRADE-OFF", "DOMINATED")) for f in fl[t["id"]] + PROPOSALS[t["id"]]["flags"])]
    L = []
    w = L.append
    w("# Event card audit, %s" % date)
    w("")
    w("Open requirement row 34 (director, 2026-10-12). Audit only: no data file is changed. Method: a static pass over "
      "`data/stories/*.json` (65 cards, %d choices) and the post-match press questions (`MediaConference.gd`); then %d seeded careers "
      "of 10 seasons on CI (`tools/audit/cards_impl.gd`; 3 real lists and 3 redraft with real names on, 2 fictional-name controls); then a "
      "copy pass against CLAUDE.md. Tools: `tools/audit/card_audit_report.py` (the static flags and this sheet) and "
      "`tools/audit/card_copy_proposals.py` (the hand-written flags and copy lines). Cards are answered by a seeded random choice, so "
      "every choice and follow-up can come up. \"Per 10 seasons\" is the pooled count over the %d real-names careers (%d seasons)."
      % (nchoice, len(careers), real["n"], real["seasons"]))
    w("")
    w("## Summary")
    w("")
    w("| | Count |")
    w("|---|---|")
    w("| Story cards / choices | 65 / %d |" % nchoice)
    w("| Press questions (older cards) / answers | %d / %d |" % (len(PRESS), len(PRESS) * 3))
    w("| Story choices with no effect at all | %d |" % sum(1 for t in deck for f in fl[t["id"]] if f.startswith("ZERO-EFFECT")))
    w("| Story choices whose effects cancel out | %d |" % sum(1 for t in deck for f in fl[t["id"]] if f.startswith("CANCELS")))
    w("| Press answers with no effect (the middle answer of every question) | 6 (5 give nothing back; `big_win` sets up the Muckraker's later question) |")
    w("| Story choices that only nudge morale by 2 or less | %d |" % kinds["WEAK"])
    w("| Choices that lose to another on every lever (no trade-off) | %d, on %d cards |" % (kinds["NO-TRADE-OFF"] + kinds["DOMINATED"], len(no_trade)))
    w("| Promises not kept (copy says it tells, shows or does something; the result does not) | %d, plus the time trial |" % (kinds["PROMISE"] - 1))
    w("| Premises the trigger does not check | %d cards |" % kinds["PREMISE"])
    w("| Costs a coach would know that no line states before the pick | %d choices on %d cards |" % (sum(1 for t in deck for f in fl[t["id"]] if f.startswith("COST-UNSTATED")), sum(1 for t in deck if any(f.startswith("COST-UNSTATED") for f in fl[t["id"]]))))
    w("| Cards never seen in the real-names careers | %d |" % len(zero))
    w("| Cards under 1 per 10 seasons (zero included) | %d |" % len(rare))
    w("| Copy proposals | %d lines on %d cards |" % (ncopy, sum(1 for v in PROPOSALS.values() if v["copy"])))
    w("")
    w("## Findings that cut across cards")
    w("")
    for line in CROSS:
        w("- " + line)
    w("")
    w("## Cards that never or rarely appear")
    w("")
    w("Real-names careers (%d, %d seasons), under 1 per 10 seasons. The last column says why, from the card's own trigger." % (real["n"], real["seasons"]))
    w("")
    w("| Card | Real names | Fictional names | Why |")
    w("|---|---|---|---|")
    deck_by = {t["id"]: t for t in deck}
    for cid in sorted(rare, key=lambda c: (per10(real, c), c)):
        w("| %s | %.1f | %.1f | %s |" % (cid, per10(real, cid), per10(fict, cid), why_rare(deck_by[cid], real, fict, deck)))
    w("")
    w("## Press questions (the older cards)")
    w("")
    w("Every question offers the same three answers: accountable (board up, players down), tactical (neither moves) and protective (players up, board down). "
      "So the middle answer does nothing by design, and which question was asked changes only the wording. Counted per 10 seasons in all %d careers (%d seasons), asked after the match and skipped by the autopilot."
      % (allp["n"], allp["seasons"]))
    w("")
    w("| Key | Journalist | Question | Per 10 seasons |")
    w("|---|---|---|---|")
    for key, who, q in PRESS:
        w("| %s | %s | %s | %.1f |" % (key, who, q, 10.0 * allp["press"][key] / allp["seasons"] if allp["seasons"] else 0))
    w("")
    w("## The sheet, card by card")
    w("")
    w("Each card: id, title, appearances per 10 seasons (real names; fictional-name controls in brackets), how often its trigger was true, the choices taken in all careers, then flags and copy lines. A card with no lines under it has no defect found. `stakes`/`label`/`result`/`text`/`title` lines are \"current\" -> \"better\" (reason).")
    for cat in CATS:
        cards = [t for t in deck if t["category"] == cat]
        w("")
        w("### %s (%d)" % (cat.capitalize(), len(cards)))
        w("")
        for t in cards:
            L.extend(card_block(t, fl, real, fict, allp, PROPOSALS))
    w("")
    w("## Repeated phrasing")
    w("")
    w("- %d of 65 titles use \"want\" or \"wants\": %s." % (len(rep["wants"]), ", ".join(rep["wants"])))
    for k, ids in rep["labels"].items():
        if k != "x":
            w("- Button \"%s\" is on %d cards: %s." % (k, len(ids), ", ".join(ids)))
    w("")
    w("## Not exercised")
    w("")
    for line in NOT_EXERCISED:
        w("- " + line)
    w("")
    w("## Runs")
    w("")
    w("Branch `claude/card-audit`, `audit.yml` with `impl=cards_impl`, args `seed club seasons [lists] [real]`: %s." % run_ids)
    w("")
    text = "\n".join(L)
    open(out_path, "w", encoding="utf-8", newline="\n").write(text)
    return len(text.encode("utf-8"))


CROSS = []
NOT_EXERCISED = []

try:
    from card_copy_proposals import CROSS as _C, NOT_EXERCISED as _N
    CROSS, NOT_EXERCISED = _C, _N
except ImportError:
    pass


if __name__ == "__main__":
    deck = load_deck()
    mode = sys.argv[1] if len(sys.argv) > 1 else "static"
    fl = static_flags(deck)
    if mode == "static":
        print("cards %d choices %d" % (len(deck), sum(len(t["choices"]) for t in deck)))
        for t in deck:
            if fl[t["id"]]:
                print(t["id"], "; ".join(fl[t["id"]]))
    else:
        args = sys.argv[2:]
        out = "event_card_audit.md"
        date = "2026-10-12"
        dirs = []
        i = 0
        while i < len(args):
            if args[i] == "--out":
                out = args[i + 1]
                i += 2
            elif args[i] == "--date":
                date = args[i + 1]
                i += 2
            else:
                dirs.append(args[i])
                i += 1
        careers = parse_runs(dirs)
        ids = ", ".join(os.path.basename(d).replace("run_", "") for d in dirs)
        size = write_report(deck, fl, careers, out, date, ids)
        print("wrote %s (%d bytes, %d careers)" % (out, size, len(careers)))
