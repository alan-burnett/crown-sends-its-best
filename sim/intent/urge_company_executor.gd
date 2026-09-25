class_name UrgeCompanyExecutor
extends IntentExecutor

## The PC argues with a commander about what his company does (#394,
## `docs/mechanics/commanders.md` §8, SPEC §8.6, §12.6).
##
## ## 🔒 The letter moves the weights, it does not move the company
##
## The same shape as `UrgeIntentExecutor`: this writes **what was argued for, and
## when**, onto the company the man commands, and stops. His next deliberation
## weighs it (`CommanderConsiderations.UrgingConsideration`) against his regard
## for the man who wrote it — so *refusing to attack* is still attack scoring
## below retreat, and nothing here decides anything.
##
## **Through the man, not the company.** A letter is addressed to a commander;
## which company he leads is the world's knowledge. A man who has lost his
## command since the letter was written has nothing to be argued at, and the
## Intent stalls so the next month's post can say it came to nothing.

## The Order kind and the Intent kind: compliance carries one into the other.
const KIND: StringName = &"urge_company"

const EVENT_URGED: StringName = &"company_urged"

## Supplied by the turn loop.
var companies: Companies = null


func handles(intent: Intent) -> bool:
	return intent.kind == KIND


func execute(intent: Intent, state: WorldState, log: EventLog) -> StringName:
	var wanted := StringName(intent.data.get("order", ""))
	if not CommanderConsiderations.OPTIONS.has(wanted):
		return Intent.STALLED
	var company := commanded_by(companies, intent.source)
	if company == null:
		return Intent.STALLED

	# **As hard as the letter was written** (#262, `tone.md` §4), and the PC's,
	# replacing his last and nobody else's (#405).
	var tone := StringName(intent.data.get(Compliance.URGED_TONE, ""))
	company.urge(wanted, tone, state.month)

	log.emit(EVENT_URGED, intent.source, state.month, {
		"intent": String(intent.id),
		"company": String(company.id),
		"commander": String(intent.source),
		"urged": String(wanted),
		"tone": String(tone),
	}, WorldPhase.MOVEMENT)

	intent.progress = intent.months_required
	return Intent.COMPLETED


## The live company this man commands, or null.
static func commanded_by(in_companies: Companies, commander: StringName) -> Company:
	if in_companies == null or String(commander).is_empty():
		return null
	for entry in in_companies.in_resolution_order():
		var company: Company = entry
		if not company.is_empty() and company.commander == commander:
			return company
	return null
