class_name RebelSentiment
extends RefCounted

## Whether a town would be better off without the Crown in its life
## (#71, SPEC §12.3; `docs/mechanics/rebel-sentiment.md`).
##
## **The colony-side jaw of the Squeeze**, opposite Crown Standing. The Crown
## presses from one side and the colonists from the other, and the PC stands
## between them.
##
## ## 🔒 It measures who is blamed, not how bad life is
##
## SPEC §12.3 locks it: suffering the Crown caused raises sentiment; suffering
## the rebellion caused lowers it.
##
## | Situation | Blamed | Sentiment |
## | :--- | :--- | :--- |
## | Loyal town squeezed by taxes and denials | the Crown | rises |
## | Rebel town starving, trade gone, troops at the gate | the rebellion | falls |
## | Rebel town prosperous and unpunished | nobody — it is working | stays high, spreads |
##
## **Without attribution no rebel town could ever come home**, because its
## worsening life would drive it further away — and §12.3 locks that a peaceful
## return is possible. It is not flavour.
##
## ## One weighted sum, computed fresh
##
## No base-and-modifier machinery, and no carry-over term: every month the whole
## figure is worked out again from standing contributors and whatever grievances
## are still live. In steady state tax burden dominates and grievances spike on
## top, so it *reads* as a base with spikes — but a new grievance is just another
## contributor and there is no special case to keep.
##
## ## 🔒 Never a number the player sees
##
## §6: it surfaces through the Diplomat's ladders, the governor's tone, and his
## loyalty slipping in compliance. `tools/lint.gd` keeps `presentation/` away
## from it, exactly as it does Crown standing.

const EVENT_MEASURED: StringName = &"town_sentiment"

const MINIMUM: float = 0.0
const MAXIMUM: float = 100.0

# --- Tuning. All of it (§8). ------------------------------------------------

## What a month's duty is worth as resentment, per tier it served.
##
## **Weighted by the tier, which subsumes SPEC §10.2's luxury rule rather than
## duplicating it.** Luxuries are bought in the wants tier and therefore weigh
## least automatically, so "luxury taxes cause much less rebel sentiment" stops
## being a special case and becomes a consequence of where the purchase sat.
##
## It also means taxation only bites where a town is **cornered**: tax food in a
## town that grows its own and nothing happens; tax it in a town that must buy it
## and the resentment is immediate.
const TIER_WEIGHT: Dictionary = {
	"need": 1.0,
	"objective": 0.45,
	"want": 0.15,
	# A sale's duty is paid too, but a town selling surplus is not cornered — it
	# is being clipped on the way out.
	"sale": 0.2,
}

## How much a gold of weighted duty is worth in sentiment.
const TAX_RESENTMENT: float = 0.035

## The most a single month's taxation can contribute, so one enormous month of
## trade cannot rebel a town on its own.
const TAX_CEILING: float = 40.0

## What the governor's regard is worth, and what everyone else's is.
##
## **One rule for all resident contacts, scaled by loyalty** (§4), so it keeps
## working when M7 adds institutional ones. Being a jerk to the clergyman is
## mechanically dangerous, which is as it should be.
const GOVERNOR_INFLUENCE: float = 22.0
const RESIDENT_INFLUENCE: float = 6.0

## What a governor actively preparing his town for rebellion is worth on top
## (#128).
##
## **A man who has decided is not the same as a man who is sullen.** His regard
## is already counted above; this is the difference between holding an opinion
## and acting on it, and it is what makes the governor an accelerant rather than
## a passenger — he drives sentiment up, sentiment crosses the line, the town
## declares. A far better story than a number quietly passing a threshold.
const SEDITIOUS_GOVERNOR: float = 15.0

## Loyalty at which a contact neither helps nor hurts.
const LOYALTY_NEUTRAL: float = 55.0

## What a wretched life is worth, read through attribution.
const QUALITY_WEIGHT: float = 30.0

## What a town's own size and wealth add. **Prosperity breeds the thing that
## destroys it** (§4): more buildings, more trade, more to lose and more means to
## act on it.
const DEVELOPMENT_PER_BUILDING: float = 1.6
const DEVELOPMENT_PER_TRADE: float = 0.004
const DEVELOPMENT_CEILING: float = 18.0

## What a neighbour in open rebellion is worth, at its worst.
const NEIGHBOUR_WEIGHT: float = 18.0

## What each rebel after the first is worth, as a share of the one before.
##
## **Two are worse than one, and ten are not ten times worse.** SPEC §12.3 locks
## that a rebellion never stays put, so the term has to grow — but a colony half
## in revolt should be dire rather than arithmetically absurd, and a term that
## ran away would make the second rebellion decide the run.
const NEIGHBOUR_FALLOFF: float = 0.6

## What is left of a rebel town's argument once the Crown is visibly punishing
## it. **A town being ground down is an argument against rebellion**, and should
## read as one.
const PUNISHED_SHARE: float = 0.25

## What an embargo does to the town it is laid on.
##
## **It raises its sentiment**, because the suffering is visibly the Crown's
## doing rather than the rebellion's — which is the whole tension: the PC buys
## quiet among the neighbours at the price of digging in the town he is trying
## to win back.
const EMBARGO_RESENTMENT: float = 14.0


