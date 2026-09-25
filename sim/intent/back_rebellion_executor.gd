class_name BackRebellionExecutor
extends IntentExecutor

## A duke backs a rebel town, the month after he decides to (#403,
## `docs/mechanics/rival-pressure.md` §8 *They back rebel towns*).
##
## ## 🔒 An offer the town cannot refuse
##
## His letter goes to the town's governor, not the PC, and with it:
##
## - **gold, food and guns**, into the town's purse and stores;
## - **a company with a commander**, new men from outside the colony, never the
##   town's own. Its allegiance is rebel and so is its commander, and it takes its
##   standing order as the town's own companies do. **The duke feeds it**
##   (`Company.SUPPORTED_ABROAD`), so the town never pays for it.
##
## All of it scales with the town's people. **The town is never lost to him**:
## backing is not conquest, and nothing here touches whose town it is.
##
## ## Through an Intent, like every other act
##
## He decided in phase 8 (`RebelBacking`); this lands it in phase 2 of the month
## after (Seam C). A town that has come back to the Crown meanwhile is not
## backed: the rebellion he meant to feed is over.

## The Intent kind.
const KIND: StringName = &"back_a_rebellion"

const EVENT_BACKED: StringName = &"rebellion_backed"

## What he sends, per thousand of the town's people. Placeholders
## (`rival-pressure.md` §9).
const GOLD_PER_THOUSAND: float = 60.0
const FOOD_PER_THOUSAND: float = 3.0
const GUNS_PER_THOUSAND: float = 2.0
const MEN_PER_THOUSAND: float = 250.0

## How his company is armed, per thousand men: the Crown's own supply ratio.
const COMPANY_GUNS_PER_THOUSAND: float = 1.0
const COMPANY_TOOLS_PER_THOUSAND: float = 0.45

## Supplied by the turn loop.
var run: RunState = null


func handles(intent: Intent) -> bool:
	return intent.kind == KIND


func execute(intent: Intent, state: WorldState, log: EventLog) -> StringName:
	if run == null or run.colony == null or run.companies == null:
		return Intent.STALLED
	var duke: Contact = run.contacts.get(String(intent.source))
	if duke == null or duke.is_dead:
		return Intent.ABANDONED
	var town := run.colony.by_id(StringName(intent.data.get("town", "")))
	if town == null or not town.rebelling:
		return Intent.OVERTAKEN_BY_EVENTS

	var thousands := Population.thousands(float(town.population()))
	var gold := thousands * GOLD_PER_THOUSAND
	var food := thousands * FOOD_PER_THOUSAND
	var guns := thousands * GUNS_PER_THOUSAND
	town.receive_gold(gold)
	town.store(&"food", food)
	town.store(&"guns", guns)

	var context := ColonyContext.new(state, log, run.streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	context.commanders = run.commanders
	context.contacts = run.contacts
	var men := int(roundf(thousands * MEN_PER_THOUSAND))
	var in_thousands := float(men) / float(Population.THOUSAND)
	var company := run.companies.raise_company(
		Company.REBEL, men,
		{"guns": in_thousands * COMPANY_GUNS_PER_THOUSAND, "tools": in_thousands * COMPANY_TOOLS_PER_THOUSAND},
		Company.SUPPORTED_ABROAD, town.at, context,
		OrderRule.order_for(town, town.intent, context), Company.COMMANDED)
	company.raised_by = duke.id
	company.raised_under = town.intent
	company.backs = town.id
	# **New men, and a new man at their head**: none of the colony's veterans.
	Commanders.take_command(company, null, run, context)

	duke.backed_rebellion = String(town.id)
	log.emit(EVENT_BACKED, duke.id, state.month, {
		"duke": String(duke.id),
		"town": String(town.id),
		"gold": gold,
		"food": food,
		"guns": guns,
		"men": men,
		"company": String(company.id),
	}, WorldPhase.MOVEMENT)
	intent.progress = intent.months_required
	return Intent.COMPLETED
