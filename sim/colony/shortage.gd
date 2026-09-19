class_name Shortage
extends RefCounted

## How badly a town is short of something, **as a gradient rather than a flag**
## (#48).
##
## The governor's letters run on perception ladders (`docs/mechanics/perception.md`),
## and a ladder needs rungs. If the sim only knew "short" and "not short", every
## letter about food would read the same whether the town had missed a meal or
## was eating its horses — and a player who cannot tell those apart cannot act on
## the difference, which is the whole game.
##
## So Consume records the **fraction of the need that went unmet**, and this
## names the bands. The number is the truth; the name is what a letter can reach
## for without inventing its own thresholds.

const NONE: StringName = &"none"
const PINCHED: StringName = &"pinched"
const SHORT: StringName = &"short"
const HUNGRY: StringName = &"hungry"
const STARVING: StringName = &"starving"

## Worst last. **Not an ordering the letters may infer over** — tones are
## unordered and so is this, as far as prose is concerned. It is here so the sim
## can find the band, not so anything can say "hungry or worse".
const GRADES: Array[StringName] = [NONE, PINCHED, SHORT, HUNGRY, STARVING]

## Where each band begins, as a share of the need that went unmet.
const THRESHOLDS: Array[float] = [0.0, 0.05, 0.25, 0.5, 0.8]

## Below this a town is not considered to have gone without at all. Rounding, a
## few head short of a month's grain — not a famine.
const TOLERANCE: float = 0.05


## The band a shortfall falls in.
static func grade_of(unmet_fraction: float) -> StringName:
	var grade: StringName = NONE
	for i in GRADES.size():
		if unmet_fraction >= THRESHOLDS[i]:
			grade = GRADES[i]
	return grade


## Whether a town went meaningfully without.
static func is_short(unmet_fraction: float) -> bool:
	return unmet_fraction >= TOLERANCE


## The share of a need that went unmet, `0.0` to `1.0`.
static func unmet(needed: float, consumed: float) -> float:
	if needed <= 0.0:
		return 0.0
	return clampf(1.0 - consumed / needed, 0.0, 1.0)
