class_name TestCase
extends RefCounted
## Minimal test base. Methods named test_* are run by run_tests.gd and may await.

var failures: Array[String] = []
var current: String = ""
var tree: SceneTree = null   ## set by the runner


func frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func fail(msg: String) -> void:
	failures.append("%s: %s" % [current, msg])


func assert_true(cond: bool, msg: String = "expected true") -> void:
	if not cond:
		fail(msg)


func assert_false(cond: bool, msg: String = "expected false") -> void:
	if cond:
		fail(msg)


func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		fail("%s expected %s got %s" % [msg, str(b), str(a)])


func assert_ne(a, b, msg: String = "") -> void:
	if a == b:
		fail("%s expected different from %s" % [msg, str(b)])


func setup() -> void:
	pass


func teardown() -> void:
	pass
