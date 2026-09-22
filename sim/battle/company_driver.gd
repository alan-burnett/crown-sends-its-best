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
		if company.is_empty() or company.destination == Company.NOWHERE:
			continue
		company.advance(company.destination, context)


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
