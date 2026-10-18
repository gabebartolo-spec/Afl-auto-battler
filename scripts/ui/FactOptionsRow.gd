class_name FactOptionsRow
extends HFlowContainer
## The responses beside one opposition fact (FactOptions), as a short row under
## it: each its name in bold, what it does for you and what it costs; an
## unsuitable one is dimmed and disabled, its reason in the phrase's place. A
## fixed order, nothing marked best. A tap says which response it was; the hub
## decides what that opens.

const MIN_W_NARROW := 130.0
const MIN_W_WIDE := 330.0


## `options` are FactOptions.options; `on_pick` gets the option's dictionary.
func setup(fact_index: int, options: Array, narrow: bool, on_pick: Callable) -> FactOptionsRow:
	name = "FactOptions_%d" % fact_index
	add_theme_constant_override("h_separation", 5)
	add_theme_constant_override("v_separation", 5)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for o in options:
		add_child(_button(fact_index, o, narrow, on_pick))
	return self


func _button(fact_index: int, o: Dictionary, narrow: bool, on_pick: Callable) -> Control:
	var key := str(o["plan"]) if str(o["call"]) == "plan" else str(o["call"])
	var wrap := MarginContainer.new()
	wrap.name = "FactOptionWrap_%d_%s" % [fact_index, key]
	wrap.custom_minimum_size.x = MIN_W_NARROW if narrow else MIN_W_WIDE
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The button is the background and the tap target; the words sit over it.
	var b := UiKit.btn("", UiKit.SECONDARY)
	b.name = "FactOption_%d_%s" % [fact_index, key]
	b.custom_minimum_size.y = 44 if narrow else 36
	b.set_meta("option", o)
	var enabled := bool(o["enabled"])
	b.disabled = not enabled
	wrap.add_child(b)
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 5 if narrow else 3)
	wrap.add_child(pad)
	# The name, then what it does for you and what it costs, each sized
	# (GateOdds): on a phone and a PC alike, a column the option's width wraps.
	var col: BoxContainer = UiKit.vbox(1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.add_child(col)
	var head := UiKit.lbl(str(o["label"]), UiKit.BODY, UiKit.TEXT, true)
	head.name = "OptionName"
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	if enabled and str(o.get("gain", "")) != "":
		var up := UiKit.lbl(str(o["gain"]), UiKit.SMALL, UiKit.TEXT)
		up.name = "OptionGain"
		up.mouse_filter = Control.MOUSE_FILTER_IGNORE
		up.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(up)
	var sub := UiKit.lbl(str(o["cost"]) if enabled else str(o["reason"]), UiKit.SMALL, UiKit.TEXT if enabled else UiKit.MUTED)
	sub.name = "OptionSub"
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	if not enabled:
		# Dimmed, not hidden: the reason still reads.
		head.modulate.a = 0.6
		sub.modulate.a = 0.8
	b.pressed.connect(func(): on_pick.call(o))
	return wrap
