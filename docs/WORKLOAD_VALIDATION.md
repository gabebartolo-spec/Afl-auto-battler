# Weekly workload validation

Implementation: ARD-M5-015, explicitly assigned as proposal 4.

## Behaviour

MatchSim records effort only while a player is on the ground. Career processing
applies that effort and recovery once per completed week, after all matches
finish. The same path handles simulated and watched matches, AI clubs, regular
season byes and finals byes. Week identity uses completed finals weeks, including
the Grand Final, whose bracket pointer does not advance.

Workload lowers starting energy and the ceiling for bench/break recovery. It
does not alter permanent ratings or injury rolls. Auto-pick weighs readiness
against ability; named players remain selectable. Existing Out selection gives
a week without senior effort. Offseason rollover clears workload everywhere.

Existing generic player save serialization preserves the new fields. Missing
fields default to fresh; no save version migration is required. Detailed match
effort is not added to the slim historical save records.

## Regression coverage

The new `workload` suite has 32 checks: older player records, accumulated load,
rest, durability/age recovery, idempotence, long-run bounds, energy ceilings,
ground/bench effort, stepped matches with default moment choices, automatic
and manual selection, career save/replay, finals byes, Grand Final processing,
offseason reset and readiness copy at 360 x 800.

Run: `tools/run_tests.sh workload save selection finals`.

## Measurement

Run: `godot --headless --path . --script tools/workload_probe.gd`.

Local Godot 4.6.3 results, seeds 42000–42127:

| Scenario | Result |
|---|---|
| GEE squad at 50 workload versus the same fresh squad, against COL; 128 paired seeds | Home margin changed by -17.96 points on average; standard error 3.45 |
| One regular career season, every club automatically selecting | 587 Fresh, 82 Carrying a load, 0 Needs a break after the final round |
| Highest workload at that season checkpoint | 42.97 of the internal 100-point scale |

The paired experiment is a deliberately loaded **whole-squad** comparison, not
a prediction of the effect of resting one player. Most players stay fresh with
automatic rotations and selection. The high-readiness warning is reserved for
heavier schedules/effort; the synthetic repeated-heavy-game regression reaches
it and a week omitted returns that player to Fresh. No coefficient was changed
to chase a single match result.

## Validation limits

The local runtime is 4.6.3; repository CI specifies 4.7.2. GitHub source access
was available through the connector, but local binary assets could not be
downloaded. Local UI checks therefore used temporary substitute fonts and a
placeholder logo, excluded from the change. They verify readiness presence and
wrapping, not the final typography or native Android presentation. GitHub CI
uses the original assets. A native phone playtest remains outstanding.
