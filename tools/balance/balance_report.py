"""One-page balance report for tools/balance.sh runs.

Reads <run>/a_*.jsonl (and b_*.jsonl when paired), averages each team stat per
team-match, and marks it against real AFL 2026 rates (afl_team_rates.json):
IN when inside the 18 clubs' lowest..highest, NEAR when within mean +-2 sd,
else OUT. Paired runs also show B - A with its standard error over seeds, so a
change is real when |delta| > 2 se.
"""
import argparse, csv, glob, json, math, os, statistics as st

HERE = os.path.dirname(os.path.abspath(__file__))
# sim stat -> afl_team_rates key (score is computed from goals/behinds there)
MAP = {"disposals": "disposals", "kicks": "kicks", "handballs": "handballs",
       "marks": "marks", "contested_marks": "contested_marks", "tackles": "tackles",
       "inside50": "inside_50s", "clearances": "clearances", "hitouts": "hitouts",
       "frees_for": "frees_for", "goals": "goals", "behinds": "behinds",
       "rebound50": "rebound_50s", "rebounds": "rebound_50s"}
EXTRA = ["score", "clangers", "intercepts", "one_percenters", "metres_gained", "strength", "draftees",
         "contested_possessions", "ground_ball_gets", "pressure_acts", "ball_ups", "throw_ins", "stoppages"]
# Real wet against dry, match totals 2022-25 (docs/research/WEATHER_EVIDENCE.md [ABC];
# scoring [BB] modern era, accuracy [BB]/[SI] in points). Shown for a paired run as B against A,
# so it reads as the real reference when A is a perfect day and B a wet one.
REAL_WET = {"tackles": "+12%", "clangers": "+9%", "ground_ball_gets": "+9%",
            "contested_possessions": "+7%", "one_percenters": "+15%", "marks": "-13%",
            "contested_marks": "-10%", "kicks": "0%", "handballs": "-1%", "goals": "-",
            "score": "about -5%", "stoppages": "more (no public count)",
            "ball_ups": "more (no public count)", "throw_ins": "-"}


def load(run, arm):
    rows = {}
    for f in glob.glob(os.path.join(run, arm + "_*.jsonl")):
        with open(f, encoding="utf-8") as fh:
            for line in fh:
                if line.strip():
                    r = json.loads(line)
                    rows[r["i"]] = r
    return rows


def per_match(rows, key):
    """Seed -> mean of both teams' value (one team-match average per match)."""
    return {i: sum(float(t.get(key, 0)) for t in r["teams"]) / 2 for i, r in rows.items()}


def margins(rows):
    m = [abs(r["teams"][0]["score"] - r["teams"][1]["score"]) for r in rows.values()]
    h = [r["teams"][0]["score"] - r["teams"][1]["score"] for r in rows.values()]
    return m, h


# Set shots against real AFL (docs/research/SET_SHOT_EVIDENCE.md): share of shots
# from the Champion Data expected-score shot counts [WH] (2026: 5,951 set of
# 10,859, 55%); goals per shot by distance [ABC] 2021-25, the straight-in-front
# column (Director Bible #62 names these as the targets), set / general play.
# [ABC]'s "straight" is within 30 degrees, so the sim's 45 m "slight angle" spot
# is a straight-column shot. The sim's pocket (15 m, tight angle) is its own row
# against the 10-20 m wide cells: set 66% and 55% (mean 60.5%), general 21% and 22%.
REAL_SET_SHARE = 0.55
# Real shots that score (goals + behinds per shot at goal, [WH] 2026: 9,047 of
# 10,860). Set and general-play no-score rates are not published apart.
REAL_SCORING_PER_SHOT = 0.833
SHOT_BANDS = ["0-10", "10-20", "20-30", "30-40", "40-50", "50+", "pocket"]
REAL_SET_ACC = {"0-10": 1.00, "10-20": 0.96, "20-30": 0.85, "30-40": 0.71, "40-50": 0.54, "50+": 0.33, "pocket": 0.605}
REAL_GP_ACC = {"0-10": 0.89, "10-20": 0.63, "20-30": 0.51, "30-40": 0.38, "40-50": 0.39, "50+": 0.34, "pocket": 0.215}


def pooled(R, key):
    return sum(float(t.get(key, 0)) for r in R.values() for t in r["teams"])


def share_by_seed(R, scoring=False):
    """Seed -> set-shot share of that match's shots (both teams), in percent.
    scoring=True counts only shots that scored (goal or behind) on both sides."""
    def cnt(t, pre):
        if scoring:
            return float(t.get(pre + "_g", 0)) + float(t.get(pre + "_b", 0))
        return float(t.get(pre + "_n", 0))
    out = {}
    for i, r in R.items():
        n = sum(cnt(t, "sshot") + cnt(t, "gshot") for t in r["teams"])
        if n:
            out[i] = 100 * sum(cnt(t, "sshot") for t in r["teams"]) / n
    return out


