extends Node
## Proof-of-concept test for the game-flow state machine and the seal mini-game.
## Run headless:  godot --headless --path . res://tests/state_machine_test.tscn
## Exit code 0 = all checks passed. Add `-- shots=/some/dir` to also save screenshots.

const S := preload("res://scripts/game_state.gd").State

# Edges from the design diagram, written out independently of GameState.TRANSITIONS.
const EXPECTED_EDGES := [
	"Running_restaurant>Walking_on_Beach",
	"Walking_on_Beach>Running_restaurant",
	"Walking_on_Beach>Talking_to_Seal",
	"Talking_to_Seal>Walking_on_Beach",
	"Talking_to_Seal>Seal_mini_game",
	"Seal_mini_game>Talking_to_Seal",
]
# While a recipe is waiting, Talking_to_Seal only leads to the next day.
const PENDING_EDGES := ["Talking_to_Seal>Running_restaurant"]

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
	print("== transition table matches the diagram")
	GameState.seal_fed = true   # this test covers the loop after the day-1 story
	for pending in [false, true]:
		for from in S.values():
			for to in S.values():
				GameState.state = from
				GameState.result_pending = pending
				var edge: String = GameState.state_name(from) + ">" + GameState.state_name(to)
				var expect: bool
				if pending and from == S.TALKING_TO_SEAL:
					expect = edge in PENDING_EDGES
				else:
					expect = edge in EXPECTED_EDGES
				check(GameState.can_go(to) == expect, "%s%s %s" % ["(recipe waiting) " if pending else "", "allowed" if expect else "blocked", edge])
	GameState.reset()
	GameState.seal_fed = true
	GameState.tutorial_seen = true

	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await frames(5)

	print("== Running_restaurant")
	check(game.level_path.ends_with("temp_restaurant_scene.tscn"), "restaurant scene loaded")
	check(buttons() == ["Walking_on_Beach"], "buttons: %s" % [buttons()])
	check(not GameState.go(S.SEAL_MINI_GAME), "Running_restaurant -> Seal_mini_game refused")

	print("== Walking_on_Beach -> Talking_to_Seal")
	check(GameState.go(S.WALKING_ON_BEACH), "go to beach")
	await frames(5)
	var chef: CharacterBody2D = game.level.chef
	await hold("left", 0.3)
	var chef_spot := chef.position
	check(GameState.go(S.TALKING_TO_SEAL), "talk to seal")
	await frames(5)
	check(game.popup == null, "no recipe pop-up before the mini-game")
	check(buttons() == ["Walking_on_Beach", "Seal_mini_game"], "buttons: %s" % [buttons()])

	print("== Seal_mini_game")
	check(GameState.go(S.SEAL_MINI_GAME), "start mini-game")
	await frames(5)
	var sea: Node = game.level
	check(game.level_path.ends_with("sea_repeat.tscn"), "sea scene loaded")
	check(sea._count.text == "0/10" and sea._bar.value == 0, "HUD shows 0/10, bar empty")
	check(sea._timer_label.text == "0:30", "timer starts at 0:30 (shows %s)" % sea._timer_label.text)
	var tl: Control = sea._timer_label
	var vp := get_viewport().get_visible_rect().size
	check(tl.get_global_rect().end.x > vp.x * 0.85 and tl.get_global_rect().position.y < vp.y * 0.15, "timer sits in the top-right corner")
	check(buttons() == ["Talking_to_Seal"], "buttons: %s" % [buttons()])
	# swim around for a few seconds: at least one fish must be on screen every frame
	var always_visible := true
	var max_fish := 0
	var seal: CharacterBody2D = sea.seal
	Input.action_press("right")
	var t := 0.0
	var start_ms := Time.get_ticks_msec()
	while t < 3.0:
		# sample every drawn frame: that's what the player actually sees
		await get_tree().process_frame
		t = (Time.get_ticks_msec() - start_ms) / 1000.0
		if t > 1.5 and Input.is_action_pressed("right"):
			Input.action_release("right")
			Input.action_press("down")
		var fish: Array = sea.live_fish()
		max_fish = max(max_fish, fish.size())
		if not sea._any_in_view(fish):
			always_visible = false
	Input.action_release("down")
	check(always_visible, "at least one fish on screen every frame")
	check(sea.time_left > 26.0 and sea.time_left < 27.5, "timer counts down (%.1f s left after ~3 s)" % sea.time_left)
	check(sea._timer_label.text in ["0:27", "0:28"], "timer label updates (%s)" % sea._timer_label.text)
	check(max_fish <= sea.MAX_FISH, "never more than %d fish (saw %d)" % [sea.MAX_FISH, max_fish])
	check((seal.sprite as AnimatedSprite2D).animation.begins_with("idle_") or (seal.sprite as AnimatedSprite2D).animation.begins_with("swim_"), "seal uses swim_/idle_ animations in the sea")
	await shot("1_mini_game_start")

	# catch fish by swimming the seal onto them
	var hud_ok := true
	var shot_taken := false
	var tries := 0
	while sea.caught < 10 and tries < 40:
		tries += 1
		var fish: Array = sea.live_fish()
		if fish.is_empty():
			await frames(2)
			continue
		var before: int = sea.caught
		seal.position = (fish[0] as Area2D).position
		await frames(4)
		check(sea.caught > before, "fish caught on contact (%d/10)" % sea.caught)
		hud_ok = hud_ok and sea._count.text == "%d/10" % sea.caught and int(sea._bar.value) == sea.caught
		if sea.caught >= 5 and not shot_taken:
			shot_taken = true
			await shot("2_mini_game_half")
	check(hud_ok, "HUD count and bar always match the fish caught")
	check(sea._count.text == "10/10" and sea._bar.value == 10, "bar full at 10/10")
	check(not seal.can_move, "seal stops when the bar is full")
	await get_tree().create_timer(sea.END_DELAY + 0.3).timeout

	print("== back to Talking_to_Seal with the recipe pop-up")
	check(GameState.state == S.TALKING_TO_SEAL, "mini-game ended itself -> Talking_to_Seal")
	await frames(5)
	check(game.level_path.ends_with("main.tscn"), "beach shown in the background")
	check(game.level.seal != null and not game.level.chef.can_move and not game.level.seal.can_move, "chef and seal frozen, talking")
	check(game.level.chef.position == chef_spot, "chef is where we left him")
	check(game.popup != null and game.popup.is_inside_tree(), "recipe pop-up shown")
	check(game.popup.name_label.text == "Fish Sandwich", "first unlock is Fish Sandwich (got %s)" % game.popup.name_label.text)
	check("Fish Sandwich" in GameState.unlocked_recipes, "recipe added to unlocked list")
	check(buttons() == ["Running_restaurant (new day)"], "buttons: %s" % [buttons()])
	check(not GameState.go(S.SEAL_MINI_GAME), "can't replay the mini-game while the recipe is waiting")
	await get_tree().create_timer(0.5).timeout
	await shot("3_recipe_popup")

	print("== any key -> next day")
	var ev := InputEventKey.new()
	ev.keycode = KEY_X
	ev.physical_keycode = KEY_X
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(5)
	check(GameState.state == S.RUNNING_RESTAURANT, "key press starts the next day")
	check(GameState.day == 2, "day counter is 2")
	check(game.popup == null, "pop-up closed")
	check(game.level_path.ends_with("temp_restaurant_scene.tscn"), "back in the restaurant")

	print("== second win unlocks the next recipe, mouse click continues")
	GameState.go(S.WALKING_ON_BEACH); GameState.go(S.TALKING_TO_SEAL); GameState.go(S.SEAL_MINI_GAME)
	GameState.go(S.TALKING_TO_SEAL)   # debug-button shortcut
	await frames(5)
	check(game.popup != null and game.popup.name_label.text == "Smoothie", "second unlock is Smoothie")
	await get_tree().create_timer(0.5).timeout
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(320, 300)
	Input.parse_input_event(click)
	await frames(5)
	check(GameState.state == S.RUNNING_RESTAURANT and GameState.day == 3, "click starts day 3")

	print("== timer runs out -> no recipe, next day")
	GameState.go(S.WALKING_ON_BEACH); GameState.go(S.TALKING_TO_SEAL); GameState.go(S.SEAL_MINI_GAME)
	await frames(5)
	sea = game.level
	var recipes_before := GameState.unlocked_recipes.size()
	sea.time_left = 0.2
	await frames(30)
	check(sea._timer_label.text == "0:00", "timer stops at 0:00")
	check(not sea.seal.can_move, "seal stops when time is up")
	await shot("4_time_up")
	await get_tree().create_timer(sea.END_DELAY + 0.3).timeout
	await frames(5)
	check(GameState.state == S.TALKING_TO_SEAL and not GameState.last_won, "back to Talking_to_Seal as a loss")
	check(GameState.unlocked_recipes.size() == recipes_before, "no recipe unlocked")
	check(game.popup != null and game.popup.title.text == "Out of time!", "pop-up says Out of time!")
	check(buttons() == ["Running_restaurant (new day)"], "buttons: %s" % [buttons()])
	await get_tree().create_timer(0.5).timeout
	await shot("5_out_of_time")
	var ev2 := InputEventKey.new()
	ev2.keycode = KEY_SPACE
	ev2.physical_keycode = KEY_SPACE
	ev2.pressed = true
	Input.parse_input_event(ev2)
	await frames(5)
	check(GameState.state == S.RUNNING_RESTAURANT and GameState.day == 4, "key press starts day 4 after losing")


# ---------------------------------------------------------------- helpers
func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await get_tree().create_timer(seconds).timeout
	Input.action_release(action)
	await frames(2)


func buttons() -> Array:
	var out := []
	for b in game._buttons.get_children():
		if not b.is_queued_for_deletion():
			out.append(b.text)
	return out


func shot(name: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(name + ".png"))
