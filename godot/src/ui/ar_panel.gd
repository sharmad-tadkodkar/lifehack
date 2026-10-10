class_name ArPanel
extends PanelContainer
## A HUD panel in the AR / heads-up style: translucent glass with chamfered corners, a thin edge
## line, bright corner brackets, tick marks, faint scanlines and a small header tag above it.
## It draws its own frame; content goes in as children (laid out inside `margin`).
## Becoming visible plays a short flicker-in. Colours and sizes come from HudStyle (config/ui.cfg).

## Small caps label drawn above the top-left corner ("" = none).
@export var tag := ""
## Frame colour (the HUD cyan by default; warnings use the warn colour).
var color := Color.CYAN
var fill := Color(0, 0.1, 0.15, 0.6)
var margin := 18.0
var chamfer := 14.0
var bracket := 16.0

var _style: HudStyle
var _reveal: Tween


func _init(style: HudStyle = null, tag_text := "") -> void:
	_style = style
	tag = tag_text
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if style:
		color = style.c.accent
		fill = style.c.panel
		chamfer = float(style.frame.chamfer)
		bracket = float(style.frame.bracket)
		margin = float(style.frame.margin)
	var box := StyleBoxEmpty.new()
	box.set_content_margin_all(margin)
	box.content_margin_top = margin + 2.0
	add_theme_stylebox_override("panel", box)
	visibility_changed.connect(_on_visibility_changed)


func set_color(new_color: Color) -> void:
	color = new_color
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var c := chamfer
	var outline := PackedVector2Array([Vector2(0, 0), Vector2(w - c, 0), Vector2(w, c), Vector2(w, h),
		Vector2(c, h), Vector2(0, h - c), Vector2(0, 0)])
	# glass: fill, a lighter band at the top, scanlines
	draw_colored_polygon(outline.slice(0, 6), fill)
	draw_rect(Rect2(2, 2, w - c - 2, minf(26.0, h * 0.35)), Color(color, 0.05))
	var y := 4.0
	while y < h - 2.0:
		draw_line(Vector2(2, y), Vector2(w - 2, y), Color(color, 0.025))
		y += 3.0
	# edge line with a soft glow
	draw_polyline(outline, Color(color, 0.12), 4.0, true)
	draw_polyline(outline, Color(color, 0.45), 1.0, true)
	# bright corner brackets (top-left, bottom-right)
	var b := minf(bracket, minf(w, h) * 0.4)
	draw_polyline(PackedVector2Array([Vector2(0, b), Vector2(0, 0), Vector2(b, 0)]), color, 2.0)
	draw_polyline(PackedVector2Array([Vector2(w, h - b), Vector2(w, h), Vector2(w - b, h)]), color, 2.0)
	# tick marks along the bottom edge and a status pip in the chamfer
	for i in 4:
		var x := w - c - 18.0 - i * 7.0
		if x > b + 6.0:
			draw_line(Vector2(x, h - 4.0), Vector2(x, h - 1.0), Color(color, 0.6), 1.0)
	draw_line(Vector2(w - c + 3.0, 3.0), Vector2(w - 3.0, c - 3.0), Color(color, 0.8), 2.0)
	if tag != "" and _style:
		var font := _style.display_font
		var size_px := int(_style.s.tag)
		var tag_width := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		draw_rect(Rect2(b + 4.0, -size_px * 0.5 - 4.0, tag_width + 12.0, size_px + 6.0), Color(fill, 0.95))
		draw_string(font, Vector2(b + 10.0, size_px * 0.45), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func _on_visibility_changed() -> void:
	if not is_visible_in_tree() or _style == null:
		return
	if _reveal and _reveal.is_valid():
		_reveal.kill()
	var seconds := float(_style.t.reveal)
	modulate.a = 0.0
	_reveal = create_tween()
	_reveal.tween_property(self, "modulate:a", 0.8, seconds * 0.3)
	_reveal.tween_property(self, "modulate:a", 0.25, seconds * 0.15)
	_reveal.tween_property(self, "modulate:a", 1.0, seconds * 0.55)
