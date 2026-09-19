class_name CrownRefusal
extends RefCounted

## When the Crown stops honouring the PC's word
## (SPEC §10.3, §5; `docs/mechanics/crown-standing.md` §3).
##
## ## 🔒 A gate, not a threshold
##
## SPEC §10.3 locks it: **the player always gets the Chancellor's warning before
## the Crown first refuses to honour his promised gold.**
##
## A threshold check on standing violates that the first time a catastrophic
## promise lands and standing falls from Content to nothing in one month — and
## `CrownStanding` is deliberately built to allow exactly that. So refusal
## **waits**: for the warning to have been delivered, and for the full countdown
## to have elapsed. However fast the arithmetic collapses, the political process
## takes its time.
##
## That separation is the whole reason standing and refusal are two machines.
##
## ## The window is the point
##
## During `WARNED`, **promises are still honoured.** That is deliberate: it gives
## the PC two turns to make a few decisive commitments knowing they will be paid,
## before the faucet closes.
##
## A window the player cannot see is a trap rather than an opportunity, so the
## Chancellor's warning states the deadline in fiction — what is pledged in the
## next two letters, and nothing after. The player never sees a number and can
## still act on it.
##
## **A promise is honoured when the Crown pays, not when it is made.** One made
## during the window whose payment falls after refusal begins still breaks: the
## window resolves near-term commitments, and cannot be used to bank long ones.
##
## ## The grade
##
## Entering `REFUSING` raises the bar for the rest of the run — a credit rating
## losing a grade on every default. The arithmetic of recovery does not change;
## the Crown simply requires more proof each time before it reopens the faucet.
##
## **The grade drops on entering `REFUSING`, not on falling below the
## threshold.** A PC who dips into lost standing and claws back inside the window
## has not defaulted, and charging him for a near miss would blunt the very thing
## the window is for.

const SOLVENT: StringName = &"solvent"
const WARNED: StringName = &"warned"
const REFUSING: StringName = &"refusing"

## Turns between the Chancellor's warning and the faucet closing.
const WARNING_TURNS: int = 2

## Where the bar sits on a first default, and how far it rises each time.
const FIRST_RESTORE: float = 35.0
const GRADE_STEP: float = 10.0

## **Capped so recovery stays theoretically possible**, not to be merciful. A PC
## on his fourth collapse must climb nearly to Content before the Crown will pay
## a penny on his word.
const MAX_RESTORE: float = 65.0

const EVENT_WARNED: StringName = &"crown_warned"
const EVENT_REFUSING: StringName = &"crown_refusing"
const EVENT_RESTORED: StringName = &"crown_restored"

var state: StringName = SOLVENT

## Turns left before the faucet closes. `-1` when nothing is counting.
var countdown: int = -1

## The month the window shuts, so the warning can say so in fiction.
var deadline_month: int = -1

## What standing must reach before the Crown pays again.
var restore_threshold: float = FIRST_RESTORE

## How many times the Crown has cut the PC off. Drives the grade.
var cutoffs: int = 0

## **"It's my first day"** (SPEC §5). One extra warning cycle, once per run.
##
## Granted by Run Setup (#79); until that exists nobody has it, which is the
## honest default rather than a quiet gift.
var has_grace: bool = false
var grace_spent: bool = false


## Whether the Crown will honour gold promised on the PC's word.
##
## **True while warned.** That is the window, and it is the point.
func pays() -> bool:
	return state != REFUSING


func is_warning() -> bool:
	return state == WARNED


# --- A month ----------------------------------------------------------------

## Advance the political process one month. Returns what happened, or `{}`.
##
## Takes the standing rather than reading it, so the two machines stay separate
## and this one can be driven straight from a test.
func advance(standing: CrownStanding, month: int) -> Dictionary:
	match state:
		SOLVENT:
			return _maybe_warn(standing, month)
		WARNED:
			return _count_down(standing, month)
		REFUSING:
			return _maybe_restore(standing, month)
	return {}


## Lost confidence opens the window. It does not close the faucet.
func _maybe_warn(standing: CrownStanding, month: int) -> Dictionary:
	if not standing.has_lost_confidence():
		return {}
	return _open_the_window(month, false)


func _open_the_window(month: int, on_grace: bool) -> Dictionary:
	state = WARNED
	countdown = WARNING_TURNS
	deadline_month = month + WARNING_TURNS
	return {
		"event": EVENT_WARNED,
		"turns": WARNING_TURNS,
		"deadline_month": deadline_month,
		"final": on_grace or not _grace_left(),
		"on_grace": on_grace,
	}


func _grace_left() -> bool:
	return has_grace and not grace_spent


## Inside the window: claw back, or run out of time.
func _count_down(standing: CrownStanding, month: int) -> Dictionary:
	if not standing.has_lost_confidence():
		# **A near miss, not a default.** He recovered inside the window, so the
		# grade is untouched — and if he slips again he gets a fresh warning and
		# a fresh countdown, so restoration is never immediately undone.
		return _restore(month, true)

	countdown -= 1
	if countdown > 0:
		return {}

	if _grace_left():
		# The perk runs the same cycle a second time: the countdown expires, the
		# Chancellor writes again in a rather more exasperated register, and a
		# fresh countdown begins. A repeatable cycle rather than a warning
		# counter, so further quirks that grant grace need no new machinery.
		grace_spent = true
		return _open_the_window(month, true)

	return _close_the_faucet(month)


func _close_the_faucet(month: int) -> Dictionary:
	state = REFUSING
	countdown = -1
	deadline_month = -1
	cutoffs += 1
	restore_threshold = minf(
		MAX_RESTORE, FIRST_RESTORE + float(cutoffs - 1) * GRADE_STEP
	)
	return {
		"event": EVENT_REFUSING,
		"cutoffs": cutoffs,
		"restore_threshold": restore_threshold,
		"month": month,
	}


func _maybe_restore(standing: CrownStanding, month: int) -> Dictionary:
	if standing.standing < restore_threshold:
		return {}
	return _restore(month, false)


func _restore(month: int, near_miss: bool) -> Dictionary:
	state = SOLVENT
	countdown = -1
	deadline_month = -1
	return {
		"event": EVENT_RESTORED,
		"near_miss": near_miss,
		"restore_threshold": restore_threshold,
		"month": month,
	}


# --- Serialisation ----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"state": String(state),
		"countdown": countdown,
		"deadline_month": deadline_month,
		"restore_threshold": restore_threshold,
		"cutoffs": cutoffs,
		"has_grace": has_grace,
		"grace_spent": grace_spent,
	}


static func from_dict(data: Dictionary) -> CrownRefusal:
	var restored := CrownRefusal.new()
	restored.state = StringName(data.get("state", SOLVENT))
	restored.countdown = int(data.get("countdown", -1))
	restored.deadline_month = int(data.get("deadline_month", -1))
	restored.restore_threshold = float(data.get("restore_threshold", FIRST_RESTORE))
	restored.cutoffs = int(data.get("cutoffs", 0))
	restored.has_grace = bool(data.get("has_grace", false))
	restored.grace_spent = bool(data.get("grace_spent", false))
	return restored
