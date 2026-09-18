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

## The word this contact would use.
static func word(measure_id: String, raw: float, lean: float, ladder: PackedStringArray) -> String:
	var index := rung(measure_id, raw, lean, ladder.size())
	if index < 0:
		return ""
	return ladder[index]


## The rung index, or -1 if the ladder is unusable.
static func rung(measure_id: String, raw: float, lean: float, rung_count: int) -> int:
	if rung_count < 2:
		push_error("A ladder needs at least two rungs, got %d." % rung_count)
		return -1

	var p := MeasureRegistry.normalize(measure_id, raw)
	var perceived := clampf(p + clampf(lean, -1.0, 1.0), 0.0, 1.0)

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
