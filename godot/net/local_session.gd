class_name LocalSession
extends GameSession
## Single-process session: the engine runs here, every seat but mine is a bot.
## Also used by NetSession on the host side through `GameHost`.

var host: GameHost


func _init(p_name: String = "You") -> void:
	my_name = p_name
	is_host = true
	my_seat = 0


func start_game(config: Dictionary = {}) -> void:
	var cfg := config.duplicate(true)
	var n: int = cfg.get("players", 4) if cfg.get("players", 4) is int else cfg["players"].size()
	if cfg.get("players", 4) is int:
		var names := [my_name]
		for i in range(1, n):
			names.append("Bot %d" % i)
		cfg["players"] = names
	if not cfg.has("bots"):
		cfg["bots"] = range(1, n)
	host = GameHost.new()
	host.sync_for_viewer.connect(_on_sync)
	host.finished.connect(func(res): game_over.emit(res))
	game_started.emit()
	host.start(cfg)


func _on_sync(viewer: int, snap: Dictionary, prompt_dict: Variant, events: Array) -> void:
	if viewer == my_seat:
		_apply_sync(snap, prompt_dict, events)


func submit(prompt_id: int, response: Dictionary) -> void:
	if host == null or not host.respond(my_seat, prompt_id, response):
		error.emit("That response was not accepted.")
