class_name Experts
extends RefCounted

## Where a specialist comes from (#169, `docs/mechanics/the-provost.md` §4,
## `docs/mechanics/immigration.md` §7).
##
## ## 🔒 Growth is fractional and it accumulates
##
## A town's monthly growth is not whole people. It is something like **+4.5
## workers and +0.1 experts**. The workers arrive; **the 0.1 does nothing at all
## — it is saved.** When the accumulated fraction reaches one, a functional
## expert appears.
##
## Carrying the remainder is the whole trick. A town drawing a tenth of a scholar
## a month gets one in the tenth month rather than never, which is what makes
## education an investment with a horizon rather than a lottery.
##
## ## 🔒 Education gates natural growth, not arrivals
##
## A town with no learning **never raises an expert of its own** — no schooling,
## no scholars. It can still be *sent* them, because the Provost's expert knob
## reaches every town whether or not it has a library. An unlettered town is not
## shut out of expertise; it simply cannot generate any, and must be given what
## it gets.
##
## ## 🔒 His expertise is decided when he appears, not when it was earned
##
## He becomes an expert in **whatever would serve the town most**, and nothing
## about the list is authored — SPEC §12.2 says there are as many kinds as there
## are producible resources, and the town picks by value.
##
## Because the type is fixed at the moment he materialises rather than when the
## fraction was earned, **a town that changes character while accumulating gets
## an expert suited to what it has become**, not to what it was.
##
## ## Workers go before experts, always
##
## Not enforced here — it is `Consume._take_one_life`'s rule, and Expedition's.
## The consequence belongs here though: **accumulated expertise is safe from a
## bad winter**, so years of slow learning cannot be undone by one of them.

const EVENT_APPEARED: StringName = &"expert_appeared"

## How he came to be here. Both land the same man; the difference is only what a
## letter may truthfully say about him.
const RAISED: StringName = &"raised"
const ARRIVED: StringName = &"arrived"

## The most of its own growth a town ever turns into expertise, however learned.
##
## Well short of all of it: a town of nothing but scholars is a town with nobody
## to work its ground, and §4's compounding engine would run away without a
## ceiling on it. Tuning.
const LEARNED_SHARE: float = 0.4

## The education at which a town reaches half of that. Tuning.
##
## A theatre alone is 1.0, a printing press with it 4.0, and a library adds one
## for every scholar already resident — so this sits where a town that has built
## deliberately for learning is past halfway and a town that has not is nowhere
## near it.
const HALF_LEARNED: float = 5.0


## What share of a town's own growth its learning turns into expertise.
##
## 🔒 **Zero education is zero share, exactly.** Not nearly zero — a town with
## no learning must never raise a scholar however long it waits, and a small
## positive share would only make it slow.
static func share_of_growth(town: Town) -> float:
	if town.education <= 0.0:
		return 0.0
	# 🔒 **Divided by a thousand** (#426, `population.md` §5): births are people
	# and an expert is one man among them, or a town would raise hundreds a month.
	return LEARNED_SHARE * town.education / (town.education + HALF_LEARNED) \
		/ float(Population.THOUSAND)


## Put a fraction of a person aside. Whole people are `materialise`'s business.
static func accrue(town: Town, scholars: float) -> void:
	town.experts_accrued += maxf(0.0, scholars)


## Turn whatever has accumulated into whole people (Seam A).
##
## Returns `{count, specialism}`; the count is zero in most months of most towns,
## which is the point of the accrual.
static func materialise(
	town: Town,
	context: ColonyContext,
	origin: StringName,
	phase: StringName,
) -> Dictionary:
	var appearing := int(floorf(town.experts_accrued))
	if appearing <= 0:
		return {"count": 0, "specialism": &""}

	town.experts_accrued -= float(appearing)
	var trade := specialism_for(town, context)
	town.add_experts(trade, appearing)

	# One event per man. Two in a month is rare enough to be worth saying twice,
	# and a letter that names a new scholar should not have to read a count out
	# of a payload that almost always means one.
	for _each in appearing:
		context.log.emit(EVENT_APPEARED, town.id, context.state.month, {
			"town": String(town.id),
			"specialism": String(trade),
			"origin": String(origin),
			"experts": town.expert_total(),
		}, phase)
	return {"count": appearing, "specialism": trade}


