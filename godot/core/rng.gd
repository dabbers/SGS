class_name CardRng
extends RefCounted
## Seeded random source. Every random decision the engine makes goes through
## this so a game is fully reproducible from (seed, inputs).

var _r := RandomNumberGenerator.new()


func _init(seed_value: int) -> void:
	_r.seed = seed_value


func randi_range(from: int, to: int) -> int:
	return _r.randi_range(from, to)


func shuffle(arr: Array) -> void:
	# Fisher-Yates using our own generator (Array.shuffle() uses the global one).
	for i in range(arr.size() - 1, 0, -1):
		var j := _r.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[_r.randi_range(0, arr.size() - 1)]
