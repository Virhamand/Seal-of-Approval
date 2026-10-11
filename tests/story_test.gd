extends Node
## Story flow test: day-1 rescue, rating bar, ending.
## Run: godot --headless --path . res://tests/story_test.tscn   (add `-- shots=/dir` for screenshots)

const S := preload("res://scripts/game_state.gd").State

var failures := 0
var checks := 0
var shots_dir := ""
var game: Node


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		printerr("  FAIL ", what)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			shots_dir = a.substr(6)
	await run()
	print("\n%d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func run() -> void:
	GameState.reset()
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await wait(0.2)

	print("== day 1 restaurant")
	check(game._rating_panel.visible and game._rating_value.text == "0/100", "rating bar shows 0/100")

	print("== day 1 beach: pan to fainted seal")
	GameState.go(S.WALKING_ON_BEACH)
	await wait(0.2)
	var beach: Node = game.level
	check(beach._cutscene and not beach.chef.can_move, "camera pans, chef can't move")
	await wait(2.0)
	await shot("1_day1_pan_to_seal")
	check(String(beach.seal.sprite.animation) in ["fall", "die"], "seal plays fall/die (%s)" % beach.seal.sprite.animation)
	await wait(3.0)
	check(not beach._cutscene and beach.chef.can_move, "pan finished, control back")
	check(String(beach.seal.sprite.animation) == "die", "die animation looping")

	print("== feed the seal")
	beach.chef.position = beach.seal.position + Vector2(-50, 0)
	await wait(0.1)
	check(beach._prompt.visible and beach._prompt_label.text == beach.FEED_TEXT, "feed prompt shown near seal")
	await shot("2_feed_prompt")
	press_interact()
	await wait(0.3)
	check(GameState.state == S.TALKING_TO_SEAL, "F -> Talking_to_Seal")
	check(beach.seal.sprite.animation == "fall" and beach.seal.sprite.frame == 2, "seal shows eyes-open frame")
	await wait(2.0)
	check(GameState.seal_fed and String(beach.seal.sprite.animation).begins_with("idle_"), "seal got up and idles")
	check(game.popup != null and game.popup.name_label.text == "Fish Sandwich", "recipe unlocked without mini-game")
	await wait(0.5)
	await shot("3_day1_recipe")
	press_key()
	await wait(0.2)
	check(GameState.state == S.RUNNING_RESTAURANT and GameState.day == 2, "next day")

	print("== day 2: play the mini-game, rating hidden there")
	GameState.go(S.WALKING_ON_BEACH)
	await wait(0.2)
	beach = game.level
	check(not beach._cutscene, "no pan on a normal day")
	beach.chef.position = beach.seal.position + Vector2(-50, 0)
	await wait(0.1)
	check(beach._prompt_label.text == beach.PLAY_TEXT, "prompt says [F] Play")
	click_seal(beach)
	await wait(1.0)
	check(GameState.state == S.SEAL_MINI_GAME, "click on seal -> mini-game starts")
	check(not game._rating_panel.visible, "rating bar hidden in the mini-game")
	GameState.go(S.TALKING_TO_SEAL)   # debug skip
	await wait(0.6)
	press_key()
	await wait(0.2)

	print("== fill rating and go to the beach")
	var fill: Button = null
	for b in game._buttons.get_parent().get_children():
		if b is Button and b.text == "Fill rating":
			fill = b
	fill.pressed.emit()
	check(GameState.rating == 100 and game._rating_value.text == "100/100", "debug button fills the bar")
	GameState.go(S.WALKING_ON_BEACH)
	await wait(0.2)
	beach = game.level
	check(beach._cutscene, "pans to the waiting seal")
	await wait(2.0)
	await shot("4_ending_pan")
	await wait(3.0)
	beach.chef.position = beach.seal.position + Vector2(-50, 0)
	await wait(0.1)
	check(beach._prompt_label.text == beach.TALK_TEXT, "prompt says [F] Talk")
	press_interact()
	await wait(0.3)
	check(beach._dialogue_index == 0 and beach._dialogue_layer.visible, "congratulation dialogue")
	await shot("5_congrats")
	for i in beach.CONGRATS.size():
		press_key()
		await wait(0.1)
	check(game._end_layer != null and GameState.ending, "The End screen")
	await shot("6_the_end")

	print("== play again")
	var again: Button = game._end_layer.find_children("*", "Button", true, false)[0]
	again.pressed.emit()
	await wait(0.3)
	check(GameState.state == S.RUNNING_RESTAURANT and GameState.day == 1 and GameState.rating == 0 and not GameState.seal_fed, "fresh game")


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func press_interact() -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)


func press_key() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_X
	ev.physical_keycode = KEY_X
	ev.pressed = true
	Input.parse_input_event(ev)


func click_seal(beach: Node) -> void:
	# simulate a click on the seal: point the mouse at it via the viewport transform
	var vp := beach.get_viewport()
	var screen: Vector2 = vp.get_final_transform() * (vp.get_canvas_transform() * beach.seal.position)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = screen
	ev.global_position = screen
	get_viewport().warp_mouse(screen)
	Input.parse_input_event(ev)


func shot(name: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(name + ".png"))