## Which specialism he turns out to have.
##
## **What a multiplier on this resource would actually be worth here**, which is
## three things and not one:
##
## | | |
## | :--- | :--- |
## | What the town wants | `Valuation.town`, the measure it prices anything by |
## | What there is to multiply | its ground's yield, and the recipes it is running |
## | What another of this kind adds | the next expert, after diminishing returns |
##
## 🔒 **A multiplier on nothing is worth nothing.** The middle term is what makes
## the doc's progression fall out rather than being authored: a fur town gets a
## trapper because its ground gives furs, then a farmer, and **a weaver once it
## is actually turning furs into cloth** — not on the promise of a loom, since
## every town may weave anyway (#152), but on having the furs to weave.
static func specialism_for(town: Town, context: ColonyContext) -> StringName:
	var colony: Colony = null
	if context != null and context.colony != null:
		colony = context.colony
	else:
		colony = Colony.new()
		colony.add(town)
	var desired := DesiredStock.for_town(town, ColonySnapshot.of(colony))
	var potential := _what_there_is_to_multiply(town, context)

	var best := &""
	var best_worth := -1.0
	for resource in ResourceCatalogue.ids():
		var id := StringName(resource)
		var worth := _worth(town, id, desired, potential)
		if worth > best_worth + 0.0001 \
				or (absf(worth - best_worth) <= 0.0001 and String(id) < String(best)):
			best = id
			best_worth = worth

	# A town with nothing at all to multiply — no ground worked, no recipe — still
	# gets a man rather than losing him. He takes up whatever it most wants.
	if best_worth <= 0.0:
		best = _most_wanted(town, desired)
	return best


## What an expert in one resource would be worth to this town, on its own.
##
## The public form of the same three terms, so a reader can ask about one trade
## without re-deriving the whole board. 🔒 **Exactly zero where there is nothing
## to multiply** — the lock itself rather than a consequence of it.
static func worth_of(town: Town, resource: StringName, context: ColonyContext) -> float:
	var colony: Colony = null
	if context != null and context.colony != null:
		colony = context.colony
	else:
		colony = Colony.new()
		colony.add(town)
	var desired := DesiredStock.for_town(town, ColonySnapshot.of(colony))
	return _worth(town, resource, desired, _what_there_is_to_multiply(town, context))


static func _worth(
	town: Town,
	resource: StringName,
	desired: DesiredStock,
	potential: Dictionary,
) -> float:
	return Valuation.town(resource, desired, town.held(resource)) \
		* float(potential.get(String(resource), 0.0)) \
		* _next_expert_adds(town, resource)


## What this town could put a multiplier on, by resource.
##
## Its ground and its loom both, because §12.2's experts multiply a resource
## "including its processed forms" — so the brewer is reachable the month the
## brewhouse is, and not before.
static func _what_there_is_to_multiply(town: Town, context: ColonyContext) -> Dictionary:
	var out: Dictionary = {}
	if context != null and context.map != null:
		for at in context.tiles_of(town):
			for resource in ResourceCatalogue.ids():
				var amount := context.map.yield_at(at.x, at.y, StringName(resource))
				if amount > 0.0:
					out[resource] = float(out.get(resource, 0.0)) + amount

	# 🔒 **What it is actually running, not what it could.** Every town may weave
	# — a building improves the terms rather than unlocking them (#152) — so
	# availability says nothing at all. What separates a cloth town from a town
	# that would like to be one is **having the furs**, and that is the reading
	# that makes the doc's progression fall out: the weaver arrives once the
	# trapping is going, and not on the promise of it.
	for entry in Conversion.all():
		var recipe: Conversion = entry
		var makes := recipe.made_by(town)
		var takes := recipe.consumes_for(town)
		if makes <= 0.0 or takes <= 0.0:
			continue
		var running := clampf(town.held(recipe.input) / takes, 0.0, 1.0)
		if running <= 0.0:
			continue
		var id := String(recipe.output)
		out[id] = float(out.get(id, 0.0)) + makes * running
	return out


## What the *next* expert of a kind is worth, after diminishing returns.
##
## The fifth trapper adds a fraction of what the first did (SPEC §12.2), so a
## town that has been lucky in furs starts turning out farmers on its own.
static func _next_expert_adds(town: Town, resource: StringName) -> float:
	var had := float(town.expert_count(resource))
	return WorkPhase.EXPERT_BONUS * pow(WorkPhase.EXPERT_FALLOFF, had)


## The fallback, when there is nothing to multiply: what the town most wants.
static func _most_wanted(town: Town, desired: DesiredStock) -> StringName:
	var best := &""
	var best_worth := -1.0
	for resource in ResourceCatalogue.ids():
		var id := StringName(resource)
		var worth := Valuation.town(id, desired, town.held(id))
		if worth > best_worth + 0.0001 \
				or (absf(worth - best_worth) <= 0.0001 and String(id) < String(best)):
			best = id
			best_worth = worth
	return best
