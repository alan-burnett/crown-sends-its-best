class_name Education
extends RefCounted

## What a town has worth teaching (#168, `docs/mechanics/the-provost.md` §3).
##
## **A town attribute, like quality of life** — not a colony one.
##
## ## 🔒 It does exactly one thing
##
## It sets how likely growth is to arrive as an **expert** rather than a worker.
## A learned town turns its growth into expertise; an ignorant one turns it into
## hands. Nothing else reads it, and nothing else should.
##
## And it gates **natural growth only**. A town with none will never raise an
## expert of its own — no schooling, no scholars — but it can still *receive*
## them, because immigration brings experts on its own terms. An unlettered town
## is not shut out of expertise; it simply cannot generate any.
##
## ## 🔒 A library turns expertise into more expertise
##
## Three things raise it, and the third is the whole design:
##
## | Source | |
## | :--- | :--- |
## | Buildings | the theatre and the printing press contribute |
## | The curriculum | raises every town's a little, for very little |
## | **Resident experts, through a library** | an expert in an unlettered town teaches nobody |
##
## That last rule is the compounding engine, and the reason the library is
## expensive and sits where it does in the tree: **a town that gets its first
## scholar finds the second easier.** A college extends it to the experts it
## counts from elsewhere, so three tobacco men in three towns make a college town
## work as though it held all three.
##
## ## There is no schoolhouse
##
## Every town already teaches its children in a shack. Schooling is universal,
## free, and on its own worth almost nothing, which is why the curriculum needs
## no building and reaches every town — there is always somewhere to send the
## books. **What a town lacks is not a schoolroom but anything worth teaching in
## it.**

const EVENT_MEASURED: StringName = &"town_education"

## World value the curriculum policy presses on.
##
## **The seam, cut and left open** (#173). Nothing writes it yet; the Provost's
## knobs ticket is what will. Reading it here now costs nothing and means the
## policy is a data change rather than a change to this file, exactly as
## `Valuation.crown` took a `state` before any policy moved a price.
const CURRICULUM_KEY: String = "policy.curriculum"

## How much noticing takes, before the log calls it a change.
const NOTICEABLE: float = 0.05


## What this town has worth teaching, now.
static func of(town: Town, context: ColonyContext) -> float:
	var total := 0.0
	for id in town.buildings:
		var building := Building.find(StringName(id))
		if building == null or not Building.is_lit(town, StringName(id)):
			continue
		total += float(building.effect("education", 0.0))

	total += _from_scholars(town, context)
	if context != null and context.state != null:
		total += maxf(0.0, float(context.state.get_value(CURRICULUM_KEY, 0.0)))
	return maxf(0.0, total)


## What the town's scholars teach, which is nothing without somewhere to teach.
##
## **The building carries the rate**, so a library and a college are the same
## rule with different numbers rather than two mechanisms.
static func _from_scholars(town: Town, context: ColonyContext) -> float:
	var per_expert := 0.0
	var reaches_the_colony := false
	for id in town.buildings:
		var building := Building.find(StringName(id))
		if building == null or not Building.is_lit(town, StringName(id)):
			continue
		per_expert = maxf(per_expert, float(building.effect("education_per_expert", 0.0)))
		if float(building.effect("counts_distant_experts", 0.0)) > 0.0:
			reaches_the_colony = true
	if per_expert <= 0.0:
		return 0.0

	var scholars := town.expert_total()
	if reaches_the_colony and context != null and context.colony != null:
		for other in context.colony.in_order():
			if other != town:
				scholars += other.expert_total()
	return per_expert * float(scholars)


## Bring the town's education up to date, and say so if it moved (Seam A).
static func settle(town: Town, context: ColonyContext) -> void:
	var before := town.education
	town.education = of(town, context)
	if absf(town.education - before) < NOTICEABLE:
		return
	context.log.emit(EVENT_MEASURED, town.id, context.state.month, {
		"town": String(town.id),
		"education": town.education,
		"was": before,
		"rising": town.education > before,
	}, WorldPhase.COLONY_MONTH)
