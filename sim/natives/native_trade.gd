class_name NativeTrade
extends RefCounted

## Where an agreement with a village comes from, and who answers (#206,
## SPEC §10.1, §11.3, §12.5; `docs/mechanics/natives.md` §5).
##
## ## 🔒 The tribe proposes. The town never does
##
## `propose` takes a tribe and produces an offer. There is no function here that
## takes a town and produces one, and the whole shape of the file is the lock:
## a dev who wanted a town to open an agreement would have to add one.
##
## The offer goes through the deliberation kernel on `faction_posture`, so which
## axis a people picks is their temperament acting on their situation, and the
## scoring trace says why.
##
## ## 🔒 The governor accepts, not the PC
##
## Towns run themselves (§11.3, locked). The answer is **the town's valuation and
## its governor's intent**, and the PC is not consulted — he reads about it next
## month, in a report, from a man who thought it a good bargain.
##
## Keying acceptance to the **intent** is what makes the PC's one instrument
## real: a governor urged toward defence will not hand guns to anybody, and a
## governor left to increase economic output will trade whatever pays. The PC
## cannot forbid the bargain; he can be the reason the man was in a different
## frame of mind a month earlier.

const EVENT_PROPOSED: StringName = &"native_trade_proposed"
const EVENT_REFUSED: StringName = &"native_trade_refused"

## What a governor holding each intent will not give away, whatever it is worth.
##
## 🔒 **The PC's instrument, a month early.** Not a veto and not a policy: the
## man's own purpose, which the PC may have argued him into or out of.
const WILL_NOT_PART_WITH: Dictionary = {
	String(GovernorIntent.DEFENCE): ["guns", "horses", "iron"],
	String(GovernorIntent.SEDITION): ["guns", "horses", "iron", "tools"],
	# A man set on driving them off does not trade with them at all, and the
	# empty list would be the wrong shape for that — see `would_accept`.
	String(GovernorIntent.SURVIVAL): ["food"],
}


## What this people would offer this town, or null (Seam A).
##
## 🔒 **Only above a standing threshold.** A people who do not trust the colony
## do not come to it with their winter stores, and there is no argument or
## inducement that opens the conversation — it is earned by what colonists do.
static func propose(
	tribe: Tribe,
	village: Village,
	town: Town,
	desired: DesiredStock,
	context: ColonyContext,
) -> TradeAgreement:
	if tribe == null or village == null or town == null:
		return null
	if tribe.is_irreconcilable_with(Tribe.COLONY):
		return null
	if tribe.trust() < TradeConsiderations.OPENS_ABOVE:
		return null

	var candidates := _axes(village, town)
	if candidates.is_empty():
		return null

	var decision := Deliberation.choose(tribe, candidates, _context(
		tribe, village, town, desired, context))
	if not decision.has_choice():
		return null

	var chosen := decision.chosen
	var deal := TradeAgreement.new()
	deal.tribe = tribe.id
	deal.town = town.id
	deal.they_give = StringName(chosen.get_value("they_give", &""))
	deal.we_give = StringName(chosen.get_value("we_give", &""))
	deal.opened_month = context.state.month

	context.log.emit(EVENT_PROPOSED, town.id, context.state.month, {
		"tribe": String(tribe.id),
		"town": String(town.id),
		"they_give": String(deal.they_give),
		"we_give": String(deal.we_give),
	}, WorldPhase.RECKONING)
	return deal


## Whether the governor takes it.
##
## **His town's valuation, and his own purpose.** The first is the wise advice
## §11.3 gives him; the second is the thing the PC can argue with.
static func would_accept(
	deal: TradeAgreement,
	town: Town,
	desired: DesiredStock,
) -> bool:
	if deal == null or town == null or desired == null:
		return false

	# 🔒 A man set on driving them off does not sit down with them.
	if town.intent == GovernorIntent.DRIVE_OFF:
		return false

	var barred: Array = WILL_NOT_PART_WITH.get(String(town.intent), [])
	if barred.has(String(deal.we_give)):
		return false

	# And it has to be a bargain, **per gold traded**.
	#
	# The exchange is fair value for fair value, so the only question left is
	# whether a gold's worth of what comes in is doing more for this town than a
	# gold's worth of what goes out was doing already. `Valuation.town` is in
	# gold per unit, so the comparison is that value over the Crown's price —
	# which is the same gap `worth_buying` and `worth_selling` read, asked
	# against a neighbour instead of against a customs house.
	return _per_gold(deal.they_give, desired, town) > _per_gold(deal.we_give, desired, town)


## What a gold's worth of a resource is doing for this town.
static func _per_gold(resource: StringName, desired: DesiredStock, town: Town) -> float:
	return Valuation.town(resource, desired, town.held(resource)) \
		/ maxf(0.0001, Valuation.crown(resource))


## Every axis this village could put to this town.
##
## Sorted on both ends, so which one wins a tie is the situation's business and
## not the iteration order's.
static func _axes(village: Village, town: Town) -> Array:
	var out: Array = []
	var offering: Array = village.stores.keys()
	offering.sort()
	var asking: PackedStringArray = ResourceCatalogue.ids()
	asking.sort()

	for give in offering:
		for want in asking:
			if String(give) == String(want):
				continue
			out.append(Candidate.new(
				StringName("%s_for_%s" % [give, want]),
				{"they_give": StringName(give), "we_give": StringName(want)},
			))
	return out


static func _context(
	tribe: Tribe,
	village: Village,
	town: Town,
	desired: DesiredStock,
	context: ColonyContext,
) -> DeliberationContext:
	var thinking := DeliberationContext.new(
		DecisionKind.FACTION_POSTURE, context.state, context.log)
	thinking.phase = WorldPhase.RECKONING
	thinking.month = context.state.month
	thinking.data = {
		"tribe": tribe,
		"village": village,
		"town": town,
		"desired": desired,
		# 🔒 **What their circumstances make them want** (`Valuation.natives`).
		# A village arming itself wants guns far more than one that is growing,
		# so the valuations move rather than a hostility gate being bolted on.
		"appetite": appetite_of(village),
		"most_wanted": _most_wanted(village),
	}
	return thinking


## How much more than usual a village wants a thing, given what it is doing.
##
## 🔒 **Their objective, which is their situation** (`natives.md` §4). Nothing
## here asks what they think of the colony: a frightened people want guns whether
## or not they mean to use them on anybody.
static func appetite_of(village: Village) -> Dictionary:
	match village.objective if village != null else &"":
		Village.ARM_OURSELVES, Village.DRIVE_THEM_OFF:
			return {"guns": 2.2, "horses": 1.6, "tools": 1.1}
		Village.WORK_MORE_LAND:
			return {"tools": 1.8, "horses": 1.4}
		Village.FEED_OURSELVES:
			return {"food": 2.0, "tools": 1.2}
		_:
			return {"tools": 1.3, "clothing": 1.2}


## The most any one thing is worth to them this month, for scaling.
static func _most_wanted(village: Village) -> float:
	var appetite := appetite_of(village)
	var most := 0.0001
	for id in ResourceCatalogue.ids():
		most = maxf(most, Valuation.natives(StringName(id), appetite))
	return most
