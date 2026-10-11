@tool
extends Node2D

# SEAL & SERVE - single-script Godot 4 game. All art is drawn in code.

enum S { MENU, HELP, SHIFT, FOOD, DRINK, DAYEND, SHORE, MINI, MINIEND, ENDING }

@export_tool_button("Draw end screen") var my_button: Callable = draw_ending

const THRESHOLD := 100   # fame needed to win
const SHIFT_LEN := 5     # customers per shift
const FOOD_P := Vector2(90, 262)
const DRINK_P := Vector2(550, 262)
const COUNTER_P := Vector2(320, 165)
const SEAL_P := Vector2(430, 215)

# steps: [prompt, correct, decoy1, decoy2]; "s" = star value (data-driven)
var FOODS = [
	{"n":"Fries","s":1,"c":Color("e8c04a"),"steps":[["Fry the potatoes","Fry","Freeze","Boil"]]},
	{"n":"Fish Sandwich","s":2,"c":Color("c98b52"),"steps":[["Pick bread","Bun","Rock","Cup"],["Add fish","Fish","Snow","Boot"],["Finish it","Lemon","Ice","Sand"]]},
	{"n":"Fish Soup","s":3,"c":Color("e0a070"),"steps":[["Heat the pot","Broth","Gravel","Tea"],["Add fish","Fish","Snow","Boot"],["Add veggies","Carrot","Candle","Soap"]]},
	{"n":"Seafood Stew","s":4,"c":Color("d0684a"),"steps":[["Heat the pot","Broth","Gravel","Tea"],["Add shrimp","Shrimp","Pebble","Sock"],["Add fish","Fish","Snow","Boot"],["Season","Salt","Glue","Paint"]]},
	{"n":"Salmon Platter","s":5,"c":Color("f08a6a"),"steps":[["Set the plate","Greens","Gravel","Wool"],["Grill salmon","Salmon","Shoe","Cloud"],["Add a side","Potato","Brick","Soap"],["Garnish","Dill","Mud","Coal"]]}
]
var DRINKS = [
	{"n":"Water","s":1,"c":Color("9fd8f0"),"steps":[["Fill a glass","Pour","Spill","Freeze"]]},
	{"n":"Berry Drink","s":2,"c":Color("c0306a"),"steps":[["Pick the juice","Berry","Gravel","Oil"],["Fill the glass","Pour","Spill","Dump"]]},
	{"n":"Hot Cocoa","s":3,"c":Color("6b3a1e"),"steps":[["Heat milk","Milk","Sand","Ice"],["Add cocoa","Cocoa","Salt","Pepper"],["Pour in mug","Pour","Spill","Dump"]]},
	{"n":"Berry Smoothie","s":4,"c":Color("d65aa0"),"steps":[["Add berries","Berry","Pebble","Soap"],["Add ice","Ice","Coal","Sand"],["Blend it","Blend","Stir","Wait"]]},
	{"n":"Iced Special","s":5,"c":Color("7fe0e8"),"steps":[["Crush ice","Ice","Glue","Rock"],["Add syrup","Syrup","Soap","Salt"],["Add a splash","Fizz","Mud","Oil"],["Pour it","Pour","Spill","Dump"]]}
]
# ordered progression list: [category, index]
var REWARDS = [["f",1],["d",1],["f",2],["d",2],["f",3],["d",3],["f",4],["d",4]]

var state = S.MENU
var day = 1
var fame = 0
var uf = [0]
var ud = [0]
var reward_idx = 0
var seal_healthy = false
var feed_stage = 0
var pp = Vector2(320, 230)
var face = 1.0
var held_f = -1
var held_d = -1
var cust = null
var served = 0
var next_t = 1.0
var day_stars = 0
var popup_stars = 0
var popup_t = 0.0
var msg = ""
var msg_t = 0.0
var prep_r = -1
var prep_step = 0
var opts = []
var btns = []
var tt = 0.0
# minigame
var sp = Vector2(320, 180)
var items = []
var spawn_t = 0.0
var tleft = 35.0
var got_f = 0
var got_w = 0
var need = 4
var mini_ok = false
var unlock_text = ""

