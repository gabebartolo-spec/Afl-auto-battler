extends CanvasLayer
## Frame-time probe for the phone measurement (visual audit 4.8): in an exported
## DEBUG build only (ScreenLayout adds it; never in the editor, tests or a
## release build), a line in the corner gives the screen, the average frame
## time and the worst frame over the last two seconds, so the director can read
## the cost of a vignette on his own phone. Each screen's figures are also
## appended to user://perf_probe.csv for a closer look later.

const WINDOW := 2.0
const LOG_PATH := "user://perf_probe.csv"

var _label: Label
var _times: Array[float] = []
var _elapsed := 0.0
var _scene := ""


func _ready() -> void:
	layer = 128
	_label = Label.new()
	_label.position = Vector2(6, 6)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(1, 1, 0.6))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _process(delta: float) -> void:
	_times.append(delta * 1000.0)
	_elapsed += delta
	if _elapsed < WINDOW:
		return
	var scene := get_tree().current_scene
	_scene = str(scene.name) if scene != null else "-"
	var total := 0.0
	var worst := 0.0
	for t in _times:
		total += t
		worst = maxf(worst, t)
	var avg := total / maxf(1.0, float(_times.size()))
	_label.text = "%s  ·  %.1f ms avg  ·  %.0f ms worst  ·  %d fps" % [_scene, avg, worst, int(round(1000.0 / maxf(avg, 0.001)))]
	_log(avg, worst)
	_times.clear()
	_elapsed = 0.0


func _log(avg: float, worst: float) -> void:
	var exists := FileAccess.file_exists(LOG_PATH)
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if f == null:
		return
	if exists:
		f.seek_end()
	else:
		f.store_line("time_ms,screen,avg_ms,worst_ms")
	f.store_line("%d,%s,%.2f,%.2f" % [Time.get_ticks_msec(), _scene, avg, worst])