def shots_section(A, B):
    """Set-shot share, conversion by distance and scoring shots, per arm."""
    if not any("sshot_n" in t for r in A.values() for t in r["teams"]):
        return
    arms = [("A", A)] + ([("B", B)] if B else [])
    print("\n## Shots\n")
    head = "| per team-match | real |" + "".join(f" {k} |" for k, _ in arms) + (" B-A | se |" if B else "")
    print(head)
    print("|" + "---|" * (head.count("|") - 1))

    def row(label, real, vals, a=None, b=None, fmt="{:.1f}"):
        line = f"| {label} | {real} |" + "".join(" " + fmt.format(v) + " |" for v in vals)
        if a is not None and b is not None:
            common = [i for i in a if i in b]
            d = [b[i] - a[i] for i in common]
            se = st.stdev(d) / math.sqrt(len(d)) if len(d) > 1 else 0.0
            line += " " + ("{:+.2f}".format(st.mean(d))) + f" | {se:.2f} |"
        print(line)
    n = {k: len(R) * 2 for k, R in arms}
    for key, label in (("sshot_n", "set shots"), ("gshot_n", "general-play shots")):
        row(label, "-", [pooled(R, key) / n[k] for k, R in arms],
            per_match(A, key) if B else None, per_match(B, key) if B else None)
    sc = {k: {i: sum(float(t.get("goals", 0)) + float(t.get("behinds", 0)) for t in r["teams"]) / 2
              for i, r in R.items()} for k, R in arms}
    row("scoring shots (goals + behinds)", "22.4", [st.mean(sc[k].values()) for k, _ in arms],
        sc["A"] if B else None, sc.get("B"))
    sh = {k: share_by_seed(R) for k, R in arms}
    row("set-shot share of shots (general play counted only when it scores)", f"{100 * REAL_SET_SHARE:.0f}%",
        [100 * pooled(R, "sshot_n") / max(1, pooled(R, "sshot_n") + pooled(R, "gshot_n")) for k, R in arms],
        sh["A"] if B else None, sh.get("B"), fmt="{:.1f}")

    def scoring_share(R):
        ss = pooled(R, "sshot_g") + pooled(R, "sshot_b")
        return 100 * ss / max(1, ss + pooled(R, "gshot_g") + pooled(R, "gshot_b"))
    sc_sh = {k: share_by_seed(R, True) for k, R in arms}
    row("set-shot share of scoring shots", "~55%*", [scoring_share(R) for k, R in arms],
        sc_sh["A"] if B else None, sc_sh.get("B"), fmt="{:.1f}")
    print("\nThe sim logs a general-play shot only when it scores, so the first share has a short"
          " denominator; the scoring-shot share counts both kinds alike. *Real: "
          f"{100 * REAL_SET_SHARE:.0f}% of shots are set shots and {100 * REAL_SCORING_PER_SHOT:.0f}% of"
          " shots score [WH]; if both kinds score equally often, set shots are 55% of scoring shots too"
          " (the two no-score rates are not published apart).")
    print("\nGoals per shot, pooled over every shot of the arm. Real: [ABC] 2021-25, straight in front"
          " (within 30 degrees); the pocket row against the 10-20 m wide cells.\n")
    head = "| shots | real set | real general |" + "".join(f" {k} goals/shot | {k} a team |" for k, _ in arms)
    print(head)
    print("|" + "---|" * (head.count("|") - 1))
    for band in SHOT_BANDS:
        label = "set, pocket (15 m, tight angle)" if band == "pocket" else f"set, {band} m"
        line = f"| {label} | {100 * REAL_SET_ACC[band]:.1f}% | {100 * REAL_GP_ACC[band]:.1f}% |"
        for k, R in arms:
            sn = pooled(R, f"sshot_{band}_n")
            line += (f" {100 * pooled(R, f'sshot_{band}_g') / sn:.0f}% |" if sn else " - |") + f" {sn / n[k]:.2f} |"
        print(line)
    for key, label in (("sshot", "all set shots"), ("gshot", "general play (no distance in the sim)")):
        line = f"| {label} | - | - |"
        for k, R in arms:
            sn = pooled(R, key + "_n")
            line += (f" {100 * pooled(R, key + '_g') / sn:.0f}% |" if sn else " - |") + f" {sn / n[k]:.2f} |"
        print(line)
def duel_section(A, B):
    """Key forward v key defender (row 94): contests per duel per match from the
    engine's duel log, as the full-time line reads them. A duel is one key
    forward's match: [contests, marks, most against one defender, verdict]."""
    if not any("duels" in r for r in A.values()):
        return
    arms = [("A", A)] + ([("B", B)] if B else [])
    stats = {}
    for name, R in arms:
        rows = [d for r in R.values() for d in r.get("duels", [])]
        n = max(1, len(rows))
        c = sorted(d[0] for d in rows)
        stats[name] = {
            "contests": st.mean(c) if c else 0.0,
            "median": st.median(c) if c else 0.0,
            "pair": st.mean(d[2] for d in rows) if rows else 0.0,
            "6+": 100 * sum(d[0] >= 6 for d in rows) / n,
            "shown": 100 * sum(d[0] >= 4 for d in rows) / n,
            "mark%": 100 * sum(d[1] for d in rows) / max(1, sum(c)),
            "beat": 100 * sum(d[0] >= 4 and d[3] > 0 for d in rows) / n,
            "even": 100 * sum(d[0] >= 4 and d[3] == 0 for d in rows) / n,
            "held": 100 * sum(d[0] >= 4 and d[3] < 0 for d in rows) / n,
            "duels": len(rows)}
    print("\n## Key forward v key defender (contests per duel per match)\n")
    print("A duel is one key forward's match against his direct opponent(s), from MatchSim.duel_log "
          "(what the full-time line counts; MatchNotes shows a line from 4 contests). "
          "beat / even / held: the line's verdict, as a share of all duels.\n")
    head = "| arm | duels | contests mean | median | v one defender | 6+ contests | line shown (4+) | forward marks | beat / even / held |"
    print(head)
    print("|" + "---|" * (head.count("|") - 1))
    for name, _ in arms:
        s = stats[name]
        print(f"| {name} | {s['duels']} | {s['contests']:.2f} | {s['median']:.0f} | {s['pair']:.2f} | {s['6+']:.0f}% | "
              f"{s['shown']:.0f}% | {s['mark%']:.1f}% | {s['beat']:.0f} / {s['even']:.0f} / {s['held']:.0f} |")
    if B:
        def per(R):
            return {i: st.mean(d[0] for d in r["duels"]) for i, r in R.items() if r.get("duels")}
        a, b = per(A), per(B)
        d = [b[i] - a[i] for i in a if i in b]
        if len(d) > 1:
            print(f"\nContests per duel B-A {st.mean(d):+.2f} (se {st.stdev(d) / math.sqrt(len(d)):.2f}, paired by seed).")


TAIL = (40, 60, 80, 100, 120)
ROOT = os.path.dirname(os.path.dirname(HERE))


def real_margins():
    """Real AFL 2026 home-and-away margins from data/raw/fixtures_2026.json (finals left out)."""
    path = os.path.join(ROOT, "data", "raw", "fixtures_2026.json")
    if not os.path.exists(path):
        return []
    games = json.load(open(path, encoding="utf-8"))["games"]
    return [abs(g["hscore"] - g["ascore"]) for g in games
            if g.get("complete") == 100 and not g.get("is_final")]