# ---------------------------------------------------------------- flow
func reset_game():
	day = 1; fame = 0
	uf = [0]; ud = [0]
	reward_idx = 0
	seal_healthy = false; feed_stage = 0
	start_shift()

func start_shift():
	served = 0; cust = null; held_f = -1; held_d = -1
	next_t = 1.0; day_stars = 0; popup_t = 0.0
	prep_r = -1
	pp = Vector2(320, 230)
	state = S.SHIFT

func say(s):
	msg = s; msg_t = 2.0

func spawn_customer():
	cust = {"f": uf.pick_random(), "d": ud.pick_random()}

func serve():
	var ok_f = held_f == cust["f"]
	var ok_d = held_d == cust["d"]
	var full = FOODS[cust["f"]]["s"] + DRINKS[cust["d"]]["s"]
	var st = 0
	if ok_f and ok_d: st = full
	elif ok_f or ok_d: st = int(full * 0.5)
	fame += st; day_stars += st
	popup_stars = st; popup_t = 1.6
	cust = null; held_f = -1; held_d = -1
	served += 1; next_t = 1.7
	if fame >= THRESHOLD:
		fame = THRESHOLD
		state = S.ENDING

func do_unlock():
	if reward_idx >= REWARDS.size():
		unlock_text = "Menu complete! No more recipes to unlock."
		return
	var r = REWARDS[reward_idx]
	reward_idx += 1
	if r[0] == "f":
		uf.append(r[1]); unlock_text = "New food unlocked: " + FOODS[r[1]]["n"]
	else:
		ud.append(r[1]); unlock_text = "New drink unlocked: " + DRINKS[r[1]]["n"]

func start_mini():
	state = S.MINI
	sp = Vector2(320, 180); items = []; spawn_t = 0.2
	tleft = 35.0; got_f = 0; got_w = 0
	need = 4 + min((day - 1) / 3, 3)

func end_mini(ok):
	mini_ok = ok
	unlock_text = ""
	if ok: do_unlock()
	state = S.MINIEND

# ---------------------------------------------------------------- update
func _process(delta):
	tt += delta
	if popup_t > 0: popup_t -= delta
	if msg_t > 0: msg_t -= delta
	match state:
		S.SHIFT, S.FOOD, S.DRINK:
			if state == S.SHIFT: move_player(delta, Rect2(20, 130, 600, 200))
			if cust == null and state == S.SHIFT:
				next_t -= delta
				if next_t <= 0:
					if served < SHIFT_LEN: spawn_customer()
					else: state = S.DAYEND
		S.SHORE:
			move_player(delta, Rect2(20, 130, 600, 200))
		S.MINI:
			update_mini(delta)
	queue_redraw()

func dir_vec():
	var v = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): v.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): v.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): v.y += 1
	return v

func move_player(delta, r):
	var v = dir_vec()
	if v != Vector2.ZERO:
		pp += v.normalized() * 110.0 * delta
		if v.x != 0: face = sign(v.x)
	pp = pp.clamp(r.position, r.end)

func update_mini(delta):
	tleft -= delta
	var v = dir_vec()
	if v != Vector2.ZERO:
		sp += v.normalized() * 170.0 * delta
		if v.x != 0: face = sign(v.x)
	sp = sp.clamp(Vector2(24, 60), Vector2(616, 340))
	spawn_t -= delta
	if spawn_t <= 0 and items.size() < 8:
		items.append({"p": Vector2(randf_range(30, 610), randf_range(65, 340)), "t": randi() % 2})
		spawn_t = 0.55
	for it in items.duplicate():
		if sp.distance_to(it["p"]) < 22:
			if it["t"] == 0: got_f = min(got_f + 1, need)
			else: got_w = min(got_w + 1, need)
			items.erase(it)
	if got_f >= need and got_w >= need: end_mini(true)
	elif tleft <= 0: end_mini(false)

