class_name TownCompany
extends Company

## A town, presented as the combatant it already is (#218, `battles.md` §9).
##
## ## 🔒 There is no siege subsystem
##
## **Towns fight by the same arithmetic.** A town has population and supplies, so
## it computes force exactly as a company does — which is why this *is* a
## `Company` rather than something a second resolver knows how to talk to.
## `Force`, `Battle` and the resolution order are untouched by it.
##
## *A siege takes months* then **falls out** of a hard target being worn down by
## §6's curve: a besieger at 0.2 casualties a month is at 1.0 a year later
## because the town's force fell as its people did. Nothing schedules that, no
## state records that it is happening, and there is no stage to advance.
##
## **A dev who finds himself writing one has missed that the town is already a
## combatant.**
##
## ## What it borrows and what it answers for itself
##
## | | |
## | :--- | :--- |
## | **size** | everybody in the town, experts included |
## | **arms** | the guns, tools and horses in its warehouse |
## | **supply** | its own larder — a starving town defends worse |
## | **terrain** | the ground it stands on, like anyone |
## | **fortification** | its own wall, plus what it has built, plus a fort if one stands on the tile |
## | **leadership** | none. A town is headless, so nobody deliberates for it and nobody learns from it |
##
## ## 🔒 It is a view, and the state stays on the town
##
## Built fresh whenever somebody is close enough to fight, and thrown away
## after — so a town that grew, built a palisade or emptied its granary fights
## this month as it is this month, rather than as it was when something first
## marched on it.
##
## The one thing that has to survive between months is the **fractional
## casualties**, and it lives on the `Town` for exactly that reason. See
## `Town.battle_owed`.
##
## ## 🔒 A town is not a body of people in the open
##
## `CLAUDE.md` draws the line: an expedition and a company under arms lose a
## share of their **stores** along with their people, and a town does not. Its
## warehouse is not on its back. So `_remove` is overridden whole rather than
## extended, and the base class's proportional loss of arms never runs here —
## a town that loses half its people keeps every musket, and the survivors are
## better armed for it.

## 🔒 **Not `company_destroyed`.** That optic prices a company wiped out
## (`prestige.md` §4) and a town lost is priced separately and far higher; a town
## emitting both would have the court hear about the same disaster twice and
## charge for it twice.
const EVENT_STORMED: StringName = &"town_stormed"

## The town this stands for. Every write goes through it.
var town: Town = null

## Whose men are at the wall, for the record the colony keeps of how it lost a
## town. Set by whoever built this view, because the attacker is the only one who
## knows.
var stormed_by: StringName = &""


## Present a town as a combatant, ready to be handed to `Battle` like any other.
##
## `allegiance` is **read off the town**, so §12.3's locks apply to it unchanged:
## a loyal town cannot be attacked by the colony's own militia, and a rebel town
## can be attacked by Crown troops and by nobody else of the colony. Neither is a
## rule here — both fall out of `Battle.may_fight` reading one field.
static func of(town: Town, attacker: Company = null) -> TownCompany:
	if town == null:
		return null
	var view := TownCompany.new(town.id, 0)
	view.town = town
	view.allegiance = Company.REBEL if town.rebelling else Company.COLONIAL
	view.at = town.at
	view.support = town.id
	view.size = town.population()
	view.casualties_owed = town.battle_owed
	view.order = StandingOrder.DEFEND_THE_TOWN

	# **Its warehouse is its armoury.** The same three resources a company wants,
	# read the same way — so a town that has been stockpiling guns for a governor
	# bent on defence is measurably harder to take, and one that sold them is not.
	for resource in Company.armed_resources():
		var held := town.held(StringName(resource))
		if held > 0.0:
			view.arms[String(resource)] = held

	# **A hungry town fights worse**, through the same field an unsupported
	# company uses. `battles.md` §3 has a company's effectiveness fall the month
	# its support does; a town's support is its own larder, and famine is the
	# same condition arriving by a different road.
	view.unsupported_months = town.months_hungry

	if attacker != null:
		view.stormed_by = attacker.allegiance
	return view


