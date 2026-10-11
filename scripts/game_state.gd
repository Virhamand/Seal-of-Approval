extends Node
## Global game-flow state machine (autoload: GameState).
##
##   Running_restaurant <-> Walking_on_Beach <-> Talking_to_Seal -> Seal_mini_game
##          ^                                                            |
##          |_______________(new day)______ Unlock_recipe <______________|
##
## Call GameState.go(GameState.State.X). Illegal transitions are refused and
## logged, so nothing can skip a step in the diagram.

enum State {
	RUNNING_RESTAURANT,
	WALKING_ON_BEACH,
	TALKING_TO_SEAL,
	SEAL_MINI_GAME,
	UNLOCK_RECIPE,
}

## Legal next states for each state (straight from the diagram).
const TRANSITIONS := {
	State.RUNNING_RESTAURANT: [State.WALKING_ON_BEACH],
	State.WALKING_ON_BEACH: [State.RUNNING_RESTAURANT, State.TALKING_TO_SEAL],
	State.TALKING_TO_SEAL: [State.WALKING_ON_BEACH, State.SEAL_MINI_GAME],
	State.SEAL_MINI_GAME: [State.UNLOCK_RECIPE],
	State.UNLOCK_RECIPE: [State.RUNNING_RESTAURANT],
}

const NAMES := {
	State.RUNNING_RESTAURANT: "Running_restaurant",
	State.WALKING_ON_BEACH: "Walking_on_Beach",
	State.TALKING_TO_SEAL: "Talking_to_Seal",
	State.SEAL_MINI_GAME: "Seal_mini_game",
	State.UNLOCK_RECIPE: "Unlock_recipe",
}

signal state_changed(from: State, to: State)
signal day_started(day: int)

var state: State = State.RUNNING_RESTAURANT
var day := 1


func allowed_next() -> Array:
	return TRANSITIONS[state]


func can_go(to: State) -> bool:
	return to in TRANSITIONS[state]


## Move to `to` if the diagram allows it. Returns false (and changes nothing) otherwise.
func go(to: State) -> bool:
	if not can_go(to):
		push_warning("GameState: illegal transition %s -> %s" % [state_name(state), state_name(to)])
		return false
	var from := state
	state = to
	if from == State.UNLOCK_RECIPE and to == State.RUNNING_RESTAURANT:
		day += 1
		day_started.emit(day)
	print("[GameState] day %d: %s -> %s" % [day, state_name(from), state_name(to)])
	state_changed.emit(from, to)
	return true


func reset() -> void:
	state = State.RUNNING_RESTAURANT
	day = 1


func state_name(s: State) -> String:
	return NAMES[s]
