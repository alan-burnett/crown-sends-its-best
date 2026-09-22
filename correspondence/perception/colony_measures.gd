class_name ColonyMeasures
extends RefCounted

## What a correspondent can be asked to judge, drawn from the real colony (#54).
##
## ## Why a governor sees different numbers under the same names
##
## The Crown's officers write about the colony. **A governor writes about his
## town**, and SPEC §8.2 makes him the PC's only window into a place. So the
## measure ids do not change — `food_security` is `food_security` — but for a
## governor they carry *his town's* answer.
##
## That is what lets one perception ladder serve both. The Steward saying the
## colony is amply provisioned and the Governor of Ashmere saying his people are
## in genuine want are not a contradiction: they are two true statements about
## different things, and the player has to hold both. Giving them separate
## measure ids would have made that a content problem to be remembered in every
## letter file rather than a property of who is writing.
##
## ## Truth in, bias out
##
## **Everything here is exact.** The lean that turns a number into a word lives
## in the perception resolver (`docs/mechanics/perception.md`), and it is capped
## at one rung whatever the contact's temperament. A measure that shaded itself
## would double the bias and let a letter say something false, which SPEC §9.1
## forbids.

## How far along the town's current project is, `0.0` to `1.0`.
const OBJECTIVE_PROGRESS: String = "objective_progress"

## How well stocked the town is against everything it needs, `0.0` to `1.0`.
const STOCKPILE_HEALTH: String = "stockpile_health"

## What the town bought and sold this month, in gold.
const TRADE_VOLUME: String = "trade_volume"

## How the people next door regard the colony, nought to a hundred (#208).
##
## 🔒 **Present only for a contact who has somebody next door.** A governor who
## has never seen a tribe has nothing to say about one, and the way that is made
## true is that the measure is simply not in his dictionary — so a letter of his
## that asked for it would have nothing to judge, and the condition that gates
## such letters asks the same question.
##
## 🔒 **And it is never rendered.** It reaches the page through a
## `{perception:}` ladder and a contact's lean, or not at all, which is what
## keeps standing from ever being a number the player sees (SPEC §12.5).
const NATIVE_REGARD: String = "native_regard"

## How far the colony has got, nought to one (#209).
##
## 🔒 **Towns, population and territory — what a man across a border can see.**
## Never `net_position`: the Crown's ledger is the Crown's and a rival has no
## sight of it. If rival aggression read net position, the same number would
## drive Crown Standing, prestige *and* the rivals, and the PC would be punished
## three ways for the single thing the Crown demands of him
## (`rival-pressure.md` §2).
const COLONY_REACH: String = "colony_reach"

## The same thing asked the other way round: **is it still small?** (#209)
##
## 🔒 **This is the whole of "a contact with his values inverted".** A duke cares
## about the colony not having got far, so a prospering colony drags him down by
## exactly the machinery a failing colony drags a governor down — no second
## scalar, no inversion flag, no bespoke drift. Defined off `COLONY_REACH` in one
## place, so the two can never disagree about how far the colony has got.
const COLONY_IS_NO_THREAT: String = "colony_is_no_threat"

## How much of this town's own ground is in their hands, nought to one (#208).
##
## **The thing a governor can see with his eyes**, as distinct from what they
## think of him, which he can only guess at.
const NATIVE_PRESSURE: String = "native_pressure"

## What share of the money that moved stayed with the Crown, `-1` to `+1` (#282).
##
## 🔒 **A patron's measure, and only a patron's.** `COLONY_REACH` above carries
## the lock that a rival never sees `net_position`, and this is the other half of
## it: the ledger is the Crown's, so the men who read it are the Crown's — the
## patron whose interest in the colony is an interest in its books.
##
## 🔒 **A margin rather than a pile of gold** (`perception.md` §4a). The absolute
## figure is pinned to a quantity, so a ladder hung on it would say one word for
## the whole of a large colony's run; a share reads the same for a hamlet and a
## province that are each doing equally well by the Crown. `{param:}` still
## carries the true figure, and always did.
##
## 🔒 **And it is why a pragmatic man cannot be bought** (`patrons.md` §6).
## Paying him lowers the very figure he respects, so the only way to please him
## is to run the place well. Prestige would have closed a loop here — pleasing a
## patron banks prestige and his regard is itself part of prestige — which is why
## the doc names this and not that.
const COLONY_NET_POSITION: String = "colony_net_position"

## Whether the colony is governed quietly, nought to one (#282).
##
## **The worst town, not the average.** A respectable man watches the place that
## is about to go, and an average would let nine contented towns hide the tenth
## — which is the one that ends his business.
##
## ⚠️ **`patrons.md` §12 leaves this open** — *whether Respectable reads
## colony-wide sentiment or his worst town* — and says only that the worst town
## is sharper. The worst town is what shipped, because the alternative made the
## vice do nothing in a colony of six; it is one line here and the PO's to
## overturn.
const COLONY_IS_QUIET: String = "colony_is_quiet"

