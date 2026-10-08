class_name NpcWaypoint
extends Marker3D
## A stop on an NPC's route. The NPC walks here, turns to face this marker's -Z and does `task`:
##   work_overhead / browse_shelf / look_around   play that clip (looping ones run for a while)
##   inspect                                      kneel, look closely, stand back up
##   idle                                         just stand there for a bit

@export var task := "idle"
