# How weather changes AFL football: evidence and conclusions (2026-10-06)

The director asked the lead for its own research and conclusions ("do your own research into how weather impacts footy and draw your own conclusions"). Every number below names its source. Measures and samples differ between sources, so treat magnitudes as ranges to calibrate against, not exact targets.

## How often

- **Poor weather:** about 1 game in 5. That's 335 of 1,625 in 2012–19 [SI], and 630 of 2,819 weather-tagged games wet in 2008–23 [BB].
- **Rain by venue** [BB]: GMHBA Stadium (Geelong) 37.6%, MCG 28.6%, SCG 25.7%, Gold Coast 20.6%, Gabba 20.5%.
  - Perth is drier [ABC].
  - Docklands' roof is closed or treated as dry [ABC][BB].
  - Sydney and outdoor Victorian sides see rain in about 1 game in 6 [ABC].
- **Wind of 20 km/h or more:** 382 of 2,640 dry matches, about 14% [OUW].
- **Heat over 25°C:** clusters early in the season, more so as seasons start in March. The AFL Heat Policy was enacted in each of the first four rounds of 2025 [ABC].

## Wet (rain falling)

| Measure (match totals, 2022–25) [ABC] | Dry | Wet | Change |
|---|---|---|---|
| Marks | 185 | 161 | −13% |
| Marks on the lead | 14 | 11 | −21% |
| Marks inside 50 | 24 | 20 | −14% |
| Contested marks | 20 | 18 | −10% |
| Contested possessions | 266 | 284 | +7% |
| Ground ball gets | 180 | 196 | +9% |
| Tackles | 118 | 132 | +12% |
| Turnovers | 132 | 147 | +11% |
| Clangers | 114 | 125 | +9% |
| One-percenters | 90 | 104 | +15% |
| Kicks / handballs | 427 / 291 | 428 / 288 | 0% / −1% |
| Shots at goal | 50 | 48 | −4% |

- **Scoring:** −10.7 points a game overall [BB]. The modern era is −4.6 (2016–23), against −8.9 (2008–15) [BB]. Another source has 177 against 164 [SI].
- **Accuracy:** −1 point (53.0% to 52.0%) [BB]; −2 points (49.3% to 47.3%) [SI].
- **The kick-to-handball ratio does not change** [ABC][SI]. "Boot it in the wet" is a myth.
- **Contested ball matters more.** Winning the contested possession count wins 64% of games when dry and 69% when wet. Winning forward-50 ground balls wins 61% against 72% [ABC].
- **Corridor use from defence drops about 20%,** and play runs in straighter lines with positions held more [ABC].
- **Margins:** about 4 points tighter [BB]. But favourites won slightly more often in poor weather, 75.6% against 71.8% [SI]. Read it as: better sides adapt; rain isn't a lottery.
- **Players and teams differ.** Some players average about 2 coaches' votes more in poor weather [SI]. Geelong win 75.9% of their wet games [BB], and Collingwood 92% since 2022 [ABC].

## Windy (20 km/h or more)

- **A threshold, not a slope.** Under 20 km/h there's no measurable effect. At 20 km/h and above, about −5.2 combined points (t = −3.44, n = 382) [OUW].
- **Ground matters.** The MCG bowl shows little effect; open grounds (Perth, the SCG) show large effects on small samples [OUW].
- **Play:** far fewer marks, more territory gained, more turnovers, and targets harder to hit by hand or foot [ABC]. A breeze down the ground favours one end, the "five-goal breeze" [AFLLab].

## Hot (over 25°C) and cold (under 10°C)

- **Hot** [ABC]:
  - bounces +11%, shots +3%, goals +2%, contested marks −3%;
  - freer-flowing, more uncontested ball, fewer stoppages;
  - but fatigue and cramp, with the AFL Heat Policy's longer breaks and extra water runners.
- **Cold** [ABC]: goals −8%, contested marks +14%, tackles +8%. Often comes with dew, which plays like a light wet.

## Conclusions for ARD

1. **Four conditions** (the director's choice): perfect day (the dry, calm baseline), wet, windy, hot. Docklands is always a perfect day.
2. **Likelihood by venue and month,** from the frequencies above.
3. **Effects on existing MatchSim keys,** calibrated to the ranges above:
   - wet: marks down, contested ball and stoppages up, turnovers and clangers up, gain down, a small accuracy drop;
   - windy: marks down, turnovers up, accuracy down, and a breeze end per quarter;
   - hot: uncontested ball and pace up early, with fatigue harder late.
4. **Gameplans suit conditions:**
   - wet favours Win contest and Defensive press, and hurts Attack corridor;
   - windy favours Controlled tempo;
   - hot favours Attack corridor, and Defensive press fades;
   - a perfect day favours Attack corridor and Controlled tempo.
5. **A visible "Wet-weather player" trait** (the director's choice): cleaner hands and smarter use in the wet only.
6. **The forecast is known in the week** (the director's choice). It's a fact on the Hub, not advice.

## Sources

- [ABC] Atkinson & Lawson, "How 'the winter game' Australian Rules football adapts to rain, cold and heat", ABC News, 25 June 2025. Open-Meteo, BoM and fitzRoy data, 2022–25.
- [SI] Elliott, "How Different Weather Conditions Affect AFL Performance", Stats Insider, 8 July 2020. fitzRoy data, 2012–19.
- [BB] "What rain really does to AFL football — 630 wet games measured", betbetter.world. 2008–23, CC BY 4.0.
- [OUW] "AFL Wind and Scoring: what strong wind costs a total", OverUnderWeather Research Desk, 2026. 2,640 dry matches, 2004–26.
- [AFLLab] "Environmental factors affecting AFL outcomes: the weather, part 2", The AFL Lab, August 2018.
