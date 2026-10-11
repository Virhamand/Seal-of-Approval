extends Node
## Proof-of-concept test for the game-flow state machine.
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
	"Seal_mini_game>Unlock_recipe",
	"Unlock_recipe>Running_restaurant",
]

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
	for from in S.values():
		for to in S.values():
			GameState.state = from
			var edge: String = GameState.state_name(from) + ">" + GameState.state_name(to)
			check(GameState.can_go(to) == (edge in EXPECTED_EDGES), "%s %s" % ["allowed" if edge in EXPECTED_EDGES else "blocked", edge])
	GameState.reset()

	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await frames(5)

	print("== Running_restaurant")
	check(game.level_path.ends_with("temp_restaurant_scene.tscn"), "restaurant scene loaded")
	check(buttons() == ["Walking_on_Beach"], "only legal button shown: %s" % [buttons()])
	var chef: CharacterBody2D = game.level.chef
	var seal: CharacterBody2D = game.level.seal
	check(chef.can_move and not seal.can_move, "chef movement on, seal movement off")
	var c0 := chef.position
	var s0 := seal.position
	await hold("right", 0.4)
	check(chef.position.x > c0.x + 5, "chef walks when pressing right")
	check(seal.position == s0, "seal stays put")
	await shot("1_running_restaurant")
	var first: Node = game.level.current_customer
	check(live_customers() == 1, "one customer on screen")
	var max_seen := 0
	var t := 0.0
	while t < 3.4:
		max_seen = max(max_seen, live_customers())
		t += get_process_delta_time()
		await get_tree().process_frame
	check(not is_instance_valid(first), "first customer deleted after 3 s")
	check(live_customers() == 1 and game.level.current_customer != first, "next customer spawned")
	check(max_seen <= 1, "never more than one customer at a time")

	print("== illegal jump is refused")
	check(not GameState.go(S.SEAL_MINI_GAME), "Running_restaurant -> Seal_mini_game refused")
	check(GameState.state == S.RUNNING_RESTAURANT, "state unchanged")

	print("== Walking_on_Beach")
	check(GameState.go(S.WALKING_ON_BEACH), "go to beach")
	await frames(5)
	check(game.level_path.ends_with("main.tscn"), "beach scene loaded")
	check(bodies() == ["chef"], "only the chef is on the beach: %s" % [bodies()])
	chef = game.level.chef
	c0 = chef.position
	await hold("down", 0.4)
	check(chef.position.y > c0.y + 5, "chef walks on the beach")
	check(buttons() == ["Running_restaurant", "Talking_to_Seal"], "buttons: %s" % [buttons()])
	await shot("2_walking_on_beach")

	print("== Talking_to_Seal")
	check(GameState.go(S.TALKING_TO_SEAL), "talk to seal")
	await frames(5)
	check(game.level.chef == chef, "same beach, chef kept")
	seal = game.level.seal
	check(seal != null and seal.is_inside_tree(), "seal appears")
	check(not chef.can_move and not seal.can_move, "chef and seal frozen")
	c0 = chef.position
	s0 = seal.position
	await hold("left", 0.4)
	check(chef.position == c0 and seal.position == s0, "nobody moves while talking")
	check(buttons() == ["Walking_on_Beach", "Seal_mini_game"], "buttons: %s" % [buttons()])
	await shot("3_talking_to_seal")

	print("== back to Walking_on_Beach and talk again")
	check(GameState.go(S.WALKING_ON_BEACH), "leave conversation")
	await frames(5)
	check(bodies() == ["chef"] and chef.can_move, "seal gone, chef free again")
	check(GameState.go(S.TALKING_TO_SEAL), "talk again")
	await frames(3)

	print("== Seal_mini_game")
	check(GameState.go(S.SEAL_MINI_GAME), "start mini-game")
	await frames(5)
	check(game.level_path.ends_with("sea_repeat.tscn"), "sea scene loaded")
	check(bodies() == ["seal"], "only the seal in the sea: %s" % [bodies()])
	seal = game.level.seal
	check(seal.can_move and seal.swim_mode, "seal movement on, swim mode on")
	s0 = seal.position
	Input.action_press("right")
	await frames(10)
	check((seal.sprite as AnimatedSprite2D).animation == "swim_right", "moving right plays swim_right")
	Input.action_release("right")
	Input.action_press("up")
	await frames(10)
	check((seal.sprite as AnimatedSprite2D).animation == "swim_up", "moving up plays swim_up")
	await shot("4_seal_mini_game")
	Input.action_release("up")
	check(seal.position.distance_to(s0) > 5, "seal swims")
	check(not GameState.go(S.RUNNING_RESTAURANT), "can't skip Unlock_recipe")
	check(buttons() == ["Unlock_recipe"], "buttons: %s" % [buttons()])

	print("== Unlock_recipe")
	check(GameState.go(S.UNLOCK_RECIPE), "win mini-game")
	await frames(5)
	check(game.level_path.ends_with("new_recipe.tscn"), "new recipe screen shown")
	check(buttons() == ["Running_restaurant (new day)"], "buttons: %s" % [buttons()])
	await shot("5_unlock_recipe")

	print("== new day")
	check(GameState.go(S.RUNNING_RESTAURANT), "start next day")
	await frames(5)
	check(GameState.day == 2, "day counter is 2")
	check(game.level_path.ends_with("temp_restaurant_scene.tscn"), "back in the restaurant")


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


func live_customers() -> int:
	var n := 0
	for c in game.level.get_children():
		if c.has_node("Customer") and not c.is_queued_for_deletion():
			n += 1
	return n


func bodies() -> Array:
	var out := []
	for c in game.level.get_children():
		if c is CharacterBody2D and not c.is_queued_for_deletion():
			out.append("chef" if c.has_method("get") and c.get_script() == preload("res://sprites/chef.gd") else "seal")
	out.sort()
	return out


func shot(name: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(name + ".png"))
