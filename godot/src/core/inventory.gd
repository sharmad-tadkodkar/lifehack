class_name Inventory
extends RefCounted
## Where every item is: a location id, "hands" (the one item being carried) or "installed"
## (in use on the car). The player carries at most one item at a time.

const HANDS := "hands"
const INSTALLED := "installed"

var held := ""
var item_at: Dictionary = {}


func _init(items: Dictionary) -> void:
	for item_id: String in items:
		item_at[item_id] = str(items[item_id].get("starts_at", INSTALLED))


func location_of(item_id: String) -> String:
	return item_at.get(item_id, "")


## Items lying at `location`, alphabetical so menus are stable.
func items_at(location: String) -> Array[String]:
	var out: Array[String] = []
	for item_id: String in item_at:
		if item_at[item_id] == location:
			out.append(item_id)
	out.sort()
	return out


## Picks `item_id` up from `location`. Anything already in hands is set down there (a swap).
## Returns "" on success, otherwise the reason ("not_here", "installed").
func take(item_id: String, location: String) -> String:
	var where := location_of(item_id)
	if where == INSTALLED:
		return "installed"
	if where != location:
		return "not_here"
	if held != "":
		item_at[held] = location
	item_at[item_id] = HANDS
	held = item_id
	return ""


func put_down(location: String) -> String:
	if held == "":
		return "nothing_held"
	item_at[held] = location
	held = ""
	return ""


## The held item goes into use on the car (jack under it, spare on the hub).
func consume_held() -> void:
	if held != "":
		item_at[held] = INSTALLED
		held = ""


func move(item_id: String, location: String) -> void:
	if held == item_id:
		held = ""
	item_at[item_id] = location