def real_history():
    """Real AFL 2010-2025, every match with finals (afl_comebacks.json, AFL Tables): (h[4], a[4])."""
    path = os.path.join(HERE, "afl_comebacks.json")
    if not os.path.exists(path):
        return []
    return [(g["h"], g["a"]) for g in json.load(open(path, encoding="utf-8"))["games"]]


def came_back(h, a, k):
    """The winner was k or more points down at a quarter break (QT, HT or 3QT)."""
    if h[3] == a[3]:
        return False
    s = 1 if h[3] > a[3] else -1
    return any(s * (a[q] - h[q]) >= k for q in range(3))


def wilson(k, n, z=1.96):
    if n == 0:
        return 0.0, 0.0
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return 100 * (c - h), 100 * (c + h)


def margin_tail(A, B):
    """The margin distribution's tail: share of matches at 40+ .. 120+ points, mean, p90, p99,
    max, against real AFL 2026; paired runs add B - A per seed with its standard error."""
    real = real_margins()
    hist = real_history()
    hm = [abs(h[3] - a[3]) for h, a in hist]
    common = [i for i in A if i in B] if B else list(A)
    ma = {i: abs(A[i]["teams"][0]["score"] - A[i]["teams"][1]["score"]) for i in common}
    mb = {i: abs(B[i]["teams"][0]["score"] - B[i]["teams"][1]["score"]) for i in common} if B else {}
    n = len(common)
    print(f"\n## Margin tail ({n} matches{' per arm, paired' if B else ''})\n")
    head = f"| margin | real AFL 2026 ({len(real)} H&A games, 95% CI) | real 2010-25 ({len(hm)}) | A |"
    if B:
        head += " B | B-A | se | sig |"
    print(head)
    print("|" + "---|" * (head.count("|") - 1))

    def row(label, f_real, f_hist, fa, fb, fmt):
        line = f"| {label} | {f_real} | {f_hist} | {fmt(st.mean(fa))} |"
        if B:
            d = [b - a for a, b in zip(fa, fb)]
            md = st.mean(d)
            se = st.stdev(d) / math.sqrt(len(d)) if len(d) > 1 else 0.0
            sig = "yes" if se > 0 and abs(md) > 2 * se else ""
            line += f" {fmt(st.mean(fb))} | {fmt(md, True)} | {fmt(se)} | {sig} |"
        print(line)
    for t in TAIL:
        k = sum(x >= t for x in real)
        lo, hi = wilson(k, len(real))
        rr = f"{100*k/len(real):.1f}% ({k}; {lo:.1f}-{hi:.1f})" if real else "-"
        fa = [100.0 * (ma[i] >= t) for i in common]
        fb = [100.0 * (mb[i] >= t) for i in common] if B else []
        hh = f"{100*sum(x >= t for x in hm)/len(hm):.1f}%" if hm else "-"
        row(f"{t}+", rr, hh, fa, fb, lambda v, s=False: (f"{v:+.2f}%" if s else f"{v:.2f}%"))
    rr = f"{st.mean(real):.1f}" if real else "-"
    row("mean margin", rr, f"{st.mean(hm):.1f}" if hm else "-", [float(ma[i]) for i in common], [float(mb[i]) for i in common] if B else [],
        lambda v, s=False: (f"{v:+.2f}" if s else f"{v:.2f}"))
    # Upsets and comebacks (bible principle 2: decisions move the odds, never the certainty).
    if common and "q_score" in A[common[0]]["teams"][0]:
        def stronger_won(R, i):
            t = R[i]["teams"]
            if t[0]["strength"] == t[1]["strength"] or t[0]["score"] == t[1]["score"]:
                return None
            return 100.0 * ((t[0]["strength"] > t[1]["strength"]) == (t[0]["score"] > t[1]["score"]))

        def cb(R, i, k):
            t = R[i]["teams"]
            return 100.0 * came_back(t[0]["q_score"], t[1]["q_score"], k)
        ids = [i for i in common if stronger_won(A, i) is not None and (not B or stronger_won(B, i) is not None)]
        fmt = lambda v, s=False: (f"{v:+.2f}%" if s else f"{v:.2f}%")
        row("stronger list wins", "-", "-", [stronger_won(A, i) for i in ids],
            [stronger_won(B, i) for i in ids] if B else [], fmt)
        for k in (18, 24, 30):
            hh = f"{100*sum(came_back(h, a, k) for h, a in hist)/len(hist):.1f}%" if hist else "-"
            row(f"winner {k}+ down at a break", "-", hh, [cb(A, i, k) for i in common],
                [cb(B, i, k) for i in common] if B else [], fmt)
    for name, R in (("A", ma), ("B", mb)):
        if not R:
            continue
        v = sorted(R.values())
        print(f"\n{name}: p90 {v[int(0.9*(len(v)-1))]}, p99 {v[int(0.99*(len(v)-1))]}, max {v[-1]}"
              + (f" (real 2026 p90 {sorted(real)[int(0.9*(len(real)-1))]}, max {max(real)}; 2010-25 p99 "
                 f"{sorted(hm)[int(0.99*(len(hm)-1))]}, max {max(hm)})" if real and hm and name == "A" else ""))
ROLES = ["DEF", "MID", "FWD", "RUCK"]
ROLE_REF = {"disposals": "disposals", "kicks": "kicks", "handballs": "handballs", "marks": "marks",
            "rebounds": "rebound_50s", "inside50": "inside_50s", "clearances": "clearances", "goals": "goals"}


def role_rate(r, role, key):
    """One match's per player-game rate for a line (both sides pooled), or None."""
    pg = sum(t.get("roles", {}).get(role, {}).get("pg", 0) for t in r["teams"])
    if pg == 0:
        return None
    return sum(t.get("roles", {}).get(role, {}).get(key, 0.0) for t in r["teams"]) / pg


def role_share(r, role):
    """One match's share of both sides' disposals that went to a line."""
    tot = sum(t.get("roles", {}).get(x, {}).get("disposals", 0.0) for t in r["teams"] for x in t.get("roles", {}))
    if tot == 0:
        return None
    return sum(t.get("roles", {}).get(role, {}).get("disposals", 0.0) for t in r["teams"]) / tot


