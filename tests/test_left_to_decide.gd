extends TestCase

## A contact left to decide does what he decided (#450, SPEC §9.3, §9.6).
##
## 🔒 A decision the PC ignores, or one culled or withheld because the man
## handled it himself, is taken in his own interest or at random — and **what he
## chose happens**, as his own will (Seam C). It used to end at an event nothing
## read. 🔒 A request the PC ignores is still a rude refusal, not a decision.
##
## ⚠ He does not spend the Crown's money, provisionally, until the PO rules in
## `contacts.md` §3.

const SEED: int = 450

var content: ContentDatabase = null
var run: RunState = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)
	run = RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	run.world.month = 10


func after_each() -> void:
	reset_world()
	content.free()


func _governor() -> Contact:
	return run.contact(run.colony.in_order()[0].governor_id)


## A question with one answer, so what he decides is not in doubt.
func _one_answer(effect: Dictionary) -> Letter:
	return Letter.from_record({
		"id": "governor.a_question", "sender": "governor", "type": "question",
		"params": {"governor": "contact"},
		"body": [{"text": "A question."}],
		"reply": {"steps": [{"id": "answer", "prompt": "The answer", "options": [
			{"id": "only", "label": "the only answer", "text": "The only answer.", "effect": effect},
		]}]},
	})


func _inbound(letter: Letter, sender: Contact) -> InboundLetter:
	var inbound := InboundLetter.new(String(letter.id), sender.id)
	inbound.id = &"inbound_1"
	inbound.params = {"governor": String(sender.id)}
	return inbound


func _his_will(contact: Contact) -> Array:
	var out: Array = []
	for intent in run.intents.live():
		if intent.source == contact.id and intent.origin == Intent.ORIGIN_WILL:
			out.append(intent)
	return out


func test_what_he_decides_alone_he_does() -> void:
	var governor := _governor()
	var letter := _one_answer({"urge_intent": {"to": "{governor}", "intent": "military"}})
	Silence.decide_alone(governor, letter, _inbound(letter, governor), run, true)

	var will := _his_will(governor)
	assert_eq(will.size(), 1, "he decided and nothing followed")
	if will.size() != 1:
		return
	assert_eq(String(will[0].kind), String(M1Registrations.ORDER_URGE_INTENT))
	assert_eq(String(will[0].data.get("intent", "")), "military", "he did something other than he chose")
	var decided: Array = run.log.of_type(Silence.EVENT_DECIDED_ALONE)
	assert_eq(String(decided[-1].payload["chose"]), "only", "the event does not name what he chose")
	assert_eq(decided[-1].payload["did"], [String(M1Registrations.ORDER_URGE_INTENT)])


func test_culled_or_withheld_he_does_it_too() -> void:
	# The same call, not ignored: he never asked.
	var governor := _governor()
	var letter := _one_answer({"urge_intent": {"to": "{governor}", "intent": "go_tall"}})
	Silence.decide_alone(governor, letter, _inbound(letter, governor), run, false)
	assert_eq(_his_will(governor).size(), 1, "a question he handled himself changed nothing")


func test_an_ignored_request_is_a_rude_refusal_and_nothing_more() -> void:
	var governor := _governor()
	var letter := Letter.from_record({
		"id": "governor.a_request", "sender": "governor", "type": "request",
		"params": {"governor": "contact"},
		"body": [{"text": "A request."}],
		"reply": {"steps": [{"id": "answer", "prompt": "The answer", "options": [
			{"id": "yes", "label": "yes", "text": "Yes.",
				"effect": {"urge_intent": {"to": "{governor}", "intent": "military"}}},
		]}]},
	})
	var result := Silence.resolve_one(governor, letter, _inbound(letter, governor), run)
	assert_eq(String(result["outcome"]), "rude_refusal")
	assert_empty(_his_will(governor), "an ignored request was carried out as a decision")


func test_provisionally_he_does_not_spend_the_crowns_money() -> void:
	# ⚠ #450's open question: until the PO rules, the Chancellor left alone does
	# not promise himself the Crown's gold. He refuses instead.
	var chancellor := run.contact(&"chancellor")
	var letter := Letter.from_record(content.record("letters", "chancellor.how_to_answer"))
	var inbound := InboundLetter.new(String(letter.id), chancellor.id)
	inbound.params = {"amount": 120}
	var decision := Silence.decide_alone(chancellor, letter, inbound, run, true)
	assert_eq(String(decision.chosen_id()), "deny", "left alone, he spent the Crown's money")
	for intent in _his_will(chancellor):
		assert_ne(String(intent.kind), String(M1Registrations.ORDER_PROMISE_GOLD))
