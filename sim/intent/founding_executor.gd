class_name FoundingExecutor
extends IntentExecutor

## The Crown sends a town, and the PC argues about it (#180,
## `founding-towns.md` §3).
##
## Two Intents, because there are two things the PC can do about a proposal and
## they are not the same thing:
##
## | | |
## | :--- | :--- |
## | `fund_founding` | he agrees, and **what he promises is what it is equipped with** |
## | `dissuade_founding` | he argues against it, and **the decision remains the contact's** |
##
## ## 🔒 A refusal does not necessarily stop it
##
## SPEC §11.4 has these *pressed* on the colony. The PC's objection is an Order
## resolved by compliance like any other, so **a determined patron founds his
## town over it** — and the PC's only real instrument is the regard he built with
## the man beforehand.
##
## That is why the outcome is read from the compliance the Order already carries
## rather than decided here: a second opinion about whether the contact relents
## would be a second answer to a question `Compliance` has already asked, with
## the man's personality and loyalty in it.

const KIND_FUND: StringName = &"fund_founding"
const KIND_DISSUADE: StringName = &"dissuade_founding"

## Where the pending foundings live. The same array the run holds.
var foundings: Array = []


func handles(intent: Intent) -> bool:
	return intent.kind == KIND_FUND or intent.kind == KIND_DISSUADE


func execute(intent: Intent, state: WorldState, log: EventLog) -> StringName:
	var context := ColonyContext.new(state, log, null, null)
	if intent.kind == KIND_FUND:
		return _fund(intent, context)
	return _dissuade(intent, context)


## He agrees, and says how handsomely.
##
## 🔒 **The cost lands on Crown Standing through the ordinary promise path**, not
## here: the letter's other effect is a `promise_gold` to the man who proposed
## it, and `CrownAccounts` sees it exactly as it sees every other promise. A
## bespoke deduction would be a second set of books.
func _fund(intent: Intent, context: ColonyContext) -> StringName:
	var equipped := String(intent.data.get("equipped", "adequately"))
	var founding := CrownFounding.proposed(
		intent.target,
		equipped,
		StringName(intent.data.get("expert", "")),
		StringName(intent.data.get("building", "")),
		StringName(intent.data.get("intent", "")),
		context,
	)
	foundings.append(founding)
	return Intent.COMPLETED


## He argues against it.
##
## 🔒 **The decision remains the contact's.** The Order was already resolved by
## compliance before it reached an executor, so a complied objection is a contact
## who relented and anything else is a contact who did not — and the PC finds out
## either way in the next month's post.
func _dissuade(intent: Intent, context: ColonyContext) -> StringName:
	var relented := bool(intent.data.get("relented", false))
	var stopped := false
	# Sorted by id, so which proposal is dropped cannot depend on the order they
	# happened to be made in.
	for founding in _in_order():
		if founding.proposer != intent.target or founding.abandoned:
			continue
		if not relented:
			continue
		founding.abandoned = true
		stopped = true
		context.log.emit(CrownFounding.EVENT_ABANDONED, founding.id, context.state.month, {
			"founding": String(founding.id),
			"by": String(founding.proposer),
			"at_the_pc_s_request": true,
		}, WorldPhase.CROWNS_MONTH)

	# **Not a failure.** A contact who would not be talked out of it carried out
	# nothing, and the letter is answered by the town turning up anyway.
	return Intent.COMPLETED if stopped else Intent.OVERTAKEN_BY_EVENTS


func _in_order() -> Array:
	var out: Array = foundings.duplicate()
	out.sort_custom(func(a: CrownFounding, b: CrownFounding) -> bool:
		return String(a.id) < String(b.id))
	return out
