#!/usr/bin/env python3
"""How often the weather turns during a real AFL match (TODO row 160): the odds
Weather.turn_chance states in the forecast.

Director, 2026-11-12: "Yes, at a break": the weather may change at most once a
match, announced at a break, and the forecast states the odds.

Source: Open-Meteo's historical weather API (archive-api.open-meteo.com, CC BY
4.0, no key), hourly rain, 10 m wind and 2 m temperature at each outdoor AFL
ground, local time, 2016-2025, mid-March to September (the same source as
tools/balance/build_weather_rates.py).

Method:
- Match windows: every Saturday of the season at the three usual starts (1:15 pm,
  4:15 pm, 7:30 pm local), three hours each, at every ground of
  data/weather_by_venue.json that has a station today.
- Each half of the window (an hour and a half) is classified in the game's own
  order (Weather.condition: rain first, then wind on a dry half, then heat on a
  still one) with the thresholds of afl_weather_rates.json, the rain halved to the
  half's share: wet 0.15 mm or more, windy a mean 20 km/h or more, hot a mean
  25 C or more (day starts only).
- A match turns when its second half's condition differs from its first half's.
  The share that turn, by condition at the start, is the chance the forecast
  states (TURN_CHANCE in scripts/sim/Weather.gd); where it turns to is drawn from
  the ground's own month (Weather.chances), as any other day's weather is.

    python3 tools/balance/weather_turns.py            # fetch (cached) and print
    python3 tools/balance/weather_turns.py --offline  # cache only

Pages are cached in data/cache/weather_turns/ (git-ignored).
"""
from __future__ import annotations

import argparse
import json
import os
import time
import urllib.request
from datetime import date, timedelta

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, "..", "..", "data", "cache", "weather_turns")
# The game's grounds (data/weather_by_venue.json) -> (latitude, longitude).
GROUNDS = {
    "MCG": (-37.8200, 144.9834), "SCG": (-33.8917, 151.2247),
    "Adelaide Oval": (-34.9156, 138.5961), "The Gabba": (-27.4858, 153.0381),
    "Optus Stadium": (-31.9512, 115.8890), "GMHBA Stadium": (-38.1580, 144.3546),
    "People First Stadium": (-28.0063, 153.3666), "Engie Stadium": (-33.8434, 151.0670),
    "Bellerive Oval": (-42.8770, 147.3730), "Manuka Oval": (-35.3181, 149.1347),
}
YEARS = [y for y in range(2016, 2026) if y != 2020]
STARTS = [13.25, 16.25, 19.5]
WET_HALF_MM = 0.15
WIND_KMH = 20.0
HOT_C = 25.0
MONTHS = ["Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep"]


def fetch(venue: str, year: int, offline: bool) -> dict:
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, "%s_%d.json" % (venue.replace(" ", "_").lower(), year))
    if not os.path.exists(path):
        if offline:
            raise SystemExit("not cached: " + path)
        lat, lon = GROUNDS[venue]
        url = ("https://archive-api.open-meteo.com/v1/archive?latitude=%.4f&longitude=%.4f"
               "&start_date=%d-03-10&end_date=%d-09-30"
               "&hourly=precipitation,wind_speed_10m,temperature_2m&timezone=auto" % (lat, lon, year, year))
        body = ""
        for attempt in range(5):
            try:
                with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "weather-turns-research"}), timeout=60) as r:
                    body = r.read().decode("utf-8")
                break
            except OSError:
                time.sleep(5.0 * (attempt + 1))
        if body == "":
            raise SystemExit("could not fetch " + url)
        with open(path, "w", encoding="utf-8") as f:
            f.write(body)
        time.sleep(1.0)
    with open(path, encoding="utf-8") as f:
        h = json.load(f)["hourly"]
    return {t: (h["precipitation"][i] or 0.0, h["wind_speed_10m"][i] or 0.0, h["temperature_2m"][i] or 0.0)
            for i, t in enumerate(h["time"])}


def half(wx: dict, d: date, hours: list, weights: list, day: bool) -> str:
    """The game's condition over one half: hourly rain (the hour before each stamp)
    weighted by how much of that hour the half covers; wind and heat as means."""
    rain, wind, temp = 0.0, [], []
    for hr, w in zip(hours, weights):
        row = wx.get("%sT%02d:00" % (d.isoformat(), hr))
        if row is None:
            return ""
        rain += row[0] * w
        wind.append(row[1])
        temp.append(row[2])
    if rain >= WET_HALF_MM:
        return "wet"
    if sum(wind) / len(wind) >= WIND_KMH:
        return "windy"
    if day and sum(temp) / len(temp) >= HOT_C:
        return "hot"
    return "perfect"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--offline", action="store_true")
    a = ap.parse_args()
    by_start: dict = {}
    by_month: dict = {}
    to: dict = {}
    n = 0
    for venue in GROUNDS:
        for y in YEARS:
            wx = fetch(venue, y, a.offline)
            d = date(y, 3, 14)
            while d.weekday() != 5:
                d += timedelta(days=1)
            while d.month <= 9:
                for s in STARTS:
                    h0 = int(s)
                    f = s - h0
                    # Rain stamped at hour H fell in the hour before it.
                    first = half(wx, d, [h0 + 1, h0 + 2], [1.0 - f, 0.5 + f], s < 17)
                    second = half(wx, d, [h0 + 2, h0 + 3, h0 + 4], [0.5 - f if f < 0.5 else 0.0, 1.0, f], s < 17)
                    if first == "" or second == "":
                        continue
                    n += 1
                    turned = first != second
                    st = by_start.setdefault(first, [0, 0])
                    st[0] += 1
                    st[1] += int(turned)
                    mo = by_month.setdefault(MONTHS[d.month - 3], [0, 0])
                    mo[0] += 1
                    mo[1] += int(turned)
                    if turned:
                        to.setdefault(first, {}).setdefault(second, 0)
                        to[first][second] += 1
                d += timedelta(days=7)
    total = sum(v[1] for v in by_start.values())
    print("match windows: %d, turned: %d (%.1f%%)" % (n, total, 100.0 * total / n))
    print("by the start's condition (turned / windows):")
    for k in ["perfect", "wet", "windy", "hot"]:
        v = by_start.get(k, [0, 0])
        if v[0]:
            print("  %-8s %5d / %5d = %.3f   to %s" % (k, v[1], v[0], v[1] / v[0], to.get(k, {})))
    print("by month:")
    for k in MONTHS:
        v = by_month.get(k, [0, 0])
        if v[0]:
            print("  %s %5d / %5d = %.3f" % (k, v[1], v[0], v[1] / v[0]))


if __name__ == "__main__":
    main()
