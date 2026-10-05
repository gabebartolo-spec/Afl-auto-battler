# Claude game-development playbook — proposed procedures

Prepared 6 October 2026. These are reviewable examples for the interview, not installed instructions or approved roadmap items. Adapt them to the existing AFL project rules and the assigned task. They do not authorise additional features, new subscriptions or a pipeline replacement.

The companion research report explains the sources and limitations. The procedures below are my proposed synthesis. Their purpose is to let Claude spend more of its work on the game and less on guessing what to change or how to prove it.

## 1. A feature assignment that ends in a playable result

Keep the assignment brief enough to read at once. It should contain:

- **Outcome:** what the player will experience, with one concrete example.
- **Scope:** what is assigned, the relevant existing behaviour, and any approved art reference.
- **Location:** engine/version, branch/worktree, relevant scene or system and the owning agent.
- **Contracts:** data, resource or signal relationships the change must preserve.
- **Evidence:** the smallest set of checks that would establish the outcome.
- **Handoff:** changed files, decisions, results and unresolved issues.

Example assignment: “Make the existing moment-choice screen respond correctly when an overlay is visible. Preserve the approved layout. Reproduce the missed tap, identify where the input is consumed, fix the cause and demonstrate selection through the actual input route. Verify the choice applies once and the screen exits normally. Include the relevant portrait capture and required project checks.”

That example supplies an investigation target. It does not predetermine whether the bug is a hitbox, overlay, signal or state problem.

For implementation, Claude should inspect the existing path before designing a parallel one. If the requested behaviour already exists, show where it exists and narrow the task to the demonstrated gap. Resolve engine-version uncertainty before copying a remembered API.

## 2. A small completion record

Use one compact record per substantial change:

| Field | Contents |
|---|---|
| Identity | Commit or relevant uncommitted changes; engine version; project instance |
| Scenario | Seed/setup, starting state, viewport and relevant platform |
| Interaction | Actions actually delivered; distinguish staged setup from tested input |
| Result | Observed state change and visible outcome |
| Checks | Required checks run and their actual results; remaining checks clearly named |
| Visual evidence | Still or short clip where relevant; active asset/system identity |
| Limitations | What was not exercised, unavailable target evidence, unresolved concerns |

Avoid huge console dumps in the handoff. Preserve full logs and captures on disk, with links and a concise relevant excerpt. “No errors” should identify which log/run was inspected. “Looks good” should identify the image or clip being judged.

Use pass, fail and insufficient evidence. An unavailable device check is not a pass, and a missing clip is not automatically a gameplay defect.

## 3. A debugging loop that changes direction when needed

Start with a reproduction, expected behaviour and observed behaviour. Identify the last known good version when available. Classify the failure sufficiently to choose evidence: input, gameplay state, resource loading, timing, rendering, performance or persistence.

Investigate one plausible cause using relevant evidence. Apply a narrow fix and rerun the reproduction. If a second or third similar patch fails, pause that strategy and change the evidence path:

- Input: inspect event delivery, control bounds, overlays and consumption.
- Resource: identify the loaded path/version and any fallback.
- Gameplay: record the transition and its inputs, not only the final score.
- Animation: inspect the active clip/state and render the affected interval.
- Performance: measure the suspected cost in a representative run.
- Save: isolate the relevant data location and exercise reload or failure recovery.

A minimal scene or last-good comparison can be more useful than another speculative rewrite. Escalate reasoning effort when the evidence reveals a genuinely difficult problem. Request focused review when another perspective is likely to help.

The suggested repeated-failure trigger is not a task timeout. Persist with difficult work, but make each attempt answer a new question rather than rephrasing the same guess.

## 4. A motion review packet

Provide the intended movement in plain language, the actor/system under review and the approved reference where applicable. Capture a short sequence at actual game scale that includes the transition into the movement, its normal cycle and its exit or recovery where relevant.

Record that the intended resource loaded and advanced. Flag a relevant fallback or disabled feature. Keep render time and sampled state aligned. Do not let a capture driver's label stand in for the game's actual state.

Reviewers should describe concrete defects and locate their evidence: locked arms, insufficient torso contribution, foot sliding, an abrupt pose jump, clipping or unclear contact. They should distinguish visual taste from broken execution.

A contact sheet helps find the affected interval; use readable original frames and the continuous clip to assess it. Add higher-rate sampling or event timing where sparse frames could miss the defect. Label staged/offline output. Performance claims require a comparable real-time run.