def zone_share(R, zone, role):
    """Pooled share of a zone's carrier picks that went to a slot role."""
    n = d = 0
    for r in R.values():
        for t in r["teams"]:
            cz = t.get("carry_zone", {})
            n += cz.get(f"{zone}|{role}", 0)
            d += sum(v for k, v in cz.items() if k.startswith(zone + "|"))
    return None if d == 0 else n / d


def paired(A, B, fn):
    a = {i: fn(r) for i, r in A.items()}
    a = {i: v for i, v in a.items() if v is not None}
    if not B:
        return st.mean(a.values()), None, None, None
    b = {i: fn(r) for i, r in B.items()}
    common = [i for i in a if b.get(i) is not None]
    d = [b[i] - a[i] for i in common]
    se = st.stdev(d) / math.sqrt(len(d)) if len(d) > 1 else 0.0
    return st.mean(a.values()), st.mean(b[i] for i in common), st.mean(d), se


def role_report(A, B):
    """Each line's box score per player-game against real 2026 (afl_role_rates.json, grouped by
    the player's own position as the game derives it) and its share of the side's disposals;
    then who takes the ball by zone (carrier picks by slot role, no real reference)."""
    if not any("roles" in t for r in A.values() for t in r["teams"]):
        return
    ref = json.load(open(os.path.join(HERE, "afl_role_rates.json")))["roles"]
    pooled = {x: ref[x]["per_game"]["disposals"] * ref[x]["player_games"] for x in ROLES}
    real_share = {x: pooled[x] / sum(pooled.values()) for x in ROLES}
    print("\n## By line, per player-game (real 2026: tools/balance/afl_role_rates.json)\n")
    head = "| line | stat | real | A |" + (" B | B-A | se | sig |" if B else "")
    print(head)
    print("|" + "---|" * (head.count("|") - 1))
    for role in ROLES:
        rows = [(k, ref[role]["per_game"][ROLE_REF[k]], lambda r, k=k, role=role: role_rate(r, role, k)) for k in ROLE_REF]
        rows.append(("share of disposals", real_share[role], lambda r, role=role: role_share(r, role)))
        for k, real_v, fn in rows:
            ma, mb, dm, se = paired(A, B, fn)
            pct = k.startswith("share")
            f = (lambda v: f"{100*v:.1f}%") if pct else (lambda v: f"{v:.2f}")
            line = f"| {role} | {k} | {f(real_v)} | {f(ma)} |"
            if B:
                sig = "yes" if se and abs(dm) > 2 * se else ""
                line += f" {f(mb)} | {(100*dm if pct else dm):+.2f}{'pp' if pct else ''} | {(100*se if pct else se):.2f} | {sig} |"
            print(line)
    print("\nReal share of disposals pools 2026 player-games by line (DEF %.1f%% of player-games)." %
          (100 * ref["DEF"]["player_games"] / sum(ref[x]["player_games"] for x in ROLES)))
    print("\n## Who takes the ball, by zone (share of carrier picks by slot role; no real reference)\n")
    zones = ["back", "middle", "attack", "inside"]
    head = "| zone | " + " | ".join(f"{x} A" + (f" | {x} B" if B else "") for x in ROLES) + " |"
    print(head)
    print("|" + "---|" * (head.count("|") - 1))
    for z in zones:
        cells = []
        for x in ROLES:
            a = zone_share(A, z, x)
            cells.append("-" if a is None else f"{100*a:.1f}%")
            if B:
                b = zone_share(B, z, x)
                cells.append("-" if b is None else f"{100*b:.1f}%")
        print(f"| {z} | " + " | ".join(cells) + " |")


TYPE_STATS = ["disposals", "kicks", "handballs", "marks", "rebounds", "kick_ins"]
TOP_TYPES = ["Key defender"]
SEASON_GAMES = 23


