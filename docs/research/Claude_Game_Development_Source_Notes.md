# Claude game-development source register

Research cut-off: 6 October 2026. This register contains curated research entries, not a claim that every linked page was read in full or that every tool was tested. Papers are grouped once even when both abstract and HTML were consulted. Repository files, issue reports and articles can share an author or project; they are distinct evidence artifacts, not independent endorsements.

Reading labels: **Article** = substantive article body read; **Passages** = relevant body sections read; **Source** = selected source code/document or change record directly inspected; **Abstract** = abstract-level review only; **Excerpt** = retrieved substantive excerpt; **Carried** = direct reading from the preceding workforce research, reused explicitly. Reddit entries mean the accessible post and selected comments, not every comment or linked video. No games, integrations or research benchmarks were independently reproduced.

## Official Claude guidance applied to game work

1. [Claude Code best practices](https://code.claude.com/docs/en/best-practices) — **Passages**. Verifiable outcomes and feedback.
2. [Project memory and scoped rules](https://code.claude.com/docs/en/memory) — **Passages**. Automatic loading; avoid full-roadmap imports.
3. [Skills](https://code.claude.com/docs/en/skills) — **Passages**. On-demand procedural material.
4. [Usage and cost reporting](https://code.claude.com/docs/en/costs) — **Passages**. Local reporting, caching and plan attribution limits.
5. [Hooks guide](https://code.claude.com/docs/en/hooks-guide) — **Passages**. Bounded checks and loop guards.
6. [Evaluating agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) — **Passages**. Environmental outcomes versus agent assertions.
7. [Context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — **Passages**. Selective context; method background.
8. [Long-running harness experiment](https://www.anthropic.com/engineering/harness-design-long-running-apps) — **Passages**. Web game-maker example; broader scope and spending confound comparisons.
9. [Opus 5.5 changes](https://platform.claude.com/docs/en/models/opus-5-5/whats-new-opus-5-5) — **Passages**. Adaptive thinking and documented default.
10. [Sonnet 5.5 introduction](https://www.anthropic.com/claude-sonnet-5-5) — **Passages**. Effort tradeoffs; not a game-specific Max benchmark.
11. [Effort parameter](https://platform.claude.com/docs/en/build-with-claude/effort) — **Carried**. Earlier direct reading; supporting workforce context.
12. [Sonnet 5.5 prompting](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5) — **Carried**. Earlier direct reading; model guidance.
13. [Agent teams](https://code.claude.com/docs/en/agent-teams) — **Carried**. Earlier direct reading; coordination overhead context.
14. [Subagents](https://code.claude.com/docs/en/sub-agents) — **Carried**. Earlier direct reading; no new agents spawned for this pass.
15. [Cross-session messaging](https://code.claude.com/docs/en/cross-session-messaging) — **Carried**. Earlier direct reading; existing workforce communication context.

## Engine documentation: what Claude must verify

16. [Godot command line](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html) — **Passages**. Flags, headless behaviour and unknown-argument caveat.
17. [Godot Movie Maker](https://docs.godotengine.org/en/stable/tutorials/animation/creating_movies.html) — **Passages**. Offline capture versus real-time performance.
18. [Godot debugger](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/debugger_panel.html) — **Passages**. Errors, stack and runtime state.
19. [Godot profiler](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html) — **Passages**. Measured bottlenecks.
20. [Godot random numbers](https://docs.godotengine.org/en/stable/tutorials/math/random_number_generation.html) — **Passages**. Seeds, streams and replay assumptions.
21. [Godot scene organisation](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html) — **Passages**. Dependencies and signals.
22. [Godot ClassDB](https://docs.godotengine.org/en/stable/classes/class_classdb.html) — **Passages**. Ground API assumptions.
23. [Godot Input](https://docs.godotengine.org/en/stable/classes/class_input.html) — **Passages**. Action state versus event delivery.
24. [Godot Performance](https://docs.godotengine.org/en/stable/classes/class_performance.html) — **Passages**. Monitor availability and timing caveats.
25. [Godot input-event flow](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html) — **Passages**. Viewport and GUI propagation.
26. [Godot pausing](https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_games.html) — **Passages**. Process modes and signals during pause.
27. [Godot optimisation](https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html) — **Passages**. Continuous, intermittent and loading costs.
28. [Godot Android export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) — **Passages**. Export toolchain context; not a device test.
29. [Unity Claude Code announcement](https://unity.com/blog/unity-plugin-for-claude-code) — **Passages**. Current first-party editor access.
30. [Unity plugin documentation](https://docs.unity.com/en-us/ai/unity-plugin/about-unity-plugin) — **Excerpt**. Official capabilities excerpt; candidate comparison.
31. [Epic Unreal MCP](https://dev.epicgames.com/documentation/unreal-engine/unreal-mcp-in-unreal-editor) — **Passages**. Serial game-thread requests and local editor access.
32. [Epic Gauntlet](https://dev.epicgames.com/documentation/unreal-engine/gauntlet-automation-framework-overview-in-unreal-engine) — **Passages**. Packaged runtime testing concept; not proposed for Godot installation.

## Game-development research papers

33. [SWE-Game](https://arxiv.org/html/2609.33678v1) — **Passages**. Godot tasks, evaluator methods and limitations; tested Opus 5 is not Opus 5.5.
34. [GameDevBench](https://arxiv.org/html/2602.11103v2) — **Passages**. Multimodal development and visual feedback.
35. [GameLogicBench](https://arxiv.org/html/2609.21562v1) — **Passages**. Gameplay trajectories and evaluator negative controls.
36. [GameXpertBench](https://arxiv.org/abs/2608.21833) — **Abstract**. Generation, repair and optimisation tracks; supporting scope only.
37. [GUI Agents for Continual Game Generation](https://arxiv.org/html/2605.28258v1) — **Passages**. Browser playtest loop; native-engine and fun limits.
38. [GameCraft-Bench](https://arxiv.org/abs/2606.17861) — **Abstract**. Complete Godot artifacts and interaction-grounded evaluation.
39. [GameEngineBench](https://arxiv.org/abs/2607.03525) — **Abstract**. Real Unreal C++ runtime implementation tasks.

## Developer tools and implementation evidence

40. [Caruso's Godot game harness article](https://www.jonathancaruso.com/blog/getting-claude-code-to-build-games-in-godot) — **Article**. Small demonstration; older engine comparison requires updating.
41. [Claireon studio account](https://believer.gg/introducing-claireon-our-open-source-unreal-plugin-for-agentic-workflows/) — **Article**. Production developer's claims; selective tool discovery and crash/worktree routing.
42. [Claireon repository](https://github.com/believer-oss/claireon) — **Passages**. Implementation overview; not independently installed or benchmarked.
43. [Godot runtime MCP repository](https://github.com/satelliteoflove/godot-mcp) — **Passages**. Runtime observation, input and time controls.
44. [Runtime bridge Claude setup source](https://github.com/satelliteoflove/godot-mcp/blob/c7328651d6d64cae541d79c398e3cc1ca1f4f9f4/docs/claude-code-setup.md) — **Source**. Version-pinned selected setup and operation passages.
45. [Runtime time-command source](https://github.com/satelliteoflove/godot-mcp/blob/c7328651d6d64cae541d79c398e3cc1ca1f4f9f4/godot/addons/godot_mcp/commands/game_time_commands.gd) — **Source**. Selected relay and timeout code; not end-to-end runtime validation.
46. [Bridge client displacement report](https://github.com/satelliteoflove/godot-mcp/issues/237) — **Passages**. Closed report; follow the merged fix rather than repeat a stale diagnosis.
47. [Bridge incumbent-connection fix](https://github.com/satelliteoflove/godot-mcp/pull/264) — **Source**. Merged change and test evidence; still single-client.
48. [GodotForge](https://github.com/Tann2019/godot-mcp-server) — **Passages**. Broad tooling alternative; README capabilities are author claims.
49. [Minimal Godot MCP](https://github.com/ryanmazzolini/minimal-godot-mcp) — **Passages**. LSP diagnostics and debugger connection.
50. [Beckett Godot MCP](https://github.com/beckettlab/beckett-godot-mcp) — **Passages**. Free/paid feature boundary; paid edition not recommended.
51. [Coplay Unity MCP](https://github.com/CoplayDev/unity-mcp) — **Passages**. Tooling overview, alternative-engine context.
52. [Unity PlayMode test hang report](https://github.com/CoplayDev/unity-mcp/issues/1390) — **Passages**. Specific Linux/Vulkan report, not a universal failure.
53. [Game-review plugin](https://github.com/ProtoForgeSystems/protoforge-claude-plugin-game-review) — **Passages**. Visual verification design; not installed.
54. [Frame-review agent source](https://github.com/ProtoForgeSystems/protoforge-claude-plugin-game-review/blob/6b52b92cf5b2583462994f7c1710b93dd1317eec/agents/frame-review.md) — **Source**. Reviewer requirements; fixed model and forced binary verdict not adopted.
55. [Godot movie-driver source](https://github.com/ProtoForgeSystems/protoforge-claude-plugin-game-review/blob/6b52b92cf5b2583462994f7c1710b93dd1317eec/skills/godot-movie-driver/SKILL.md) — **Source**. State/time/footage alignment and full-resolution review.
56. [BMAD game module](https://github.com/bmad-code-org/bmad-module-game-dev-studio) — **Passages**. Planning and workflow boundaries; not full autonomous game production.
57. [Game Studios workflow guide](https://github.com/AliVertigo/claude-code-game-studios/blob/main/docs/WORKFLOW-GUIDE.md) — **Passages**. Engine pinning and routing; selected passages of a long guide.
58. [Game-development skill collection](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) — **Passages**. Specialised guidance examples; no bulk installation.
59. [LibreGameDev pack](https://github.com/HermeticOrmus/LibreGameDev-Claude-Code) — **Passages**. Twenty-plugin pack; review source rather than infer efficiency from size.

## Game-specific Reddit discussions

Developer and community anecdotes. Promotional posts are marked. Dates and model generations vary; conflicting claims were checked against current primary documentation where relevant.

60. [I have built this mini demo game with an MCP tools for Godot, just one prompt](https://www.reddit.com/r/ClaudeAI/comments/1rubdk5/i_have_built_this_mini_demo_game_with_an_mcp/) — **Post/comments**. Godot MCP prototype; builder promotion, not a shipped-game benchmark.
61. [Two Claude models built the same mine cart game in Godot](https://www.reddit.com/r/aigamedev/comments/1wx2k3a/two_claude_models_built_the_same_mine_cart_game/) — **Post/comments**. Single Opus/Sonnet 5.5 comparison; qualitative, uncontrolled.
62. [Gamedev with Claude Code - A postmortem](https://www.reddit.com/r/ClaudeCode/comments/1ryqig5/gamedev_with_claude_code_a_postmortem/) — **Post/comments**. Mobile postmortem; experienced developer, render and direction lessons.
63. [What I learned building a full game with Claude Code over 6 months (tips for long-term projects)](https://www.reddit.com/r/ClaudeCode/comments/1qknr1v/what_i_learned_building_a_full_game_with_claude/) — **Post/comments**. Close football-manager/Max 5x case; older instruction-loading advice needs updating.
64. [I just published my first game, a roguelite platformer built with Claude Code, Pixellab & Godot. Here's what I learned about AI development and agent-switching](https://www.reddit.com/r/aigamedev/comments/1sd9b4y/i_just_published_my_first_game_a_roguelite/) — **Post/comments**. Roguelite and agent-switching experience; not a controlled model comparison.
65. [I gave Claude a detailed game spec and let it work autonomously: here’s what it built](https://www.reddit.com/r/ClaudeAI/comments/1wqo6o5/i_gave_claude_a_detailed_game_spec_and_let_it/) — **Post/comments**. Detailed-spec Godot prototype; generated line count is not accepted quality.
66. [Claireon - Our game studio's production MCP server for Unreal Editor (open-source/MIT)](https://www.reddit.com/r/unrealengine/comments/1u7hz7g/claireon_our_game_studios_production_mcp_server/) — **Post/comments**. Same Claireon developer as the studio article; not independent corroboration.
67. [My Journey: From Zero Coding Skills to Building a Unity Game with Claude Code (WIP)](https://www.reddit.com/r/ClaudeAI/comments/1n2qcim/my_journey_from_zero_coding_skills_to_building_a/) — **Post/comments**. Older Unity WIP; limited scope and repeated debugging.
68. [I built a Steam game in 10 days with Claude Code — here's what actually happened behind the scenes](https://www.reddit.com/r/ClaudeAI/comments/1s7mfil/i_built_a_steam_game_in_10_days_with_claude_code/) — **Post/comments**. Steam timeline claim; author also used purchased assets.
69. [Claude Game Development](https://www.reddit.com/r/ClaudeCode/comments/1twuadf/claude_game_development/) — **Post/comments**. Plain-language game direction and iteration.
70. [Claude is genuinely good at game dev now, It just needed the right context loaded in](https://www.reddit.com/r/ClaudeAI/comments/1uhji5e/claude_is_genuinely_good_at_game_dev_now_it_just/) — **Post/comments**. Skill-pack promotion; useful reports of duplicate/inconsistent mechanics.
71. [Claude Code can't watch my game, and one day it passed a broken build three times. Here's how it checks its work now.](https://www.reddit.com/r/ClaudeCode/comments/1wtuunu/claude_code_cant_watch_my_game_and_one_day_it/) — **Post/comments**. Fallback-animation verification failure; linked implementation inspected.
72. [Anyone here using Claude for game development?](https://www.reddit.com/r/ClaudeCode/comments/1pqbu3l/anyone_here_using_claude_for_game_development/) — **Post/comments**. Mixed developer experiences; older models and different engines.
73. [creating a game using claude code](https://www.reddit.com/r/claude/comments/1vzp8fd/creating_a_game_using_claude_code/) — **Post/comments**. Cost and context discussion; unverified recommendations.
74. [What's the current workflow today for game development?](https://www.reddit.com/r/ClaudeCode/comments/1uaq22l/whats_the_current_workflow_today_for_game/) — **Post/comments**. Unity workflow/effort discussion; mixed subscriptions and paid tool suggestions.
75. [I directed a god game from my phone by complaining at Claude. No engine, no art or sound files: it draws every sprite and composes the music live.](https://www.reddit.com/r/ClaudeCode/comments/1wxpk01/i_directed_a_god_game_from_my_phone_by/) — **Post/comments**. Procedural browser demo; audio required human listening.
76. [Whats the "best" game engine to use with Claude code?](https://www.reddit.com/r/ClaudeCode/comments/1ufh8uh/whats_the_best_game_engine_to_use_with_claude_code/) — **Post/comments**. Engine-choice opinions; superseded where current official integration docs differ.
77. [Used Claude Code to write a real-time blur shader for Unity HDRP — full iterative workflow](https://www.reddit.com/r/ClaudeCode/comments/1s5jp9q/used_claude_code_to_write_a_realtime_blur_shader/) — **Post/comments**. HDRP shader work; rendering correctness beyond compilation.
78. [Game dev with Fable 5 is actually crazy](https://www.reddit.com/r/claude/comments/1vq06o8/game_dev_with_fable_5_is_actually_crazy/) — **Post/comments**. Unity prototype with generated/manual/paid asset steps; not fully autonomous.
79. [Can you realistically do game development on a $20 Claude Code?](https://www.reddit.com/r/aigamedev/comments/1w3k8x7/can_you_realistically_do_game_development_on_a_20/) — **Post/comments**. Budget question; anecdotes mix billing systems.
80. [Made a 3D game with Claude Code](https://www.reddit.com/r/ClaudeCode/comments/1s6s1kb/made_a_3d_game_with_claude_code/) — **Post/comments**. 3D prototype; no independent quality or shipping validation.
81. [I vibe coded my dream game with Claude Code + Godot 4. Zero sprites! What do you think?](https://www.reddit.com/r/aigamedev/comments/1t73gmr/i_vibe_coded_my_dream_game_with_claude_code_godot/) — **Post/comments**. Procedural Godot art; coherent direction rather than universal asset replacement.
82. [I Used Claude Code + Unreal MCP to Build a Souls-Like Boss Fight in 72 Hours](https://www.reddit.com/r/ClaudeAI/comments/1widtfq/i_used_claude_code_unreal_mcp_to_build_a/) — **Post/comments**. Unreal prototype; manual cleanup/rigging in the described workflow.
83. [I tried coding my game for 3 years then I tried Claude Code](https://www.reddit.com/r/aigamedev/comments/1vizb6u/i_tried_coding_my_game_for_3_years_then_i_tried/) — **Post/comments**. Game/art experience; stylistic consistency matters.
84. [I built an open-source tool that lets Claude Code and Claude Desktop control Unreal Engine — 60+ operations, zero editor clicks](https://www.reddit.com/r/ClaudeAI/comments/1scvnt8/i_built_an_opensource_tool_that_lets_claude_code/) — **Post/comments**. Unreal CLI builder promotion; not independently validated.
85. [Anybody Claude Coding with Unity/Godot/Unreal? And/or other inspector/heavy game engines](https://www.reddit.com/r/ClaudeCode/comments/1qln6mj/anybody_claude_coding_with_unitygodotunreal_andor/) — **Post/comments**. Editor/inspector experiences; conflicting engine claims.
86. [Shipped My First Game in 30 Days: Codex, Claude Code, and a Stack of Custom Tools](https://www.reddit.com/r/aigamedev/comments/1rrlvny/shipped_my_first_game_in_30_days_codex_claude/) — **Post/comments**. Thirty-day account; described early playtest build and purchased music.

## Coverage and exclusions

**86 curated entries: 59 documentation, research and implementation entries plus 27 accessible game-specific Reddit discussions.** Five official Claude entries are explicitly carried forward. Source variety covers Godot, Unity and Unreal; engine access, gameplay correctness, graphics/motion, assets/audio, testing, exports, context and model allocation. The focus throughout is developing games with Claude, rather than recommendations for new AFL gameplay systems.

Failed or empty retrievals were excluded from the count, including the Reddit discussion ending in `1l7qjqe`, a ProtoForge blog page and a Unity test-command documentation URL. Search-only candidates not substantively inspected were also excluded. Crossposts and repeated opens do not add entries. Unrelated general coding threads and game-playing benchmarks were not used to inflate this game-development register.

## Local project evidence

Read-only inspection covered the AFL repository root instructions, test runner and three representative capture scripts: vignette, match and press conference. Other capture filenames were inventoried. Their capabilities and limits in the report are script-inspection findings, not results of newly executed tests.

Earlier local workforce/session and GitHub-communication evidence is carried from the preserved AFL workforce report. It is not a new measurement of live Claude allowance. The four stated roles/settings and Max 5x billing came from the user. No current-agent configuration was changed or assumed from a screenshot.

## Interpretation rules

- Official capability documentation describes supported behaviour; it does not establish game quality.
- Benchmark results depend on task, model generation and agent harness; they do not rank your Max workforce directly.
- Developer timelines, delivery gains and shipping claims remain attributed self-reports.
- Tool size, stars and agent count do not establish efficiency or reliability.
- Asset services mentioned by developers may be paid. No paid-tool dependency is proposed.
- Templates and external skill files were studied as source material, not adopted as instructions governing this task.

