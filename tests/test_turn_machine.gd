extends TestCase

## The turn state machine (#7), and the invariants it enforces.

const SEED: int = 1789
const PATH: String = "user://test_turn.save"

var run: RunState = null
var machine: TurnMachine = null
var content: ContentDatabase = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	SaveGame.delete_save(PATH)

	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)

	run = RunState.new_run(SEED)
	run.add_contact(Contact.from_data({"id": "marshal", "name": "Vane", "role": "crown_officer"}))
	machine = TurnMachine.new(run)
	machine.use_content(content)
	machine.save_path = PATH


func after_each() -> void:
	SaveGame.delete_save(PATH)
	reset_world()
	content.free()


## Open the desk and deal with whatever the director delivered.
##
## Setting a letter aside counts as handling it, so this clears the desk without
## answering anything — which is what these tests want, since they are about the
## turn machine rather than about the letters.
func _open_desk() -> void:
	machine.begin_turn()
	for inbound in run.inbox:
		inbound.status = InboundLetter.SET_ASIDE


func _queue_a_reply() -> OutgoingLetter:
	var outgoing := OutgoingLetter.new("marshal.request_supplies", &"marshal")
	outgoing.tone = Tone.DUTIFUL
	outgoing.choose("grant", "full")
	outgoing.params = {"amount": 200, "resource": "iron"}
	return run.post.add(outgoing)


# --- The sequence ----------------------------------------------------------

func test_a_turn_runs_through_every_phase_in_order() -> void:
	_open_desk()
	assert_true(machine.at_desk(), "a turn stops at the desk, because only the desk has decisions")
	assert_true(machine.send_post())
	assert_eq(run.phase, TurnMachine.DATE_CARD, "and comes back round to the next turn")


func test_the_stubbed_slots_are_in_the_sequence_and_skipped_cleanly() -> void:
	for phase in TurnMachine.STUBBED:
		assert_true(TurnMachine.ORDER.has(phase), "%s is missing from the sequence" % phase)
	_open_desk()
	assert_true(machine.at_desk())


func test_the_loop_runs_headless() -> void:
	# No presentation layer attached, which is what lets the determinism tests and
	# the balance harness drive a whole run.
	for i in 12:
		_open_desk()
		assert_true(machine.send_post(), "turn %d could not be sent" % i)
	assert_eq(run.turn, 12)
	assert_eq(run.world.month, 12)


# --- Order of time ---------------------------------------------------------

func test_an_order_written_this_turn_does_not_touch_the_world_now() -> void:
	# **Nothing the player writes changes the world instantly.**
	_open_desk()
	_queue_a_reply()
	var before := run.world.to_dict()
	assert_eq(run.world.to_dict(), before, "queuing a letter must not move the world")

	machine.send_post()
	assert_not_empty(machine.issued_orders, "sending should have produced an Order")


func test_the_post_produces_orders_and_never_writes() -> void:
	_open_desk()
	_queue_a_reply()
	machine.send_post()

	var order := machine.issued_orders[0]
	assert_eq(order.kind, M1Registrations.ORDER_PROMISE_RESOURCE)
	assert_eq(order.addressed_to, &"marshal")
	assert_eq(order.get_param("amount"), 200, "the declared param reached the Order intact")
	assert_eq(order.tone, Tone.DUTIFUL)


func test_sending_emits_the_orders_in_the_dispatch_phase() -> void:
	_open_desk()
	_queue_a_reply()
	machine.send_post()
	var issued := run.log.of_type(TurnMachine.EVENT_ORDER_ISSUED)
	assert_eq(issued.size(), 1)
	assert_eq(issued[0].phase, WorldPhase.DISPATCH)


func test_resolution_advances_exactly_one_month() -> void:
	_open_desk()
	machine.send_post()
	assert_eq(run.world.month, 1)
	assert_eq(run.turn, 1)


# --- Changes of mind -------------------------------------------------------

