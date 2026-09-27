class_name PolicyEnactExecutor
extends IntentExecutor

## A policy agreed to after a delay is enacted when the delay is up (#449,
## `policy.md` §3, SPEC §8.5).
##
## Every other answer that agrees to a policy enacts it the month the letter is
## read (`OrderDriver._enact_if_agreed`), and marks its Intent enacted so this
## does not do it twice. **A delay is still an answer**: the enactor puts his
## name to it when the months are up, which is what makes the Marshal's
## acknowledgement — *you will have it by the spring* — true.
##
## A later letter can still overtake it, because until then it is an Intent like
## any other.

const KIND: StringName = &"enact_policy"

## Set on an Intent whose policy is already on the books.
const ENACTED: String = "enacted"

var policies: PolicyBook = null


func handles(intent: Intent) -> bool:
	return intent.kind == KIND


func execute(intent: Intent, state: WorldState, log: EventLog) -> StringName:
	if bool(intent.data.get(ENACTED, false)):
		return Intent.COMPLETED
	if not intent.advance():
		return Intent.IN_PROGRESS
	var effect := StringName(intent.data.get("effect", ""))
	if policies == null or not PolicyEffects.is_effect(effect):
		return Intent.ABANDONED
	var params := intent.data.duplicate(true)
	params.erase(ENACTED)
	policies.enact(Policy.new(
		intent.source,
		effect,
		float(intent.data.get("cost", 0.0)),
		StringName(intent.data.get("split", Policy.NONE)),
		params,
	), log, state.month)
	intent.data[ENACTED] = true
	return Intent.COMPLETED
