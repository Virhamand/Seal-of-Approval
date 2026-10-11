extends Node
## Global game-flow state machine (autoload: GameState).
##
##   Running_restaurant <-> Walking_on_Beach <-> Talking_to_Seal -> Seal_mini_game
##          ^                                       |      ^               |
##          |___(new day: click/key on recipe)______|      |_______________|
##
## Finishing the mini-game (win or time-out) returns to Talking_to_Seal with
## the result waiting on a pop-up. While a result is waiting, the only way out
## of Talking_to_Seal is the next day (Running_restaurant).
## Illegal transitions are refused and logged.
##
## Story: on day 1 the seal is found fainted on the shore and must be fed
## (Talking_to_Seal -> feed_seal()), which unlocks the first recipe without a
## mini-game. Once the rating bar is full, talking to the seal ends the game.

enum State {
	RUNNING_RESTAURANT,
	WALKING_ON_BEACH,
	TALKING_TO_SEAL,
	SEAL_MINI_GAME,
}

## Normal legal next states (straight from the diagram).
const TRANSITIONS := {
	State.RUNNING_RESTAURANT: [State.WALKING_ON_BEACH],
	State.WALKING_ON_BEACH: [State.RUNNING_RESTAURANT, State.TALKING_TO_SEAL],
	State.TALKING_TO_SEAL: [State.WALKING_ON_BEACH, State.SEAL_MINI_GAME],
	State.SEAL_MINI_GAME: [State.TALKING_TO_SEAL],
}

const NAMES := {
	State.RUNNING_RESTAURANT: "Running_restaurant",
	State.WALKING_ON_BEACH: "Walking_on_Beach",
	State.TALKING_TO_SEAL: "Talking_to_Seal",
	State.SEAL_MINI_GAME: "Seal_mini_game",
}

## Recipes unlocked one per win (the first one by feeding the seal on day 1).
## Fries and Water are on the menu from the start.
const RECIPE_ORDER := ["Fish Sandwich", "Smoothie", "Fish Soup", "Fizzy Drink",
		"Seafood Stew", "Salmon Platter"]

## The menu: stars a dish earns when served, and what the chef takes out of the
## fridge to make it ("" = a drink, served straight from the fridge).
## Later dishes are worth a lot more, so a 4-day run reaches 100 stars
## (see customers_for_rating() and pick_order()).
const MENU := {
	"Water": {"stars": 3, "ingredient": ""},
	"Fries": {"stars": 4, "ingredient": "potato"},
	"Fish Sandwich": {"stars": 8, "ingredient": "fish"},
	"Smoothie": {"stars": 10, "ingredient": ""},
	"Fish Soup": {"stars": 16, "ingredient": "fish"},
	"Fizzy Drink": {"stars": 24, "ingredient": ""},
	"Seafood Stew": {"stars": 36, "ingredient": "fish"},
	"Salmon Platter": {"stars": 50, "ingredient": "fish"},
}
const INGREDIENT_ICONS := {
	"potato": "res://sprites/sprite_sheets/potato.png",
	"fish": "res://sprites/sprite_sheets/fish_B_snapper.png",   # first frame
}
## Customers per day: MIN_CUSTOMERS + one more per CUSTOMERS_PER_STARS stars, up to MAX_CUSTOMERS.
const MIN_CUSTOMERS := 2
const MAX_CUSTOMERS := 7
const CUSTOMERS_PER_STARS := 7.0
## Customers order the newest dish NEWEST_WEIGHT times as often as the one before it.
const NEWEST_WEIGHT := 2

## 16x16 menu icon for every recipe.
const RECIPE_ICONS := {
	"Fries": "res://sprites/sprite_sheets/fries_A.png",
	"Water": "res://sprites/sprite_sheets/water_A.png",
	"Fish Sandwich": "res://sprites/sprite_sheets/fish_sandwich_A.png",
	"Smoothie": "res://sprites/sprite_sheets/smoothie_A.png",
	"Fish Soup": "res://sprites/sprite_sheets/fish_soup_A.png",
	"Fizzy Drink": "res://sprites/sprite_sheets/fizzy_drink_B.png",
	"Seafood Stew": "res://sprites/sprite_sheets/seafood_stew_A.png",
	"Salmon Platter": "res://sprites/sprite_sheets/salmon_platter_A.png",
}


## The menu icon for `recipe`, or null if it has none.
static func recipe_icon(recipe: String) -> Texture2D:
	return load(RECIPE_ICONS[recipe]) if recipe in RECIPE_ICONS else null

signal state_changed(from: State, to: State)
signal day_started(day: int)
signal recipe_unlocked(recipe: String)
## A result (recipe pop-up) became ready without a state change, e.g. after feeding.
signal result_ready
signal rating_changed(value: int)
signal ending_reached
signal restarted
## The restaurant finished serving everyone for the day (see end_service()).
signal service_finished

const RATING_MAX := 100

var state: State = State.RUNNING_RESTAURANT
var day := 1
var unlocked_recipes: Array[String] = ["Water", "Fries"]
## True between finishing the mini-game and starting the next day.
var result_pending := false
## Whether the last mini-game was won (caught every fish before time ran out).
var last_won := false
## The recipe shown on the pop-up ("" when lost or the menu is already complete).
var last_recipe := ""
# Result used by the next Seal_mini_game -> Talking_to_Seal move. Defaults to a
# win so the temporary debug button still works as a "skip".
var _next_result_won := true