def type_report(A, B):
    """Disposals a player-game by each man's type as the game names it (Roles.label), against
    real 2026 (afl_role_rates.json "types": IN = inside the 18 clubs' lowest..highest pooled rate
    for that type, NEAR = within the mean +-2 sd, else OUT); then the top key defenders by
    disposals a game over the run, as a SEASON_GAMES-game season."""
    if not any("types" in t for r in A.values() for t in r["teams"]):
        return
    ref = json.load(open(os.path.join(HERE, "afl_role_rates.json"))).get("types", {})
    names = sorted({k for r in A.values() for t in r["teams"] for k in t.get("types", {}) if k != "pl"},
                   key=lambda k: -ref.get(k, {}).get("player_games", 0))

    def rate(r, ty, k):
        pg = sum(t.get("types", {}).get(ty, {}).get("pg", 0) for t in r["teams"])
        return None if pg == 0 else sum(t.get("types", {}).get(ty, {}).get(k, 0.0) for t in r["teams"]) / pg
    print("\n## By type, per player-game (real 2026: afl_role_rates.json types; Roles.label)\n")
    head = "| type | real di | clubs range | A di | mark | A kicks | A hb | A marks | A reb50 | A kick-ins |" \
        + (" B di | B-A | se | sig |" if B else "")
    print(head)
    print("|" + "---|" * (head.count("|") - 1))
    for ty in names:
        rr = ref.get(ty)
        ma, mb, dm, se = paired(A, B, lambda r, ty=ty: rate(r, ty, "disposals"))
        if rr:
            c = rr["disposals_clubs"]
            real = rr["per_game"]["disposals"]
            mk = "IN" if c["min"] <= ma <= c["max"] else ("NEAR" if abs(ma - real) <= 2 * c["sd"] else "OUT")
            line = f"| {ty} | {real:.2f} | {c['min']:.1f}-{c['max']:.1f} | {ma:.2f} | {mk} |"
        else:
            line = f"| {ty} | - | - | {ma:.2f} | - |"
        for k in TYPE_STATS[1:]:
            v = [x for x in (rate(r, ty, k) for r in A.values()) if x is not None]
            line += f" {st.mean(v):.2f} |"
        if B:
            sig = "yes" if se and abs(dm) > 2 * se else ""
            line += f" {mb:.2f} | {dm:+.2f} | {se:.2f} | {sig} |"
        print(line)
    if any("type_src" in t for r in A.values() for t in r["teams"]):
        print("\n## Where each type's disposals happen (run A, event log: share by zone from his side's view,"
              " and share that were his first touch after his own rebound 50; no real reference)\n")
        print("| type | per game (events) | back | middle | attack | inside | after own reb50 |")
        print("|---|---|---|---|---|---|---|")
        for ty in names:
            tot = {}
            pg = 0
            for r in A.values():
                for t in r["teams"]:
                    pg += t.get("types", {}).get(ty, {}).get("pg", 0)
                    for k, v in t.get("type_src", {}).get(ty, {}).items():
                        tot[k] = tot.get(k, 0) + v
            ev = tot.get("ev", 0)
            if not ev or not pg:
                continue
            cells = " | ".join(f"{100*tot.get(z, 0)/ev:.0f}%" for z in ["back", "middle", "attack", "inside", "reb"])
            print(f"| {ty} | {ev/pg:.2f} | {cells} |")
    for ty in TOP_TYPES:
        acc = {}
        for r in A.values():
            for t in r["teams"]:
                for row in t.get("types", {}).get("pl", []):
                    if row[1] != ty:
                        continue
                    a = acc.setdefault(row[0], [0] * 7)
                    a[0] += 1
                    for j in range(6):
                        a[j + 1] += row[2 + j]
        real = {}
        try:
            with open(os.path.join(HERE, "..", "..", "data", "players_2026.csv"), encoding="utf-8") as fh:
                for row in csv.DictReader(fh):
                    real[f"{row['club']}_{row['num']}"] = row
        except OSError:
            pass
        # Men who played at least a quarter of the run's games for their club.
        need = max(1, len(A) * 2 // 18 // 4)
        top = sorted(((k, v) for k, v in acc.items() if v[0] >= need), key=lambda kv: -kv[1][1] / kv[1][0])[:10]
        print(f"\n## Top 10 by disposals a game, {ty} (run A), as a {SEASON_GAMES}-game season\n")
        print("| # | player | games | di/g | season di | real 2026 di/g | kicks/g | hb/g | marks/g | reb50/g | kick-ins/g |")
        print("|---|---|---|---|---|---|---|---|---|---|---|")
        for n, (pid, a) in enumerate(top, 1):
            g = a[0]
            rw = real.get(pid)
            nm = f"{rw['first']} {rw['last']} ({pid})" if rw else pid
            rdi = f"{int(rw['di'])/int(rw['gm']):.1f} ({rw['gm']} gm)" if rw and int(rw["gm"] or 0) > 0 else "-"
            print(f"| {n} | {nm} | {g} | {a[1]/g:.1f} | {SEASON_GAMES*a[1]/g:.0f} | {rdi} | {a[2]/g:.1f} | {a[3]/g:.1f} |"
                  f" {a[4]/g:.1f} | {a[5]/g:.1f} | {a[6]/g:.1f} |")


# Champion Data 2025 (Wheelo), intercepts a game per player by position
# (docs/research/INTERCEPT_EVIDENCE.md; tools/audit/intercept_impl.gd REAL).
ROLE_REAL = {"DEF": 4.9, "MID": 2.5, "FWD": 1.1, "RUCK": 2.2}


def ic_role_rate(rows, role):
    """Seed -> intercepts per player-game for one role (both teams pooled)."""
    out = {}
    for i, r in rows.items():
        ic = sum(float(t.get("ic_" + role, 0)) for t in r["teams"])
        pg = sum(float(t.get("pg_" + role, 0)) for t in r["teams"])
        if pg > 0:
            out[i] = (ic, pg)
    return out


def role_table(A, B):
    """Intercepts a game per player by listed position, against Champion Data."""
    if not any("pg_MID" in t for r in A.values() for t in r["teams"]):
        return
    print("\nIntercepts a game per player, by listed position (Champion Data 2025):\n")
    head = "| role | real | A | share A |" + (" B | share B | B-A | se | sig |" if B else "")
    print(head)
    print("|" + "---|" * (head.count("|") - 1))
    tot = {}
    for arm, R in (("A", A), ("B", B)):
        tot[arm] = sum(float(t.get("intercepts", 0)) for r in R.values() for t in r["teams"]) or 1.0
    for role, real in ROLE_REAL.items():
        a = ic_role_rate(A, role)
        if not a:
            continue
        ra = sum(v[0] for v in a.values()) / sum(v[1] for v in a.values())
        sa = 100 * sum(v[0] for v in a.values()) / tot["A"]
        line = f"| {role} | {real:.1f} | {ra:.2f} | {sa:.0f}% |"
        if B:
            b = ic_role_rate(B, role)
            common = [i for i in a if i in b]
            rb = sum(b[i][0] for i in common) / sum(b[i][1] for i in common)
            sb = 100 * sum(b[i][0] for i in common) / tot["B"]
            d = [b[i][0] / b[i][1] - a[i][0] / a[i][1] for i in common]
            se = st.stdev(d) / math.sqrt(len(d)) if len(d) > 1 else 0.0
            sig = "yes" if se > 0 and abs(st.mean(d)) > 2 * se else ""
            line += f" {rb:.2f} | {sb:.0f}% | {rb - ra:+.2f} | {se:.2f} | {sig} |"
        print(line)
    print("\nReal shares (Champion Data 2025): DEF 57%, MID 23%, FWD 15%, RUCK 4%; a team intercepts about 63.4 a game.")


def spoil_zone_rate(rows, keys):
    """Seed -> spoils a team-match in the zone keys (from each team's spoil_zone)."""
    return {i: sum(float(t.get("spoil_zone", {}).get(k, 0)) for t in r["teams"] for k in keys) / 2
            for i, r in rows.items()}


def spoils_section(A, B):
    """Spoils a team a game by zone and by listed position (T2.29, TODO row 11), against
    Champion Data 2026 (afl_spoil_zones.json; the zone split is an estimate, see its source)."""
    if not any("spoil_zone" in t for r in A.values() for t in r["teams"]):
        return
    ref = json.load(open(os.path.join(HERE, "afl_spoil_zones.json")))
    real = ref["per_team_match"]

    def mark(v, b):
        if b["lo"] <= v <= b["hi"]:
            return "IN"
        return "NEAR" if abs(v - b["mean"]) <= 2 * b["sd"] else "OUT"
    print("\n\n## Spoils a team a game, by zone (spoiling side's end; real zones are an estimate)\n")
    head = "| zone | AFL mean | AFL range | A | A/real | mark |" + (" B | mark | B-A | se | sig |" if B else "")
    print(head)
    print("|" + "---|" * (head.count("|") - 1))
    rows = [("total", ["d50_entry", "d50_play", "mid", "f50"], "total"),
            ("d50 (all)", ["d50_entry", "d50_play"], "d50"),
            ("  d50: entries and packs", ["d50_entry"], None),
            ("  d50: general play", ["d50_play"], None),
            ("mid (between the arcs)", ["mid"], "mid"),
            ("f50 (own forward 50)", ["f50"], "f50"),
            ("outside d50 (mid + f50)", ["mid", "f50"], None)]
    for label, keys, rk in rows:
        a = spoil_zone_rate(A, keys)
        ma = st.mean(a.values())
        b0 = real.get(rk) if rk else None
        if rk is None and keys == ["mid", "f50"]:
            b0 = {"mean": real["mid"]["mean"] + real["f50"]["mean"], "lo": real["mid"]["lo"] + real["f50"]["lo"],
                  "hi": real["mid"]["hi"] + real["f50"]["hi"], "sd": math.hypot(real["mid"]["sd"], real["f50"]["sd"])}
        line = (f"| {label} | {b0['mean']:.1f} | {b0['lo']:.1f}-{b0['hi']:.1f} | {ma:.1f} | {ma / b0['mean']:.2f} | {mark(ma, b0)} |"
                if b0 else f"| {label} | - | - | {ma:.1f} | - | - |")
        if B:
            b = spoil_zone_rate(B, keys)
            common = [i for i in a if i in b]
            d = [b[i] - a[i] for i in common]
            mb = st.mean(b[i] for i in common)
            se = st.stdev(d) / math.sqrt(len(d)) if len(d) > 1 else 0.0
            sig = "yes" if se > 0 and abs(st.mean(d)) > 2 * se else ""
            line += f" {mb:.1f} | {mark(mb, b0) if b0 else '-'} | {st.mean(d):+.2f} | {se:.2f} | {sig} |"
        print(line)
    print("\nSpoils a game per player, by listed position (measured, Champion Data 2026):\n")
    print("| role | real | A | real share | share A |")
    print("|---|---|---|---|---|")
    tot = sum(float(t.get("sp_" + r_, 0)) for r in A.values() for t in r["teams"] for r_ in ref["by_role"]) or 1.0
    for role, rr in ref["by_role"].items():
        sp = sum(float(t.get("sp_" + role, 0)) for r in A.values() for t in r["teams"])
        pg = sum(float(t.get("pg_" + role, 0)) for r in A.values() for t in r["teams"])
        if pg <= 0:
            continue
        print(f"| {role} | {rr['per_player_game']:.2f} | {sp / pg:.2f} | {100 * rr['share']:.0f}% | {100 * sp / tot:.0f}% |")
    print(f"\nReal: {ref['source']}")


def wet_section(A, B, wet):
    """Paired change in percent (B / A - 1), plus accuracy and set-shot accuracy
    in points (row 120). The real wet v dry column shows only when B is the wet
    arm and A is not (wet=True), so no other screen is read against it."""
    if not B:
        return
    common = [i for i in A if i in B]
    if not common:
        return
    print("\n## Change B against A, percent" + (" (real column: wet against dry)" if wet else "") + "\n")
    print("| stat | A | B | B/A-1 | se |" + (" real wet v dry |" if wet else ""))
    print("|---|---|---|---|---|" + ("---|" if wet else ""))
    for k in list(REAL_WET):
        a = per_match(A, k)
        b = per_match(B, k)
        ma = st.mean(a[i] for i in common)
        if ma == 0:
            continue
        mb = st.mean(b[i] for i in common)
        d = [(b[i] - a[i]) / ma for i in common]
        se = st.stdev(d) / math.sqrt(len(d)) if len(d) > 1 else 0.0
        print(f"| {k} | {ma:.1f} | {mb:.1f} | {100 * (mb / ma - 1):+.1f}% | {100 * se:.1f}% |"
              + (f" {REAL_WET[k]} |" if wet else ""))

    def acc(r, g, b):
        gg = sum(float(t.get(g, 0)) for t in r["teams"])
        bb = sum(float(t.get(b, 0)) for t in r["teams"])
        return 100 * gg / (gg + bb) if gg + bb else None
    for label, g, b, real in (("accuracy, goals per scoring shot (points)", "goals", "behinds", "-1 to -2"),
                              ("set-shot goals per set shot (points)", "sshot_g", None, "-"),
                              ("general-play goals per logged shot (points)", "gshot_g", None, "-")):
        if b is None:
            n = g.replace("_g", "_n")
            fa = {i: (100 * sum(float(t.get(g, 0)) for t in A[i]["teams"])
                      / max(1.0, sum(float(t.get(n, 0)) for t in A[i]["teams"]))) for i in common}
            fb = {i: (100 * sum(float(t.get(g, 0)) for t in B[i]["teams"])
                      / max(1.0, sum(float(t.get(n, 0)) for t in B[i]["teams"]))) for i in common}
            pa = 100 * sum(float(t.get(g, 0)) for i in common for t in A[i]["teams"]) / max(1.0, sum(
                float(t.get(n, 0)) for i in common for t in A[i]["teams"]))
            pb = 100 * sum(float(t.get(g, 0)) for i in common for t in B[i]["teams"]) / max(1.0, sum(
                float(t.get(n, 0)) for i in common for t in B[i]["teams"]))
        else:
            fa = {i: acc(A[i], g, b) for i in common}
            fb = {i: acc(B[i], g, b) for i in common}
            pa = 100 * sum(float(t.get(g, 0)) for i in common for t in A[i]["teams"]) / sum(
                float(t.get(g, 0)) + float(t.get(b, 0)) for i in common for t in A[i]["teams"])
            pb = 100 * sum(float(t.get(g, 0)) for i in common for t in B[i]["teams"]) / sum(
                float(t.get(g, 0)) + float(t.get(b, 0)) for i in common for t in B[i]["teams"])
        d = [fb[i] - fa[i] for i in common if fa[i] is not None and fb[i] is not None]
        se = st.stdev(d) / math.sqrt(len(d)) if len(d) > 1 else 0.0
        print(f"| {label} | {pa:.1f} | {pb:.1f} | {pb - pa:+.1f} pts | {se:.1f} |" + (f" {real} |" if wet else ""))


# Ruck integrity (T2.31): hit-outs per team and per number-one ruck, hit-outs to
# advantage, the club spread and the match duel spread, against Champion Data 2025 and
# 2026 (afl_ruck_rates.json, built by build_ruck_rates.py from the Wheelo cache).
RUCK_DUEL = (10, 20, 30)


def _ratio(num, den):
    def f(r):
        d = sum(den(t) for t in r["teams"])
        return None if d == 0 else 100 * sum(num(t) for t in r["teams"]) / d
    return f


RUCK_ROWS = [
    ("team hit-outs", "team_hitouts", lambda r: sum(float(t.get("hitouts", 0)) for t in r["teams"]) / 2, ""),
    ("team hit-outs to advantage", "team_hta", lambda r: sum(float(t.get("hitouts_adv", 0)) for t in r["teams"]) / 2, ""),
    ("to advantage, % of hit-outs", "team_hta_pct",
     _ratio(lambda t: float(t.get("hitouts_adv", 0)), lambda t: float(t.get("hitouts", 0))), "%"),
    ("number-one ruck: hit-outs", "ruck1_hitouts", lambda r: sum(t["ruck1"][0] for t in r["teams"]) / 2, ""),
    ("number-one ruck: to advantage", "ruck1_hta", lambda r: sum(t["ruck1"][1] for t in r["teams"]) / 2, ""),
    ("number-one ruck: to advantage %", "ruck1_hta_pct", _ratio(lambda t: t["ruck1"][1], lambda t: t["ruck1"][0]), "%"),
    ("number-one ruck: share of team hit-outs", "ruck1_share",
     _ratio(lambda t: t["ruck1"][0], lambda t: float(t.get("hitouts", 0))), "%"),
    ("number-one ruck: ruck contests*", "ruck1_contests", lambda r: sum(t["ruck1"][2] for t in r["teams"]) / 2, ""),
    ("number-one ruck: hit-outs per ruck contest*", "ruck1_win_pct",
     _ratio(lambda t: t["ruck1"][0], lambda t: t["ruck1"][2]), "%"),
]


def _mark(v, rr):
    if rr["min"] <= v <= rr["max"]:
        return "IN"
    return "NEAR" if abs(v - rr["mean"]) <= 2 * rr["sd"] else "OUT"


def ruck_section(A, B):
    if not any("ruck1" in t for r in A.values() for t in r["teams"]):
        return
    path = os.path.join(HERE, "afl_ruck_rates.json")
    if not os.path.exists(path):
        return
    ref = json.load(open(path, encoding="utf-8"))
    r26, r25 = ref["2026"]["league"], ref["2025"]["league"]
    print("\n## Rucks (T2.31; real: Champion Data via Wheelo, tools/balance/afl_ruck_rates.json)\n")
    print("Number-one ruck: the side's man with the most hit-outs in the match (real: the club's listed ruck with "
          "the most season hit-outs, per game he played). Mark against 2026's 18 clubs: IN inside lowest..highest, "
          "NEAR within mean +-2 sd, OUT.\n")
    head = "| per team-match | real 2026 mean | 2026 range | real 2025 mean | A | mark |" + (" B | B-A | se | sig |" if B else "")
    print(head)
    print("|" + "---|" * (head.count("|") - 1))
    for label, key, fn, unit in RUCK_ROWS:
        ma, mb, dm, se = paired(A, B, fn)
        rr = r26[key]
        line = (f"| {label} | {rr['mean']:.1f}{unit} | {rr['min']:.1f}-{rr['max']:.1f} | {r25[key]['mean']:.1f}{unit} |"
                f" {ma:.1f}{unit} | {_mark(ma, rr)} |")
        if B:
            sig = "yes" if se and abs(dm) > 2 * se else ""
            line += f" {mb:.1f}{unit} | {dm:+.2f} | {se:.2f} | {sig} |"
        print(line)
    print("\n*The sim counts a ruck contest only when someone wins the tap, so its hit-outs per contest is the"
          " share of won taps (the two rucks sum to 100%); real ruck contests include taps nobody wins."
          " Read those two rows' marks with this in mind.")
    ruck_clubs(A, B, ref)
    ruck_duels(A, B)


def ruck_clubs(A, B, ref):
    """Feast or famine at club level: each club's sim average against the real 18 clubs' spread."""
    r26 = ref["2026"]["league"]
    names = {}
    with open(os.path.join(ROOT, "data", "clubs.csv"), encoding="utf-8") as f:
        for line in f.read().splitlines()[1:]:
            c = line.split(",")
            names[c[1]] = c[0]
    real_club = {names.get(k, k): v for k, v in ref["2026"]["clubs"].items()}
    for name, R in (("A", A), ("B", B)):
        if not R:
            continue
        acc = {}
        for r in R.values():
            for t in r["teams"]:
                c = acc.setdefault(t.get("club", "?"), [0, 0.0, 0, 0, 0])
                c[0] += 1
                c[1] += float(t.get("hitouts", 0))
                c[2] += t["ruck1"][0]
                c[3] += t["ruck1"][2]
                c[4] += t["ruck1"][3]
        club = {k: {"team_hitouts": v[1] / v[0], "ruck1_hitouts": v[2] / v[0],
                    "ruck1_win_pct": 100 * v[2] / max(1, v[3]), "rating": v[4] / v[0]} for k, v in acc.items()}
        common = [k for k in club if k in real_club]
        print(f"\n### Club spread, arm {name} (each club over {min(acc[k][0] for k in common)}+ team-matches)\n")
        print("| club average | real lowest | real highest | real sd | sim lowest | sim highest | sim sd | r with real club |")
        print("|---|---|---|---|---|---|---|---|")
        for key, label in (("team_hitouts", "team hit-outs"), ("ruck1_hitouts", "number-one ruck hit-outs"),
                           ("ruck1_win_pct", "number-one ruck hit-outs per contest*")):
            v = [club[k][key] for k in common]
            rv = [real_club[k][key] for k in common]
            rr = r26[key]
            corr = st.correlation(v, rv) if len(v) > 2 and st.pstdev(v) > 0 else float("nan")
            print(f"| {label} | {rr['min']:.1f} | {rr['max']:.1f} | {rr['sd']:.2f} | {min(v):.1f} | {max(v):.1f} |"
                  f" {st.pstdev(v):.2f} | {corr:+.2f} |")
        if name == "A":
            print("\n| club | sim no.1 ruck rating | sim team hit-outs | real 2026 | sim no.1 ruck | real no.1 ruck |")
            print("|---|---|---|---|---|---|")
            for k in sorted(common, key=lambda k: -club[k]["team_hitouts"]):
                rc = real_club[k]
                print(f"| {k} | {club[k]['rating']:.0f} | {club[k]['team_hitouts']:.1f} | {rc['team_hitouts']:.1f} |"
                      f" {club[k]['ruck1_hitouts']:.1f} | {rc['ruck1_hitouts']:.1f} ({rc['ruck1']}) |")


def ruck_duels(A, B):
    """How often one side wins the match's hit-outs by a big margin (sim only)."""
    arms = [R for R in (A, B) if R]
    print("\n### Duel spread per match (no real per-match reference in the repo)\n")
    head = "| per match | A |" + (" B |" if B else "")
    print(head)
    print("|" + "---|" * (head.count("|") - 1))

    def tm(r):
        return abs(float(r["teams"][0].get("hitouts", 0)) - float(r["teams"][1].get("hitouts", 0)))

    def rm(r):
        return abs(r["teams"][0]["ruck1"][0] - r["teams"][1]["ruck1"][0])

    def top(r):
        h = [float(t.get("hitouts", 0)) for t in r["teams"]]
        return max(h) / sum(h) if sum(h) else 0.5

    def share(R, test):
        return 100 * sum(test(r) for r in R.values()) / len(R)
    print("| mean team hit-out margin |" + "".join(f" {st.mean(tm(r) for r in R.values()):.1f} |" for R in arms))
    for k in RUCK_DUEL:
        print(f"| team hit-out margin {k}+ |" + "".join(f" {share(R, lambda r: tm(r) >= k):.1f}% |" for R in arms))
    for k in RUCK_DUEL[:2]:
        print(f"| number-one rucks {k}+ hit-outs apart |" + "".join(f" {share(R, lambda r: rm(r) >= k):.1f}% |" for R in arms))
    for s in (0.60, 0.65, 0.70):
        print(f"| one side wins {100 * s:.0f}%+ of the match's hit-outs |"
              + "".join(f" {share(R, lambda r: top(r) >= s):.1f}% |" for R in arms))
    print("\nReal per-match hit-out splits are not in the repo; the club spread above is the sourced check.")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", required=True)
    ap.add_argument("--n", type=int, default=0)
    ap.add_argument("--secs", type=int, default=0)
    ap.add_argument("--a", default="base")
    ap.add_argument("--b", default=None)
    o = ap.parse_args()
    real = json.load(open(os.path.join(HERE, "afl_team_rates.json")))["per_team_match"]
    A = load(o.run, "a")
    B = load(o.run, "b") if o.b else {}
    keys = sorted({k for r in A.values() for t in r["teams"] for k in t if isinstance(t[k], (int, float))})
    shown = [k for k in MAP if k in keys] + [k for k in EXTRA if k in keys]
    rate = len(A) * (2 if B else 1) / max(1, o.secs)
    print(f"# Balance run: {len(A)} matches{' x2 arms' if B else ''}, {o.secs}s ({rate:.1f} matches/s)\n")
    print(f"A = `{o.a}`" + (f", B = `{o.b}` (same seeds)" if B else "") + "\n")
    head = "| stat (per team-match) | AFL mean | AFL range | A | mark |"
    if B:
        head += " B | mark | B-A | se | sig |"
    print(head)
    print("|" + "---|" * (head.count("|") - 1))
    outs = []
    for k in shown:
        a = per_match(A, k)
        ma = st.mean(a.values())
        ref = real.get(MAP.get(k, ""), None)

        def mark(v):
            if not ref:
                return "-"
            if ref["min"] <= v <= ref["max"]:
                return "IN"
            return "NEAR" if abs(v - ref["mean"]) <= 2 * ref["sd"] else "OUT"
        line = f"| {k} | {ref['mean']:.1f} | {ref['min']:.1f}-{ref['max']:.1f} |" if ref else f"| {k} | - | - |"
        line += f" {ma:.1f} | {mark(ma)} |"
        if mark(ma) == "OUT":
            outs.append(k)
        if B:
            b = per_match(B, k)
            common = [i for i in a if i in b]
            d = [b[i] - a[i] for i in common]
            mb = st.mean(b[i] for i in common)
            se = st.stdev(d) / math.sqrt(len(d)) if len(d) > 1 else 0.0
            sig = "yes" if se > 0 and abs(st.mean(d)) > 2 * se else ("yes" if se == 0 and st.mean(d) != 0 else "")
            line += f" {mb:.1f} | {mark(mb)} | {st.mean(d):+.2f} | {se:.2f} | {sig} |"
        print(line)
    wet_section(A, B, "--weather wet" in (o.b or "") and "--weather wet" not in o.a)
    role_table(A, B)
    spoils_section(A, B)
    for name, R in (("A", A), ("B", B)):
        if not R:
            continue
        m, h = margins(R)
        n = len(m)
        print(f"\n{name} margins: mean {st.mean(m):.1f}, median {st.median(m):.0f}, "
              f"60+ {100*sum(x >= 60 for x in m)/n:.1f}%, 100+ {100*sum(x >= 100 for x in m)/n:.1f}%, "
              f"draws {100*sum(x == 0 for x in m)/n:.1f}%, home win {100*sum(x > 0 for x in h)/n:.1f}%, home margin {st.mean(h):+.1f} "
              f"(se {st.stdev(h)/math.sqrt(n):.1f})")
    print("\nReal AFL (docs/LEAGUE_BALANCE.md): 60+ about 15.5%, 100+ about 1.9%, home win 59.3%.")
    shots_section(A, B)
    duel_section(A, B)
    ruck_section(A, B)
    margin_tail(A, B)
    role_report(A, B)
    type_report(A, B)
    print(f"\nOUT of real range (A): {', '.join(outs) if outs else 'none'}")


if __name__ == "__main__":
    main()
