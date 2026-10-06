#!/usr/bin/env python3
"""Proposal only (ARD-M4-016): turn data/weather_by_venue.json's monthly means into
windy and hot shares, with two cut-offs found from the evidence in
docs/research/WEATHER_EVIDENCE.md. No game code reads this.

  python3 tools/balance/weather_cutoffs.py

Model: a match day is windy (or hot) with probability sigmoid((mean - cutoff) / soft),
where `mean` is the venue-month's BoM mean 3pm wind (or mean max temperature) and
`soft` is the width of the transition (day-to-day spread around the monthly mean).
Weights: home games by venue (one per tenant club) and by round count per month.
"""
import json, math, os

HERE = os.path.dirname(os.path.abspath(__file__))
D = json.load(open(os.path.join(HERE, "..", "..", "data", "weather_by_venue.json")))
MONTHS = D["months"]  # Mar..Sep
# 24 rounds: roughly 3 in March, then 4 a month, one block of finals in September.
MONTH_W = {"Mar": 3, "Apr": 4, "May": 4, "Jun": 4, "Jul": 4, "Aug": 4, "Sep": 1}
# Home games per venue: one weight per tenant club (Marvel Stadium is roofed: excluded).
VENUE_W = {v: len([c for c in x["clubs"].split(",")]) for v, x in D["venues"].items()}

WIND_CAP = 0.35   # no venue-month is windy more often than this (the lead, after Geelong)
WET_TARGET = 0.21  # wet matches, league-wide, all games: 335/1,625 [SI]; 630/2,819 [BB]
ROOFED_TENANTS = 5  # Marvel Stadium: five clubs' home games, never wet
SOFT_WIND = 3.0   # km/h of day-to-day spread around the monthly mean 3pm wind
SOFT_TEMP = 3.0   # degrees C around the monthly mean maximum


def sig(x):
    return 1.0 / (1.0 + math.exp(-x))


def weighted(fn):
    num = den = 0.0
    for v, x in D["venues"].items():
        for m in MONTHS:
            w = VENUE_W[v] * MONTH_W[m]
            num += w * fn(x["months"][m])
            den += w
    return num / den


def bisect(f, lo, hi, target):
    for _ in range(60):
        mid = (lo + hi) / 2
        if f(mid) > target:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


def p_wind(mo, c):
    return min(WIND_CAP, sig((mo["wind_3pm_kmh"] - c) / SOFT_WIND))


# 1. Windy: about 14% of outdoor match days (382 of 2,640 dry matches, [OUW]), with every
#    venue-month capped at WIND_CAP, and the cut-off re-fitted so the league still lands there.
wind_cut = bisect(lambda c: weighted(lambda mo: p_wind(mo, c)), 0, 60, 0.14)

# 1b. Wet: a rain day (>= 1 mm) is not a wet match; the ball is only wet if it rains in the
#     three hours of the game. Scale every venue-month's rain-day share by one factor k so
#     wet matches come to WET_TARGET across all games (the roofed ground counts as dry).
outdoor_w = sum(VENUE_W[v] * sum(MONTH_W.values()) for v in D["venues"])
roofed_w = ROOFED_TENANTS * sum(MONTH_W.values())
mean_rain = weighted(lambda mo: mo["rain"])
k = WET_TARGET * (outdoor_w + roofed_w) / outdoor_w / mean_rain

# 2. Hot: the cut-off where most hot days fall in March and April (the Heat Policy was
#    enacted in each of the first four rounds of 2025 [ABC]). Take the lowest cut-off
#    for which at least 70% of the league's hot-day weight is in March and April.
def hot_late_share(c):
    tot = early = 0.0
    for v, x in D["venues"].items():
        for m in MONTHS:
            w = VENUE_W[v] * MONTH_W[m] * sig((x["months"][m]["mean_max_c"] - c) / SOFT_TEMP)
            tot += w
            if m in ("Mar", "Apr"):
                early += w
    return early / tot if tot else 0.0

hot_cut = None
for c10 in range(150, 400):
    c = c10 / 10
    if hot_late_share(c) >= 0.70:
        hot_cut = c
        break
hot_overall = weighted(lambda mo: sig((mo["mean_max_c"] - hot_cut) / SOFT_TEMP))

print("Windy cut-off: mean 3pm wind %.1f km/h (soft %.1f, cap %d%%); league windy share %.1f%%"
      % (wind_cut, SOFT_WIND, 100 * WIND_CAP, 100 * weighted(lambda mo: p_wind(mo, wind_cut))))
print("Wet factor k = %.3f on the BoM rain-day share (outdoor wet share %.1f%%, all games incl. the roofed ground %.1f%%)"
      % (k, 100 * k * mean_rain, 100 * k * mean_rain * outdoor_w / (outdoor_w + roofed_w)))
print("Hot cut-off: mean max %.1f C (soft %.1f); league hot share %.1f%%, March-April share of hot days %.0f%%"
      % (hot_cut, SOFT_TEMP, 100 * hot_overall, 100 * hot_late_share(hot_cut)))
print()
hdr = "| venue | " + " | ".join(MONTHS) + " |"
print("Windy share by venue and month (%)")
print(hdr); print("|---|" + "---|" * len(MONTHS))
for v, x in D["venues"].items():
    print("| %s | " % v + " | ".join("%d" % round(100 * p_wind(x["months"][m], wind_cut)) for m in MONTHS) + " |")
print()
print("Hot share by venue and month (%)")
print(hdr); print("|---|" + "---|" * len(MONTHS))
for v, x in D["venues"].items():
    print("| %s | " % v + " | ".join("%d" % round(100 * sig((x["months"][m]["mean_max_c"] - hot_cut) / SOFT_TEMP)) for m in MONTHS) + " |")
print()
print("Wet share by venue and month (%): k times the BoM rain days over days in the month")
print(hdr); print("|---|" + "---|" * len(MONTHS))
for v, x in D["venues"].items():
    print("| %s | " % v + " | ".join("%d" % round(100 * k * x["months"][m]["rain"]) for m in MONTHS) + " |")
