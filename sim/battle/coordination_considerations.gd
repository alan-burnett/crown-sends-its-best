class_name CoordinationConsiderations
extends RefCounted

## How commanders coordinate without a general staff (#222,
## `docs/mechanics/commanders.md` §4).
##
## §4 names four questions and this file is those four, as considerations on the
## ordinary kernel:
##
## | | |
## | :--- | :--- |
## | **somebody is already going there** | the anti-convergence one, and the only negative |
## | **a town is sitting undefended** | the gap-covering one |
## | **a friend is about to be overwhelmed** | go to the sound of the guns |
## | **this is the only road left open** | the ground that holds the colony together |
##
## ## 🔒 Weights, not rules
##
## Every one of them is a **weight in a personality vector** (`deliberation.md`).
## None is a filter, none short-circuits, and a commander's temperament decides
## how much each is worth to him — so a cautious man covers gaps and a glory-
## hunter piles onto the prize, and neither is scripted into a particular
## officer. §4: *do not paper over the symptom by scripting behaviour into
## particular commanders. A scripted commander is a commander whose letters can
## lie about why.*
##
## ## 🔒 And no faction-level actor exists
##
## There is nothing here that looks at the whole army and assigns roles. §4 keeps
## that in reserve — *if the harness shows either failure mode, the fallback is a
## faction-level assessment that assigns roles before anyone deliberates* — and
## is explicit that it must not be built pre-emptively.

const KINDS: Array[StringName] = [DecisionKind.COMMANDER_OBJECTIVE]

## 🔒 The names, and the list a test checks §4's four against.
const ALL: PackedStringArray = [
	"somebody_is_already_going_there",
	"a_town_sitting_undefended",
	"a_friend_about_to_be_overwhelmed",
	"the_only_road_left_open",
]

## How far away a commander stops caring, in tiles. Beyond it a gap is somebody
## else's problem, which is what stops every company in the game converging on
## one undefended village on the far side of the map. Tuning.
const WITHIN: float = 12.0


static func register_all() -> void:
	Deliberation.register_consideration(
		AlreadyGoingConsideration.new(&"somebody_is_already_going_there"), KINDS)
	Deliberation.register_consideration(
		UndefendedConsideration.new(&"a_town_sitting_undefended"), KINDS)
	Deliberation.register_consideration(
		OverwhelmedConsideration.new(&"a_friend_about_to_be_overwhelmed"), KINDS)
	Deliberation.register_consideration(
		OnlyRoadConsideration.new(&"the_only_road_left_open"), KINDS)


# --- 🔒 What a commander may read ------------------------------------------

## 🔒 **Intents other commanders committed in an earlier month, and nothing
## else.**
##
## The one-month lag everything in the world runs on (`CLAUDE.md`), applied here
## because this is the only place in the game where one actor reads another's
## plan. Every commander commits in the same phase, so without the
## `committed_month` filter the ones deliberating later would read the fresh
## decisions of the ones before them — and the order of the company list would
## quietly become a chain of command. **That is the general staff, arrived at by
## accident.**
##
## His own plans are excluded too. A commander is not coordinating with himself,
## and counting his own last objective as *somebody is already going there* would
## make him avoid the place he had chosen.
static func plans_laid_before_now(
	context: DeliberationContext, mine: StringName
) -> Array[Intent]:
	var out: Array[Intent] = []
	var book: IntentBook = context.data.get("book", null)
	if book == null:
		return out
	for intent in book.live():
		if intent.kind != MarchingOrders.MARCH_ON:
			continue
		if intent.source == mine:
			continue
		if intent.committed_month >= context.state.month:
			continue
		out.append(intent)
	return out


## Whose side a plan is on. Read off the Intent rather than looked up, because a
## commander killed since he committed it is still a man whose company is on its
## way.
static func _allegiance_of(intent: Intent) -> StringName:
	return StringName(intent.data.get("allegiance", ""))


static func _target_of(intent: Intent) -> Vector2i:
	var at: Array = intent.data.get("at", [])
	if at.size() < 2:
		return Company.NOWHERE
	return Vector2i(int(at[0]), int(at[1]))


## How much of a commander's attention a place this far away is worth.
##
## **One at his feet, nothing past `WITHIN`.** Distance is not a filter — a
## consideration that returned zero beyond a radius would be a rule pretending to
## be a weight — it is the taper that makes near problems matter more than far
## ones, which is most of what keeps an army from converging.
static func nearness(from: Vector2i, to: Vector2i) -> float:
	if from == Company.NOWHERE or to == Company.NOWHERE:
		return 0.0
	var apart := float(maxi(absi(to.x - from.x), absi(to.y - from.y)))
	return clampf(1.0 - apart / WITHIN, 0.0, 1.0)


## The odds a company faces against everything hostile standing next to it.
##
## Shared by two considerations, and the same reading `CommanderConsiderations`
## uses for his own fight — so *a friend is about to be overwhelmed* and *I am
## about to be overwhelmed* are one judgement.
static func odds_for(company: Company, context: DeliberationContext) -> float:
	var world: ColonyContext = context.data.get("context", null)
	if company == null or world == null or world.companies == null:
		return 1.0
	var map: WorldMap = context.data.get("map", null)

	var theirs := 0.0
	for entry in world.companies.in_resolution_order():
		var other: Company = entry
		if Battle.may_fight(company, other) and Battle.are_in_contact(company, other):
			theirs += Force.of(other, map, false)
	if theirs <= 0.0:
		return 1.0

	var mine := Force.of(company, map, true)
	var both := mine + theirs
	return 1.0 if both <= 0.0 else clampf(mine / both, 0.0, 1.0)


