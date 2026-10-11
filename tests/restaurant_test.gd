extends Node
## Restaurant service: customers, fridge -> stove -> register, stars, walls, door,
## and the 4-day star maths. Run headless:
##   godot --headless --path . res://tests/restaurant_test.tscn  (add -- shots=/dir for screenshots)

const S := preload("res://scripts/game_state.gd").State

var checks := 0
var failures := 0
var shots_dir := ""
var game: Node


func check(cond: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			shots_dir = a.substr(6)
	await run()
	print("\n%d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func run() -> void:
	print("== 4-day maths (worst and best case, both mini-games won)")
	var worst := 0
	var best := 0
	var day_menus := [["Water", "Fries"], ["Fries", "Fish Sandwich"], ["Fish Sandwich", "Smoothie"], ["Smoothie", "Fish Soup"]]
	for d in 4:
		var low: int = GameState.stars_for(day_menus[d][0])
		var high: int = GameState.stars_for(day_menus[d][1])
		worst += GameState.customers_for_rating(worst) * low
		best += GameState.customers_for_rating(best) * high
		if d == 2:
			check(best < 100, "can't reach 100 before day 4 (best after day 3: %d)" % best)
	check(worst >= 100, "always reach 100 by the end of day 4 (worst case: %d)" % worst)
	check(GameState.customers_for_rating(0) == 2 and GameState.customers_for_rating(200) == 7, "2 customers on day 1, never more than 7")

	print("== day 1 service")
	GameState.reset()
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await wait(0.3)
	var r: Node = game.level
	r.spawn_interval = 60.0   # one customer at a time for this test
	check(game.level_path.ends_with("restaurant.tscn"), "restaurant scene loaded")
	check(GameState.customers_today == 2, "2 customers on day 1")
	check(r._tutorial != null and not r.chef.can_move, "cooking tutorial shown first, chef waits")
	check(Music.current == "interior", "restaurant music playing")
	await shot("0_tutorial")
	await wait(0.5)
	await wait(r.first_customer_delay + 1.0)
	check(r.line.is_empty(), "no customers while the tutorial is up")
	press_key()
	await wait(0.2)
	check(r._tutorial == null and r.chef.can_move and GameState.cooking_tutorial_seen, "any key closes it")
	check(game._direction_label.text == r.MORNING[1], "morning line shown after it")
	var chef: CharacterBody2D = r.chef

	print("== walls")
	chef.position = Vector2(84, 132)
	await hold("up", 1.5)
	check(chef.position.y > 100, "kitchen counter/wall stops the chef (y=%.0f)" % chef.position.y)
	chef.position = Vector2(36, 132)   # left end of the kitchen
	await hold("down", 1.6)
	check(chef.position.y > 190, "gap at the left end of the counter lets him into the dining room (y=%.0f)" % chef.position.y)
	await hold("left", 1.0)
	check(chef.position.x > 20, "outer wall stops him (x=%.0f)" % chef.position.x)
	chef.position = r.door_start
	await hold("down", 1.5)
	check(chef.position.y < 352 and GameState.state == S.RUNNING_RESTAURANT, "doormat is blocked while customers are coming (y=%.0f)" % chef.position.y)
	check(game._direction_label.text == game.DIRECTIONS.busy, "chef says he can't leave")
	chef.position = r.kitchen_start

	print("== first customer")
	await wait(r.first_customer_delay + 2.5)
	check(r.line.size() == 1 and r.line[0].order in ["Water", "Fries"], "one customer in line, ordering %s" % (r.line[0].order if r.line.size() else "-"))
	check(r.line[0].waiting and r.line[0].bubble != null and r.line[0].bubble.visible, "order bubble over their head")
	check(live_children(r._orders_box) == 1, "order listed in the panel")
	await shot("1_first_customer")

	print("== fridge / stove / register")
	var g = r.line[0]
	var order: String = g.order
	chef.position = r.cell_pos(r.fridge_cell) + Vector2(0, 24)
	await frames(2)
	await press_interact()
	check(not r.held.is_empty() and r.held.dish == order and r.held_sprite.visible, "took the item for the order")
	if GameState.is_drink(order):
		check(r.held.cooked, "a drink is ready straight from the fridge")
	else:
		check(not r.held.cooked, "food comes out as an ingredient")
		chef.position = r.stoves[0].pos + Vector2(0, 24)
		await frames(2)
		await press_interact()
		check(r.held.is_empty() and not r.stoves[0].item.is_empty() and r.stoves[0].spinner.visible, "ingredient on the stove, loading circle shown")
		await wait(r.cook_time * 0.5)
		check(r.stoves[0].progress > 0.3 and r.stoves[0].progress < 0.8, "circle fills over time (%.2f)" % r.stoves[0].progress)
		await shot("2_cooking")
		await wait(r.cook_time * 0.6)
		check(r.stoves[0].bubble != null and not r.stoves[0].spinner.visible, "dish bubble over the stove when done")
		await press_interact()
		check(r.held.dish == order and r.held.cooked, "picked the dish up")
	var before := GameState.rating
	chef.position = r.cell_pos(r.register_cell) + Vector2(0, -24)
	await frames(2)
	await press_interact()
	check(GameState.rating == before + GameState.stars_for(order), "served: +%d stars" % GameState.stars_for(order))
	check(r.held.is_empty() and not g.waiting and r.line.is_empty(), "customer leaves the line, hands empty")
	check(String(g.sprite.animation) == "happy", "customer is happy")
	await wait(0.5)
	await shot("3_served")
	await wait(6.0)
	check(not is_instance_valid(g.node), "customer walked out through the door")
	check(GameState.customers_done == 1, "1 of 2 customers done")

	print("== second customer, patience")
	r._spawn_timer = 0.5
	while r.line.is_empty():
		await wait(0.2)
	var g2 = r.line[0]
	while not g2.arrived:
		await wait(0.2)
	check(g2.patience_bar.value > 90, "patience bar full on arrival")
	g2.patience_left = 0.3
	await wait(0.6)
	check(not g2.waiting and r.line.is_empty() and GameState.rating == before + GameState.stars_for(order), "impatient customer leaves without stars")
	await wait(6.5)
	check(GameState.service_done, "service ends when the last customer has left")
	check(game._direction_label.text == game.DIRECTIONS.walk, "direction: take a walk on the beach")
	chef.position = r.door_start
	await hold("down", 1.0)
	check(GameState.state == S.WALKING_ON_BEACH, "doormat leads out to the beach after service")
	check(Music.current == "seaside", "beach music on the beach")


# ---------------------------------------------------------------- helpers
func live_children(n: Node) -> int:
	var k := 0
	for c in n.get_children():
		if not c.is_queued_for_deletion():
			k += 1
	return k


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await wait(seconds)
	Input.action_release(action)
	await frames(2)


func press_key() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_X
	ev.physical_keycode = KEY_X
	ev.pressed = true
	Input.parse_input_event(ev)


## Press F and wait until the event has been delivered (input is flushed on process frames).
func press_interact() -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame


func shot(name: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(name + ".png"))