## Restaurant rating, 0..RATING_MAX. The restaurant adds to it with add_rating().
var rating := 0
## Day-1 story beat: has the fainted seal been fed yet?
var seal_fed := false
## The congratulation talk has happened and the end screen is showing.
var ending := false
## The state we came from on the last transition.
var previous_state: State = State.RUNNING_RESTAURANT
## Where the chef stood on the beach last time (kept across visits).
var beach_chef_position := Vector2.INF
## Today's customers have all been served (the restaurant calls end_service()).
var service_done := false
## The player has interacted with the seal today (it stops calling).
var seal_answered := false
## The mini-game tutorial has been shown.
var tutorial_seen := false
## The cooking tutorial (first day in the restaurant) has been shown.
var cooking_tutorial_seen := false
## Today's service: how many customers come, and how many have been dealt with.
var customers_today := 0
var customers_done := 0


func allowed_next() -> Array:
	if state == State.TALKING_TO_SEAL and result_pending:
		return [State.RUNNING_RESTAURANT]
	if state == State.TALKING_TO_SEAL and not seal_fed:
		return [State.WALKING_ON_BEACH]   # no mini-game until the seal has been fed
	return TRANSITIONS[state]


func can_go(to: State) -> bool:
	return to in allowed_next()


## Move to `to` if the diagram allows it. Returns false (and changes nothing) otherwise.
func go(to: State) -> bool:
	if not can_go(to):
		push_warning("GameState: illegal transition %s -> %s" % [state_name(state), state_name(to)])
		return false
	var from := state
	previous_state = from
	state = to
	if to == State.TALKING_TO_SEAL:
		seal_answered = true
	if from == State.SEAL_MINI_GAME and to == State.TALKING_TO_SEAL:
		_finish_mini_game(_next_result_won)
		_next_result_won = true
	elif from == State.TALKING_TO_SEAL and to == State.RUNNING_RESTAURANT:
		result_pending = false
		service_done = false
		seal_answered = false
		customers_today = 0
		customers_done = 0
		day += 1
		day_started.emit(day)
	print("[GameState] day %d: %s -> %s" % [day, state_name(from), state_name(to)])
	state_changed.emit(from, to)
	return true


## Called by the mini-game when it ends. won = caught every fish in time.
func end_mini_game(won: bool) -> bool:
	_next_result_won = won
	return go(State.TALKING_TO_SEAL)


func _finish_mini_game(won: bool) -> void:
	result_pending = true
	last_won = won
	last_recipe = ""
	if won:
		for r in RECIPE_ORDER:
			if r not in unlocked_recipes:
				last_recipe = r
				unlocked_recipes.append(r)
				break
		recipe_unlocked.emit(last_recipe)


# ---------------------------------------------------------------- rating
func add_rating(amount: int) -> void:
	set_rating(rating + amount)


func set_rating(value: int) -> void:
	rating = clampi(value, 0, RATING_MAX)
	rating_changed.emit(rating)


func is_rating_full() -> bool:
	return rating >= RATING_MAX


# ---------------------------------------------------------------- service
## For the restaurant: call this once the last customer of the day is served.
## From day 2 on, the seal starts calling from the shore.
func end_service() -> void:
	if service_done:
		return
	service_done = true
	service_finished.emit()


## Work out today's customer count from the rating (once per day).
func start_service() -> void:
	if customers_today == 0:
		customers_today = customers_for_rating(rating)


static func customers_for_rating(stars: int) -> int:
	return clampi(MIN_CUSTOMERS + int(stars / CUSTOMERS_PER_STARS), MIN_CUSTOMERS, MAX_CUSTOMERS)


## What the next customer orders: the newest dish most of the time, otherwise the one before it.
func pick_order() -> String:
	var n := unlocked_recipes.size()
	if n < 2 or randi() % (NEWEST_WEIGHT + 1) < NEWEST_WEIGHT:
		return unlocked_recipes[n - 1]
	return unlocked_recipes[n - 2]


static func stars_for(recipe: String) -> int:
	return MENU[recipe].stars if recipe in MENU else 1


static func ingredient_of(recipe: String) -> String:
	return MENU[recipe].ingredient if recipe in MENU else ""


static func is_drink(recipe: String) -> bool:
	return ingredient_of(recipe) == ""


## The 16x16 picture of an ingredient ("potato", "fish").
static func ingredient_icon(ingredient: String) -> Texture2D:
	if ingredient not in INGREDIENT_ICONS:
		return null
	var tex: Texture2D = load(INGREDIENT_ICONS[ingredient])
	if ingredient == "fish":
		var frame := AtlasTexture.new()   # the fish sheet: take the first swim frame
		frame.atlas = tex
		frame.region = Rect2(0, 0, 16, 16)
		return frame
	return tex


## Should the seal be making its call right now?
func seal_calling() -> bool:
	return seal_fed and day >= 2 and service_done and not seal_answered and not ending


# ---------------------------------------------------------------- story
## Day 1: the player fed the fainted seal. Unlocks the first recipe and shows
## the recipe pop-up (the next day starts when it is dismissed).
func feed_seal() -> void:
	if seal_fed:
		return
	seal_fed = true
	_finish_mini_game(true)
	result_ready.emit()


## The seal has congratulated the player: show the end screen.
func reach_ending() -> void:
	ending = true
	ending_reached.emit()


## Start a brand new game from day 1.
func restart() -> void:
	var from := state
	reset()
	restarted.emit()
	state_changed.emit(from, state)


func reset() -> void:
	state = State.RUNNING_RESTAURANT
	day = 1
	unlocked_recipes = ["Water", "Fries"]
	result_pending = false
	last_won = false
	last_recipe = ""
	_next_result_won = true
	rating = 0
	seal_fed = false
	ending = false
	previous_state = State.RUNNING_RESTAURANT
	beach_chef_position = Vector2.INF
	service_done = false
	seal_answered = false
	tutorial_seen = false
	cooking_tutorial_seen = false
	customers_today = 0
	customers_done = 0
	rating_changed.emit(rating)


func state_name(s: State) -> String:
	return NAMES[s]
