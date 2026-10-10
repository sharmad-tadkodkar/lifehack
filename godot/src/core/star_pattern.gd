class_name StarPattern
extends RefCounted
## Final tightening order for lug nuts numbered 0..count-1 around the hub. After the first nut
## (any), each next nut must be as far across from the previous one as any remaining nut is.
## For five nuts that is the star (0-2-4-1-3, either direction); for four, the criss-cross.

var count := 5
var tightened: Array[int] = []


func _init(nut_count: int) -> void:
	count = nut_count


## "ok", "done" (already tightened), "wrong" (not across) or "invalid".
func try(nut: int) -> String:
	if nut < 0 or nut >= count:
		return "invalid"
	if tightened.has(nut):
		return "done"
	if not valid_next().has(nut):
		return "wrong"
	tightened.append(nut)
	return "ok"


## The nuts that would be accepted next.
func valid_next() -> Array[int]:
	var remaining: Array[int] = []
	for n in count:
		if not tightened.has(n):
			remaining.append(n)
	if tightened.is_empty():
		return remaining
	var last := tightened[-1]
	var best := 0
	for n in remaining:
		best = maxi(best, _distance(last, n))
	var out: Array[int] = []
	for n in remaining:
		if _distance(last, n) == best:
			out.append(n)
	return out


func is_complete() -> bool:
	return tightened.size() == count


func _distance(a: int, b: int) -> int:
	var d := absi(a - b)
	return mini(d, count - d)
