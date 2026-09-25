class_name GrievanceConsiderations
extends RefCounted

## How a governor answers a tribe's letter (#435, `docs/mechanics/natives.md`
## §11, `deliberation.md`).
##
## 🔒 **A decision point, so it goes through the kernel** and emits its trace:
## yield, gift, refuse or threaten, scored on his intent, his temperament, the
## town's safety and what yielding would cost the town. The two things that
## cannot be answered at all are **filters**: a town cannot unfound itself, and a
## man cannot give what his town does not hold.
##
## Every figure here is a placeholder for M8's tuning.

## 🔒 **What his intent makes of a complaint** (§11). A cell is a push toward an
## answer, −1 to +1, like the agendas' table. Go wide wants the ground; military
## wants the fight; a town going tall buys its quiet.
const BY_INTENT: Dictionary = {
	"go_tall": {"yield": 0.3, "gift": 0.6, "refuse": -0.2, "threaten": -0.3},
	"go_wide": {"yield": -0.4, "gift": 0.1, "refuse": 0.5, "threaten": 0.2},
	"get_rich": {"yield": 0.1, "gift": -0.4, "refuse": 0.3, "threaten": 0.0},
	"military": {"yield": -0.5, "gift": -0.3, "refuse": 0.3, "threaten": 0.8},
	"education": {"yield": 0.3, "gift": 0.3, "refuse": -0.2, "threaten": -0.3},
	"prepare_for_rebellion": {"yield": 0.3, "gift": 0.3, "refuse": -0.2, "threaten": -0.4},
}

## **An unsafe town buys peace**; a safe one has nothing to be afraid of. Read
## against how unsafe it is, so a perfectly safe town hears nothing from this.
const BY_DANGER: Dictionary = {"yield": 1.0, "gift": 0.6, "refuse": -0.6, "threaten": -1.0}

## A trait's middle, and how far from it counts as all the way (`Temperament`).
const TRAIT_MIDDLE: float = 0.9
const TRAIT_SPAN: float = 0.7


static func register_all() -> void:
	var kinds: Array = [DecisionKind.TRIBE_GRIEVANCE]
	Deliberation.register_consideration(ByIntent.new(), kinds)
	Deliberation.register_consideration(ByDanger.new(), kinds)
	Deliberation.register_consideration(CostOfYielding.new(), kinds)
	Deliberation.register_consideration(CostOfAGift.new(), kinds)
	Deliberation.register_consideration(ByTemper.new(), kinds)
	Deliberation.register_consideration(AsTheCrownUrged.new(), kinds)
	Deliberation.register_filter(OnlyWhatCanBeYielded.new(), kinds)
	Deliberation.register_filter(OnlyWhatHeHasToGive.new(), kinds)


# --- What a gift is ---------------------------------------------------------------

## What the tribe would be sent, from this town: `{resource, amount}`, or empty.
##
## ⚠ assumed in §11: **worth a month of the tile's yield**, paid in **what the
## tribe values most** (§5) — the first thing on the village's appetite, most
## wanted first, that the town holds. Priced at the Crown's figure, which is the
## one price every side of the colony reads.
static func gift_for(grievance: TribeGrievance, town: Town, village: Village, map: WorldMap) -> Dictionary:
	if grievance == null or town == null:
		return {}
	var worth := month_of_the_tile(grievance.at, map)
	var appetite := NativeTrade.appetite_of(village)
	var wanted: Array = appetite.keys()
	wanted.sort_custom(func(a: String, b: String) -> bool:
		var left := float(appetite[a])
		var right := float(appetite[b])
		return left > right if not is_equal_approx(left, right) else a < b)
	for resource in wanted:
		var held := town.held(StringName(resource))
		if held <= 0.0:
			continue
		var price := maxf(0.0001, ResourceCatalogue.price_of(StringName(resource)))
		return {"resource": String(resource), "amount": minf(held, worth / price)}
	return {}


## What a month of this tile gives, at the Crown's prices. **Never nought**, so a
## gift for a company standing on bare rock is still a gift.
static func month_of_the_tile(at: Vector2i, map: WorldMap) -> float:
	var worth := 0.0
	if map != null and map.in_bounds(at.x, at.y):
		for id in ResourceCatalogue.ids():
			worth += map.yield_at(at.x, at.y, StringName(id)) * ResourceCatalogue.price_of(StringName(id))
	return maxf(worth, MINIMUM_GIFT)


## The least a gift is worth. Tuning.
const MINIMUM_GIFT: float = 20.0


static func _grievance(context: DeliberationContext) -> TribeGrievance:
	return context.get_value("grievance")


static func _town(context: DeliberationContext) -> Town:
	return context.get_value("town")


static func _trait(actor: DeliberationActor, name: StringName) -> float:
	var contact := actor as Contact
	if contact == null:
		return 0.0
	return clampf((float(contact.traits.get(String(name), TRAIT_MIDDLE)) - TRAIT_MIDDLE) / TRAIT_SPAN, -1.0, 1.0)


