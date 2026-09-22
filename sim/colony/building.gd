class_name Building
extends RefCounted

## Something a town can build (SPEC §11.3).
##
## **Prerequisites, costs and effects are all data.** Nothing in code names a
## building, so adding one is adding a file — which is the test of whether the
## tree is really a tree or a switch statement wearing one.

static var _buildings: Dictionary = {}  # String -> Building

var id: StringName = &""
var display_name: String = ""

## Buildings that must already stand. **All of them**, not any.
var requires: PackedStringArray = PackedStringArray()


## Resource id -> how much the Build phase consumes (#49).
var cost: Dictionary = {}

## **Gold a month to keep it running** (#151), and it may be zero.
##
## A building is not a one-off cost and a permanent gain. A town that overbuilds
## and goes broke watches its own advantages switch off — and get them back the
## moment it can pay again, because upkeep is a squeeze rather than a punishment.
var upkeep: float = 0.0

## What it does once it stands.
var effects: Dictionary = {}

## **Uncommon.** A church brings a clergyman, an armoury a quartermaster
## (SPEC §8.2). Declared here; nothing consumes it until M7 — the field, not the
## feature.
var grants_contact: String = ""

## 🔒 **A building that widens a man the town already has** (#276,
## `institutional-contacts.md` §1).
##
## The cathedral, the armoury and the college. **An extension never creates a
## second contact** — it widens the first, which is what `buildings.md` means by
## the cathedral's *more with the contact*.
##
## Named rather than derived from `requires`, because a prerequisite and a
## widening are different claims: the gunsmith requires the foundry and widens
## nobody.
var extends_contact: String = ""


static func load_from(records: Array) -> void:
	_buildings = {}
	for record in records:
		var building := Building.new()
		building.id = StringName(record.get("id", ""))
		if building.id.is_empty():
			push_error("A building record has no id.")
			continue
		building.display_name = String(record.get("name", record.get("id", "")))
		building.requires = PackedStringArray(record.get("requires", []))
		building.cost = record.get("cost", {}).duplicate()
		building.upkeep = maxf(0.0, float(record.get("upkeep", 0.0)))
		building.effects = record.get("effects", {}).duplicate()
		building.grants_contact = String(record.get("grants_contact", ""))
		building.extends_contact = String(record.get("extends_contact", ""))
		_buildings[String(building.id)] = building


static func reset() -> void:
	_buildings = {}


static func has(id: StringName) -> bool:
	return _buildings.has(String(id))


static func find(id: StringName) -> Building:
	return _buildings.get(String(id))


static func ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(_buildings.keys())
	out.sort()
	return out


## Buildings a town could start right now, sorted.
##
## **A building cannot be started when its prerequisites are unmet**, and one
## already standing is not on offer again.
static func available_to(town: Town) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id in ids():
		if town.has_building(StringName(id)):
			continue
		if find(StringName(id)).prerequisites_met(town):
			out.append(id)
	return out


## What this building leads to, sorted. The other direction through the tree.
static func unlocked_by(id: StringName) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for other in ids():
		if find(StringName(other)).requires.has(String(id)):
			out.append(other)
	return out


func prerequisites_met(town: Town) -> bool:
	for required in requires:
		if not town.has_building(StringName(required)):
			return false
	return true


func cost_of(resource: StringName) -> float:
	return float(cost.get(String(resource), 0.0))


## Resources this building needs, sorted.
func costed_resources() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(cost.keys())
	out.sort()
	return out


func effect(name: String, fallback: Variant = 0.0) -> Variant:
	return effects.get(name, fallback)


# --- What standing buildings add up to -------------------------------------
#
# Asked of the town rather than stored on it, so a building's effect cannot
# drift out of step with whether the building is actually there.

## 🔒 **Standing is not the same as working** (#151).
##
## A town that cannot pay a building's upkeep keeps the building and loses the
## effect. It is not lost, not damaged, not demolished — it stands idle and
## switches back on the month the town can afford it again.
##
## Every reader below goes through this, which is the only way the two can never
## disagree: a yield that counted a dark mill would have the town produce from a
## building the governor is writing home to say has stopped.
static func is_lit(town: Town, id: StringName) -> bool:
	return town == null or not town.dark_buildings.has(String(id))


## What the town owes this month to keep everything it has built running.
static func upkeep_for(town: Town) -> float:
	var owed := 0.0
	for id in town.buildings:
		var building := find(StringName(id))
		if building != null:
			owed += building.upkeep
	return owed

