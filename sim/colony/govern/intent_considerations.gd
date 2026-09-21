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

## **Too many mouths for the ground the town can work** (#175).
##
## Deliberately a *second* consideration rather than a term folded into
## `room_to_grow`, because `deliberation.md` makes personality a weight vector:
## two considerations give two weights and therefore two kinds of governor —
## **the ambitious man who settles because there is land, and the pragmatic one
## who settles because there are too many mouths.** A single blended term
## collapses both into the same character.
##
## `founding-towns.md` §2 needs both to exist, or only one of its two expedition
## kinds ever launches: the grand one and the shed one have different motives,
## not merely different cargo.
##
## It also has no floor where `room_to_grow` has one. A one-town colony can never
## see enough unclaimed land for room to go positive, so settling was unreachable
## by construction. **A town too full for its fields is too full whether or not
## anyone has surveyed the frontier.**
const CROWDING: StringName = &"crowding"

## **How much of the ground this town could work belongs to somebody else**
## (#204).
##
## Deliberately separate from `native_threat`, and for the reason `crowding` is
## separate from `room_to_grow`: two considerations give two weights and
## therefore **two kinds of governor who want the natives gone** — the frightened
## man, who weighs the threat, and the covetous one, who weighs the fields. A
## single blended term would collapse a man who is afraid and a man who is greedy
## into the same character, and they are not the same character at all.
##
## It argues for settling elsewhere just as readily as for driving them off,
## which is what keeps it a measure of the situation rather than an argument for
## one answer.
const NATIVE_LAND: StringName = &"native_land"

const MANDATE: StringName = &"mandate"
const URGING: StringName = &"crown_urging"

## Consideration ids this system introduces, sorted. `Governor` gives each new
## governor a weight for every one of them.
const ALL: PackedStringArray = [
	"crowding", "crown_urging", "food_security", "mandate", "native_land",
	"native_threat", "quality_of_life", "revenue", "room_to_grow",
]

## How long the Crown's Mandate keeps half its pull. SPEC §6.1 says "especially
## in the early game" and nothing more, so this is tuning.
const MANDATE_HALF_LIFE: float = 18.0

## How long the PC's last pronouncement keeps half its pull.
##
## **A letter is not a standing order** — a governor remembers it and it fades,
## and one urged this spring is running his own town again eighteen months later.
## That property is the point and is not up for negotiation.
##
## 🔒 **A year, and not six months** (#212). At six the PC re-sent the same
## instruction two or three times a year to hold a man on course, watched him
## drift back in between, and wondered why. **That is nagging, not ruling**, and
## it turned the game's central lever into an upkeep chore.
##
## Much longer would be wrong the other way: one letter setting a town's course
## for a decade is too strong for how little it costs to send.
const URGING_HALF_LIFE: float = 12.0

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
	Deliberation.register_consideration(Crowding.new(), kinds)
	Deliberation.register_consideration(NativeLand.new(), kinds)
	Deliberation.register_consideration(Mandate.new(), kinds)
	Deliberation.register_consideration(CrownUrging.new(), kinds)
	Deliberation.register_filter(RoomToSettle.new(), kinds)
	Deliberation.register_filter(OnlyIfHeLoathesYou.new(), kinds)
	Deliberation.register_filter(SomebodyToDriveOff.new(), kinds)


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
			GovernorIntent.DRIVE_OFF:
				# **The frightened man's answer.** A governor who reads the
				# neighbours as dangerous and has a heavy weight here stops
				# thinking about walls and starts thinking about the people
				# behind them.
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


## How many mouths the town has for the ground it can work.
##
## 🔒 **Against workable ground, not population alone.** A town of two hundred
## with room to work is not crowded; a town of forty on six tiles is. That is
## what makes the measure mean anything, and it has a consequence worth keeping:
## **the expansion branch lowers crowding by raising influence**, so a town can
## build its way out of needing to leave and guard towers become a real
## alternative to a daughter town.
class Crowding extends Consideration:
	func _init() -> void:
		super(IntentConsiderations.CROWDING)

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var pressure := IntentConsiderations.crowding_of(context)
		match candidate.id:
			GovernorIntent.SETTLEMENT:
				return pressure
			GovernorIntent.POPULATION:
				# A man watching his town outgrow its fields does not answer by
				# sending for more people.
				return -pressure
			GovernorIntent.ECONOMY:
				# More hands than ground is a reason to make more of the ground.
				return pressure * 0.4
		return 0.0