# ---------------------------------------------------------------- input
func near(p, d): return pp.distance_to(p) < d

func _unhandled_input(e):
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for b in btns:
			if b[0].has_point(e.position):
				on_btn(b[1]); return
	if e is InputEventKey and e.pressed and not e.echo:
		var k = e.keycode
		var act = (k == KEY_E or k == KEY_SPACE)
		var ent = (k == KEY_ENTER or k == KEY_KP_ENTER)
		match state:
			S.MENU:
				if ent: reset_game()
			S.HELP:
				if ent or k == KEY_ESCAPE: state = S.MENU
			S.SHIFT:
				if act: interact_shift()
				elif k == KEY_Q and cust == null: state = S.DAYEND
			S.FOOD, S.DRINK:
				if k == KEY_ESCAPE: prep_r = -1; state = S.SHIFT
			S.DAYEND:
				if ent: state = S.SHORE; pp = Vector2(120, 260)
			S.SHORE:
				if act: interact_shore()
			S.MINIEND:
				if ent: day += 1; start_shift()

func interact_shift():
	if near(FOOD_P, 75):
		if cust != null: state = S.FOOD; prep_r = -1
		else: say("Waiting for a customer...")
	elif near(DRINK_P, 75):
		if cust != null: state = S.DRINK; prep_r = -1
		else: say("Waiting for a customer...")
	elif near(COUNTER_P, 75):
		if cust == null: say("No customer at the counter.")
		elif held_f >= 0 and held_d >= 0: serve()
		else: say("Need food AND a drink first!")

func interact_shore():
	if not near(SEAL_P, 65): return
	if not seal_healthy:
		feed_stage += 1
		if feed_stage == 1: say("The seal nibbles the fish... now some water!")
		else:
			seal_healthy = true
			say("The seal perks up! Press E to play.")
	else:
		start_mini()

func cur_list(): return FOODS if state == S.FOOD else DRINKS

func on_btn(id):
	match id:
		"start": reset_game()
		"help": state = S.HELP
		"back": state = S.MENU
		"cancel": prep_r = -1; state = S.SHIFT
		_:
			if id.begins_with("pick:"):
				prep_r = int(id.substr(5)); prep_step = 0; make_opts()
			elif id.begins_with("opt:"):
				choose(int(id.substr(4)))

func make_opts():
	var st = cur_list()[prep_r]["steps"][prep_step]
	opts = [st[1], st[2], st[3]]
	opts.shuffle()

func choose(i):
	var rec = cur_list()[prep_r]
	var st = rec["steps"][prep_step]
	if opts[i] == st[1]:
		prep_step += 1
		if prep_step >= rec["steps"].size():
			if state == S.FOOD: held_f = prep_r
			else: held_d = prep_r
			say("Ready: " + rec["n"])
			prep_r = -1
			state = S.SHIFT
		else:
			make_opts()
	else:
		say("Not that one!")

# ---------------------------------------------------------------- draw helpers
func txt(s, p, size = 12, col = Color.WHITE):
	draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func ctxt(s, y, size = 12, col = Color.WHITE):
	draw_string(ThemeDB.fallback_font, Vector2(0, y), s, HORIZONTAL_ALIGNMENT_CENTER, W(), size, col)

func W(): return 640.0

func box(x, y, w, h, c): draw_rect(Rect2(x, y, w, h), c)

func btn(id, r, label, col = Color("3d6f8f")):
	var hov = r.has_point(get_local_mouse_position())
	draw_rect(r, col.lightened(0.25) if hov else col)
	draw_rect(r, Color("14202b"), false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 4),
		label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, Color.WHITE)
	btns.append([r, id])

