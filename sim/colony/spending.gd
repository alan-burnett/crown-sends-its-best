class_name Spending
extends RefCounted

## How much a town spends, and on what (#137,
## `docs/mechanics/town-economy.md` §4).
##
## ## 🔒 The tiers favour, they do not gate
##
## SPEC §11.3, as the Author revised it:
##
## > Towns spend mostly in their best interests. They will favour trying to meet
## > their needs, then complete their objectives, then spend on luxuries, but they
## > will behave realistically — trying to keep a reserve month to month when
## > their survival is not at stake, and spending a little on luxuries even when
## > there are more important things to buy.
##
## So a tier is **a heavy multiplier on what a thing is worth, not a gate in
## front of it.** A very cheap comfort can outrank a very expensive marginal
## need, and a town one coin short of cloth still buys a little beer.
##
## **That is not a leak.** It is the instinct `quality-of-life.md` is built on —
## enough rum and people do not mind that they are hungry — arriving on the
## buying side instead of the consumption side. A strict gate would have made the
## two sides of the game disagree about the same townspeople.
##
## ## And the numbers are data
##
## Every figure here is tuning, so it lives in `data/colony/spending.json` and
## not in a constant. The multiplier between a need and a want is exactly the
## sort of number that gets moved every playtest, and moving it must not be a
## code change.

const NEED: StringName = &"need"
const OBJECTIVE: StringName = &"objective"
const WANT: StringName = &"want"

static var _tiers: Dictionary = {"need": 8.0, "objective": 2.5, "want": 1.0}
static var _purse_reserve_months: float = 2.0
static var _pleasure_gold_per_head: float = 7.0
static var _rounds: int = 20


static func load_from(record: Dictionary) -> void:
	_tiers = record.get("tiers", _tiers).duplicate()
	_purse_reserve_months = float(record.get("purse_reserve_months", _purse_reserve_months))
	_pleasure_gold_per_head = float(record.get("pleasure_gold_per_head", _pleasure_gold_per_head))
	_rounds = int(record.get("rounds", _rounds))


static func reset() -> void:
	_tiers = {"need": 8.0, "objective": 2.5, "want": 1.0}
	_purse_reserve_months = 2.0
	_pleasure_gold_per_head = 7.0
	_rounds = 20


## What a tier does to a thing's worth.
static func tier_multiplier(tier: StringName) -> float:
	return float(_tiers.get(String(tier), 1.0))


## How many purchases a town makes in a month before it stops reconsidering.
##
## Bounded, because what is worth buying changes as the cart fills and the only
## honest way to find the next purchase is to look again.
static func rounds() -> int:
	return _rounds


## What a unit of contentment is worth in gold, per head.
##
## **Comforts cannot be scored on `base` like everything else.** A luxury's worth
## to a town is not what the resource is in itself — it is what the next measure
## does for the people drinking it, which falls as the cellar fills and depends
## on what else is in there (`quality-of-life.md` §4). This is the exchange rate
## that puts that on the same scale as a sack of grain, so one ranked list can
## hold both.
static func pleasure_worth(mouths: float) -> float:
	return maxf(1.0, mouths) * _pleasure_gold_per_head


## The gold a town holds back against the months ahead (§4).
##
## ## 🔒 Needs override it
##
## A town that cannot eat this month spends its last coin, because holding money
## against next month while starving is not prudence. **The reserve gates
## comforts and the objective, never survival.**
static func purse_reserve(town: Town, context: ColonyContext) -> float:
	var mouths := maxf(1.0, float(town.population()))
	var monthly := 0.0
	for resource in ColonyNeeds.needed_resources():
		var id := StringName(resource)
		monthly += mouths * ColonyNeeds.per_head(id) \
			* Valuation.crown(id, context.state) * (1.0 + context.tax_rate(id))
	return monthly * _purse_reserve_months
