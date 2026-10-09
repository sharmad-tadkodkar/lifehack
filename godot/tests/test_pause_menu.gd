extends GutTest
## The Esc menu pauses and resumes the game and reports Restart / Quit; Main wires those up.

var menu: PauseMenu


func before_each() -> void:
	menu = PauseMenu.new()
	add_child_autofree(menu)


func after_each() -> void:
	get_tree().paused = false


func test_open_pauses_and_resume_unpauses() -> void:
	menu.open()
	assert_true(menu.is_open)
	assert_true(menu.visible)
	assert_true(get_tree().paused, "the game is paused behind the menu")
	menu.choose(0)
	assert_false(menu.is_open)
	assert_false(get_tree().paused)


func test_escape_closes_the_menu() -> void:
	menu.open()
	var escape := InputEventAction.new()
	escape.action = &"pause"
	escape.pressed = true
	menu._unhandled_input(escape)
	assert_false(menu.is_open)
	assert_false(get_tree().paused)


func test_number_keys_choose() -> void:
	watch_signals(menu)
	menu.open()
	var two := InputEventAction.new()
	two.action = &"choice_2"
	two.pressed = true
	menu._unhandled_input(two)
	assert_signal_emitted(menu, "restart_requested")
	assert_false(get_tree().paused, "restart unpauses first")


func test_quit_is_reported() -> void:
	watch_signals(menu)
	menu.open()
	menu.choose(2)
	assert_signal_emitted(menu, "quit_requested")
	menu.close()


func test_main_wires_the_menu() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait_physics_frames(1)
	var pause_menu: PauseMenu = main.get_node("PauseMenu")
	assert_true(pause_menu.restart_requested.is_connected(main.restart))
	assert_true(pause_menu.quit_requested.is_connected(get_tree().quit))
	assert_true(main.get_node("ProcedureController").play_again_requested.is_connected(main.restart),
		"E after finishing restarts the same way")
	main.free()