## The terms this building sets for a conversion, or empty.
##
## `{"ratio": input per unit of output, "throughput": input per worker-month}`.
##
## ## 🔒 Only the ratio is authored
##
## **A worker makes two** (`town-economy.md` §11). The base is anchored on the
## output, so a town worker turns out two of the processed good and consumes
## `2 x ratio` of the input; a conversion building doubles what he puts through.
##
## Both figures therefore fall out of the ratio, and authoring the second would
## let them drift apart — which they did: every throughput shipped in #183 was
## exactly half what it should have been, and nothing could tell, because the
## file agreed with itself.
func conversion_terms(recipe: StringName) -> Dictionary:
	var all: Dictionary = effect("conversions", {})
	var terms: Dictionary = all.get(String(recipe), {})
	if terms.is_empty():
		return {}
	var ratio := maxf(0.0001, float(terms.get("ratio", 1.0)))
	var base := base_ratio_for(recipe)
	# The building that sets the worst terms *is* the base case — the town hall
	# for everything ungated, the gunsmith for guns. Anything better is an
	# improvement, and an improvement doubles the throughput.
	var batches := 2.0 if is_equal_approx(ratio, base) else 4.0
	return {"ratio": ratio, "throughput": batches * base}


## The worst terms anything in the tree offers for a conversion.
##
## **That is the base**, by definition: the town hall speaks for every ungated
## recipe and the gunsmith for the one that is gated, and each of them is the
## least generous thing that can perform it.
static func base_ratio_for(recipe: StringName) -> float:
	var worst := 0.0
	for id in ids():
		var building := find(StringName(id))
		if building == null:
			continue
		var all: Dictionary = building.effect("conversions", {})
		if not all.has(String(recipe)):
			continue
		worst = maxf(worst, float(all[String(recipe)].get("ratio", 1.0)))
	return maxf(0.0001, worst)


## 🔒 **The best building the town has for a conversion sets its terms** (#152).
##
## ## A building defines a conversion; it does not multiply one
##
## This was a `yield_bonus` raising output while input stayed fixed, so
## efficiency and throughput could only move together. They are different things:
##
## > Once you build a tool factory you are shipping it **a great deal more iron**
## > than you were shipping to individual blacksmiths. **Consumption goes up and
## > the ratio improves.**
##
## A bonus can say neither of those. Two dials can say both, and a building that
## improves one without the other is authorable.
##
## ## And the base case is not a special case
##
## Every town has a **town hall** from the moment it is founded, and its job is to
## define the eight base ratios. So there is no fallback branch in code for "a
## town with no building for this" — the rule is uniform, and an upgrade is
## simply a building that defines better terms.
##
## Better means a lower ratio; a tie goes to the one that puts more through, and
## then to the name, so the choice never depends on iteration order.
static func terms_for(town: Town, recipe: StringName) -> Dictionary:
	var best: Dictionary = {}
	var from := ""
	if town != null:
		var held := town.buildings.duplicate()
		held.sort()
		for id in held:
			var building := find(StringName(id))
			if building == null or not is_lit(town, StringName(id)):
				continue
			var terms := building.conversion_terms(recipe)
			if terms.is_empty():
				continue
			if best.is_empty() or _better(terms, best):
				best = terms
				from = id
	if best.is_empty():
		return {}
	return {
		"ratio": maxf(0.0001, float(best.get("ratio", 1.0))),
		"throughput": maxf(0.0, float(best.get("throughput", 0.0))),
		"from": from,
	}


## Whether any building in the data defines terms for a recipe (#150).
##
## **What makes a recipe exist at all.** A conversion nothing can perform is not
## a conversion, and this is asked of the whole building tree rather than of one
## town — the recipe is real, and whether *this* town can run it is
## `terms_for` returning something.
static func anything_defines(recipe: StringName) -> bool:
	for id in ids():
		var building := find(StringName(id))
		if building != null and not building.conversion_terms(recipe).is_empty():
			return true
	return false


## Which buildings would let a town perform a conversion it cannot, sorted.
##
## **So a letter can name the thing it lacks.** A governor reporting that his
## militia has no muskets and no way to make any should be able to say what would
## fix it, and that has to come from the data rather than from prose.
static func would_allow(recipe: StringName) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id in ids():
		var building := find(StringName(id))
		if building != null and not building.conversion_terms(recipe).is_empty():
			out.append(id)
	out.sort()
	return out


static func _better(terms: Dictionary, than: Dictionary) -> bool:
	var ratio := float(terms.get("ratio", 1.0))
	var beaten := float(than.get("ratio", 1.0))
	if not is_equal_approx(ratio, beaten):
		return ratio < beaten
	return float(terms.get("throughput", 0.0)) > float(than.get("throughput", 0.0))


## Whether the town has something better than its town hall for a conversion.
##
## **What "it has a use for this" means** now that a bonus no longer says it
## (`desired_stock.gd`). A loom makes furs worth having in a way they are not in
## a town without one.
static func improves_conversion(town: Town, recipe: StringName) -> bool:
	var terms := terms_for(town, recipe)
	return not terms.is_empty() and String(terms.get("from", "")) != String(BASE)


