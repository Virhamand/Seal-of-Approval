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

## Recipes unlocked one per mini-game win, in the legacy game's order.
const RECIPE_ORDER := ["Fish Sandwich", "Berry Drink", "Fish Soup", "Hot Cocoa",
		"Seafood Stew", "Berry Smoothie", "Salmon Platter", "Iced Special"]

signal state_changed(from: State, to: State)
signal day_started(day: int)
signal recipe_unlocked(recipe: String)

var state: State = State.RUNNING_RESTAURANT
var day := 1
var unlocked_recipes: Array[String] = ["Fries", "Water"]
## True between finishing the mini-game and starting the next day.
var result_pending := false
## Whether the last mini-game was won (caught every fish before time ran out).
var last_won := false
## The recipe shown on the pop-up ("" when lost or the menu is already complete).
var last_recipe := ""
# Result used by the next Seal_mini_game -> Talking_to_Seal move. Defaults to a
# win so the temporary debug button still works as a "skip".
var _next_result_won := true


func allowed_next() -> Array:
	if state == State.TALKING_TO_SEAL and result_pending:
		return [State.RUNNING_RESTAURANT]
	return TRANSITIONS[state]


func can_go(to: State) -> bool:
	return to in allowed_next()


## Move to `to` if the diagram allows it. Returns false (and changes nothing) otherwise.
func go(to: State) -> bool:
	if not can_go(to):
		push_warning("GameState: illegal transition %s -> %s" % [state_name(state), state_name(to)])
		return false
	var from := state
	state = to
	if from == State.SEAL_MINI_GAME and to == State.TALKING_TO_SEAL:
		_finish_mini_game(_next_result_won)
		_next_result_won = true
	elif from == State.TALKING_TO_SEAL and to == State.RUNNING_RESTAURANT:
		result_pending = false
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


func reset() -> void:
	state = State.RUNNING_RESTAURANT
	day = 1
	unlocked_recipes = ["Fries", "Water"]
	result_pending = false
	last_won = false
	last_recipe = ""
	_next_result_won = true


func state_name(s: State) -> String:
	return NAMES[s]
