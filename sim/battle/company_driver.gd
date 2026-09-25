class_name CompanyDriver
extends RefCounted

## Companies march, and companies nobody fed bleed (#211,
## `docs/mechanics/battles.md` §3, §7, §8).
##
## ## Phase 2, because that is where things on the map move
##
## The same phase expeditions cross in, and **before Territory and the Colony
## Month** — so a company that arrived somewhere this month is there before the
## ground is recomputed around it.
##
## ## Phase 7, because that is where the month is judged
##
## The town victuals its companies in phase 4. A company nobody fed goes without
## in phase 7, which is the earliest the answer is actually known.
##
## 🔒 **The order between the two is the whole of "it cannot disband its way out
## of famine"** (§3). A company asked about its rations *before* the town had a
## chance to send them would starve every month, and a town that could drop it in
## a bad year would make militia a lever rather than a commitment.
##
## ## 🔒 Nothing here fights
##
## Battle resolution, casualties, forts and terrain defence are M6. What this
## owns is the object on the map and the month that wears it down — so the
## milestone that brings fighting adds a resolver and finds the model already
## there, including the ordering it has to resolve in.
##
## `Company.attacks_this_month` is written and has no caller, exactly as
## `ExpeditionParty.attacked` was: the ticket that brings enemies decides what an
## attack does, rather than this one guessing.

## The one list, and the ground it stands on.
##
## **Held as the objects themselves rather than as the run**, the way
## `ExpeditionDriver` holds its parties: `sim/` sits at the bottom of the stack,
## and a driver reaching into `RunState` would be the sim naming the layer above
## it.
var companies: Companies = null
var colony: Colony = null
var map: WorldMap = null

## The roster, so a company can find the man who decides for it (#221).
var contacts: Dictionary = {}

## What each commander has learned (#223), so a battle can add to it.
var commanders: CommanderBook = null

## 🔒 **Where the commanders' plans live** (#222). The same book governors and
## contacts commit to, because a commander's objective is an Intent like any
## other — Seam C, and the reason coordination needs no structure of its own.
var book: IntentBook = null

## 🔒 **Only for commissioning** (#342). `Commanders.take_command` is the one
## door into the contact roster, and that door is `RunState`'s — a company that
## found itself a commander by writing into the dictionary directly would join
## without the date redundancy ranks by (#255).
var run: RunState = null

## 🔒 **What the colony knows of the map** (#434, SPEC §11.2): what an exploring
## company walks toward, and what it reveals. Null in a fixture, and then nobody
## explores.
var knowledge: MapKnowledge = null

## So an explorer that walks past a village learns of it (`natives.md`).
var natives: Tribes = null

## The expeditions on the map (#417), so a war party can fall on one.
var parties: Array = []


func on_phase(phase: StringName, state: WorldState, log: EventLog, streams: RngStreams) -> void:
	if companies == null:
		return
	var context := ColonyContext.new(state, log, streams, map)
	context.colony = colony
	context.companies = companies
	context.commanders = commanders
	context.contacts = contacts
	context.knowledge = knowledge
	context.natives = natives

	match phase:
		WorldPhase.MOVEMENT:
			_march(context)
		WorldPhase.RECKONING:
			_victual(context)
		WorldPhase.INTENT:
			_settle_objectives(context)


## Everyone marches, in resolution order.
##
## 🔒 **The order is §7's, even though nothing fights yet.** Movement is where
## two companies first contend for the same tile, and a march ordered by however
## the array happened to be built would be a different game on the same seed.
## Phase 8: every commander decides where he is taking his company (#222).
##
## 🔒 **After the month has happened and before the next one starts**, which is
## the whole of the one-month lag: he commits here and marches on it in phase 2
## of the month after. What he reads when he chooses are plans committed in
## earlier months, so the order of this loop cannot become a chain of command —
## see `CoordinationConsiderations.plans_laid_before_now`.
func _settle_objectives(context: ColonyContext) -> void:
	if book == null:
		return
	for entry in companies.in_resolution_order():
		var company: Company = entry
		if company.is_empty() or company.is_headless():
			continue
		MarchingOrders.settle(company, context, book, contacts)


## 🔒 **A company raised in the colony month finds its man when it is time to
## move** (#342).
##
## Phase 4 of month N puts men under arms; phase 2 of month N+1 is the first time
## they could go anywhere, and that is where a commander is needed. It is the
## same one-month separation everything else runs on rather than a delay invented
## here — and a militia raised to defend its town needs nobody at all, which
## `StandingOrder` answers and this does not.
func _commission(context: ColonyContext) -> void:
	if run == null:
		return
	for entry in companies.in_resolution_order():
		var company: Company = entry
		if company.is_empty() or not company.is_headless():
			continue
		if not company.wants_a_commander():
			continue
		Commanders.take_command(
			company, _home_of(company), run, context)