## 🔒 **Its own wall, counted in points** (§9).
##
## `Force` adds the ground on top and converts the pair, so a fort raised on a
## town's tile is worth what a fort is worth, the town is worth what it has
## built, and neither replaces the other. A besieger's siegecraft then discounts
## the whole of it, exactly as it discounts a rebel's fort.
func own_defence_points() -> float:
	return Building.fortification_points_for(town) if town != null else 0.0


## Casualties accumulate on the **town**, not on this month's view of it.
##
## 🔒 Without this a besieger inflicting less than a whole man a month would
## kill nobody ever, and §6's grind — the thing that makes a siege take months
## without any machinery saying so — would silently not happen.
func take_casualties(men: float, reason: StringName, context: ColonyContext) -> int:
	if town == null:
		return 0
	casualties_owed = town.battle_owed
	var lost := super(men, reason, context)
	town.battle_owed = casualties_owed
	return lost


## 🔒 **Armed attack takes a share, and that is the deliberate exception**
## (`CLAUDE.md`, §9).
##
## No event of *hardship* ever costs a town more than one population — not a
## famine month, not a shortage, not a bad winter. Overwhelming force is the one
## thing that does not queue, because **a rule that metered a massacre out one
## man a month would make it read as a bad harvest.**
##
## 🔒 **Workers still go before experts**, through `Town.take_one_life` — the
## same call famine makes, so a sack cannot eat the schoolmasters first. What
## differs between a famine and a storming is how many, never whose.
func _remove(count: int, reason: StringName, context: ColonyContext) -> int:
	if town == null:
		return 0
	var wanted := mini(maxi(0, count), town.population())
	if wanted <= 0:
		return 0

	var taken: Dictionary = {}
	var lost := 0
	for _each in wanted:
		var who := town.take_one_life()
		if who.is_empty():
			break  # There is nobody left to lose.
		taken[who] = int(taken.get(who, 0)) + 1
		lost += 1
	if lost <= 0:
		return 0

	size = town.population()
	if size <= 0:
		casualties_owed = 0.0
		town.battle_owed = 0.0

	# 🔒 **One event, and it names every man in it.** The uniform *one event per
	# life* of a famine cannot hold here — the exception is precisely that a
	# storming is not a sequence of unlucky months — so the legibility has to
	# come from the payload instead: the map, the ledger and the governor's
	# letter all read `lost` and `taken` rather than counting events.
	context.log.emit(EVENT_STORMED, town.id, context.state.month, {
		"town": String(town.id),
		"name": town.display_name,
		"reason": String(reason),
		"by": String(stormed_by),
		"lost": lost,
		"taken": taken,
		"remaining": town.population(),
		"at": [town.at.x, town.at.y],
	}, WorldPhase.MOVEMENT)

	_the_crowns_man(context)
	_the_town_may_be_lost(context)
	return lost


## 🔒 **Only enemies endanger the Diplomat** (`the-diplomat.md` §6), and this is
## the path that was reserved for it.
##
## **One roll for the attack, not one per head**, which is what
## `attack_took_him`'s own signature asks for — it takes the population *after*
## the losses and prices his danger at `1 / new_population`, so the roll already
## knows how bad the month was. A roll per head would price the same month twice
## and make any real assault certain to kill him.
##
## `battles.md` §13 holds this open; **this ticket answers it** and the PR says
## so, because an open item that nothing implements and an open item something
## quietly decided are different kinds of risk.
func _the_crowns_man(context: ColonyContext) -> void:
	if context.contacts == null or context.streams == null:
		return
	var ids: PackedStringArray = PackedStringArray(context.contacts.keys())
	ids.sort()
	for id in ids:
		var contact: Contact = context.contacts[id]
		if contact != null and contact.role == Contact.ROLE_DIPLOMAT:
			Diplomat.attack_took_him(contact, town, town.population(), context)


## 🔒 **A town reduced to nothing leaves the colony** (SPEC §12.3).
##
## Through `Colony.lost`, which is the only way out and fires the optic exactly
## once. This is the seam that file named and said M6 would fill.
func _the_town_may_be_lost(context: ColonyContext) -> void:
	if town.population() > 0 or context.colony == null:
		return
	context.colony.lost(town, stormed_by, "stormed", context, WorldPhase.MOVEMENT)
