class_name InteractionSpot
extends Area3D
## A place the player can stand and work. One spot can cover several procedure locations
## (the car's front-left corner covers both the wheel and the jack point). Children:
##   Stand_<location>               Marker3D: where the player stands, facing its -Z
##   Cam_<location>                 Camera3D: the close-up shot used while working there
##   Rests/<location>/<item|drop>   Marker3D: where items lie at that location

signal player_entered(spot: InteractionSpot)
signal player_exited(spot: InteractionSpot)

@export var locations: PackedStringArray = []


func _ready() -> void:
	add_to_group(&"interaction_spot")
	body_entered.connect(func(body: Node3D) -> void:
		if body is PlayerController:
			player_entered.emit(self))
	body_exited.connect(func(body: Node3D) -> void:
		if body is PlayerController:
			player_exited.emit(self))


func covers(location: String) -> bool:
	return locations.has(location)


func primary_location() -> String:
	return locations[0] if not locations.is_empty() else ""


func stand_for(location: String) -> Marker3D:
	var stand := get_node_or_null("Stand_" + location) as Marker3D
	return stand if stand else get_node_or_null("Stand_" + primary_location()) as Marker3D


func cam_for(location: String) -> Camera3D:
	var cam := get_node_or_null("Cam_" + location) as Camera3D
	return cam if cam else get_node_or_null("Cam_" + primary_location()) as Camera3D


func rest_for(location: String, key: String) -> Node3D:
	return get_node_or_null("Rests/%s/%s" % [location, key]) as Node3D