func _march(context: ColonyContext) -> void:
	_commission(context)
	for entry in companies.in_resolution_order():
		var company: Company = entry
		if company.is_empty():
			continue
		_take_the_month(company, context)


## One company's month: **move and attack, interleaved** (#217, `battles.md` §8).
##
## A normal company moves *and* attacks in the same month — not one or the
## other, or nothing could ever be chased down. Cavalry does both twice, and
## taking them a tile at a time is what makes that a tempo advantage as well as a
## combat one: **strike, reposition and strike again while the foot are still
## marching.**
##
## 🔒 **Whether to attack is his decision, and there is no branch that asks
## whether he will obey** (#221, `commanders.md` §5). He scores attack, hold,
## march, withdraw and disband and takes the best, so refusing is attack scoring
## below retreat.
func _take_the_month(company: Company, context: ColonyContext) -> void:
	# 🔒 **A leaderless company follows its order and does nothing else**
	# (`battles.md` §4, `commanders.md` §3). It has nobody to deliberate for it,
	# so it never chooses and never reconsiders — but an order that leaves the
	# town takes it out (#434), because leadership no longer comes from the order.
	if company.is_headless():
		_follow_the_order(company, context)
		return

	var from := company.at
	# 🔒 **A month is so many moves and so many attacks, and he spends them**
	# (§8). A normal company has one of each, which is what *moves and attacks in
	# the same month* means; cavalry has two of each, which is the tempo
	# advantage. Asking what he wants each time rather than marching first is the
	# only way a foot company gets to do both.
	var moves := company.tiles_this_month()
	var attacks := company.attacks_this_month()

	while moves > 0 or attacks > 0:
		var to_burn := _something_to_burn(company)
		var prey := _party_in_reach(company)
		# **Asked once and used twice.** What is in front of him decides both what
		# he may choose and what he swings at, and one of the two things it can be
		# — a town — is a view built on the spot, so looking twice would build two
		# of them and let him deliberate about one and attack the other.
		var enemy := _in_contact_with(company)
		match _what_he_decides(company, enemy, context):
			CommanderConsiderations.MARCH:
				if moves <= 0:
					break
				company.step_toward(company.destination)
				moves -= 1
			CommanderConsiderations.EXPLORE:
				if moves <= 0:
					break
				_explore_a_step(company, context)
				moves -= 1
			CommanderConsiderations.RAZE:
				# 🔒 **It takes his month** (§7): what limits harassment is that a
				# company spends its month doing it, and only ever dwindles.
				_raze(company, to_burn, context)
				break
			CommanderConsiderations.STRIKE:
				if attacks <= 0 or prey == null:
					break
				_strike(company, prey, context)
				attacks -= 1
			CommanderConsiderations.ATTACK:
				if attacks <= 0:
					break
				_engage(company, enemy, context)
				attacks -= 1
			CommanderConsiderations.WITHDRAW:
				if moves <= 0:
					break
				# Back to the town that victuals him, a tile at a time. He is not
				# fleeing a battle — there is no rout — he has decided the field
				# is not worth his men.
				company.step_toward(_home_tile(company))
				moves -= 1
			CommanderConsiderations.DISBAND:
				company.stand_down(_home_of(company), context)
				break
			_:
				# 🔒 **Holding ends his month.** The board has not changed, so
				# asking again would give the same answer for ever.
				break

		if company.is_empty():
			break

	if company.at != from and not company.is_empty():
		company.report_march(from, context)


## 🔒 **A leaderless company's month: its order, and only its order** (#434,
## `commanders.md` §3). Nobody deliberates; the order says where it goes.
##
## | Order | Each month |
## | :--- | :--- |
## | defend the town | nothing: it stands, and fights what attacks it |
## | explore | a move a tile toward the nearest unexplored land, revealing it; it seeks no battle |
## | guard the border | toward the edge of its town's ground that faces the nearest threat |
## | march on a foe | toward its foe, and it attacks whatever it may fight in front of it |
func _follow_the_order(company: Company, context: ColonyContext) -> void:
	var from := company.at
	var moves := company.tiles_this_month()
	var attacks := company.attacks_this_month()
	match StandingOrder.of(company.order):
		StandingOrder.EXPLORE:
			for _step in moves:
				if not _explore_a_step(company, context):
					break
		StandingOrder.GUARD_THE_BORDER:
			var post := OrderRule.border_post(_home_of(company), context)
			for _step in moves:
				if post == Company.NOWHERE or company.step_toward(post):
					break
		StandingOrder.MARCH_ON_A_FOE:
			var foe := OrderRule.foe_of(company, _home_of(company), context)
			while moves > 0 or attacks > 0:
				var enemy := _in_contact_with(company)
				if enemy != null and attacks > 0:
					_engage(company, enemy, context)
					attacks -= 1
				elif enemy == null and foe != null and not foe.is_empty() and moves > 0:
					company.step_toward(foe.at)
					moves -= 1
				else:
					break
				if company.is_empty():
					break
	if company.at != from and not company.is_empty():
		company.report_march(from, context)


