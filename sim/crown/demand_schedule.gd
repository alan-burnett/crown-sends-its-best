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
## | `askers` | how many sources are demanding — every `reach` draw adds one |
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
## floors. Reach is bounded by **room** — there are only so many people in the
## world with a hand out, and `room_for` says how many of each.
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

## How many hands of each source the world holds (#339). The defaults are the
## world's: one Crown officer's ask is built, there are three dukes, and a run
## meets three patrons unless a quirk says otherwise.
const DEFAULT_ROOM: Dictionary = {"crown": 1, "duke": 3, "patron": 3}

static var _steady: Dictionary = {}
static var _growth: Dictionary = {}

## A run's lifts over the room in the data, kept apart from the loaded record so
## a quirk in one run never rewrites the content another run reads.
static var _room_lifts: Dictionary = {}


static func load_from(record: Dictionary) -> void:
	_steady = record.get("steady", {})
	_growth = record.get("growth", {})
	_room_lifts = {}


static func reset() -> void:
	_steady = {}
	_growth = {}
	_room_lifts = {}


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


# --- 🔒 The knob: how many hands the world holds ----------------------------

## How many hands of this source the Squeeze may put out (#339, §6).
##
## **What bounds a source is how many of it the world holds**, not a count of
## hands before it. A draw of *more hands out* chooses among the sources with
## room left, so this is also what stops a fourth duke appearing.
static func room_for(source: StringName) -> int:
	var room: Dictionary = _growth.get(String(DemandGrowth.REACH), {}).get("room", {})
	var base := int(room.get(String(source), DEFAULT_ROOM.get(String(source), 0)))
	return maxi(base, int(_room_lifts.get(String(source), 0)))


## Make room for more of one source, for a run whose world is more crowded than
## most — *Busy patrons* (`perks-and-quirks.md` §4).
##
## 🔒 **It only ever raises.** A quirk that quietly removed a duke from a run
## would be a far larger claim than any of them makes, and `rival-pressure.md`
## has the three dukes as a fixture of every run.
static func make_room(source: StringName, count: int) -> void:
	_room_lifts[String(source)] = maxi(int(_room_lifts.get(String(source), 0)), count)


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


## How many sources are demanding at all: the Steward's, and every hand the
## Squeeze has put out since.
##
## 🔒 **A count, and nothing gates on it** (#339). It used to be `1 + reach` and
## everything else read thresholds off it — goods at two hands, dukes at three,
## patrons at five — which is a ladder no doc asked for. What is asking is now
## `DemandGrowth.sources`, and this only counts them for the log and the harness.
static func askers(growth: DemandGrowth) -> int:
	var base := int(_steady_value("askers", float(DEFAULT_ASKERS)))
	return base + (0 if growth == null else growth.sources.size())


## Whether a duke is among the hands out yet.
##
## 🔒 **Dimension 4 and nothing else** (#210, `crown-demands.md` §6). A duke
## demanding tribute is a draw of *more hands out* that put out his hand, so
## there is **no second clock anywhere** and no schedule of his own — and no
## place in a queue either (#339): he may be the first hand a run meets, or the
## last.
static func rivals_are_asking(growth: DemandGrowth) -> bool:
	return growth != null and growth.sources_of(DemandGrowth.SOURCE_DUKE) > 0


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