# --- The four ---------------------------------------------------------------

## 🔒 **Is somebody already going there.**
##
## The anti-convergence consideration, and the only negative one. A place an
## ally's company is already making for is worth less, so the second commander to
## look at an attractive target finds it fractionally less attractive — and the
## third less again, because this counts them.
##
## **It does not forbid.** Two companies converging on one village is sometimes
## exactly right, and a filter here would be the faction-level assignment §4 says
## not to build. A commander who wants the prize badly enough still takes it.
class AlreadyGoingConsideration:
	extends Consideration

	func score(
		_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext
	) -> float:
		var company := MarchingOrders.company_of(candidate)
		if company == null:
			return 0.0
		var here := MarchingOrders.at_of(candidate)
		if here == company.at:
			return 0.0

		var covered := 0
		for intent in CoordinationConsiderations.plans_laid_before_now(
				context, company.commander):
			if CoordinationConsiderations._allegiance_of(intent) != company.allegiance:
				continue
			if CoordinationConsiderations._target_of(intent) == here:
				covered += 1
		if covered <= 0:
			return 0.0
		# **Diminishing, not absolute.** The first ally heading there costs the
		# place most of its appeal and each one after costs less, so an army does
		# not swing wholesale from converging to refusing to converge.
		return -clampf(1.0 - 1.0 / (1.0 + float(covered)), 0.0, 1.0) * 2.0


## 🔒 **Is a town sitting undefended.**
##
## The gap-covering consideration. A town with nobody standing in it is worth
## going to — to hold, if it is mine, and to take, if it is not.
##
## **Both readings are the same number** because both are *go there*, and which
## one it means is settled by allegiance rather than by a branch: `may_fight`
## already knows whether this commander is the town's protection or its problem.
class UndefendedConsideration:
	extends Consideration

	func score(
		_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext
	) -> float:
		var town := MarchingOrders.town_of(candidate)
		var company := MarchingOrders.company_of(candidate)
		if town == null or company == null:
			return 0.0
		var world: ColonyContext = context.data.get("context", null)
		if world == null or world.companies == null:
			return 0.0

		var wall := TownCompany.of(town)
		var mine := company.allegiance == wall.allegiance
		if not mine and not Battle.may_fight(company, wall):
			# Neither his to hold nor his to take. A rebel town is nothing to a
			# colonial militia either way (SPEC §12.3), and a town he has no
			# business at should not draw him.
			return 0.0

		for entry in world.companies.in_resolution_order():
			var guard: Company = entry
			if guard.is_empty() or guard.allegiance != wall.allegiance:
				continue
			if Battle.tiles_in_contact(town.at, guard.at):
				return 0.0  # Somebody is standing in it.
		return CoordinationConsiderations.nearness(company.at, town.at)


## 🔒 **Is a friendly company about to be overwhelmed.**
##
## Going to the sound of the guns, and it is worth most when the friend is worst
## off — a company holding its own is not calling for help.
##
## **It reads the board and not the book**, deliberately: a company being
## overwhelmed *right now* is not a plan anybody committed, it is a fact about
## the map, and waiting a month to notice it would be waiting a month too long.
class OverwhelmedConsideration:
	extends Consideration

	func score(
		_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext
	) -> float:
		var friend := MarchingOrders.other_of(candidate)
		var company := MarchingOrders.company_of(candidate)
		if friend == null or company == null:
			return 0.0
		if friend.allegiance != company.allegiance or friend.is_empty():
			return 0.0

		var odds := CoordinationConsiderations.odds_for(friend, context)
		if odds >= 0.5:
			return 0.0
		return clampf((0.5 - odds) * 2.0, 0.0, 1.0) \
			* CoordinationConsiderations.nearness(company.at, friend.at)


## 🔒 **Is this the only road left open.**
##
## The ground that holds the colony together. A tile the colony's roads run
## through is worth standing on, and worth more the more of them it carries —
## which makes *the only road left open* the top of a scale rather than a special
## case, and means there is no state anywhere recording that a road has been cut.
##
## A crossroads a hostile company is sitting on is therefore drawn to by the
## commander who can reach it, without anything having assigned him to it.
class OnlyRoadConsideration:
	extends Consideration

	func score(
		_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext
	) -> float:
		var company := MarchingOrders.company_of(candidate)
		if company == null:
			return 0.0
		var world: ColonyContext = context.data.get("context", null)
		if world == null or world.colony == null:
			return 0.0

		var towns := world.colony.in_order()
		if towns.size() < 2:
			return 0.0  # A colony of one has no road to lose.

		var here := MarchingOrders.at_of(candidate)
		var roads := 0
		var carried := 0
		for index in towns.size():
			for other in range(index + 1, towns.size()):
				var from: Town = towns[index]
				var to: Town = towns[other]
				if from.at == Vector2i(-1, -1) or to.at == Vector2i(-1, -1):
					continue
				roads += 1
				if CoordinationConsiderations._road_runs_through(from.at, to.at, here):
					carried += 1
		if roads <= 0 or carried <= 0:
			return 0.0
		return float(carried) / float(roads) \
			* CoordinationConsiderations.nearness(company.at, here)


## Whether the straight line between two tiles passes through a third.
##
## The same walk `Company.step_toward` makes, so the road a commander can hold is
## the road a column actually takes.
static func _road_runs_through(from: Vector2i, to: Vector2i, here: Vector2i) -> bool:
	if here == from or here == to:
		return false
	var at := from
	var steps := maxi(absi(to.x - from.x), absi(to.y - from.y))
	for _tile in steps:
		at += Vector2i(signi(to.x - at.x), signi(to.y - at.y))
		if at == here:
			return true
	return false
