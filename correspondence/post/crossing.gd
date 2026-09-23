class_name Crossing
extends RefCounted

## How long the post takes each way, and the letters presently on the water
## (#390, `docs/mechanics/perks-and-quirks.md` §4, *Distant colony*).
##
## **Zero in every run without the quirk**, and the whole of this file is inert
## at zero: `deliver` hands back exactly what it was given, nothing is queued,
## nothing is saved. A colony at the ordinary distance behaves as it always did,
## down to the object identity of its inbox.
##
## ## 🔒 A queue, not a delay on delivery
##
## A distant colony's news **should be a month stale** — the letter should
## describe the colony as it was when it was written, not as it is when it
## arrives. A delay that re-read the current state at delivery would give the PC
## *timely news, later*, which is the opposite of distance.
##
## That costs nothing to get right, because `InboundLetter` is **already a
## snapshot**: the director decides the letter *and its values* at composition
## and the letter file never re-decides what it is about. So holding a composed
## letter is holding the month it was composed in, and the staleness falls out of
## the existing contract rather than being arranged.
##
## ## 🔒 It is the same number both ways
##
## §4 says *correspondence takes an extra month **each way***, so the outbound
## delay in `OrderDriver` and the inbound queue here read the same knob. Two
## numbers would let a run exist in which the PC hears late and is obeyed
## promptly, which is not a distant colony — it is a slow contact.
##
## ## 🔒 And it is the only quirk that changes the loop
##
## `perks-and-quirks.md` §1 has quirks as *facts about the world he was given*,
## and a colony further away is the most literal version of that the game can
## express. Every other quirk is a magnitude inside the loop; this one is the
## loop.

const EVENT_POSTED: StringName = &"letter_at_sea"

## Extra months each way. Zero without the quirk.
static var _months: int = 0


static func months() -> int:
	return _months


static func set_months(count: int) -> void:
	_months = maxi(0, count)


static func reset() -> void:
	_months = 0


## Whether the post takes any longer than it used to.
static func is_distant() -> bool:
	return _months > 0


## Put this month's composed letters on the water and take off what has landed.
##
## **Returns the inbox for this month.** At zero it is the argument, untouched,
## which is what keeps an ordinary run identical rather than merely equivalent.
##
## 🔒 **Composed letters go in; whatever is due comes out.** A letter written in
## March under a two-month crossing is read in May, and it still says what was
## true in March — which is the quirk.
static func deliver(run: RunState, composed: Array[InboundLetter]) -> Array[InboundLetter]:
	if run == null:
		return composed
	if not is_distant():
		# 🔒 **Nothing is queued at the ordinary distance**, so a run that never
		# carried the quirk has nothing in the hold to save, load or reason about.
		return composed

	for letter in composed:
		letter.arrives_month = run.world.month + _months
		run.at_sea.append(letter)
		run.log.emit(EVENT_POSTED, letter.sender, run.world.month, {
			"letter": letter.letter_id,
			"written": letter.month,
			"arrives": letter.arrives_month,
		}, WorldPhase.DISPATCH)

	var landed: Array[InboundLetter] = []
	var still_out: Array[InboundLetter] = []
	for letter in run.at_sea:
		if letter.arrives_month <= run.world.month:
			landed.append(letter)
		else:
			still_out.append(letter)
	run.at_sea = still_out
	return landed
