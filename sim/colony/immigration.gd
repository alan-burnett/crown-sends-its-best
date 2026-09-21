class_name Immigration
extends RefCounted

## Who arrives, and what they bring (#170, `docs/mechanics/immigration.md`).
##
## ## Where it sits
##
## **World month phase 1, Arrivals**, alongside everything else crossing from the
## Crown. Immigrants land with their own supplies and gold and join at once; the
## town pays nothing for them (SPEC §12.1).
##
## It reads the quality of life **last month's Settle** wrote, so arrivals are a
## consequence of how the town was doing — which is precisely the lever the PC's
## letters reach.
##
## ## 🔒 Each town computes its own, and there is no pool
##
## Settlers are not divided between towns. A town worth coming to gets people
## whether or not its neighbour does, and two identical towns receive identical
## arrivals however many others exist. A pool would make a good town's reward
## depend on somebody else's failure, which is not what emigration is.
##
##     arrivals = crown_flow x appeal
##     appeal   = pull(quality of life) + buildings + policy
##
## Multiplicative on `crown_flow`, because **if nobody is leaving home no amount
## of appeal conjures settlers out of nothing.**
##
## ## 🔒 Immigration is flat; births are proportional
##
## Arrivals do not scale with town size, so immigration dominates when a town is
## small and natural growth when it is large — both halves falling out of one
## decision rather than being balanced against each other.
##
## It also lets a town founded late in a run catch up, because the same trickle
## is transformative at twelve and trivial at two hundred.
##
## ## The pull is steep, and that is the point
##
## Near zero below a floor — **nobody emigrates to a miserable place** — and
## rising sharply above it. A good town gets a virtuous circle and a bad one a
## stagnation that is *breakable*, because quality of life is exactly what the
## PC's letters reach.

const EVENT_ARRIVED: StringName = &"settlers_arrived"

## What the Crown's circumstances send, before any town's appeal.
##
## **The seam for §5**, which ties the flow to the Crown's decline: as things
## worsen at home more people leave, so immigration rises over a run precisely as
## demands grow and the PC can least afford to feed them. Nothing drives it yet
## (#171); reading it here means that ticket is a driver rather than a rewrite.
const FLOW_KEY: String = "crown.emigration"
const FLOW_BASE: float = 1.0

## Quality of life below which essentially nobody comes.
const MISERY_FLOOR: float = 0.35

## How sharply appeal climbs above the floor. Tuning.
const PULL_STEEPNESS: float = 2.5

## What a thriving town pulls, at the top of the curve. Tuning.
const PULL_AT_BEST: float = 4.0

## What a fraction of an expert is worth carrying month to month.
const EXPERT_SHARE: float = 0.04

## What each settler brings with him, in gold. They land with their own supplies
## and their own coin, and that coin feeds `means` in quality of life — so a wave
## of settlers is a windfall before it is a burden (§6).
const PURSE_PER_HEAD: float = 12.0

## Beasts per settler at the top of the Provost's livestock knob. Tuning.
const BEASTS_PER_HEAD: float = 0.08


## How many people a town would draw this month, and of what kind.
##
## Returns `{workers, experts, appeal}`. `experts` is fractional on purpose —
## §7 keeps the remainder and lands a whole person when it reaches one.
static func due(town: Town, context: ColonyContext) -> Dictionary:
	var flow := FLOW_BASE
	if context != null and context.state != null:
		flow += maxf(0.0, float(context.state.get_value(FLOW_KEY, 0.0)))

	# **The Provost's volume knob** (#173, `the-provost.md` §2). It multiplies,
	# because a policy that added a flat number would send the same wave to a
	# wretched town as to a thriving one — and §4's whole point is that the
	# colony has to be worth coming to first.
	var appeal := (pull_of(town) + _from_buildings(town)) 		* (1.0 + _knob(context, PolicyEffects.VOLUME_KEY))
	var arriving := maxf(0.0, flow * appeal)

	# **Education gates natural growth, not arrivals** (`the-provost.md` §3). A
	# town with no learning can still be *sent* scholars; what its own schooling
	# decides is whether it ever raises one. So the share here is a property of
	# the crossing rather than of the town's library.
	# The expert knob rides alongside the buildings that draw scholars, so a
	# printing press and the Provost's policy compound rather than one shadowing
	# the other.
	var scholars := arriving 		* (EXPERT_SHARE + _knob(context, PolicyEffects.EXPERTS_KEY)) 		* (1.0 + _draws_experts(town))
	return {
		"workers": maxf(0.0, arriving - scholars),
		"experts": scholars,
		"appeal": appeal,
	}


