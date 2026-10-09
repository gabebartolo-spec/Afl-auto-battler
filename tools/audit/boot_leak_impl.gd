extends RefCounted
## Boot-colour leak (ROADMAP 1.11): how many covered pixels of the figure sheets draw boot
## colour after VRAM compression where the lossless sheet has none. Loads each sheet's
## imported BPTC (desktop) and ASTC (phone) texture, decompresses it, and runs the figure
## shader's weight maths on it beside the lossless PNG. CI's software renderer can't show
## BPTC damage on screen; this reads the compressed texels themselves.
## A leak: lossless boots < 0.05, decompressed boots > 0.15. Counted at texel centres (1:1)
## and half way between four texels (a magnified draw's in-between sample).
## Reads the sheet format from VignetteFigures.gd's header: boots left over (before
## ard-asset-pipeline's boot_weight.py) or boots in mask G beside the sock band (after).
## No arguments. One `LEAK` line per texture format and sample, then `SUMMARY`.

const DIR := "res://assets/vignette/figures_%s.png"
const ZONE_LO := 0.25     # figure.gdshader BOOT_ZONE_LO / HI
const ZONE_HI := 0.45

var w := 0
var h := 0
var folded := false

func run() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/match/VignetteFigures.gd")
	folded = src.contains("G sock band + boots")
	print("FORMAT ", "boots in mask G (folded)" if folded else "boots left over")
	var s0 := _png("shade")
	var m0 := _png("mask")
	var d0 := _png("design")
	var zone := _zone(d0)
	var summary := []
	for fmt in ["bptc", "astc"]:
		var s1 := _imported("shade", fmt)
		var m1 := _imported("mask", fmt)
		if s1.is_empty() or m1.is_empty():
			print("LEAK %s missing (not imported)" % fmt)
			continue
		for half in [false, true]:
			var r := _count(s0, m0, s1, m1, zone, half)
			print("LEAK %s %s leak=%d off=%d covered=%d" % [fmt, "half" if half else "1:1", r[0], r[1], r[2]])
			summary.append("%s %s %d" % [fmt, "half" if half else "1:1", r[0]])
	print("SUMMARY ", ", ".join(summary))

func _png(which: String) -> PackedByteArray:
	var img := Image.load_from_file(ProjectSettings.globalize_path(DIR % which))
	img.convert(Image.FORMAT_RGBA8)
	w = img.get_width()
	h = img.get_height()
	return img.get_data()

func _imported(which: String, fmt: String) -> PackedByteArray:
	var cfg := ConfigFile.new()
	if cfg.load((DIR % which) + ".import") != OK:
		return PackedByteArray()
	var path := str(cfg.get_value("remap", "path." + fmt, ""))
	if path == "" or not FileAccess.file_exists(path):
		return PackedByteArray()
	var tex := CompressedTexture2D.new()
	if tex.load(path) != OK:
		return PackedByteArray()
	var img := tex.get_image()
	print("IMPORTED %s %s format=%d" % [which, fmt, img.get_format()])
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img.get_data()

## Per texel: how much of mask G is sock band (figure.gdshader band_share, before filtering).
func _zone(d: PackedByteArray) -> PackedFloat32Array:
	var z := PackedFloat32Array()
	z.resize(w * h)
	for i in w * h:
		z[i] = smoothstep(ZONE_LO, ZONE_HI, d[i * 4 + 1] / 255.0)
	return z

## [leaks, samples with any weight off by > 0.15, covered samples]
func _count(s0: PackedByteArray, m0: PackedByteArray, s1: PackedByteArray, m1: PackedByteArray,
		zone: PackedFloat32Array, half: bool) -> Array:
	var leaks := 0
	var off := 0
	var covered := 0
	var n := 4 if half else 1
	for y in h - 1:
		for x in w - 1:
			var i := y * w + x
			var taps: Array = [i, i + 1, i + w, i + w + 1] if half else [i]
			var a := 0.0
			for t in taps:
				a += s0[t * 4 + 3]
			if a / n < 127.5:
				continue
			covered += 1
			var lossless := _weights(s0, m0, zone, taps)
			var decoded := _weights(s1, m1, zone, taps)
			if lossless[5] < 0.05 and decoded[5] > 0.15:
				leaks += 1
			for k in 6:
				if absf(lossless[k] - decoded[k]) > 0.15:
					off += 1
					break
	return [leaks, off, covered]

## The shader's six weights (base, band, skin, hair, shorts, boots) at the mean of the taps.
func _weights(s: PackedByteArray, m: PackedByteArray, zone: PackedFloat32Array, taps: Array) -> Array:
	var v := [0.0, 0.0, 0.0, 0.0, 0.0]
	var z := 0.0
	for t in taps:
		v[0] += m[t * 4]
		v[1] += m[t * 4 + 1]
		v[2] += m[t * 4 + 2]
		v[3] += s[t * 4 + 1]
		v[4] += s[t * 4 + 2]
		z += zone[t]
	var n := float(taps.size())
	for k in 5:
		v[k] /= 255.0 * n
	z /= n
	if not folded:
		return [v[0], v[1], v[2], v[3], v[4], clampf(1.0 - (v[0] + v[1] + v[2] + v[3] + v[4]), 0.0, 1.0)]
	var band: float = v[1] * z
	var total: float = maxf(v[0] + v[1] + v[2] + v[3] + v[4], 0.05)
	return [v[0] / total, band / total, v[2] / total, v[3] / total, v[4] / total, (v[1] - band) / total]