Calibrate a new checker once against a representative known broken case. If it passes missing or fallback animation, improve the checker before trusting future approvals.

## 5. A real-interaction pilot

Pick one short AFL flow with meaningful state changes. For example: reach a match, encounter a moment, choose an option, continue and verify the persisted consequence.

Setup can seed the career or stage the expensive match condition. Once the tested interaction begins, deliver the appropriate input through the runtime input path, observe receipt and verify the effect. Keep a callback-only unit check as a separate layer where useful.

Include one relevant failure case: an obscuring overlay, a repeated tap or an unavailable option. The choice depends on the feature being tested; do not build a giant input matrix before proving the pilot useful.

Record desktop simulation and target-device touch separately. Review the actual player screen, not just a cropped illustration detached from the UI flow.

## 6. An editor/runtime ownership handoff

Before an agent drives an editor or game instance, identify:

- Worktree and project path.
- Editor/runtime instance and connection or port.
- Owner and permitted mutations.
- Test save/data location and generated-output destination.
- How that instance is started, stopped and recovered.

If another agent already owns a single-client bridge, the next agent waits for that resource, uses an isolated instance or continues useful work without it. It must not take over a healthy connection or terminate unrelated processes.

For shared assets or contracts, communicate the actionable change once: affected resources, regeneration required and compatibility expectation. Handoffs should let another agent continue without rereading the entire conversation.

## 7. An asset production packet

Define the asset's role, approved style and target scene. Include dimensions, scale/pivot, naming, animation layout, relevant shader inputs and the expected metadata.

Build a representative sample first. Check it in Godot alongside the actual actor, camera, UI and lighting. Review the generated resource identity so a stale import cannot masquerade as the new result. Expand production only after that sample meets the intended outcome.

For the existing AFL pipeline, retain MPFB/Blender and atlas automation unless a specific bottleneck justifies a change. Use incremental regeneration, stable manifests and versioned parameters where the interview approves them. Existing validation remains the starting point.

For scene dressing, use a reusable component set and scene-specific placement. Preview background and foreground elements with the full composition, including the text area and audience where appropriate. The objective is the already-requested coherent scene, not asset volume.

For audio, separate file/event/level checks from actual listening. Confirm output format, timing and mix behaviour technically; let a supported listening process or the director assess repetition, clarity and feel. Do not claim the agent heard a result based solely on a waveform or successful import.

## 8. A seeded investigation packet

For a simulation or balance question, preserve the scenario, seed set, engine/build and comparison conditions. Define the question before running a large audit: whether a change affects scoring, a tactical pattern, availability or another assigned outcome.

Use paired before/after scenarios where practical, with enough variation to avoid judging a lucky match. Report relevant distributions, exceptions and uncertainty. Keep simulation correctness separate from whether the result feels like good football.

Use the existing test/audit infrastructure. A future extensive content-complete balance audit and a narrow regression investigation have different purposes; neither should become a token-heavy conversation for every individual match.

## 9. A packaged-build review packet

Identify the exported build and target environment. Select a short smoke flow appropriate to the change: launch, load, navigate, play, save and return/reload as needed.

Check resources and behaviour in the export rather than assuming editor success transfers. Include device input, viewport and performance evidence when they matter. Keep capture drivers, mock data and editor bridges out of the required release path.

If target testing is unavailable, record the gap explicitly and retain the editor evidence. Do not invent a target pass. This should help the director judge readiness without reading a technical console.

## 10. A workforce comparison that respects your subscription

Compare a small selection of normal game tasks across candidate settings over time. Keep scope and tools sufficiently comparable. Record:

- Whether the result was accepted and why.
- Escaped defects, retries and reviewer/author rework.
- Elapsed work time and tool/context activity.
- Observed Max allowance changes where available, with attribution limitations.
- Whether the task needed architecture, bounded implementation or visual judgment.

Use those observations to route future work. Do not convert cached input totals into a fictional subscription bill or choose a model from one demo. Preserve useful cached context during active work; renew sessions at sensible task boundaries with durable handoffs.

The first experiment should be small enough to finish during ordinary development. Retain a procedure only if it produces clearer decisions, fewer failed attempts or better accepted game changes.

## Interview starting point

Discuss C1 in the research report first: proportionate proof from the running game, starting with one existing AFL flow. Decide its scope before discussing the optional editor bridge or other tooling. No procedure here should be copied into production instructions before the interview approves it.
