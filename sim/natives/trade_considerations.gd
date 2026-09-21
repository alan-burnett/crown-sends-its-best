class_name TradeConsiderations
extends RefCounted

## What a people weigh when they decide what to offer the colony (#206,
## SPEC §12.5; `docs/mechanics/natives.md` §5, `deliberation.md` §1).
##
## 🔒 **`faction_posture` has been a registered decision kind with nothing
## registered against it since the kernel was built.** This is the milestone
## that owes it considerations: *a milestone that adds a system ships that
## system's considerations with it* (CLAUDE.md), and until now a tribe could be
## asked to choose and would have had nothing to choose with.
##
## Each candidate is an **axis**: what the village would give and what it wants
## for it. Personality is the weight vector, so three peoples looking at the same
## town make three different offers with no code per people — one trades away
## whatever it has most of, another will deal only for the thing it cannot make.
##
## Written as named subclasses rather than lambdas: a `Callable` living in a
## static registry segfaults Godot 4.7 on shutdown (CLAUDE.md).

## How much of the thing we would give is going spare.
const SPARE: StringName = &"what_we_can_spare"

## How badly we want the thing we are asking for.
const WANT: StringName = &"what_we_cannot_make"

## Whether they could actually supply it. There is no sense asking a town for
## guns it does not have.
const THEIRS: StringName = &"what_they_have"

## How much they would value what we are offering. A people who deal at all
## would rather offer a thing the town is short of than a thing it is sick of.
const THEIR_NEED: StringName = &"what_they_lack"

const ALL: PackedStringArray = [
	"what_they_have", "what_they_lack", "what_we_can_spare", "what_we_cannot_make",
]

## Where a people stop being willing to open an agreement at all.
##
## 🔒 **Above `TradeAgreement.CLOSES_BELOW`**, so a bargain struck in a good year
## survives a bad month instead of flickering open and shut. Tuning.
const OPENS_ABOVE: float = 52.0

## Below this native worth, a thing is something they could make for themselves
## and there is no reason to ask a colony for it. Tuning.
const WORTH_ASKING_FOR: float = 1.2

## What counts as a town having plenty of a thing, for judging whether it could
## actually supply it.
##
## **High enough to tell a storehouse from a shelf.** At a low figure everything
## a town holds at all saturates, the consideration stops distinguishing
## anything, and every candidate ties — which is how `only_what_we_cannot_make`
## came to look redundant when it is the only thing standing between a people and
## asking a colony for stone. Tuning.
const PLENTY: float = 400.0


static func register_all() -> void:
	var kinds: Array = [DecisionKind.FACTION_POSTURE]
	Deliberation.register_consideration(Spare.new(), kinds)
	Deliberation.register_consideration(Want.new(), kinds)
	Deliberation.register_consideration(Theirs.new(), kinds)
	Deliberation.register_consideration(TheirNeed.new(), kinds)
	Deliberation.register_filter(OnlyWhatWeHave.new(), kinds)
	Deliberation.register_filter(OnlyWhatWeCannotMake.new(), kinds)


# --- The considerations -----------------------------------------------------

## How much of what we would give is genuinely spare.
##
## **A people do not trade their winter away.** The surplus is measured over what
## the village keeps back, so a hungry village offers nothing however much grain
## passed through its hands this month.
class Spare extends Consideration:
	func _init() -> void:
		super(TradeConsiderations.SPARE)

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var village: Village = context.get_value("village")
		if village == null:
			return 0.0
		var spare := TradeConsiderations.spare_in(village, candidate.get_value("they_give", &""))
		# Against a month of their own eating, so "a lot" means the same thing in
		# a village of twenty and a village of two hundred.
		var month := maxf(1.0, float(village.people) * ColonyNeeds.per_head(&"food"))
		return clampf(spare / month, 0.0, 1.0)


## How badly we want what we are asking for.
##
## SPEC §12.2 and §10.1: **guns, tools and horses**, the things a craft they do
## not have makes for them. `Valuation.natives` is where that lives and it has
## been waiting for this.
class Want extends Consideration:
	func _init() -> void:
		super(TradeConsiderations.WANT)

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var wanted: StringName = candidate.get_value("we_give", &"")
		var worth := Valuation.natives(wanted, context.get_value("appetite", {}))
		# Against the most valuable thing on the table this month, so the figure
		# means *the best of what is going* rather than an absolute.
		var most: float = float(context.get_value("most_wanted", 1.0))
		return clampf(worth / maxf(0.0001, most), 0.0, 1.0)


## Whether the town could actually supply it.
##
## **An offer nobody can meet is not an offer.** A people who have watched a town
## for a year know roughly what is in its stores.
class Theirs extends Consideration:
	func _init() -> void:
		super(TradeConsiderations.THEIRS)

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var town: Town = context.get_value("town")
		if town == null:
			return 0.0
		var held := town.held(candidate.get_value("we_give", &""))
		return clampf(held / TradeConsiderations.PLENTY, 0.0, 1.0)


## How much the town would value what we are offering.
##
## A people who deal at all would rather bring a thing the town is short of. It
## makes the bargain likelier to be taken and it makes them useful, which is
## worth more to them than the price.
class TheirNeed extends Consideration:
	func _init() -> void:
		super(TradeConsiderations.THEIR_NEED)

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var town: Town = context.get_value("town")
		var desired: DesiredStock = context.get_value("desired")
		if town == null or desired == null:
			return 0.0
		var offered: StringName = candidate.get_value("they_give", &"")
		var worth := Valuation.town(offered, desired, town.held(offered))
		return clampf(worth / maxf(0.0001, Valuation.crown(offered) * 2.0), 0.0, 1.0)


# --- The filters ------------------------------------------------------------

## 🔒 **The axis names a resource the village is actually producing.**
##
## A filter and not a weight (`deliberation.md` §5): offering a thing they do not
## have is not a worse bargain, it is not a bargain. A weight could lose a close
## vote and put them at the table with nothing in their hands.
class OnlyWhatWeHave extends DeliberationFilter:
	func _init() -> void:
		super(&"only_what_we_have")

	func permits(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> bool:
		var village: Village = context.get_value("village")
		if village == null:
			return false
		return TradeConsiderations.spare_in(
			village, candidate.get_value("they_give", &"")) > 0.0


## 🔒 **And they ask only for what they cannot make.**
##
## SPEC §12.2. A people asking a colony for stone would be a people with no
## reason to deal with it at all, and the whole weight of §5 is that the trade
## which most helps a town is the trade that arms the tribe beside it.
class OnlyWhatWeCannotMake extends DeliberationFilter:
	func _init() -> void:
		super(&"only_what_we_cannot_make")

	func permits(_actor: DeliberationActor, candidate: Candidate, _context: DeliberationContext) -> bool:
		return ResourceCatalogue.native_worth(candidate.get_value("we_give", &"")) \
			>= TradeConsiderations.WORTH_ASKING_FOR


## How much of a thing a village holds above what it keeps back.
##
## Shared by the consideration and the filter, so "spare" cannot come to mean two
## different things — the same arrangement `room_to_grow` has with its filter.
static func spare_in(village: Village, resource: StringName) -> float:
	if village == null:
		return 0.0
	var held := float(village.stores.get(String(resource), 0.0))
	if resource == &"food":
		return maxf(0.0, held - float(village.people) * ColonyNeeds.per_head(&"food") * 2.0)
	return maxf(0.0, held)