## How many mouths there are for each tile the town can actually work.
##
## Shared with anything else that needs to ask, so "crowded" cannot come to mean
## two different things — the same reason `room_in_the_colony` is shared.
##
## Zero when the town has room to spare and climbing past one when it does not.
static func crowding_of(context: DeliberationContext) -> float:
	var town: Town = context.get_value("town")
	var territory: Territory = context.get_value("territory")
	if town == null or territory == null:
		return 0.0

	var ground := 0
	for at in territory.influence:
		if StringName(territory.influence[at]) == town.id:
			ground += 1
	if ground <= 0:
		# Nowhere at all to work is as crowded as a town can be.
		return 1.0

	var mouths_per_tile := float(town.population()) / float(ground)
	return clampf(
		(mouths_per_tile - COMFORTABLE_MOUTHS_PER_TILE) / COMFORTABLE_MOUTHS_PER_TILE,
		0.0, 1.0
	)


## How many people a tile of the town's own ground supports before it feels full.
##
## **The shared open item** between `founding-towns.md` §11 and
## `immigration.md` §10 — how crowded before a town starts shedding people — and
## it wants tuning against the two together rather than being settled here.
const COMFORTABLE_MOUTHS_PER_TILE: float = 2.0


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


## How much of the ground this town could work is somebody else's.
##
## **The covetous man's argument**, and the second route to wanting them gone.
class NativeLand extends Consideration:
	func _init() -> void:
		super(IntentConsiderations.NATIVE_LAND)

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var pressed := IntentConsiderations.land_in_other_hands(context)
		match candidate.id:
			GovernorIntent.DRIVE_OFF:
				return pressed
			GovernorIntent.SETTLEMENT:
				# The other answer to the same problem, and the cheap one: go
				# somewhere nobody is.
				return pressed * 0.6
			GovernorIntent.ECONOMY:
				# Fields he cannot work are fields that will not pay.
				return -pressed * 0.4
		return 0.0


## 🔒 **A man cannot intend to drive off people he has never met** (#204).
##
## A filter and not a weight (`deliberation.md` §5): a weight can lose a close
## vote, and a governor four hundred miles from the nearest village adopting
## *drive them off* is not a close vote, it is nonsense. The intent is reachable
## only where there is somebody in reach to mean it about.
class SomebodyToDriveOff extends DeliberationFilter:
	func _init() -> void:
		super(&"somebody_to_drive_off")

	func permits(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> bool:
		if candidate.id != GovernorIntent.DRIVE_OFF:
			return true
		return IntentConsiderations.land_in_other_hands(context) > 0.0


class RoomToSettle extends DeliberationFilter:
	func _init() -> void:
		super(&"somewhere_to_settle")

	func permits(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> bool:
		if candidate.id != GovernorIntent.SETTLEMENT:
			return true
		return IntentConsiderations.room_in_the_colony(context) > 0.0


## The share of this town's own fields that a tribe holds, nought to one.
##
## Shared by the consideration and the filter so that "their land is in my way"
## cannot come to mean two different things — the same arrangement `room_to_grow`
## and its filter have, and for the same reason.
##
## 🔒 **It counts, it does not adjudicate.** `natives.md` §10 leaves who works a
## contested tile to the Author; this says only how many of them there are.
static func land_in_other_hands(context: DeliberationContext) -> float:
	var town: Town = context.get_value("town")
	var territory: Territory = context.get_value("territory")
	var natives: Tribes = context.get_value("natives")
	if town == null or territory == null or natives == null:
		return 0.0

	var tiles := territory.tiles_of(town.id)
	if tiles.is_empty():
		return 0.0
	var theirs := 0
	for tile in tiles:
		if not String(natives.holder_of(tile)).is_empty():
			theirs += 1
	return clampf(float(theirs) / float(tiles.size()), 0.0, 1.0)


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
