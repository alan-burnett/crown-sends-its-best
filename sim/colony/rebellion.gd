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
## ## The gap is the drama
##
## It declares at 65 and returns at 45, and the space between them is hysteresis
## for the same reason crown standing has it: **a town that flickers between
## rebellion and loyalty month to month is noise, not drama.** One threshold
## would give a town sitting near it a coin toss every month, and the Diplomat
## would have nothing coherent to report.
##
## ## The sign flip is the PC's foothold
##
## On rebelling, the largest standing contributor goes to zero, because the town
## stops paying duty to a Crown it no longer recognises. Its quality of life then
## falls — it cannot buy what it does not grow, and its specialty rots unsold.
##
## Under attribution (`rebel-sentiment.md` §2) that falling quality of life now
## **lowers** sentiment, because the rebellion is visibly what caused it. That is
## the whole mechanism behind a peaceful return, and it is why none of this needs
## Crown troops — which are M6 in any case, so in M3 a rebellion can only end by
## the town choosing to end it.
##
## ## And the loop runs both ways
##
## If the town survives and its life recovers, sentiment stops falling, and its
## neighbours see a rebel town prosperous and unpunished. **A rebellion that is
## not being put down is an advertisement.**

## Illustrative, and all tuning (`rebel-sentiment.md` §5, §8).
const DECLARES_AT: float = 65.0
const RETURNS_AT: float = 45.0

const EVENT_DECLARED: StringName = &"town_declared_rebellion"
const EVENT_RETURNED: StringName = &"town_returned_to_the_crown"


## Move a town across the line, if this month's reckoning puts it there.
##
## Returns what changed, or empty. Called from Settle with the sentiment just
## measured, so the state the *next* month reads is the state this month earned.
static func resolve(town: Town, context: ColonyContext) -> StringName:
	if not town.rebelling and town.rebel_sentiment >= DECLARES_AT:
		town.rebelling = true
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

	if town.rebelling and town.rebel_sentiment <= RETURNS_AT:
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