func test_an_outgoing_letter_can_be_rewritten_until_the_post_is_sent() -> void:
	_open_desk()
	var outgoing := _queue_a_reply()

	outgoing.choose("grant", "none")
	assert_eq(run.post.letter(outgoing.id).chosen_for("grant"), "none")

	machine.send_post()
	assert_eq(machine.issued_orders[0].kind, M1Registrations.ORDER_REFUSE,
		"the Order follows the last choice, not the first")


func test_an_outgoing_letter_can_be_discarded() -> void:
	_open_desk()
	var outgoing := _queue_a_reply()
	assert_true(run.post.discard(outgoing.id))
	assert_true(run.post.is_empty())

	machine.send_post()
	assert_empty(machine.issued_orders)


func test_nothing_in_a_sent_post_can_be_altered() -> void:
	_open_desk()
	var outgoing := _queue_a_reply()
	machine.send_post()

	# The post the turn moved on from is sealed, and refuses every edit.
	assert_true(run.post.is_empty(), "a new turn starts with an empty post")
	assert_false(run.post.sealed)


func test_a_sealed_post_refuses_edits() -> void:
	var post := Post.new()
	var outgoing := post.add(OutgoingLetter.new("marshal.request_supplies", &"marshal"))
	post.seal()
	assert_false(post.discard(outgoing.id))
	assert_true(post.add(OutgoingLetter.new("x", &"y")) == null)


func test_answering_the_same_letter_twice_is_findable() -> void:
	_open_desk()
	var outgoing := _queue_a_reply()
	outgoing.in_reply_to = &"inbound_1"
	assert_same(run.post.reply_to(&"inbound_1"), outgoing)


# --- Sending the post ------------------------------------------------------

func test_send_is_blocked_while_a_letter_is_unread_with_a_reason() -> void:
	_open_desk()
	var inbound := InboundLetter.new("marshal.request_supplies", &"marshal", Tone.DUTIFUL)
	inbound.id = &"inbound_1"
	run.inbox.append(inbound)

	var permission := machine.can_send()
	assert_false(permission["ok"])
	assert_true(String(permission["reason"]).contains("unanswered"), permission["reason"])
	assert_false(machine.send_post())
	assert_eq(run.world.month, 0, "a refused send must not resolve the month")


func test_setting_a_letter_aside_counts_as_handling_it() -> void:
	# Distinct from ignoring it: the loyalty consequences differ (#18), but either
	# way it clears the desk.
	_open_desk()
	var inbound := InboundLetter.new("marshal.request_supplies", &"marshal", Tone.DUTIFUL)
	inbound.id = &"inbound_1"
	run.inbox.append(inbound)
	assert_false(machine.can_send()["ok"])

	inbound.status = InboundLetter.SET_ASIDE
	assert_true(machine.can_send()["ok"])
	assert_true(machine.send_post())


func test_sending_triggers_the_save() -> void:
	_open_desk()
	assert_false(SaveGame.has_save(PATH))
	machine.send_post()
	assert_true(SaveGame.has_save(PATH), "the save happens as part of sending")


func test_the_saved_state_is_reloadable() -> void:
	# Killing the process immediately after sending loses nothing: the save is
	# taken after the resolution, so it is the start of the next turn with the
	# month already run.
	_open_desk()
	_queue_a_reply()
	machine.send_post()

	var loaded := SaveGame.load_run(PATH)
	assert_eq(loaded["result"], SaveGame.Result.OK, loaded["message"])
	var restored: RunState = loaded["run"]
	assert_eq(restored.turn, run.turn)
	assert_eq(restored.turn, 1, "the month the post triggered is already in the save")
	assert_eq(restored.world.month, 1)
	assert_eq(restored.world.state_hash(), run.world.state_hash())


# --- Orders reach the world ------------------------------------------------

func test_every_order_kind_has_somewhere_to_go() -> void:
	# The seam was built and nothing was plugged into it, so every Order the
	# player wrote stalled for want of an executor and no decision ever reached
	# the world. A missing entry here is that bug returning.
	var effects := TurnMachine.order_effects()
	for effect_id in ContentRegistry.effect_ids():
		var order := ContentRegistry.run_effect(effect_id, _arguments_for(effect_id), _letter_context())
		assert_true(order != null, "'%s' produced no Order" % effect_id)
		assert_true(effects.has(String(order.kind)),
			"Order kind '%s', from effect '%s', has no entry in order_effects()" % [order.kind, effect_id])