# --- Considerations ------------------------------------------------------------------

class ByIntent extends Consideration:
	func _init() -> void:
		super(&"answer_by_intent")

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var town := GrievanceConsiderations._town(context)
		if town == null:
			return 0.0
		var row: Dictionary = GrievanceConsiderations.BY_INTENT.get(String(town.intent), {})
		return float(row.get(String(candidate.id), 0.0))


class ByDanger extends Consideration:
	func _init() -> void:
		super(&"answer_by_danger")

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var town := GrievanceConsiderations._town(context)
		if town == null:
			return 0.0
		var danger := clampf(1.0 - town.safety, 0.0, 1.0)
		return danger * float(GrievanceConsiderations.BY_DANGER.get(String(candidate.id), 0.0))


## 🔒 **What yielding would cost the town** (§11): the tile's share of what the
## town harvested, so giving up one field of forty costs little and giving up
## the only field costs everything. Only ever pulls away from yielding.
class CostOfYielding extends Consideration:
	func _init() -> void:
		super(&"cost_of_yielding")

	func applies_to(candidate: Candidate) -> bool:
		return candidate.id == TribeGrievance.YIELD

	func score(_actor: DeliberationActor, _candidate: Candidate, context: DeliberationContext) -> float:
		var town := GrievanceConsiderations._town(context)
		var grievance := GrievanceConsiderations._grievance(context)
		if town == null or grievance == null:
			return 0.0
		if grievance.act == TribeGrievance.COMPANY_ON_ITS_GROUND:
			# Calling men home costs the town nothing it harvests.
			return 0.0
		var total := 0.0
		for key in town.harvested_at:
			for resource in town.harvested_at[key]:
				total += float(town.harvested_at[key][resource])
		if total <= 0.0:
			return 0.0
		var here := 0.0
		var this_tile: Dictionary = town.harvested_at.get("%d,%d" % [grievance.at.x, grievance.at.y], {})
		for resource in this_tile:
			here += float(this_tile[resource])
		return -clampf(4.0 * here / total, 0.0, 1.0)


## What a gift would take out of the town's stores of the thing given.
class CostOfAGift extends Consideration:
	func _init() -> void:
		super(&"cost_of_a_gift")

	func applies_to(candidate: Candidate) -> bool:
		return candidate.id == TribeGrievance.GIFT

	func score(_actor: DeliberationActor, _candidate: Candidate, context: DeliberationContext) -> float:
		var town := GrievanceConsiderations._town(context)
		var gift: Dictionary = context.get_value("gift", {})
		if town == null or gift.is_empty():
			return 0.0
		var held := maxf(0.0001, town.held(StringName(gift["resource"])))
		return -clampf(float(gift["amount"]) / held, 0.0, 1.0)


## 🔒 **His temperament** (§11: *his personality*). Mettle reaches for the
## threat and away from yielding; pity reaches for the gift. Read off his traits,
## which every contact already has, so no governor needs rolling again.
class ByTemper extends Consideration:
	func _init() -> void:
		super(&"answer_by_temper")

	func score(actor: DeliberationActor, candidate: Candidate, _context: DeliberationContext) -> float:
		var mettle := GrievanceConsiderations._trait(actor, Temperament.METTLE)
		var pity := GrievanceConsiderations._trait(actor, Temperament.PITY)
		match candidate.id:
			TribeGrievance.THREATEN:
				return mettle
			TribeGrievance.REFUSE:
				return 0.3 * mettle
			TribeGrievance.YIELD:
				return 0.5 * pity - 0.5 * mettle
			TribeGrievance.GIFT:
				return pity
		return 0.0


## 🔒 **What the PC urged, when he was asked** (#436, §11). It moves which answer
## he gives and never gives it by itself: one push among several, as hard as the
## letter was written. Present only when his compliance took the letter.
class AsTheCrownUrged extends Consideration:
	func _init() -> void:
		super(&"answer_as_urged")

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var grievance := GrievanceConsiderations._grievance(context)
		if grievance == null or String(grievance.urged).is_empty() or candidate.id != grievance.urged:
			return 0.0
		return IntentConsiderations.intensity_of(grievance.urged_tone)


# --- Filters ----------------------------------------------------------------------------

## 🔒 **A town cannot unfound itself**, and a warning is not an act to stop.
class OnlyWhatCanBeYielded extends DeliberationFilter:
	func _init() -> void:
		super(&"only_what_can_be_yielded")

	func permits(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> bool:
		if candidate.id != TribeGrievance.YIELD:
			return true
		var grievance := GrievanceConsiderations._grievance(context)
		return grievance != null and grievance.may_be_yielded()


## 🔒 **Nobody gives what his town does not hold.**
class OnlyWhatHeHasToGive extends DeliberationFilter:
	func _init() -> void:
		super(&"only_what_he_has_to_give")

	func permits(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> bool:
		if candidate.id != TribeGrievance.GIFT:
			return true
		return not (context.get_value("gift", {}) as Dictionary).is_empty()
