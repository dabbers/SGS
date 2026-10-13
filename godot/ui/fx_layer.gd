class_name FxLayer
extends Control
## Full-screen overlay that plays table animations one after another:
## flying cards, floating text, shakes, flashes and turn banners.
## Everything is queued so a burst of events reads as a sequence.

var defs: Dictionary = {}
var _queue: Array[Callable] = []
var _running := false
var speed := 1.0   ## < 1 slows everything down
var enabled := true  ## false drops everything enqueued (used while replaying history)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func enqueue(fn: Callable) -> void:
	if not enabled or not is_inside_tree():
		return
	_queue.append(fn)
	_pump()


func clear() -> void:
	_queue.clear()


signal idle   ## emitted whenever the queue drains


func is_busy() -> bool:
	return _running or not _queue.is_empty()


func _pump() -> void:
	if _running or _queue.is_empty():
		return
	_running = true
	while not _queue.is_empty():
		# Long backlogs play faster so the table never falls far behind.
		speed = clampf(1.0 + _queue.size() * 0.12, 1.0, 3.0)
		var fn: Callable = _queue.pop_front()
		await fn.call()
	speed = 1.0
	_running = false
	idle.emit()


func _t(seconds: float) -> float:
	return seconds / maxf(speed, 0.05)


func wait(seconds: float) -> void:
	await get_tree().create_timer(_t(seconds)).timeout


## A card flies from `from` to `to` (global positions of its centre).
func fly_card(info: Dictionary, from: Vector2, to: Vector2, duration: float = 0.45, hold: float = 0.4, end_scale: float = 1.0, spin: float = 0.0) -> void:
	var cv := CardView.new()
	cv.setup(int(info.get("id", -1)), info, defs)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.disabled = false
	add_child(cv)
	cv.pivot_offset = CardView.SIZE / 2
	cv.global_position = from - CardView.SIZE / 2
	cv.scale = Vector2(0.6, 0.6)
	cv.rotation = -spin
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(cv, "global_position", to - CardView.SIZE / 2, _t(duration))
	tw.tween_property(cv, "scale", Vector2(end_scale, end_scale), _t(duration))
	tw.tween_property(cv, "rotation", 0.0, _t(duration))
	await tw.finished
	await wait(hold)
	var fade := create_tween()
	fade.tween_property(cv, "modulate:a", 0.0, _t(0.2))
	await fade.finished
	cv.queue_free()


## Quick dash of a small card from the centre to a target, then burst.
func dash(info: Dictionary, from: Vector2, to: Vector2) -> void:
	await fly_card(info, from, to, 0.28, 0.05, 0.5)


func float_text(pos: Vector2, text: String, color: Color = Color.WHITE, size: int = 34) -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "TitleLabel"
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.reset_size()
	l.global_position = pos - l.size / 2
	l.pivot_offset = l.size / 2
	l.scale = Vector2(0.6, 0.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2(1.15, 1.15), _t(0.18)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position:y", pos.y - l.size.y / 2 - 48, _t(0.9)).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, _t(0.5)).set_delay(_t(0.5))
	await tw.finished
	l.queue_free()


func banner(text: String, color: Color = SgsTheme.GOLD) -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "TitleLabel"
	l.add_theme_font_size_override("font_size", 44)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	add_child(l)
	l.reset_size()
	var vs := size
	l.global_position = Vector2(-l.size.x, vs.y * 0.42)
	bg.size = Vector2(vs.x, l.size.y + 24)
	bg.global_position = Vector2(0, vs.y * 0.42 - 12)
	bg.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(bg, "modulate:a", 1.0, _t(0.15))
	tw.tween_property(l, "global_position:x", (vs.x - l.size.x) / 2, _t(0.3)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	await wait(0.55)
	var out := create_tween().set_parallel(true)
	out.tween_property(l, "global_position:x", vs.x + 20, _t(0.25)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	out.tween_property(bg, "modulate:a", 0.0, _t(0.25))
	await out.finished
	l.queue_free()
	bg.queue_free()