func ell(c, rx, ry):
	var pts = PackedVector2Array()
	for i in 20:
		var a = i * TAU / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func draw_star(c, r, col):
	var pts = PackedVector2Array()
	for i in 10:
		var a = -PI / 2 + i * PI / 5
		var rr = r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)

func fame_bar(x, y, w):
	box(x, y, w, 14, Color("1a1410"))
	box(x + 1, y + 1, (w - 2) * float(fame) / THRESHOLD, 12, Color("f5c542"))
	draw_rect(Rect2(x, y, w, 14), Color("f0e6d0"), false, 1.0)
	draw_star(Vector2(x - 10, y + 7), 7, Color("f5c542"))
	txt("%d/%d" % [fame, THRESHOLD], Vector2(x + w * 0.5 - 14, y + 11), 10, Color.WHITE)

func draw_person(p, shirt, chef):
	box(p.x - 4, p.y + 8, 3, 4, Color("2b2b3a")); box(p.x + 1, p.y + 8, 3, 4, Color("2b2b3a"))
	box(p.x - 5, p.y - 4, 10, 12, shirt)
	box(p.x - 4, p.y - 12, 8, 8, Color("f2c9a0"))
	box(p.x - 4, p.y - 13, 8, 3, Color("5a3a22"))
	if chef: box(p.x - 4, p.y - 18, 8, 5, Color.WHITE)

func draw_food(i, p):
	box(p.x - 9, p.y + 3, 18, 4, Color("f0f0f0"))
	box(p.x - 7, p.y - 5, 14, 8, FOODS[i]["c"])
	box(p.x - 7, p.y - 5, 14, 2, FOODS[i]["c"].lightened(0.3))

func draw_drink(i, p):
	box(p.x - 5, p.y - 7, 10, 14, Color(1, 1, 1, 0.45))
	box(p.x - 4, p.y - 2, 8, 8, DRINKS[i]["c"])
	draw_rect(Rect2(p.x - 5, p.y - 7, 10, 14), Color("dfeff7"), false, 1.0)

