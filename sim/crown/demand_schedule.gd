class_name DemandSchedule
extends RefCounted

## Where the bar actually sits, given how far the run has grown
## (`docs/mechanics/crown-demands.md` §§2, 6, 8).
##
## `DemandGrowth` decides *which* axis moved and how often. This turns that into
## the four numbers the rest of the demand system reads:
##
## | | |
## | :--- | :--- |
## | `months_between` | how often a demand arrives — `frequency` shortens it |
## | `gold_target` | what a gold demand asks for — `size` raises it |
## | `refusal_cost` | what saying no costs — `desperation` raises it |
## | `askers` | how many sources are demanding — `reach` raises it |
##
## **Every magnitude is data** (`data/crown/demands.json`), because calibration
## is a harness sweep and not a judgement anyone can make at a keyboard. §8 sets
## the target as *equal expected pressure across the reference players* — the
## spendthrift never feels desperation, the miser feels almost nothing else —
## and that is measured, not guessed.
##
## ## Frequency and reach have ceilings; size and desperation do not
##
## Demands are unskippable, so growth in frequency pushes directly against SPEC
## §9.6's letter volume targets rather than being absorbed by them. It is the
## one axis whose growth can make the game *worse* rather than harder, so it
## floors. Reach ceilings because there are only so many people in the world with
## a hand out before M7 brings patrons.
##
## Size and desperation are deliberately unbounded here. §11 leaves open whether
## growth should saturate at all — a fifty-year run sees forty-odd growth events
## and a demand grown a hundredfold stops reading as a Crown — but that is the
## PO's question, and guessing a cap would settle it silently.

const DEFAULT_MONTHS_BETWEEN: float = 4.0
const DEFAULT_GOLD_TARGET: float = 600.0
const DEFAULT_REFUSAL_COST: float = 6.0
const DEFAULT_ASKERS: int = 1
const DEFAULT_TERM_MONTHS: int = 6
const DEFAULT_RESOURCE_SHARE: float = 0.25
const DEFAULT_DEADLINE_TURNS: int = 3

static var _steady: Dictionary = {}
static var _growth: Dictionary = {}


static func load_from(record: Dictionary) -> void:
	_steady = record.get("steady", {})
	_growth = record.get("growth", {})


static func reset() -> void:
	_steady = {}
	_growth = {}


static func _steady_value(key: String, fallback: float) -> float:
	return float(_steady.get(key, fallback))


## How far one axis has grown, tolerating a run that has no growth state.
##
## A null growth is the steady bar, not an error: the standing driver and the
## demand book are each useful in a fixture that does not care which year it is,
## and the alternative is every caller guarding the same way.
static func _level(growth: DemandGrowth, dimension: StringName) -> float:
	return 0.0 if growth == null else float(growth.level_of(dimension))


static func _growth_value(dimension: StringName, key: String, fallback: float) -> float:
	var entry: Dictionary = _growth.get(String(dimension), {})
	return float(entry.get(key, fallback))


## Months between demands. **Shortened by `frequency`, with a floor**, because
## the one thing growth must not do is bury the desk (SPEC §9.6).
static func months_between(growth: DemandGrowth) -> float:
	var base := _steady_value("months_between", DEFAULT_MONTHS_BETWEEN)
	var step := _growth_value(DemandGrowth.FREQUENCY, "months_between", -0.5)
	var floor_at := _growth_value(DemandGrowth.FREQUENCY, "floor", 1.5)
	return maxf(floor_at, base + step * _level(growth, DemandGrowth.FREQUENCY))


## What a gold demand asks for. **Set above a young colony's output** and raised
## by `size` from year four (§2).
static func gold_target(growth: DemandGrowth) -> float:
	var base := _steady_value("gold_target", DEFAULT_GOLD_TARGET)
	var step := _growth_value(DemandGrowth.SIZE, "gold_target", 0.35)
	return base * (1.0 + step * _level(growth, DemandGrowth.SIZE))


## What refusing costs, as a multiple of the steady figure.
##
## **The axis a player who pays everything never feels**, which is why it cannot
## be folded into size and why §8 refuses to reduce difficulty to one number.
static func refusal_cost(growth: DemandGrowth) -> float:
	var base := _steady_value("refusal_cost", DEFAULT_REFUSAL_COST)
	var step := _growth_value(DemandGrowth.DESPERATION, "refusal_cost", 0.4)
	return base * (1.0 + step * _level(growth, DemandGrowth.DESPERATION))


## How many sources are demanding at all.
##
## §6: not only patrons, who are M7 — Crown officers who were not asking before,
## and **rival dukes demanding tribute**, whose demands cost prestige rather than
## standing and so add pressure the player's existing defences do not answer.
static func askers(growth: DemandGrowth) -> int:
	var base := int(_steady_value("askers", float(DEFAULT_ASKERS)))
	var step := int(_growth_value(DemandGrowth.REACH, "askers", 1.0))
	var ceiling := int(_growth_value(DemandGrowth.REACH, "ceiling", 4.0))
	return mini(ceiling, base + step * int(_level(growth, DemandGrowth.REACH)))


## How long the colony has to reach a revenue target.
##
## **Does not grow.** None of the four axes is "less time", and adding a fifth
## silently would change what the bucket means. If the term should tighten, that
## is a dimension and belongs in the doc.
static func term_months() -> int:
	return int(_steady_value("term_months", float(DEFAULT_TERM_MONTHS)))


## How often a demand asks for goods rather than gold.
##
## **Gold is the routine and resources are the exception** (`crown-demands.md`
## §5). A resource demand costs two letters, a payment decision and a governor's
## compliance; at every demand the desk becomes a logistics exercise and SPEC
## §9.6's promise that it will not become a chore is broken. They are for when
## the Marshal's war genuinely needs a thing the colony makes.
static func resource_share() -> float:
	return clampf(_steady_value("resource_share", DEFAULT_RESOURCE_SHARE), 0.0, 1.0)


## How many turns the PC has to answer a demand for goods.
##
## **More than one, and that is the whole point.** A careful player writes to the
## governor first and learns whether the goods can be had — it costs him a month,
## and the demand may not wait, but it turns a blind bet into an informed one. A
## demand answered by return of post makes that play impossible and reduces the
## decision to a coin toss (§5).
static func deadline_turns() -> int:
	return maxi(2, int(_steady_value("deadline_turns", float(DEFAULT_DEADLINE_TURNS))))


## The whole bar in one dictionary, for the event log and the harness.
static func bar(growth: DemandGrowth) -> Dictionary:
	return {
		"months_between": months_between(growth),
		"gold_target": gold_target(growth),
		"refusal_cost": refusal_cost(growth),
		"askers": askers(growth),
	}