## 🔒 **An improvement he could burn** (#418): on his tile or beside it, not a
## road (roads come of trade), and on the ground of a town he may fight. The
## nearest, then north-west first; `Company.NOWHERE` if there is none.
func _something_to_burn(company: Company) -> Vector2i:
	if map == null or colony == null or company.at == Company.NOWHERE:
		return Company.NOWHERE
	var best := Company.NOWHERE
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var at := company.at + Vector2i(dx, dy)
			if not map.in_bounds(at.x, at.y):
				continue
			var improvement := Improvement.find(map.improvement_at(at.x, at.y))
			if improvement == null or improvement.natural:
				continue
			var owner := _ground_of(at)
			if owner == null or not Battle.may_fight(company, TownCompany.of(owner, company)):
				continue
			if best == Company.NOWHERE or _nearer(at, best, company.at):
				best = at
	return best


## 🔒 **An expedition he could fall on** (#417, `founding-towns.md` §7 *Who
## strikes one*): in contact, and **only for natives and dukes**. Rebels never
## strike one (SPEC §12.3: an expedition is a loyal town's people), and nobody
## else is in the business.
func _party_in_reach(company: Company) -> ExpeditionParty:
	if company.allegiance != Company.NATIVE and company.allegiance != Company.RIVAL:
		return null
	for entry in parties:
		var party: ExpeditionParty = entry
		if party.is_empty() or party.at == Vector2i(-1, -1):
			continue
		if Battle.tiles_in_contact(company.at, party.at):
			return party
	return null


## 🔒 **The arithmetic of a battle, with one side that does not fight back**
## (#417, the Author's ruling, `founding-towns.md` §7):
##
##     share = LETHALITY × striker's force ÷ party's force
##
## The party's force is a company's with **no arms and no commander**: its
## people, its supply and the ground it stands on. It inflicts nothing, and the
## share is capped at the whole party — at which it is lost completely.
func _strike(company: Company, party: ExpeditionParty, context: ColonyContext) -> void:
	var standing := Company.new(StringName(party.id), 0)
	standing.size = party.souls()
	standing.at = party.at
	standing.allegiance = Company.COLONIAL
	var theirs := Force.of(standing, map, true, company)
	var mine := Force.of(company, map, false, standing)
	if theirs <= 0.0 or mine <= 0.0:
		return
	var share := minf(1.0, Battle.lethality() * mine / theirs)
	party.attacked(share, "native" if company.allegiance == Company.NATIVE else "rival", context)


## Whose ground a tile is: the first town by id whose reach covers it, as
## `Territory.compute` settles a contested tile.
func _ground_of(at: Vector2i) -> Town:
	for town in colony.in_order():
		if maxi(absi(town.at.x - at.x), absi(town.at.y - at.y)) <= Territory.reach_of(town):
			return town
	return null


func _nearer(a: Vector2i, b: Vector2i, from: Vector2i) -> bool:
	var da := maxi(absi(a.x - from.x), absi(a.y - from.y))
	var db := maxi(absi(b.x - from.x), absi(b.y - from.y))
	if da != db:
		return da < db
	return a.y < b.y or (a.y == b.y and a.x < b.x)


## Burn it (#418, §7). The tile reverts to its unimproved yield and the town
## must rebuild at full cost and time. **It is harassment, not war**: no town
## changes hands and no company is lost, so nothing here is an optic.
func _raze(company: Company, at: Vector2i, context: ColonyContext) -> void:
	if at == Company.NOWHERE:
		return
	var burnt := map.improvement_at(at.x, at.y)
	var owner := _ground_of(at)
	map.clear_improvement(at.x, at.y)
	map.set_idle(at.x, at.y, false)
	context.log.emit(Company.EVENT_RAZED, company.id, context.state.month, {
		"improvement": String(burnt),
		"at": [at.x, at.y],
		"town": String(owner.id) if owner != null else "",
		"company": String(company.id),
		"allegiance": String(company.allegiance),
		# **Who did it**, for the painting and for the record. A governor's
		# letter reports the burnt farm; whether he knows who burnt it is not
		# this event's to say.
		"raised_by": String(company.raised_by),
		"commander": String(company.commander),
	}, WorldPhase.MOVEMENT)


