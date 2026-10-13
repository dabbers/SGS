extends SceneTree
## Headless test runner:  godot --headless --path . -s tests/run_tests.gd [filter]

var _filter := ""


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		_filter = a


## Runs once the tree is the main loop (needed for scenes, timers, networking).
func _initialize() -> void:
	_run(_filter)


func _run(filter: String) -> void:
	_instantiate_autoloads()
	var total := 0
	var failed := 0
	var dir := DirAccess.open("res://tests")
	var files := Array(dir.get_files())
	files.sort()
	for f in files:
		if not f.begins_with("test_") or not f.ends_with(".gd") or f == "test_case.gd":
			continue
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			print("  FAIL %s: script failed to load" % f)
			failed += 1
			continue
		var inst = script.new()
		if not inst is TestCase:
			continue
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			if filter != "" and not name.contains(filter) and not f.contains(filter):
				continue
			total += 1
			inst.current = "%s.%s" % [f, name]
			var before: int = inst.failures.size()
			inst.tree = self
			inst.setup()
			await inst.call(name)
			inst.teardown()
			if inst.failures.size() > before:
				failed += 1
				for i in range(before, inst.failures.size()):
					print("  FAIL ", inst.failures[i])
			else:
				print("  ok   ", inst.current)
	print("\n%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)


## `-s` mode does not create autoload singletons; tests that use scenes need them.
func _instantiate_autoloads() -> void:
	for prop in ProjectSettings.get_property_list():
		var key: String = prop["name"]
		if not key.begins_with("autoload/"):
			continue
		var path: String = str(ProjectSettings.get_setting(key)).trim_prefix("*")
		var script = load(path)
		if script == null:
			continue
		var node: Node = script.new()
		node.name = key.trim_prefix("autoload/")
		root.add_child(node)
