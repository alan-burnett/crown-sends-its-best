class_name TurnMachine
extends RefCounted

## The spine of the game loop: date card, desk, send the post, resolution,
## repeat.
##
## SPEC §7's seven steps, with the cutscene and map-playback slots left as no-ops
## for M1. It **runs headless**, with no presentation layer attached, which is
## what lets the determinism tests and the balance harness drive a whole run.
##
## Three invariants live here:
##
## - **🔒 Order of time.** Letters sent this turn are acted on during the *next*
##   simulation step. Nothing the player writes changes the world instantly. The
##   Orders this turn's post produces become Intents, and an Intent committed in
##   one month executes in phase 2 of the next, so the **physical** consequence
##   lands a turn after the acknowledgment.
## - **🔒 Sending the post commits every decision in it and saves the game.**
## - **🔒 Changes of mind are allowed only within a turn.** Until the post is
##   sent, any outgoing letter may be reopened, rewritten, or discarded.

# --- Phases (SPEC §7) ------------------------------------------------------

const DATE_CARD: StringName = &"date_card"
const OPENING_CUTSCENES: StringName = &"opening_cutscenes"
const MAP_PLAYBACK: StringName = &"map_playback"
const DESK: StringName = &"desk"
const SENDING: StringName = &"sending"
const CLOSING_CUTSCENES: StringName = &"closing_cutscenes"
const RESOLUTION: StringName = &"resolution"

const ORDER: Array[StringName] = [
	DATE_CARD, OPENING_CUTSCENES, MAP_PLAYBACK, DESK, SENDING, CLOSING_CUTSCENES, RESOLUTION,
]

## The slots M1 leaves empty. They are in `ORDER` so the sequence is the spec's,
## and skipped cleanly so nothing has to special-case their absence later.
const STUBBED: Array[StringName] = [OPENING_CUTSCENES, MAP_PLAYBACK, CLOSING_CUTSCENES]

const EVENT_TURN_BEGAN: StringName = &"turn_began"
const EVENT_POST_SENT: StringName = &"post_sent"
const EVENT_ORDER_ISSUED: StringName = &"order_issued"

var run: RunState = null
var month_runner: WorldMonth = null

## Where letter templates come from. Supplied rather than reached for: the
## `Content` autoload only exists when the project boots normally, and this loop
## has to run headless under `--script` for the tests and the balance harness.
var content: ContentDatabase = null

## Where the post's Orders go. #16 resolves them into Intents through compliance;
## until then they are collected so the seam is visible and testable.
var issued_orders: Array[Order] = []

## Set when the post is sent, so a caller can save exactly then and no earlier.
var save_path: String = SaveGame.SAVE_PATH
var saves_on_send: bool = true


func _init(p_run: RunState) -> void:
	run = p_run
	month_runner = WorldMonth.new(run.intents, run.streams)
	month_runner.drivers = [StubWorld.new()]
	month_runner.executors = [StubIntentExecutor.new()]


# --- Driving the turn ------------------------------------------------------

## Begin a turn: the date card, the stubbed cutscene and playback slots, and then
## the desk. Stops there, because **only the desk has decisions**.
func begin_turn() -> void:
	run.phase = DATE_CARD
	run.log.emit(EVENT_TURN_BEGAN, &"run", run.world.month, {
		"turn": run.turn,
		"month": run.world.month,
		"year": run.world.year_index(),
		"month_of_year": run.world.month_of_year(),
	})
	for phase in ORDER:
		if phase == DESK:
			break
		run.phase = phase
	run.phase = DESK


func at_desk() -> bool:
	return run.phase == DESK


## Whether the post may be sent.
##
## Blocked while any incoming letter is still unread, **with a reason**, because
## a send button that simply does nothing is worse than one that explains itself.
func can_send() -> Dictionary:
	if run.phase != DESK:
		return {"ok": false, "reason": "The post can only be sent from the desk."}
	var unread := run.unread()
	if not unread.is_empty():
		return {
			"ok": false,
			"reason": "%d letter%s still unanswered." % [unread.size(), "" if unread.size() == 1 else "s"],
		}
	return {"ok": true, "reason": ""}


## Send the post: commit every Order in it, save, and resolve the month.
##
## Confirmation is the caller's job (#23) — this is the irreversible half, and it
## refuses to run while anything is unhandled.
func send_post() -> bool:
	var permission := can_send()
	if not permission["ok"]:
		push_error("The post cannot be sent: %s" % permission["reason"])
		return false

	run.phase = SENDING
	issued_orders = _build_orders()
	run.post.seal()

	run.log.emit(EVENT_POST_SENT, &"pc", run.world.month, {
		"turn": run.turn,
		"letters": run.post.size(),
		"orders": issued_orders.size(),
	}, WorldPhase.DISPATCH)

	for phase in [CLOSING_CUTSCENES, RESOLUTION]:
		run.phase = phase
		if phase == RESOLUTION:
			_resolve()

	# **The save happens as part of sending**, not on a timer and not on quit.
	#
	# After the resolution rather than before it, so that killing the process the
	# instant the post goes loses nothing: the saved state is the start of the
	# next turn, with the month already run. Saving first would leave a resume
	# holding a sealed post and a month that had not happened yet.
	if saves_on_send:
		SaveGame.save(run, save_path)

	return true


## The simulation runs. This is the **next** step relative to the post just sent,
## which is what "nothing the player writes changes the world instantly" means.
func _resolve() -> void:
	run.last_diff = month_runner.run(run.world, run.log)
	run.turn += 1
	run.inbox.clear()
	run.post = Post.new()
	run.phase = DATE_CARD


## Turn the post's choices into Orders.
##
## **An Order is never a write.** Building them here, at send time rather than as
## the player clicks, is what makes rewriting an outgoing letter free: nothing
## downstream has happened yet.
func _build_orders() -> Array[Order]:
	var orders: Array[Order] = []
	for outgoing in run.post.all():
		var letter := _letter(outgoing.letter_id)
		if letter == null:
			continue
		var context := _context_for(outgoing, letter)
		for step in letter.steps():
			var step_id := String(step.get("id", ""))
			if not outgoing.has_chosen(step_id):
				continue
			var option := _option(step, outgoing.chosen_for(step_id))
			if option.is_empty():
				continue
			for effect_id in option.get(LetterSchema.KEY_EFFECT, {}):
				var order := ContentRegistry.run_effect(
					String(effect_id), option[LetterSchema.KEY_EFFECT][effect_id], context
				)
				if order == null:
					continue
				order.id = StringName("%s.%s" % [outgoing.id, step_id])
				orders.append(order)
				run.log.emit(EVENT_ORDER_ISSUED, order.addressed_to, run.world.month,
					order.to_dict(), WorldPhase.DISPATCH)
	return orders


func _context_for(outgoing: OutgoingLetter, _letter: Letter) -> LetterContext:
	var context := LetterContext.new(run.world, run.contact(outgoing.addressed_to), outgoing.tone)
	context.diff = run.last_diff
	context.params = outgoing.params
	return context


func _letter(letter_id: String) -> Letter:
	if content == null:
		push_error("TurnMachine has no content source.")
		return null
	if not content.has_record("letters", letter_id):
		push_error("No letter '%s'." % letter_id)
		return null
	return Letter.from_record(content.record("letters", letter_id))


## The chosen option, or an empty dictionary. Typed rather than `Variant` so the
## call site stays statically typed — an inferred Variant is a parse error here.
func _option(step: Dictionary, option_id: String) -> Dictionary:
	for option in step.get(LetterSchema.KEY_OPTIONS, []):
		if String(option.get("id", "")) == option_id:
			return option
	return {}