## The ends of the margin: everything the Crown put in lost, and everything it
## put in returned several times over. **Fixed by the arithmetic, not tuning** —
## a share cannot leave `[-1, +1]`.
const DEEP_IN_THE_RED: float = -1.0
const HANDSOMELY_IN_PROFIT: float = 1.0

## Months of stock that counts as a healthy store. Matches the food ladder in
## `docs/mechanics/perception.md` §4 so the two read alike.
const HEALTHY_MONTHS: float = 3.0

## Where an average town sits on the trade scale. A town trading its share of
## the colony's business reads here.
const AVERAGE_TOWN: float = 1.0

## The top of the trade scale: twice its share is as busy as the ladder goes.
const BUSY_TOWN: float = 2.0


## What this contact is in a position to judge.
##
## A Crown officer gets the colony's figures; a governor gets his town's, under
## the same names.
static func for_contact(run: RunState, contact: Contact) -> Dictionary:
	var measures := WorldValues.measures(run.world)
	if contact == null or run.colony == null:
		return measures

	# **What anybody across a border can see** (#209). On every contact, because
	# it is a fact about the world rather than a thing only one man is placed to
	# judge — the Crown's officers read it as progress and a duke reads it as a
	# threat, which is the whole of the inversion.
	measures[COLONY_REACH] = reach_of(run)
	measures[COLONY_IS_NO_THREAT] = 1.0 - reach_of(run)

	# **What a man at court can see, which is the ledger** (#282). On the patrons
	# alone: `COLONY_REACH` above is the lock that a rival never reads the Crown's
	# books, and putting these on every contact would be the same leak by another
	# door.
	if contact.role == Contact.ROLE_PATRON:
		measures[COLONY_NET_POSITION] = net_position_of(run)
		measures[COLONY_IS_QUIET] = quiet_of(run)

	# **The Diplomat before the governors**, because he governs nothing and would
	# otherwise fall out here with the Crown's officers — and he is the one man
	# §8.1 says reports more widely than his own doorstep (#208).
	if contact.role == Contact.ROLE_DIPLOMAT:
		_add_the_neighbours(measures, run, contact, Diplomat.home_of(contact, run.colony))
		return measures

	var town := run.colony.governed_by(contact.id)
	if town == null:
		return measures

	measures[WorldValues.FOOD] = food_months(town)
	measures[WorldValues.QUALITY_OF_LIFE] = town.quality_of_life
	measures[OBJECTIVE_PROGRESS] = Objective.progress_fraction(town)
	measures[STOCKPILE_HEALTH] = stockpile_health(town)
	measures[TRADE_VOLUME] = trade_standing(run.colony, town)
	_add_the_neighbours(measures, run, contact, town)
	return measures


## What this man knows of the people next door, if anybody is next door (#208).
##
## 🔒 **Governors report on the tribes their towns touch, and only those.** The
## Diplomat is the exception §8.1 makes him: he reports **more widely**, on the
## worst of them anywhere in the colony, which is what he is for.
static func _add_the_neighbours(
	measures: Dictionary,
	run: RunState,
	contact: Contact,
	town: Town,
) -> void:
	if run.tribes == null:
		return

	if contact.role == Contact.ROLE_DIPLOMAT:
		var angriest := run.tribes.the_angriest()
		if angriest != null and colony_touches_anybody(run):
			measures[NATIVE_REGARD] = angriest.trust()
			measures[NATIVE_PRESSURE] = pressure_on(run, town)
		return

	var neighbour := tribe_beside(run, town)
	if neighbour == null:
		return
	measures[NATIVE_REGARD] = neighbour.trust()
	measures[NATIVE_PRESSURE] = pressure_on(run, town)


## The people this town borders, or null.
##
## **Borders** rather than *works the fields of*: a village three tiles past a
## town's border is still a village its people walk past, and SPEC §11.4's
## "near or beyond" is the same distinction. `Intrusion` already answers it, so
## this is the same measure the sim charges standing against rather than a second
## one that could drift away from it.
static func tribe_beside(run: RunState, town: Town) -> Tribe:
	if run.tribes == null or town == null:
		return null
	var nearest: Dictionary = Intrusion.at(town.at, run.tribes)
	if float(nearest["depth"]) <= 0.0:
		return null
	return run.tribes.find(StringName(nearest["tribe"]))


## Whether anybody in the colony has a tribe for a neighbour.
static func colony_touches_anybody(run: RunState) -> bool:
	if run.colony == null:
		return false
	for town in run.colony.in_order():
		if tribe_beside(run, town) != null:
			return true
	return false


## Whether any town that has actually lived a month has a tribe for a neighbour.
##
## The Diplomat's form of the question: he reports across the colony, so his
## letter waits on *some* town having settled rather than on his own.
static func colony_touches_anybody_who_has_lived(context: LetterContext) -> bool:
	if context.sender == null or context.sender.role != Contact.ROLE_DIPLOMAT:
		return false
	if context.colony == null:
		return false
	for town in context.colony.in_order():
		if DiplomatReport.has_lived(town, context):
			return true
	return false


