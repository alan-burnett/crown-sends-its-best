class_name Objective
extends RefCounted

## What a town is working towards, and how far along it is (SPEC §11.3, #49).
##
## ## Two kinds, and the second is the one that gets forgotten
##
## The spec's examples are "constructing a building, stockpiling food, harvesting
## a resource, fortifying". Only the first has a *finish*. The rest are **standing
## postures** — a town told to stockpile food is not building a thing, it is
## behaving a certain way for as long as the order stands.
##
## So an objective is either:
##
## - a **construction** — a building id, with a cost that Build consumes over
##   months and a completion that applies an effect;
## - an **improvement** — the same, raised on a named tile rather than in the
##   town. **The governor picks the tile** (`docs/mechanics/governor-objectives.md`
##   section 5); there is no code path by which the PC names one; or
## - a **posture** — no cost, no completion, but it **bends Work and Reckon**: the
##   town works its focus resources by preference and holds them back.
##
## A governor who can only ever be part-way through a church writes the same
## letter every month. This is the class that stops that.
##
## ## Why progress lives on the town
##
## Resources put into a build are **spent, not reserved**. They leave the
## stockpile and become `objective_invested`, which is what makes "a town that
## runs short stalls rather than losing what it has already invested" true
## (#49): the invested resources are not in the stockpile to be eaten, sold or
## given away, and a stall does not refund them.

## No objective at all.
const NONE: StringName = &"none"

## A building, with a cost and a completion.
const CONSTRUCTION: StringName = &"construction"

## An improvement on a tile. A cost and a completion, like a construction, but
## the tile is part of the objective.
const IMPROVEMENT: StringName = &"improvement"

## A standing posture. No cost, no completion.
const POSTURE: StringName = &"posture"

## **A cost is met when it is met to within this.**
##
## Resources are floats and arrive by purchase, so the last unit of a thirty-unit
## cost lands as 29.999999. Without a tolerance the build is never finished, the
## town gathers for ever, and the bug looks exactly like a town that cannot
## afford the last plank.
const MET: float = 0.001

## Posture id -> its record. Data, like everything else the town does.
static var _postures: Dictionary = {}

## Intent id -> how a letter says it.
##
## **Prose belongs in the content**, even prose about a code constant. A
## governor writing "I am seeing that nobody here starves" is a sentence in a
## language, and a second language is a copied folder where only the text
## changes (SPEC §9.7).
static var _intents: Dictionary = {}



static func load_from(record: Dictionary) -> void:
	_postures = {}
	var records: Array = record.get("postures", [])
	for entry in records:
		var id := String(entry.get("id", ""))
		if id.is_empty():
			push_error("An objective posture has no id.")
			continue
		_postures[id] = {
			"name": String(entry.get("name", id)),
			"focus": PackedStringArray(entry.get("focus", [])),
		}


	_intents = {}
	for entry in record.get("intents", []):
		var intent := String(entry.get("id", ""))
		if not intent.is_empty():
			_intents[intent] = {
				"name": String(entry.get("name", intent)),
				"pursuing": String(entry.get("pursuing", "")),
				"stocks": entry.get("stocks", {}).duplicate(),
			}


static func reset() -> void:
	_postures = {}
	_intents = {}


## What a letter calls an intent — a noun phrase, as in "attend to the colony's
## profit".
static func intent_name(id: StringName) -> String:
	return String(_intents.get(String(id), {}).get("name", String(id)))


## What a governor says he is doing, as a clause: "seeing that nobody starves".
static func intent_pursuing(id: StringName) -> String:
	return String(_intents.get(String(id), {}).get("pursuing", ""))


## What a governor holding this intent wants kept on hand, per head.
##
## **The modifiers are the only thing that creates demand** for a resource a town
## does not eat (`docs/mechanics/town-economy.md` §3). Months of consumption is
## zero for stone and guns, so their reserve is zero and nothing would ever buy
## them — a military intent would protect the guns a town already had and never
## send it shopping for guns it did not.
##
## Per head rather than absolute, so the demand grows with the town.
static func intent_stocks(intent: StringName) -> Dictionary:
	return _intents.get(String(intent), {}).get("stocks", {})


## Intent ids that carry prose, sorted.
static func named_intents() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(_intents.keys())
	out.sort()
	return out


## Posture ids, sorted.
static func posture_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(_postures.keys())
	out.sort()
	return out


static func is_posture(id: StringName) -> bool:
	return _postures.has(String(id))


## Which sort of objective this is. **A building id that is not a known building
## and not a known posture is `NONE`**, not a crash: content can be wrong.
static func kind_of(id: StringName) -> StringName:
	if String(id).is_empty():
		return NONE
	if Building.has(id):
		return CONSTRUCTION
	if Improvement.has(id):
		return IMPROVEMENT
	if is_posture(id):
		return POSTURE
	return NONE


static func display_name(id: StringName) -> String:
	if Building.has(id):
		return Building.find(id).display_name
	if Improvement.has(id):
		return Improvement.find(id).display_name
	if is_posture(id):
		return String(_postures[String(id)].get("name", String(id)))
	return ""


# --- Postures ---------------------------------------------------------------

## The resources a town's posture favours, sorted. Empty when it has no posture.
##
## **Read by Work**, which weights tiles yielding them, and by Reckon, which
## holds them back. That is the whole of what a posture *is*.
##
## More than one, because gathering an expedition supplies grain *and* tools, and
## a posture that could only ever name one resource would have to be split into
## two orders the governor never meant to give separately.
static func posture_focus(town: Town) -> PackedStringArray:
	if not is_posture(town.objective):
		return PackedStringArray()
	var focus: PackedStringArray = _postures[String(town.objective)].get("focus", PackedStringArray())
	var out := focus.duplicate()
	out.sort()
	return out


