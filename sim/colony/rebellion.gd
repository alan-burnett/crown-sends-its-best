class_name Rebellion
extends RefCounted

## When a town stops obeying, and when it stops refusing to
## (#72, SPEC §12.3; `docs/mechanics/rebel-sentiment.md` §5).
##
## ## 🔒 A rebel town is not a lost town
##
## In the Crown's eyes it still belongs to the PC and his job is to bring it
## back. A **lost** town is one a rival or a tribe has taken, which is a
## different thing and not reachable from here.
##
## So a rebel town is still part of the colony: it still shares resources with
## loyal neighbours toward each other's objectives, and the PC may still write to
## its governor — he will simply get nothing back.
##
## ## 🔒 It comes back when life is worse than under the Crown (#230)
##
## It declares at sentiment 65, and **records its quality of life that month**.
## For as long as it is out its quality of life carries a lift, free of the duty
## (`QualityOfLife.REBELLION_LIFT`); **it returns the month its quality of life,
## lift included, falls below the record** — SPEC §12.3's *once its people
## believe life was better under the Crown.* The lift is what makes that take
## time: the town has to lose the whole of its tax relief, and then some.
##
## This replaced a return at sentiment 45. That band could not hold: the month
## after a town declared, tax went to nothing, the quality term changed sign,
## neighbours stopped counting and the stakes lost their trade half, all at once,
## and a town that declared at 65 read near nought and came straight back — 129
## to 135 round trips in eight years. Sentiment is still measured in a rebel
## town, and still reported. It no longer brings the town back.
##
## ## 🔒 And a town that comes back is garrisoned for a year
##
## The Marshal quarters a garrison on it (`CrownTroops`), and **while it stands
## the town cannot declare**. When it sails home, is destroyed, or its policy
## lapses, the bar ends with it.
##
## ## And the loop runs both ways
##
## If the town survives and its life recovers, sentiment stops falling, and its
## neighbours see a rebel town prosperous and unpunished. **A rebellion that is
## not being put down is an advertisement.**

## Illustrative, and all tuning (`rebel-sentiment.md` §5, §8).
const DECLARES_AT: float = 65.0

const EVENT_DECLARED: StringName = &"town_declared_rebellion"
const EVENT_RETURNED: StringName = &"town_returned_to_the_crown"


## Move a town across the line, if this month's reckoning puts it there.
##
## Returns what changed, or empty. Called from Settle with the sentiment just
## measured, so the state the *next* month reads is the state this month earned.
static func resolve(town: Town, context: ColonyContext) -> StringName:
	if not town.rebelling and town.rebel_sentiment >= DECLARES_AT and not is_garrisoned(town, context):
		town.rebelling = true
		# What life was, the month it went. Settle has already measured it, and
		# without the lift, since the town was not yet out.
		town.declared_quality = town.quality_of_life
		_turn_its_companies(town, Company.REBEL, context)
		context.log.emit(EVENT_DECLARED, town.id, context.state.month, {
			"town": String(town.id),
			"population": town.population(),
			"governor": String(town.governor_id),
			# **No figure.** SPEC §12.3 keeps sentiment off the player's screens
			# and a payload carrying it is a payload a letter could render. What
			# the letters need is that it happened, and to whom.
		}, WorldPhase.COLONY_MONTH)
		return EVENT_DECLARED

	if town.rebelling and town.quality_of_life < town.declared_quality:
		town.rebelling = false
		_turn_its_companies(town, Company.COLONIAL, context)
		context.log.emit(EVENT_RETURNED, town.id, context.state.month, {
			"town": String(town.id),
			"population": town.population(),
			"governor": String(town.governor_id),
			"months_out": context.state.month - town.rebelling_since,
		}, WorldPhase.COLONY_MONTH)
		town.rebelling_since = -1
		return EVENT_RETURNED

	return &""


## 🔒 **Whether a garrison holds the town** (#230): a Crown company quartered
## on it, still standing. While one does, the town cannot declare.
static func is_garrisoned(town: Town, context: ColonyContext) -> bool:
	if context == null or context.companies == null:
		return false
	for entry in context.companies.in_resolution_order():
		var company: Company = entry
		if not company.is_empty() and company.garrisons == town.id:
			return true
	return false


## 🔒 **Its companies take its side** (#434, `commanders.md` §3). A town's
## companies are its people under arms, so when it declares they are rebels,
## and when it returns they are the Crown's colonists again — which is what
## lets a company raised to prepare for rebellion march on the Crown's troops
## the month its town declares, and forbids it before.
static func _turn_its_companies(town: Town, side: StringName, context: ColonyContext) -> void:
	if context.companies == null:
		return
	for entry in context.companies.supported_by(town.id):
		var company: Company = entry
		if company.allegiance == side:
			continue
		var was := company.allegiance
		company.allegiance = side
		context.log.emit(Company.EVENT_TURNED, company.id, context.state.month, {
			"company": String(company.id),
			"town": String(town.id),
			"from": String(was),
			"to": String(side),
		}, WorldPhase.COLONY_MONTH)
