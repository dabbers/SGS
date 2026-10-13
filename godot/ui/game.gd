extends Node
## Autoload "Game": holds the active session across scene changes.

var session: GameSession = null
var last_result: Dictionary = {}


func set_session(s: GameSession) -> void:
	if session != null and is_instance_valid(session):
		session.leave()
	session = s
	add_child(s)


func clear_session() -> void:
	if session != null and is_instance_valid(session):
		session.leave()
	session = null