## How much of this town's ground somebody else holds, nought to one.
static func pressure_on(run: RunState, town: Town) -> float:
	if town == null or run.tribes == null:
		return 0.0
	var reach := Territory.reach_of(town)
	var held := 0
	var looked := 0
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var tile := town.at + Vector2i(dx, dy)
			if run.map != null and not run.map.in_bounds(tile.x, tile.y):
				continue
			looked += 1
			if not String(run.tribes.holder_of(tile)).is_empty():
				held += 1
	if looked <= 0:
		return 0.0
	return clampf(float(held) / float(looked), 0.0, 1.0)


## How far the colony has got, nought to one.
##
## Towns, population and ground, each against what a colony of this age might
## have reached, and the three averaged so no one of them can carry the figure
## alone. **Nothing here reads gold**, and a reader looking for where the money
## comes in will not find it.
static func reach_of(run: RunState) -> float:
	if run == null or run.colony == null:
		return 0.0
	var towns := float(run.colony.size())
	var people := 0.0
	for town in run.colony.in_order():
		people += float(town.population())
	var ground := float(run.knowledge.explored_count()) if run.knowledge != null else 0.0

	return clampf((
		clampf(towns / TOWNS_AT_FULL_REACH, 0.0, 1.0)
		+ clampf(people / PEOPLE_AT_FULL_REACH, 0.0, 1.0)
		+ clampf(ground / GROUND_AT_FULL_REACH, 0.0, 1.0)
	) / 3.0, 0.0, 1.0)


## What the colony has returned the Crown against what it has cost, as a raw
## figure the registry then puts on a ladder (#282).
##
## 🔒 **The same accounts prestige reads.** Not a fresh sum over the log: two
## answers to *what has the colony been worth* would eventually disagree, and one
## of them would be in a letter.
static func net_position_of(run: RunState) -> float:
	if run == null or run.log == null:
		return 0.0
	return CrownAccounts.of(run.log).margin()


## How quietly the colony is governed, nought to one (#282).
##
## **The worst town, because that is the one that ends his business.** A town
## that has actually declared reads nought however contented the rest are, which
## is the collapse `patrons.md` §6 asks for and needs no second rule: a rebel
## town's sentiment is at the top of the scale by the time it goes.
static func quiet_of(run: RunState) -> float:
	if run == null or run.colony == null or run.colony.is_empty():
		return 1.0
	var worst := RebelSentiment.MINIMUM
	for town in run.colony.in_order():
		if town.rebelling:
			return 0.0
		worst = maxf(worst, town.rebel_sentiment)
	return clampf(1.0 - worst / RebelSentiment.MAXIMUM, 0.0, 1.0)


## What a colony that has got as far as it is going to looks like. Tuning.
const TOWNS_AT_FULL_REACH: float = 8.0
const PEOPLE_AT_FULL_REACH: float = 900.0
const GROUND_AT_FULL_REACH: float = 420.0


## How busy this town has been against the colony's average, where `1.0` is a
## town pulling its weight.
##
## **A ratio rather than gold** (`docs/mechanics/perception.md` §4a). A hundred
## gold of business is a busy month for a hamlet and nothing at all for a port,
## and a governor calling his month brisk means brisk for the place he governs.
##
## The reference is this month's colony, not a stored average, so it needs no
## state of its own and cannot drift out of step with the towns it describes.
static func trade_standing(colony: Colony, town: Town) -> float:
	if colony == null or colony.is_empty():
		return 0.0
	var across := 0.0
	for each in colony.in_order():
		across += each.traded_value
	if across <= 0.0:
		return 0.0
	var share := across / float(colony.size())
	return town.traded_value / maxf(0.001, share)


## Months of food in the larder, per mouth.
static func food_months(town: Town) -> float:
	var monthly := maxf(1.0, float(town.population())) * ColonyNeeds.per_head(&"food")
	if monthly <= 0.0:
		return 0.0
	return clampf(town.held(&"food") / monthly, 0.0, HEALTHY_MONTHS)


## How well stocked the town is across everything it must have.
##
## **The worst need, not the average.** A town with a year of grain and no cloth
## at all is not four-fifths well; it is a town with no cloth, and a governor
## writing home says so.
static func stockpile_health(town: Town) -> float:
	var worst := 1.0
	var mouths := maxf(1.0, float(town.population()))
	for resource in ColonyNeeds.needed_resources():
		var monthly := mouths * ColonyNeeds.per_head(StringName(resource))
		if monthly <= 0.0:
			continue
		var months := town.held(StringName(resource)) / monthly
		worst = minf(worst, clampf(months / HEALTHY_MONTHS, 0.0, 1.0))
	return worst
