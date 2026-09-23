class_name Perception
extends RefCounted

## How a true number becomes a biased word.
##
## A letter must be able to say "your people are starving" without the game ever
## telling the player something untrue. SPEC §9.1 draws the line: **quantities
## are exact, judgments are biased.** This is the machinery for the judgment
## half. `docs/mechanics/perception.md` is the specification.
##
## Two contacts may describe the same event very differently and both be telling
## the truth. One sim number, 180 food against 200: the Governor says
## *starving*, the Steward says *managing*. Recognisably different, not
## contradictory, and neither reports a false figure.
##
## The pipeline:
##
## 1. **Normalise.** The measure registry maps the raw value to `p` in `[0, 1]`.
## 2. **Lean.** `perceived = clamp(p + lean, 0, 1)`, applied in **normalised
##    space** rather than as an index shift, so a lean means the same thing
##    across ladders of different lengths.
## 3. **Climb.** Rungs are evenly spaced **points**, not bands:
##    `index = round(value * (N - 1))`. **Nearest, not floor**, so the top rung is
##    reachable well before 1.0 and the lower rungs are not unduly favoured.
## 4. **Cap.** The lean may never move the result more than **one rung** from the
##    truth.
##
## Without step 4 a large lean on a short ladder produces flat contradiction
## between two senders, which reads as lying rather than framing and violates
## SPEC §9.1. Direct contradiction is the failure mode this system exists to
## prevent.

# --- 🔒 The shape of a lean, which is not its size --------------------------

## How a man's bias varies with how bad things actually are.
##
## Most contacts are **flat**: the same lean wherever the truth sits, which is
## what the pipeline has always done and remains the default.
##
## **Alarmed** is steep where there is little to worry about and flattens as
## things worsen (#279, `institutional-contacts.md` §3). The journalist thinks
## every problem is equally important, so *small troubles move him nearly as far
## as large ones* — a minor shortage in a hamlet gets the same headline as a
## famine in the capital.
##
## **Sanguine** is its mirror, and it is the Marshal: flat where the journalist
## is steep, so a small threat reads as nothing at all and only a real one moves
## him. Same machinery, opposite curves, and the player has two different
## discounts to learn.
##
## 🔒 **The cap still holds.** A shape changes where a lean bites, never how far
## it may carry — so the journalist is reliably one notch more alarmed than the
## truth rather than hysterical, and the player who learns to discount him is the
## one who will miss the real famine.
const SHAPE_FLAT: StringName = &"flat"
const SHAPE_ALARMED: StringName = &"alarmed"
const SHAPE_SANGUINE: StringName = &"sanguine"

const SHAPES: Array[StringName] = [SHAPE_FLAT, SHAPE_ALARMED, SHAPE_SANGUINE]

# --- 🔒 The knob: how plainly they put it to the PC --------------------------

## How much of a man's lean reaches the page (#287, *Read between the lines*).
##
## **One in every run without the perk**, so the pipeline reads exactly as it
## always did.
##
## 🔒 **They still deceive themselves.** The perk reduces the lean *when
## reporting to the PC* — the Marshal goes on minimising every threat and the
## clergy goes on seeing the worst; they simply present it more plainly. So this
## belongs here, at the point a judgement becomes a word, and **not** on
## `Contact.leans`, which is what the man believes.
##
## It is the only perk that changes what the PC can *see* rather than what he can
## do, and it rewards a player who reads letters closely rather than one who
## plays the numbers.
static var _lean_scale: float = 1.0


static func lean_scale() -> float:
	return _lean_scale


## Turn it. Never below nothing and never past the truth: a scale above one would
## make contacts *more* biased than they are, which is a different perk and not
## this one.
static func set_lean_scale(scale: float) -> void:
	_lean_scale = clampf(scale, 0.0, 1.0)


static func reset() -> void:
	_lean_scale = 1.0


static func is_shape(id: StringName) -> bool:
	return SHAPES.has(id)


## How much trouble this man sees, given how much there is.
##
## 🔒 **A curve on the trouble, not a scaling of the lean.** §3 asks for *the
## shape of his lean rather than its size*, and scaling the magnitude turns out
## to say something else entirely: it makes every curve agree at both ends and
## differ only in the middle, which is the opposite of what *small troubles move
## him nearly as far as large ones* means.
##
## So the measure itself is bent before his flat lean goes on top. `p` is
## normalised with **1 as the untroubled end**, so trouble is `1 - p`:
##
## | | At a tenth of the trouble there is | Reads as |
## | :--- | :--- | :--- |
## | **alarmed** | most of the alarm of all of it | small troubles nearly as loud as large |
## | **sanguine** | almost none of it | a small threat is no threat |
##
## The two are mirror images and the player has two different discounts to learn.
static func trouble_seen(shape: StringName, p: float) -> float:
	var here := clampf(p, 0.0, 1.0)
	var trouble := 1.0 - here
	match shape:
		SHAPE_ALARMED:
			# Concave in the trouble: steep where there is barely any, flattening
			# once there plainly is.
			return 1.0 - sqrt(trouble)
		SHAPE_SANGUINE:
			# Convex, the mirror: nothing registers until it is genuinely bad.
			return 1.0 - trouble * trouble
		_:
			return here


## The word this contact would use.
static func word(
	measure_id: String,
	raw: float,
	lean: float,
	ladder: PackedStringArray,
	shape: StringName = SHAPE_FLAT,
) -> String:
	var index := rung(measure_id, raw, lean, ladder.size(), shape)
	if index < 0:
		return ""
	return ladder[index]


## The rung index, or -1 if the ladder is unusable.
static func rung(
	measure_id: String,
	raw: float,
	lean: float,
	rung_count: int,
	shape: StringName = SHAPE_FLAT,
) -> int:
	if rung_count < 2:
		push_error("A ladder needs at least two rungs, got %d." % rung_count)
		return -1

	var p := MeasureRegistry.normalize(measure_id, raw)
	lean *= _lean_scale
	# 🔒 **The shape bends the truth he is looking at; the lean then moves it.**
	# The cap below is measured against the *real* truth, so a shape can no more
	# carry a word two rungs than a lean can.
	var seen := trouble_seen(shape, p)
	var perceived := clampf(seen + clampf(lean, -1.0, 1.0), 0.0, 1.0)

	var truth_index := _index(p, rung_count)
	var biased_index := _index(perceived, rung_count)

	# The cap. A strong lean and a mild lean often produce the same word, because
	# this saturates at one rung — past roughly 1/(N-1) extra lean buys nothing.
	return clampi(biased_index, truth_index - 1, truth_index + 1)


## The rung the truth alone would reach, ignoring any lean.
static func truthful_rung(measure_id: String, raw: float, rung_count: int) -> int:
	if rung_count < 2:
		return -1
	return _index(MeasureRegistry.normalize(measure_id, raw), rung_count)


static func _index(value: float, rung_count: int) -> int:
	return clampi(int(roundf(value * float(rung_count - 1))), 0, rung_count - 1)