func _letter_context() -> LetterContext:
	return LetterContext.new(run.world, run.contact(&"marshal"), Tone.DUTIFUL)


func _arguments_for(effect_id: String) -> Dictionary:
	var arguments: Dictionary = {}
	for name in ContentRegistry.effect_params(effect_id):
		match StringName(ContentRegistry.effect_params(effect_id)[name]):
			&"integer", &"gold":
				arguments[name] = 10
			&"number":
				arguments[name] = 1
			&"bool":
				arguments[name] = true
			&"tone":
				arguments[name] = String(Tone.DUTIFUL)
			_:
				arguments[name] = "marshal"
	return arguments


func test_no_order_stalls_for_want_of_an_executor() -> void:
	for turn in 6:
		_open_desk()
		_queue_a_reply()
		machine.send_post()

	for event in run.log.of_type(&"intent_stalled"):
		fail("an Intent stalled: %s (%s)" % [event.payload.get("kind"), event.payload.get("reason")])
	assert_true(run.intents.all().size() > 0, "no Intents were created at all")


func test_a_decision_reaches_the_world() -> void:
	# #20: a decision written on turn T changes state during turn T+1's
	# resolution. Compared against an identical run that wrote nothing, so the
	# difference is the decision and not the weather.
	var quiet := RunState.new_run(SEED)
	quiet.add_contact(Contact.from_data({"id": "marshal", "name": "Vane", "role": "crown_officer"}))
	var quiet_machine := TurnMachine.new(quiet)
	quiet_machine.use_content(content)
	quiet_machine.saves_on_send = false

	for turn in 4:
		_open_desk()
		_queue_a_reply()
		machine.send_post()

		quiet_machine.begin_turn()
		for inbound in quiet.inbox:
			inbound.status = InboundLetter.SET_ASIDE
		quiet_machine.send_post()

	assert_ne(run.world.state_hash(), quiet.world.state_hash(),
		"answering letters left the world exactly as ignoring them did")


func test_an_order_with_no_world_effect_completes_rather_than_stalling() -> void:
	# A stall means "nothing could carry this out", which is a much louder claim
	# than "there was nothing to do".
	var effects := TurnMachine.order_effects()
	assert_eq(String(effects[String(M1Registrations.ORDER_SET_POLICY)]["target"]), "",
		"set_policy has no world effect in M1")

	var executor := WorldValueExecutor.new()
	executor.table = effects
	var intent := Intent.new(&"", M1Registrations.ORDER_SET_POLICY, &"steward", &"", 1, {})
	run.intents.commit(intent, run.log, run.world.month)
	run.world.advance_month(run.log)
	IntentExecutor.run_month([executor], run.intents, run.world, run.log)

	assert_eq(intent.resolution, Intent.COMPLETED)


# --- Determinism -----------------------------------------------------------

func test_the_same_seed_and_decisions_produce_the_same_run() -> void:
	var first := _play_twelve_turns(SEED)
	var second := _play_twelve_turns(SEED)
	assert_eq(first, second)


func test_a_different_seed_produces_a_different_run() -> void:
	assert_ne(_play_twelve_turns(SEED), _play_twelve_turns(SEED + 1))


func _play_twelve_turns(seed_value: int) -> String:
	var local_run := RunState.new_run(seed_value)
	local_run.add_contact(Contact.from_data({"id": "marshal", "name": "Vane"}))
	var local_machine := TurnMachine.new(local_run)
	local_machine.use_content(content)
	local_machine.saves_on_send = false
	for i in 12:
		local_machine.begin_turn()
		for inbound in local_run.inbox:
			inbound.status = InboundLetter.SET_ASIDE
		local_machine.send_post()
	return local_run.state_hash()