func draw_seal(p, flip, starving, s = 1.0):
	draw_set_transform(p, 0, Vector2(flip * s, s))
	var body = Color("858b93") if starving else Color("6e757d")
	draw_colored_polygon(PackedVector2Array([Vector2(-18, 0), Vector2(-32, -7), Vector2(-32, 7)]), body)
	draw_colored_polygon(ell(Vector2(4, -12), 7, 3), body)
	draw_colored_polygon(ell(Vector2(4, 12), 7, 3), body)
	draw_colored_polygon(ell(Vector2.ZERO, 23, 11), body)
	draw_colored_polygon(ell(Vector2(2, 2), 16, 5), body.lightened(0.2))
	draw_circle(Vector2(19, 0), 8, body.lightened(0.05))
	draw_circle(Vector2(26, 0), 2.5, Color("1c1f24"))
	for ey in [-4.0, 4.0]:
		var e = Vector2(21, ey)
		if starving:
			draw_line(e + Vector2(-2, -2), e + Vector2(2, 2), Color("1c1f24"), 1.5)
			draw_line(e + Vector2(-2, 2), e + Vector2(2, -2), Color("1c1f24"), 1.5)
		else:
			draw_circle(e, 1.8, Color("0f1114"))
			draw_circle(e + Vector2(0.5, -0.5), 0.6, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func panel(x, y, w, h):
	box(x, y, w, h, Color(0.1, 0.07, 0.05, 0.93))
	draw_rect(Rect2(x, y, w, h), Color("f0e6d0"), false, 2.0)

# ---------------------------------------------------------------- draw scenes
func _draw():
	btns.clear()
	match state:
		S.MENU: draw_menu()
		S.HELP: draw_menu(); draw_help()
		S.SHIFT, S.FOOD, S.DRINK:
			draw_restaurant()
			if state != S.SHIFT: draw_prep()
		S.DAYEND:
			draw_restaurant()
			panel(160, 80, 320, 190)
			ctxt("Day %d complete!" % day, 112, 18, Color("f5c542"))
			ctxt("Stars earned today: %d" % day_stars, 146, 13)
			fame_bar(240, 164, 200)
			ctxt("A noise drifts in from the beach...", 206, 12, Color("bcd6e6"))
			ctxt("Press ENTER to go to the shore", 250, 12)
		S.SHORE: draw_shore()
		S.MINI: draw_mini()
		S.MINIEND:
			draw_mini()
			panel(150, 90, 340, 170)
			if mini_ok:
				ctxt("The seal is full and happy!", 124, 16, Color("8fe08f"))
				ctxt(unlock_text, 160, 13, Color("f5c542"))
			else:
				ctxt("Out of time...", 124, 16, Color("f08a6a"))
				ctxt("No new recipe today.", 158, 12)
				ctxt("Your menu and fame are safe.", 176, 12)
			ctxt("Press ENTER for the next day", 236, 12)
		S.ENDING: draw_ending()
	if msg_t > 0 and state in [S.SHIFT, S.FOOD, S.DRINK, S.SHORE]:
		ctxt(msg, 346, 12, Color("ffe9a8"))

func draw_menu():
	box(0, 0, 640, 360, Color("2a6f9e"))
	box(0, 200, 640, 160, Color("e8f0f5"))
	box(0, 192, 640, 10, Color("bcd6e6"))
	for i in 8:
		box(fmod(i * 100.0 + tt * 12.0, 700.0) - 40, 40 + (i % 4) * 36, 30, 2, Color("7fb6dc"))
	draw_seal(Vector2(320, 150), 1.0, false, 2.0)
	ctxt("SEAL & SERVE", 78, 40, Color("fff4d6"))
	btn("start", Rect2(240, 230, 160, 32), "Start Game", Color("c97b2a"))
	btn("help", Rect2(240, 272, 160, 32), "How to Play")
	ctxt("(or press ENTER)", 330, 10, Color("4a6578"))

func draw_help():
	panel(100, 40, 440, 280)
	ctxt("HOW TO PLAY", 70, 16, Color("f5c542"))
	var lines = [
		"WASD / arrows: move      E or SPACE: interact",
		"",
		"RESTAURANT: stand at FOOD or DRINKS, press E,",
		"pick the recipe and click the right ingredients.",
		"Hold both items, then press E at the COUNTER.",
		"Stars from orders fill the Fame bar.",
		"",
		"SHORE: feed the seal, then catch all the fish",
		"and water drops before time runs out.",
		"Win = a new recipe! Lose = try again tomorrow.",
		"",
		"Fill the Fame bar to become a star restaurant!"]
	for i in lines.size():
		txt(lines[i], Vector2(125, 98 + i * 16), 12)
	btn("back", Rect2(270, 290, 100, 24), "Back")

func draw_restaurant():
	box(0, 0, 640, 360, Color("7a5233"))
	box(0, 0, 640, 110, Color("8c6a45"))
	box(0, 0, 640, 26, Color("4a3020"))
	for i in range(0, 640, 32): box(i, 110, 1, 250, Color("6a4528"))
	# windows (snowy outside)
	for wx in [40, 560]:
		box(wx, 4, 44, 18, Color("cfe6f5")); box(wx + 21, 4, 2, 18, Color("4a3020"))
	# counter
	box(180, 110, 280, 34, Color("4a2f1c")); box(180, 110, 280, 6, Color("6b4529"))
	txt("COUNTER", Vector2(290, 136), 10, Color("d9b88a"))
	# stations
	box(30, 225, 120, 80, Color("8a8f94")); box(30, 225, 120, 10, Color("b4babf"))
	txt("FOOD", Vector2(74, 270), 12, Color.WHITE)
	box(490, 225, 120, 80, Color("5b7f9e")); box(490, 225, 120, 10, Color("86a9c5"))
	txt("DRINKS", Vector2(532, 270), 12, Color.WHITE)
	# customer + order bubble
	if cust != null:
		draw_person(Vector2(320, 80), Color("c0504d"), false)
		box(370, 26, 210, 70, Color("fff4d6")); draw_rect(Rect2(370, 26, 210, 70), Color("4a2f1c"), false, 2.0)
		txt("ORDER", Vector2(378, 40), 10, Color("8a5a2b"))
		draw_food(cust["f"], Vector2(392, 62)); txt(FOODS[cust["f"]]["n"], Vector2(410, 66), 12, Color("2b1e14"))
		draw_drink(cust["d"], Vector2(392, 84)); txt(DRINKS[cust["d"]]["n"], Vector2(410, 88), 12, Color("2b1e14"))
		if held_f == cust["f"]: txt("OK", Vector2(552, 66), 12, Color("2e8b2e"))
		if held_d == cust["d"]: txt("OK", Vector2(552, 88), 12, Color("2e8b2e"))
	# player
	draw_person(pp, Color("3a7bd5"), true)
	if held_f >= 0: draw_food(held_f, pp + Vector2(-12, -30))
	if held_d >= 0: draw_drink(held_d, pp + Vector2(12, -30))
	# prompts
	if state == S.SHIFT and cust != null:
		if near(FOOD_P, 75): txt("[E] Make food", Vector2(40, 215), 12, Color("ffe9a8"))
		if near(DRINK_P, 75): txt("[E] Make drink", Vector2(500, 215), 12, Color("ffe9a8"))
		if near(COUNTER_P, 75): txt("[E] Serve", Vector2(296, 190), 12, Color("ffe9a8"))
	# HUD
	box(0, 0, 640, 26, Color(0, 0, 0, 0.35))
	txt("Day %d" % day, Vector2(10, 17), 13)
	fame_bar(210, 6, 220)
	txt("Served %d/%d" % [served, SHIFT_LEN], Vector2(530, 17), 12)
	txt("WASD move   E interact   Q end shift", Vector2(10, 354), 10, Color("d9b88a"))
	if popup_t > 0:
		var py = 140.0 - (1.6 - popup_t) * 10.0
		ctxt("+%d stars!" % popup_stars if popup_stars > 0 else "No stars...", py, 16, Color("f5c542"))
		for i in popup_stars:
			draw_star(Vector2(320 - popup_stars * 8 + i * 16 + 8, py + 18), 7, Color("f5c542"))

func draw_prep():
	panel(110, 112, 420, 240)
	var rec_list = cur_list()
	var unl = uf if state == S.FOOD else ud
	ctxt("FOOD STATION" if state == S.FOOD else "DRINK STATION", 134, 14, Color("f5c542"))
	if prep_r < 0:
		for k in unl.size():
			var i = unl[k]
			btn("pick:%d" % i, Rect2(150, 146 + k * 33, 220, 28),
				"%s  (%d stars)" % [rec_list[i]["n"], rec_list[i]["s"]])
	else:
		var rec = rec_list[prep_r]
		var st = rec["steps"][prep_step]
		ctxt("Making: " + rec["n"], 160, 14)
		ctxt("Step %d of %d" % [prep_step + 1, rec["steps"].size()], 180, 11, Color("bcd6e6"))
		ctxt(st[0] + "!", 208, 14, Color("ffe9a8"))
		for i in opts.size():
			btn("opt:%d" % i, Rect2(130 + i * 130, 232, 120, 36), opts[i], Color("c97b2a"))
	btn("cancel", Rect2(410, 318, 110, 26), "Back [Esc]", Color("6a4a3a"))

func draw_shore():
	box(0, 0, 640, 360, Color("e8f0f5"))
	box(0, 0, 640, 108, Color("2a6f9e"))
	for i in 9:
		box(fmod(i * 85.0 + tt * 14.0, 700.0) - 40, 20 + (i % 4) * 22, 34, 2, Color("7fb6dc"))
	box(0, 100, 640, 14, Color("bcd6e6"))
	for r in [Vector2(60, 140), Vector2(540, 300), Vector2(260, 320), Vector2(590, 160)]:
		draw_colored_polygon(ell(r, 18, 11), Color("7d868f"))
		draw_colored_polygon(ell(r + Vector2(-3, -3), 12, 6), Color("a2abb4"))
	draw_seal(SEAL_P, -1.0, not seal_healthy)
	draw_person(pp, Color("3a7bd5"), true)
	box(0, 0, 640, 26, Color(0, 0, 0, 0.35))
	txt("Day %d  -  Alaskan Shore" % day, Vector2(10, 17), 13)
	fame_bar(480, 6, 150)
	if not seal_healthy:
		ctxt("A seal lies weak on the snow. It looks starving!", 54, 13, Color("2b1e14"))
	if near(SEAL_P, 65):
		var t = "[E] Give fish" if (not seal_healthy and feed_stage == 0) else ("[E] Give water" if not seal_healthy else "[E] Start feeding game")
		ctxt(t, 175, 13, Color("1c3a5a"))
	else:
		txt("Walk to the seal (WASD)", Vector2(10, 354), 11, Color("4a6578"))

func draw_mini():
	box(0, 0, 640, 360, Color("1f5f99"))
	for i in 14:
		box(fmod(i * 61.0 + tt * 18.0, 680.0) - 30, 50 + (i * 47) % 300, 28, 2, Color("3a82bd"))
	for ice in [Vector2(90, 280), Vector2(540, 110), Vector2(470, 300)]:
		draw_colored_polygon(ell(ice, 26, 14), Color("dfeff7"))
	for it in items:
		if it["t"] == 0:
			draw_colored_polygon(ell(it["p"], 9, 5), Color("f08a3a"))
			draw_colored_polygon(PackedVector2Array([it["p"] + Vector2(-8, 0), it["p"] + Vector2(-14, -5), it["p"] + Vector2(-14, 5)]), Color("f08a3a"))
		else:
			draw_circle(it["p"], 7, Color("bfefff")); draw_circle(it["p"] + Vector2(-2, -2), 2, Color.WHITE)
	draw_seal(sp, face, false)
	box(0, 0, 640, 48, Color(0, 0, 0, 0.4))
	txt("Hunger", Vector2(10, 18), 11)
	box(70, 8, 150, 12, Color("1a1410")); box(71, 9, 148.0 * got_f / need, 10, Color("f08a3a"))
	txt("Thirst", Vector2(10, 38), 11)
	box(70, 28, 150, 12, Color("1a1410")); box(71, 29, 148.0 * got_w / need, 10, Color("8fdcff"))
	ctxt("%d" % ceil(max(tleft, 0.0)), 34, 26, Color.WHITE)
	txt("Catch fish + water!", Vector2(500, 28), 12)

func draw_ending():
	box(0, 0, 640, 360, Color("2a6f9e"))
	box(0, 230, 640, 130, Color("e8f0f5"))
	for i in 24:
		var x = fmod(i * 97.0, 640.0)
		var y = fmod(i * 53.0 + tt * (40 + (i % 5) * 12), 380.0) - 10
		draw_star(Vector2(x, y), 5 + (i % 3), Color("f5c542") if i % 2 == 0 else Color("fff4d6"))
	draw_seal(Vector2(320, 190), 1.0, false, 2.5)
	ctxt("Seal of Approval \u2014 You're famous now!", 74, 24, Color("fff4d6"))
	ctxt("Your shoreline restaurant is the talk of Alaska!", 100, 12, Color("ffe9a8"))
	fame_bar(220, 120, 200)
	ctxt("Finished in %d days with %d recipes" % [day, uf.size() + ud.size()], 150, 12, Color.WHITE)
	btn("start", Rect2(190, 290, 120, 32), "New Game", Color("c97b2a"))
	btn("back", Rect2(330, 290, 120, 32), "Main Menu")