## Whether the town's posture means it will not part with a resource.
##
## **A town stockpiling food that sold its surplus every month would be
## stockpiling nothing.** Reckon answers this by reserving everything the town
## holds of it, so Sell finds no spare and Relief finds nothing to give — which
## is what a standing order to hoard something actually means.
static func hoards(town: Town, resource: StringName) -> bool:
	return posture_focus(town).has(String(resource))


# --- Construction -----------------------------------------------------------

## What the build still needs, over what has already gone into it.
##
## Measured against **invested**, not against the stockpile: once resources go
## into a build they are gone from the stores, so counting the stores again would
## have the town gather everything twice.
static func outstanding(town: Town) -> Dictionary:
	var out: Dictionary = {}
	for resource in costed_resources(town):
		var still := cost_of(town, StringName(resource)) - town.invested(StringName(resource))
		if still > MET:
			out[resource] = still
	return out


## What this town is working towards costs, whichever kind it is. A posture
## costs nothing, which is why it can never stall.
static func costed_resources(town: Town) -> PackedStringArray:
	match kind_of(town.objective):
		CONSTRUCTION:
			return Building.find(town.objective).costed_resources()
		IMPROVEMENT:
			return Improvement.find(town.objective).costed_resources()
	return PackedStringArray()


static func cost_of(town: Town, resource: StringName) -> float:
	match kind_of(town.objective):
		CONSTRUCTION:
			return Building.find(town.objective).cost_of(resource)
		IMPROVEMENT:
			return Improvement.find(town.objective).cost_of(resource)
	return 0.0


## Whether this is a thing that finishes at all.
static func completes(id: StringName) -> bool:
	var kind := kind_of(id)
	return kind == CONSTRUCTION or kind == IMPROVEMENT


## What the build still needs that the town does not already have to hand.
##
## **This is the "want"** — what Work goes looking for and Exchange shops for.
## What it is outstanding, less what is already in the stockpile waiting to be
## put in.
static func still_to_gather(town: Town) -> Dictionary:
	var out: Dictionary = {}
	var still := outstanding(town)
	for resource in still:
		var missing := float(still[resource]) - town.held(StringName(resource))
		if missing > MET:
			out[resource] = missing
	return out


## Whether every resource the build needs has been invested.
static func materials_complete(town: Town) -> bool:
	return outstanding(town).is_empty()


## How much a town can put into construction in a month (#148).
##
## **Resources per month, from the people who carry them.** A large town raises a
## granary in a month; a small one takes an age over the same structure. Nothing
## has to be re-tuned when a cost changes, because the cost *is* the schedule.
##
## `build_speed` multiplies it, which is what a carpenters' hall is for.
##
## **Chosen to reproduce the doc's own worked example** — *"a granary costing 40
## wood and 20 stone is 60 resources; a town with a capacity of 30 builds it in
## exactly two months"* — which for a town of fourteen means about two per head.
##
## It is the one number in #148 that is tuning rather than mechanism, and it
## moves a great deal: across 12 seeds and five years, 0.8 gives mean rebel
## sentiment 0.48 and standing 26.3, while 2.5 gives 3.99 and 23.0. Towns that
## can build do build, and `RebelSentiment` makes prosperity breed the thing that
## destroys it. Raising or lowering this is a one-line change and the Author's.
const CAPACITY_PER_HEAD: float = 2.0


static func build_capacity(town: Town) -> float:
	var speed := 0.0
	for id in town.buildings:
		var standing := Building.find(StringName(id))
		if standing != null:
			speed += float(standing.effect("build_speed", 0.0))
	return maxf(1.0, float(town.population())) * CAPACITY_PER_HEAD * (1.0 + maxf(0.0, speed))


## What a build costs altogether, in resources.
static func total_cost(town: Town) -> float:
	var total := 0.0
	for resource in costed_resources(town):
		total += cost_of(town, StringName(resource))
	return total


## 🔒 **How long this build takes, derived rather than authored** (#148).
##
## ## The materials are the time
##
## A building used to author a `months` figure beside its cost and the two had to
## be kept plausible against each other by hand — a cost could be doubled and the
## duration left alone, and nothing would notice. One authored number instead,
## and they can no longer disagree.
##
## It also collapses two gates into one. A construction used to need its
## materials gathered *and* its months elapsed; now materials are consumed into
## the work at the capacity rate, so stalling is a single condition: the town
## cannot get the resources, or has no capacity.
static func months_required(town: Town) -> int:
	if not completes(town.objective):
		return 0
	return maxi(1, int(ceil(total_cost(town) / maxf(0.001, build_capacity(town)))))


## How far along, as `0.0` to `1.0`.
##
## **Materials and months, weighted evenly**, so "the church is half raised"
## (#49) means something whether the town is still gathering stone or already
## cutting it. A posture has no progress and returns `0.0`; ask `kind_of` first
## rather than reading a fraction that was never going to move.
static func progress_fraction(town: Town) -> float:
	if not completes(town.objective):
		return 0.0

	var required := 0.0
	var invested := 0.0
	for resource in costed_resources(town):
		var needed := cost_of(town, StringName(resource))
		required += needed
		invested += minf(needed, town.invested(StringName(resource)))
	var materials := 1.0 if required <= 0.0 else invested / required

	# **The materials are the time** (#148), so there is no second half to weigh
	# against them any more. "The church is half raised" means half its stone is
	# in the frame, which is the thing a governor could actually see.
	return clampf(materials, 0.0, 1.0)
