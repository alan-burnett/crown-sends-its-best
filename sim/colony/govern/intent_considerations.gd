class_name IntentConsiderations
extends RefCounted

## What a governor weighs when he decides what his town is for (#53).
##
## **A milestone that adds a system ships that system's considerations with it**
## (CLAUDE.md). These are the colony's: each looks at one aspect of the town and
## says how well each candidate intent answers it. The governor's personality is
## the weight vector over them, so a cautious man and a greedy man read the same
## town and want different things — with **no code per personality**.
##
## Every score is in `[-1, +1]` and neutral is `0.0`, so a consideration with
## nothing to say about a situation contributes nothing rather than quietly
## suppressing an intent. That matters most for the ones whose inputs do not
## move yet: native threat is M5 and quality of life is #50, and both must read
## as *no opinion* until then rather than as *no*.
##
## Written as named subclasses rather than lambdas: a `Callable` living in a
## static registry segfaults Godot 4.7 on shutdown (CLAUDE.md).

const FOOD: StringName = &"food_security"
const COMFORT: StringName = &"quality_of_life"
const REVENUE: StringName = &"revenue"
const THREAT: StringName = &"native_threat"
const ROOM: StringName = &"room_to_grow"
const MANDATE: StringName = &"mandate"
const URGING: StringName = &"crown_urging"

## Consideration ids this system introduces, sorted. `Governor` gives each new
## governor a weight for every one of them.
const ALL: PackedStringArray = [
	"crown_urging", "food_security", "mandate", "native_threat",
	"quality_of_life", "revenue", "room_to_grow",
]

## How long the Crown's Mandate keeps half its pull. SPEC §6.1 says "especially
## in the early game" and nothing more, so this is tuning.
const MANDATE_HALF_LIFE: float = 18.0

## How long the PC's last pronouncement keeps half its pull. A letter is not a
## standing order; a governor remembers it and it fades.
const URGING_HALF_LIFE: float = 6.0

## Months of food at which a town stops thinking about food at all.
const COMFORTABLE_MONTHS: float = 4.0

## What counts as a healthy month's duty for one town, for the revenue axis.
const HEALTHY_REVENUE: float = 80.0


static func register_all() -> void:
	var kinds: Array = [DecisionKind.GOVERNOR_INTENT]
	Deliberation.register_consideration(FoodSecurity.new(), kinds)
	Deliberation.register_consideration(Comfort.new(), kinds)
	Deliberation.register_consideration(Revenue.new(), kinds)
	Deliberation.register_consideration(NativeThreat.new(), kinds)
	Deliberation.register_consideration(RoomToGrow.new(), kinds)
	Deliberation.register_consideration(Mandate.new(), kinds)
	Deliberation.register_consideration(CrownUrging.new(), kinds)
	Deliberation.register_filter(RoomToSettle.new(), kinds)
	Deliberation.register_filter(OnlyIfHeLoathesYou.new(), kinds)


## Halve every `half_life` months. Used for both decaying pulls.
static func decayed(months: float, half_life: float) -> float:
	if half_life <= 0.0:
		return 0.0
	return pow(0.5, maxf(0.0, months) / half_life)


# --- The considerations -----------------------------------------------------

## How hungry the town is, and what that argues for.
##
## **Hunger is the one that can flip an intent on its own.** A town with a month
## of grain left has no business increasing economic output, and a governor who
## thinks otherwise is the design working — his weight on this is low and his
## town will hate him for it (`docs/mechanics/quality-of-life.md`, hope).
class FoodSecurity extends Consideration:
	func _init() -> void:
		super(IntentConsiderations.FOOD)

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var town: Town = context.get_value("town")
		if town == null:
			return 0.0
		var mouths := maxf(1.0, float(town.population()))
		var monthly := mouths * ColonyNeeds.per_head(&"food")
		var months_held := town.held(&"food") / maxf(0.001, monthly)
		var hunger := clampf(1.0 - months_held / IntentConsiderations.COMFORTABLE_MONTHS, 0.0, 1.0)

		match candidate.id:
			GovernorIntent.SURVIVAL:
				# The only intent hunger actively argues *for*, and it argues
				# against itself when the storehouses are full.
				return hunger * 2.0 - 1.0
			GovernorIntent.POPULATION:
				return -hunger * 0.5
			GovernorIntent.DEFENCE:
				return -hunger * 0.5
		return -hunger


## How well the town is living, and what that argues for.
##
## Reads `quality_of_life`, which Settle computes from
## `docs/mechanics/quality-of-life.md`. It is already a `[0, 1]` value, so there
## is no scale to apply here.
class Comfort extends Consideration:
	func _init() -> void:
		super(IntentConsiderations.COMFORT)

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var town: Town = context.get_value("town")
		if town == null:
			return 0.0
		var lack := clampf(1.0 - town.quality_of_life, 0.0, 1.0)

		match candidate.id:
			GovernorIntent.POPULATION:
				return lack
			GovernorIntent.SURVIVAL:
				return lack * 0.5
			GovernorIntent.SETTLEMENT:
				# A miserable town is in no condition to send its best men away.
				return -lack
		return 0.0


