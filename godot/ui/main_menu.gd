extends Control
## Start screen: solo vs bots, host, or join.

@onready var game: Node = get_node("/root/Game")
var name_edit: LineEdit
var players_spin: SpinBox
var address_edit: LineEdit
var port_spin: SpinBox
var status: Label


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "SGS Card Engine"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Your name"
	name_edit.text = "Player"
	box.add_child(name_edit)

	var row := HBoxContainer.new()
	box.add_child(row)
	var lbl := Label.new()
	lbl.text = "Seats (incl. bots)"
	row.add_child(lbl)
	players_spin = SpinBox.new()
	players_spin.min_value = 2
	players_spin.max_value = 8
	players_spin.value = 4
	players_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(players_spin)

	var solo := Button.new()
	solo.text = "Play vs bots"
	solo.custom_minimum_size.y = 56
	solo.pressed.connect(_on_solo)
	box.add_child(solo)

	var sep := HSeparator.new()
	box.add_child(sep)

	var net_row := HBoxContainer.new()
	box.add_child(net_row)
	address_edit = LineEdit.new()
	address_edit.placeholder_text = "Host address"
	address_edit.text = "127.0.0.1"
	address_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	net_row.add_child(address_edit)
	port_spin = SpinBox.new()
	port_spin.min_value = 1024
	port_spin.max_value = 65535
	port_spin.value = NetSession.DEFAULT_PORT
	net_row.add_child(port_spin)

	var host_btn := Button.new()
	host_btn.text = "Host a game (fill empty seats with bots)"
	host_btn.custom_minimum_size.y = 56
	host_btn.pressed.connect(_on_host)
	box.add_child(host_btn)

	var join_btn := Button.new()
	join_btn.text = "Join a game"
	join_btn.custom_minimum_size.y = 56
	join_btn.pressed.connect(_on_join)
	box.add_child(join_btn)

	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status)
	if OS.has_feature("web"):
		# ENet needs UDP; browsers only get WebSocket/WebRTC. Solo play works.
		host_btn.disabled = true
		join_btn.disabled = true
		status.text = "Online play is not available in the browser build yet. Play vs bots works."
	if not game.last_result.is_empty():
		status.text = "Last game: %s side won" % game.last_result.get("winner", "?")


func _on_solo() -> void:
	var s := LocalSession.new(name_edit.text)
	game.set_session(s)
	s.start_game({"players": int(players_spin.value), "decks": ["standard", "expansion"]})
	get_tree().change_scene_to_file("res://ui/table.tscn")


func _on_host() -> void:
	var s := NetSession.new()
	game.set_session(s)
	s.error.connect(func(m): status.text = m)
	if s.host(int(port_spin.value), name_edit.text, int(players_spin.value) - 1) == OK:
		get_tree().change_scene_to_file("res://ui/table.tscn")


func _on_join() -> void:
	var s := NetSession.new()
	game.set_session(s)
	s.error.connect(func(m): status.text = m)
	if s.join(address_edit.text, int(port_spin.value), name_edit.text) == OK:
		get_tree().change_scene_to_file("res://ui/table.tscn")