## The building every town has from the moment it is founded (#152).
##
## It is not built, not chosen and not optional. Its job is to define the base
## conversion terms, so that the base case is a building like any other rather
## than a branch in code. The Author notes it "will come in handy in other
## ways", so it is the natural anchor for future town-wide effects.
const BASE: StringName = &"town_hall"


## **Pleasure that arrives without a ship** (#153).
##
## Returns `{"served": share of the population entertained, "kinds": how many
## distinct amusements}`, which is the same pair a cellar of drink produces —
## because amusement feeds pleasure through the *same* path as a consumed luxury
## rather than as a second quality-of-life term.
##
## ## Why that matters strategically
##
## Beer and rum arrive through Exchange and can be cut off by a trade protest, a
## blockade, a rebellion, or simply no gold. **A theatre cannot be embargoed.**
## So a town with amusement has a floor of contentment underneath its luxuries,
## and the PC can build that floor permanently into a colony he cannot feed.
##
## `quality-of-life.md` establishes that pleasure *masks* the shortfall and that
## its power is greatest when life is worst. Amusement makes bread and circuses
## buildable, which is SPEC §3.2's satire working exactly as intended.
##
## **The counterweight is upkeep.** A town too poor to pay watches its amusements
## go dark in the same month its larder empties, which is why this reads through
## `is_lit` like every other effect.
static func amusement_for(town: Town) -> Dictionary:
	var served := 0.0
	for id in town.buildings:
		var building := find(StringName(id))
		if building == null or not is_lit(town, StringName(id)):
			continue
		served += maxf(0.0, float(building.effect("amusement", 0.0)))
	# 🔒 **One kind, however much of it there is** (`buildings.md` §7). A second
	# amusement building adds only to `served`: amusement is already being
	# consumed, and more of it is deeper rather than wider.
	#
	# That makes it behave exactly as a luxury does, which is the point — a town
	# with beer, rum and a theatre reaches full variety just as one with beer, rum
	# and tea does, so a colony can build its way to part of what it would
	# otherwise have to buy. Counting each building as its own kind would let six
	# amusements clear `VARIETY_TARGET` on their own and make the cellar
	# irrelevant.
	return {"served": served, "kinds": 1 if served > 0.0 else 0}


## How much this town's production of a resource is raised by what it has built.
static func yield_bonus_for(town: Town, resource: StringName) -> float:
	var bonus := 0.0
	for id in town.buildings:
		var building := find(StringName(id))
		if building == null or not is_lit(town, StringName(id)):
			continue
		var bonuses: Dictionary = building.effect("yield_bonus", {})
		bonus += float(bonuses.get(String(resource), 0.0))
	return bonus


## Extra months of need a town holds back, on top of the data's baseline.
static func reserve_months_for(town: Town, resource: StringName) -> float:
	var months_held := 0.0
	for id in town.buildings:
		var building := find(StringName(id))
		if building == null or not is_lit(town, StringName(id)):
			continue
		var months: Dictionary = building.effect("reserve_months", {})
		months_held += float(months.get(String(resource), 0.0))
	return months_held


## Every resource this town's buildings want laid in, sorted (#148).
static func reserved_resources(town: Town) -> PackedStringArray:
	var out: Dictionary = {}
	for id in town.buildings:
		var building := find(StringName(id))
		if building == null or not is_lit(town, StringName(id)):
			continue
		for resource in building.effect("reserve_months", {}):
			out[String(resource)] = true
	var sorted: PackedStringArray = PackedStringArray(out.keys())
	sorted.sort()
	return sorted


## How many head this town's buildings can graze.
##
## **Livestock off pasture eat the town's grain** (#48), so this is the
## difference between a herd that feeds the town and one that competes with it.
static func pasture_capacity_for(town: Town) -> int:
	var head := 0
	for id in town.buildings:
		var building := find(StringName(id))
		if building != null and is_lit(town, StringName(id)):
			head += int(building.effect("pasture", 0))
	return head


## What the town has built that makes it grow faster, people and herds alike.
##
## **One figure for both** (`buildings.md` §4): the granary is stored food, and
## stored food is what carries a household through a winter and a herd through a
## lean spring. A building that sped children but not calves would be two
## mechanics wearing one name.
static func growth_bonus_for(town: Town) -> float:
	var total := 0.0
	for id in town.buildings:
		var building := find(StringName(id))
		if building != null and is_lit(town, StringName(id)):
			total += float(building.effect("growth", 0.0))
	return total


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"name": display_name,
		"requires": requires.duplicate(),
		"cost": cost.duplicate(),
		"effects": effects.duplicate(),
		"grants_contact": grants_contact,
		"extends_contact": extends_contact,
	}
