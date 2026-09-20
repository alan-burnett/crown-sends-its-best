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
func conversion_terms(recipe: StringName) -> Dictionary:
	var all: Dictionary = effect("conversions", {})
	return all.get(String(recipe), {})


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


## What standing buildings contribute to quality of life. Read in Settle (#50).
static func quality_of_life_for(town: Town) -> float:
	var total := 0.0
	for id in town.buildings:
		var building := find(StringName(id))
		if building != null and is_lit(town, StringName(id)):
			total += float(building.effect("quality_of_life", 0.0))
	return total


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"name": display_name,
		"requires": requires.duplicate(),
		"cost": cost.duplicate(),
		"effects": effects.duplicate(),
		"grants_contact": grants_contact,
	}