## What the colony is returning to the Crown.
class Revenue extends Consideration:
	func _init() -> void:
		super(IntentConsiderations.REVENUE)

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		if context.state == null:
			return 0.0
		var revenue := float(context.state.get_value(WorldValues.REVENUE, 0.0))
		var poverty := clampf(1.0 - revenue / IntentConsiderations.HEALTHY_REVENUE, 0.0, 1.0)

		match candidate.id:
			GovernorIntent.ECONOMY:
				return poverty
			GovernorIntent.SETTLEMENT:
				return poverty * 0.3
		return 0.0


## Whether anybody is likely to come over the hill.
##
## **M5 gives this teeth.** It reads a world value nothing sets yet, and at zero
## it scores zero for every candidate, so today it is a registered consideration
## with no opinion — which is what lets M5 add natives without governors needing
## a new decision path to feel them.
class NativeThreat extends Consideration:
	func _init() -> void:
		super(IntentConsiderations.THREAT)

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		if context.state == null:
			return 0.0
		var threat := clampf(float(context.state.get_value("native_threat", 0.0)), 0.0, 1.0)

		match candidate.id:
			GovernorIntent.DEFENCE:
				return threat
			GovernorIntent.SURVIVAL:
				return threat * 0.5
			GovernorIntent.SETTLEMENT:
				return -threat
		return -threat * 0.3


## Whether there is anywhere to go.
class RoomToGrow extends Consideration:
	func _init() -> void:
		super(IntentConsiderations.ROOM)

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var room := IntentConsiderations.room_in_the_colony(context)
		match candidate.id:
			GovernorIntent.SETTLEMENT:
				return room * 2.0 - 1.0
			GovernorIntent.POPULATION:
				return room * 0.3
		return 0.0


## What the Crown appointed him to do (SPEC §6.1).
##
## **Its pull decays over the run.** Early on he is doing what he was sent to do;
## later he is doing what his circumstances demand. The decay lives in the score
## rather than in the actor's weight, so that a governor's personality — which is
## what `weights` means, and what the save stores — is not quietly rewritten
## month by month. His weight is how much he cares what the Crown wanted; this is
## how long ago they wanted it.
class Mandate extends Consideration:
	func _init() -> void:
		super(IntentConsiderations.MANDATE)

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var mandate := StringName(context.get_value("mandate", ""))
		if String(mandate).is_empty():
			return 0.0
		var pull := IntentConsiderations.decayed(
			float(context.month), IntentConsiderations.MANDATE_HALF_LIFE
		)
		return pull if candidate.id == mandate else -pull * 0.25


## What the PC last told him the town was for.
##
## **This is the lever the whole game turns on.** The player cannot name a
## project; he can say what matters, and a governor who takes it to heart builds
## the granary himself, on a better tile than the player would have picked.
class CrownUrging extends Consideration:
	func _init() -> void:
		super(IntentConsiderations.URGING)

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var urged := StringName(context.get_value("urged", ""))
		if String(urged).is_empty():
			return 0.0
		var age := float(context.month - int(context.get_value("urged_month", 0)))
		var pull := IntentConsiderations.decayed(age, IntentConsiderations.URGING_HALF_LIFE)
		return pull if candidate.id == urged else 0.0


# --- The filter -------------------------------------------------------------

## **A town cannot intend to settle nowhere.**
##
## A hard rule rather than a weight (`docs/mechanics/deliberation.md` §5): no
## governor, however expansionist, can send an expedition to land the colony has
## never seen. Filters run before scoring, so this removes the candidate rather
## than making it merely unattractive.
## Loyalty at or below which a governor will consider turning his town.
##
## **A filter and not a weight** (`deliberation.md` §5). A weight can lose a
## close vote and then win one; this must be unreachable to a man who does not
## loathe the PC, however the rest of his temperament falls. It is also what
## makes recovery work: raise him back over the line and the candidate simply
## stops existing for him (`contacts.md` §8).
const SEDITION_AT: float = 12.0


class OnlyIfHeLoathesYou extends DeliberationFilter:
	func _init() -> void:
		super(&"only_if_he_loathes_you")

	func permits(actor: DeliberationActor, candidate: Candidate, _context: DeliberationContext) -> bool:
		if candidate.id != GovernorIntent.SEDITION:
			return true
		var contact := actor as Contact
		return contact != null \
			and contact.loyalty() <= IntentConsiderations.SEDITION_AT


class RoomToSettle extends DeliberationFilter:
	func _init() -> void:
		super(&"somewhere_to_settle")

	func permits(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> bool:
		if candidate.id != GovernorIntent.SETTLEMENT:
			return true
		return IntentConsiderations.room_in_the_colony(context) > 0.0


## The share of the land the colony can see that no town has claimed.
##
## Shared by the consideration and the filter so that "there is room" cannot come
## to mean two different things.
static func room_in_the_colony(context: DeliberationContext) -> float:
	var map: WorldMap = context.get_value("map")
	var territory: Territory = context.get_value("territory")
	if map == null or territory == null:
		return 0.0

	var seen := 0
	var free := 0
	for at in territory.visible:
		if not map.is_land(at.x, at.y):
			continue
		seen += 1
		if not territory.inside_border(at):
			free += 1
	if seen <= 0:
		return 0.0
	return clampf(float(free) / float(seen), 0.0, 1.0)