## What a town's quality of life is worth as a reason to cross an ocean.
##
## 🔒 **Not linear.** Below the floor it is near zero, because nobody emigrates
## to a miserable place; above it, it climbs steeply.
static func pull_of(town: Town) -> float:
	var above := (town.quality_of_life - MISERY_FLOOR) / maxf(0.0001, 1.0 - MISERY_FLOOR)
	if above <= 0.0:
		return 0.0
	return PULL_AT_BEST * pow(clampf(above, 0.0, 1.0), PULL_STEEPNESS)


## What the town has built that draws people.
static func _from_buildings(town: Town) -> float:
	var total := 0.0
	for id in town.buildings:
		var building := Building.find(StringName(id))
		if building != null and Building.is_lit(town, StringName(id)):
			total += float(building.effect("immigration", 0.0))
	return total


## What shifts the composition towards scholars rather than raising the count.
static func _draws_experts(town: Town) -> float:
	var total := 0.0
	for id in town.buildings:
		var building := Building.find(StringName(id))
		if building != null and Building.is_lit(town, StringName(id)):
			total += float(building.effect("draws_experts", 0.0))
	return total


## Land this month's settlers (Seam A).
##
## 🔒 **A town never turns arrivals away** (§10). Whatever lands, joins — and a
## town that cannot support them may shed an expedition later, which is #175's
## business rather than this one's.
static func arrive(town: Town, context: ColonyContext) -> void:
	var owed := due(town, context)
	town.arrivals_accrued += float(owed["workers"])
	Experts.accrue(town, float(owed["experts"]))

	var landed := int(floorf(town.arrivals_accrued))
	town.arrivals_accrued -= float(landed)

	# **Experts arrive as fractions** (§7). `Experts` owns the remainder and the
	# specialism both, so a scholar who crossed an ocean and one a library raised
	# are the same man arriving by two roads.
	var appeared := Experts.materialise(town, context, Experts.ARRIVED, WorldPhase.ARRIVALS)
	var scholars := int(appeared["count"])

	if landed <= 0 and scholars <= 0:
		return

	town.workers += landed
	var trade: StringName = appeared["specialism"]
	# **Provision** (#173): how well supplied they come. A settler lands with his
	# own coin either way; the Provost's knob decides how much of it there is.
	var purse := float(landed + scholars) * PURSE_PER_HEAD 		* (1.0 + _knob(context, PolicyEffects.PROVISION_KEY))
	town.receive_gold(purse)
	var beasts := _livestock_with_them(town, landed + scholars, context)

	# 🔒 **No letter announces that settlers are sailing** (§11). The PC learns of
	# them when they land, in the same month's report — he could have inferred it
	# from a town whose quality of life he was raising, and nothing spells it out.
	context.log.emit(EVENT_ARRIVED, town.id, context.state.month, {
		"town": String(town.id),
		"workers": landed,
		"experts": scholars,
		"expert_in": String(trade),
		"brought": purse,
		"livestock": beasts,
	}, WorldPhase.ARRIVALS)


## What the Provost's knob is set to, as a share. Zero when he has none.
##
## **Read as a world value**, which `PolicyEffects.pressure` recomputes from the
## book every month — so a knob the PC turned down, or a policy the Crown stopped
## paying for, stops pressing the month it does.
static func _knob(context: ColonyContext, key: String) -> float:
	if context == null or context.state == null:
		return 0.0
	return maxf(0.0, float(context.state.get_value(key, 0.0)))


## The beasts that come over with them (#173, `immigration.md` §7).
##
## **Livestock occasionally, shifted by policy** — and only by policy, so a
## colony whose Provost buys none never sees a cow it did not pay for. The
## fraction is carried like everything else here: a knob worth a tenth of a beast
## a month lands one in the tenth month rather than never.
static func _livestock_with_them(town: Town, people: int, context: ColonyContext) -> int:
	var knob := _knob(context, PolicyEffects.LIVESTOCK_KEY)
	if knob <= 0.0 or people <= 0:
		return 0
	var owed := float(town.livestock_accrued.get("arriving", 0.0)) 		+ float(people) * knob * BEASTS_PER_HEAD
	var landed := int(floorf(owed))
	town.livestock_accrued["arriving"] = owed - float(landed)
	if landed <= 0:
		return 0

	# **Whatever the town is shortest of**, so the knob answers a need rather
	# than always sending the same animal. Ties break on the catalogue's sorted
	# order, which is the colony's business rather than a dictionary's.
	var kinds := ResourceCatalogue.livestock()
	if kinds.is_empty():
		return 0
	var fewest := kinds[0]
	for id in kinds:
		if town.livestock_head(StringName(id)) < town.livestock_head(StringName(fewest)):
			fewest = id
	town.add_livestock(StringName(fewest), landed)
	return landed