## One move toward the nearest land the colony has never seen, and what it sees
## there (#434, §3 *Explore*). Returns whether it moved: with nowhere left, it
## holds where it stands (⚠ assumed there).
func _explore_a_step(company: Company, context: ColonyContext) -> bool:
	var toward := OrderRule.nearest_unexplored(company.at, map, knowledge)
	if toward == Company.NOWHERE:
		return false
	company.step_toward(toward)
	var revealed := knowledge.reveal_around(map, company.at, context.state.month, natives)
	if revealed > 0:
		context.log.emit(Company.EVENT_EXPLORED, company.id, context.state.month, {
			"company": String(company.id),
			"at": [company.at.x, company.at.y],
			"revealed": revealed,
		}, WorldPhase.MOVEMENT)
	return true


## What his commander decides, this step.
##
## 🔒 **Asked afresh for every step**, because cavalry's second move happens on a
## board its first move changed — and a man who struck and then found the second
## enemy far stronger should be free to stop.
func _what_he_decides(
	company: Company, enemy: Company, context: ColonyContext
) -> StringName:
	var commander := companies.commander_of(company, contacts)
	if commander == null:
		return CommanderConsiderations.HOLD

	var deliberation := DeliberationContext.new(
		DecisionKind.COMMANDER_ORDERS, context.state, context.log)
	deliberation.phase = WorldPhase.MOVEMENT
	deliberation.data = {"map": map}

	var decision := Deliberation.choose(
		commander,
		CommanderConsiderations.options_for(
			company,
			enemy,
			company.destination != Company.NOWHERE and company.at != company.destination,
			OrderRule.nearest_unexplored(company.at, map, knowledge) != Company.NOWHERE,
			_something_to_burn(company) != Company.NOWHERE,
			_party_in_reach(company) != null),
		deliberation)
	return decision.chosen_id() if decision.has_choice() else CommanderConsiderations.HOLD


## The first thing in front of him that he may fight, in §7's order.
##
## 🔒 **Companies before towns** (#218). Not a preference — a rule with a
## consequence: a besieger cannot stroll past the militia drawn up outside a town
## to storm the town behind it, for the same reason `options_for` will not offer
## him MARCH while an enemy stands in contact. **Ground is taken only when the
## last defender is gone**, and a town's field army is a defender.
##
## Towns come through `TownCompany`, which is a `Company` and needs nothing here
## to know that it used to be a town. §12.3's locks are applied by `may_fight`
## reading its allegiance, so the colony's own militia cannot march on a loyal
## town and cannot march on a rebel one either.
func _in_contact_with(company: Company) -> Company:
	for entry in companies.in_resolution_order():
		var other: Company = entry
		if Battle.may_fight(company, other) and Battle.are_in_contact(company, other):
			return other
	if colony == null:
		return null
	for town in colony.in_order():
		if not Battle.tiles_in_contact(company.at, town.at):
			continue
		var wall := TownCompany.of(town, company)
		if Battle.may_fight(company, wall):
			return wall
	return null


## Where withdrawing takes him: the town that victuals him.
func _home_tile(company: Company) -> Vector2i:
	var town := _home_of(company)
	return town.at if town != null else company.at


## Fight whatever this company is in contact with.
##
## Returns whether a battle was fought, so an attack is spent on a fight and not
## on an empty field.
func _engage(company: Company, enemy: Company, context: ColonyContext) -> bool:
	if enemy == null:
		return false
	return not Battle.resolve(company, enemy, map, context).is_empty()


## What a month without rations does.
##
## Asked of every company the colony is responsible for, and answered from
## `supplied_month`, which the Colony Month wrote in phase 4. Crown companies are
## never asked: `is_supplied` says so for them whatever the month.
func _victual(context: ColonyContext) -> void:
	for entry in companies.in_resolution_order():
		var company: Company = entry
		if company.is_empty() or company.is_supplied(context.state.month):
			continue
		company.go_without(context)

	# 🔒 **And a leaderless militia goes home when it has stood its time**
	# (`battles.md` §4), which is what gives defence a running cost: a town under
	# sustained threat must keep re-raising and keep re-feeding.
	#
	# **After the victualling**, because a militia that stood a month it was not
	# fed still stood it — and the men who go home this month went hungry for it.
	for entry in companies.in_resolution_order():
		var militia: Company = entry
		if militia.is_empty() or not militia.has_stood_its_time(context.state.month):
			continue
		militia.stand_down(_home_of(militia), context)

	companies.bury_the_dead()


## The town a militia goes back to.
##
## **The one that victualled it**, which for a colonial company is the one that
## raised it. A company whose town is gone has nowhere to send its men, and they
## are simply no longer under arms — said plainly rather than left as a crash.
func _home_of(company: Company) -> Town:
	if colony == null or company.is_the_crowns_burden():
		return null
	return colony.by_id(company.support)
