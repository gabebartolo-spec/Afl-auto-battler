SLOTSH="C:/Users/DANTE/AppData/Local/Temp/claude/C--Users-DANTE-Documents-GitHub-Afl-auto-battler/59d453d8-7ee5-4855-b721-a96f9ef4efcf/scratchpad/godot_slot.sh"
G="C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
for n in $(seq 1 40); do slot=$(bash "$SLOTSH" claim perf) && break; sleep 15; done; [ -n "$slot" ] || { echo noslot; exit 1; }
cd C:/Users/DANTE/Documents/GitHub/Afl-auto-battler/.claude/worktrees/afl-perf
for spec in "$@"; do
  scene=${spec%%@*}; res=${spec##*@}
  export APPDATA="$PWD/.perf_appdata_$slot"; mkdir -p "$APPDATA"
  timeout 240 "$G" --path . --rendering-method gl_compatibility --rendering-driver opengl3 --script tools/visual/perf_banner.gd -- --scene $scene --size $res --out "$PWD/.perf_${scene}_${res}${TAG}.json" $EXTRA 2>&1 | grep -E "PERF|DRAWMS|ERROR|SCRIPT" | cut -c1-200
done
bash "$SLOTSH" release $slot
