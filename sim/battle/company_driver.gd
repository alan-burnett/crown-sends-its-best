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


func on_phase(phase: StringName, state: WorldState, log: EventLog, streams: RngStreams) -> void:
	if companies == null:
		return
	var context := ColonyContext.new(state, log, streams, map)
	context.colony = colony
	context.companies = companies

	match phase:
		WorldPhase.MOVEMENT:
			_march(context)
		WorldPhase.RECKONING:
			_victual(context)


## Everyone marches, in resolution order.
##
## 🔒 **The order is §7's, even though nothing fights yet.** Movement is where
## two companies first contend for the same tile, and a march ordered by however
## the array happened to be built would be a different game on the same seed.
func _march(context: ColonyContext) -> void:
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
	# 🔒 **A leaderless militia defends its town, and that is the whole of what it
	# can ever do** (`battles.md` §4). It has nobody to deliberate for it, so it
	# holds the posture it was raised with — and being attacked is not a decision
	# and needs none.
	if company.is_headless():
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
		match _what_he_decides(company, context):
			CommanderConsiderations.MARCH:
				if moves <= 0:
					break
				company.step_toward(company.destination)
				moves -= 1
			CommanderConsiderations.ATTACK:
				if attacks <= 0:
					break
				_engage(company, context)
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


## What his commander decides, this step.
##
## 🔒 **Asked afresh for every step**, because cavalry's second move happens on a
## board its first move changed — and a man who struck and then found the second
## enemy far stronger should be free to stop.
func _what_he_decides(company: Company, context: ColonyContext) -> StringName:
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
			_in_contact_with(company),
			company.destination != Company.NOWHERE and company.at != company.destination),
		deliberation)
	return decision.chosen_id() if decision.has_choice() else CommanderConsiderations.HOLD


## The first company in front of him that he may fight, in §7's order.
func _in_contact_with(company: Company) -> Company:
	for entry in companies.in_resolution_order():
		var other: Company = entry
		if Battle.may_fight(company, other) and Battle.are_in_contact(company, other):
			return other
	return null


## Where withdrawing takes him: the town that victuals him.
func _home_tile(company: Company) -> Vector2i:
	var town := _home_of(company)
	return town.at if town != null else company.at


## Fight whatever this company is in contact with.
##
## Returns whether a battle was fought, so an attack is spent on a fight and not
## on an empty field.
func _engage(company: Company, context: ColonyContext) -> bool:
	var other := _in_contact_with(company)
	if other == null:
		return false
	return not Battle.resolve(company, other, map, context).is_empty()


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
