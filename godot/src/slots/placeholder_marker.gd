class_name PlaceholderMarker
extends Node3D
## Root script of every placeholder scene. F3 toggles a floating "PLACEHOLDER" tag so it
## is obvious which parts still need a real asset (see ASSETS.md).

@export var label := ""
@export var label_height := 1.0

var _tag: Label3D


func _ready() -> void:
	_tag = Label3D.new()
	_tag.text = "PLACEHOLDER\n" + label
	_tag.position.y = label_height
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.fixed_size = true
	_tag.pixel_size = 0.0008
	_tag.font_size = 32
	_tag.outline_size = 8
	_tag.modulate = Color(1.0, 0.45, 0.3)
	_tag.visible = false
	add_child(_tag)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_placeholder_labels"):
		_tag.visible = not _tag.visible