## Work out a town's sentiment for this month.
##
## Returns the whole reckoning, so the event log carries **why** and not only
## what — the Diplomat reports on a trend and has to be able to say what is
## driving it.
static func of(
	town: Town,
	context: ColonyContext,
	grievances: Grievances,
	contacts: Dictionary,
) -> Dictionary:
	var month := context.state.month
	var parts: Dictionary = {
		"tax": _tax(town, context),
		"grievances": 0.0 if grievances == null else grievances.weight_for(town.id, month),
		"contacts": _contacts(town, contacts),
		"quality": _quality(town),
		"development": _development(town),
		"neighbours": _neighbours(town, context),
		"punishment": EMBARGO_RESENTMENT if town.is_embargoed() else 0.0,
	}

	var total := 0.0
	for key in parts:
		total += float(parts[key])
	parts["total"] = clampf(total, MINIMUM, MAXIMUM)
	return parts


# --- The contributors -------------------------------------------------------

## Duty the town paid this month, weighted by the tier each purchase served.
##
## **Read off the event log**, so what the town resents and what the Crown
## collected are the same transactions. §10.2 is precise that towns resent tax as
## they pay it, per transaction, and not as the rate is set: a town that buys
## nothing pays nothing and resents nothing.
static func _tax(town: Town, context: ColonyContext) -> float:
	var month := context.state.month
	var weighted := 0.0
	for event in context.log.for_month(month):
		if event.subject != town.id:
			continue
		var tier := ""
		match event.type:
			Trade.EVENT_BOUGHT:
				tier = String(event.payload.get("tier", "want"))
			Trade.EVENT_SOLD:
				tier = "sale"
			_:
				continue
		weighted += float(event.payload.get("tax", 0.0)) \
			* float(TIER_WEIGHT.get(tier, TIER_WEIGHT["want"]))
	return minf(TAX_CEILING, weighted * TAX_RESENTMENT)


## What the people who live here think of the PC.
##
## The governor weighs heavily — he is the town's leader and its voice. Everyone
## else weighs lightly. Low loyalty pushes sentiment up; high loyalty pushes it
## down, so a well-kept governor is a brake and a slighted one is an accelerant.
static func _contacts(town: Town, contacts: Dictionary) -> float:
	var total := 0.0
	var ids: Array = contacts.keys()
	ids.sort()
	for id in ids:
		var contact: Contact = contacts[id]
		if contact == null or not lives_in(contact, town):
			continue
		var weight := GOVERNOR_INFLUENCE if contact.id == town.governor_id \
			else RESIDENT_INFLUENCE
		total += weight * (LOYALTY_NEUTRAL - contact.loyalty()) / LOYALTY_NEUTRAL

	# **A man who has decided is not the same as a man who is sullen.** His
	# regard is already counted above; this is the difference between holding an
	# opinion and acting on it, and it is what makes the governor an accelerant
	# rather than a passenger (#128).
	if GovernorIntent.is_sedition(town.intent):
		total += SEDITIOUS_GOVERNOR
	return total


## Whether this contact lives in this town.
##
## **One rule for every resident** (§4). The governor is known by the town he
## governs; everybody else by the place named on his own record, which is the
## same field `{sender:town}` renders. The Crown's officers name no town at all
## and are an ocean away, so they never push anybody's sentiment.
static func lives_in(contact: Contact, town: Town) -> bool:
	if contact.id == town.governor_id:
		return true
	return not contact.town.is_empty() and contact.town == town.display_name


## How life is, read through **who is blamed for it** (§2).
##
## The same wretchedness points in opposite directions depending on whether the
## town is under the Crown or in rebellion against it. That is the whole of the
## attribution rule, and it is why a rebel town can be brought home at all.
static func _quality(town: Town) -> float:
	var misery := clampf(1.0 - town.quality_of_life, 0.0, 1.0)
	return -QUALITY_WEIGHT * misery if town.rebelling else QUALITY_WEIGHT * misery


## What the town has to lose, and the means to act on it.
static func _development(town: Town) -> float:
	var built := float(town.buildings.size()) * DEVELOPMENT_PER_BUILDING
	var traded := town.traded_value * DEVELOPMENT_PER_TRADE
	return minf(DEVELOPMENT_CEILING, built + traded)


## A neighbour in open rebellion, **especially while it looks prosperous and
## unpunished** (§12.3).
##
## Scaled by how well the rebel town is living, so a rebellion being ground down
## by Crown troops is an argument *against* rebelling and reads as one. A
## rebellion that is not being put down is an advertisement.
static func _neighbours(town: Town, context: ColonyContext) -> float:
	if context.colony == null or town.rebelling:
		return 0.0

	# Strongest argument first, then each one after it worth less. Sorted so the
	# order is the colony's and not the traversal's.
	var arguments: Array = []
	for other in context.colony.in_order():
		if other == town or not other.rebelling:
			continue
		arguments.append(argument_of(other))
	arguments.sort()
	arguments.reverse()

	var total := 0.0
	var share := 1.0
	for argument in arguments:
		total += float(argument) * share
		share *= NEIGHBOUR_FALLOFF
	return NEIGHBOUR_WEIGHT * total


## How persuasive one rebel town's example is.
##
## **Prosperous is persuasive, and punished is not.** SPEC §12.3 states the
## reasoning plainly: loyal towns will not keep paying taxes while a neighbour
## refuses them and suffers nothing for it. The two halves of that sentence are
## the two terms here.
static func argument_of(rebel: Town) -> float:
	var persuasive := clampf(rebel.quality_of_life, 0.0, 1.0)
	return persuasive * PUNISHED_SHARE if rebel.is_embargoed() else persuasive
