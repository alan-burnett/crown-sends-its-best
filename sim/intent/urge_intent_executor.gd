class_name UrgeIntentExecutor
extends IntentExecutor

## The PC tells a governor what his town is **for**.
##
## ## 🔒 The only thing a letter can reach
##
## SPEC §8.5: *"An order reaches the governor's intent, never the town's
## objective. The PC can argue for a goal; he cannot name the project, the tile,
## or the month."*
##
## So this executor writes exactly two fields — what was urged, and when — and
## then stops. It does **not** set the intent. A governor who has been written to
## still weighs the letter against his own reading of his town
## (`IntentConsiderations.CrownUrging`), and may keep his own mind and say so.
## That is the difference between a request and a command, and SPEC §8.5 is
## clear about which the PC is sending.
##
## `tools/lint.gd` fails if anything outside `sim/` touches a town's objective,
## which is the other half of the same lock.
##
## ## Why it completes immediately
##
## Hearing a letter is not work. The Order completes the month it arrives; what
## happens next is the governor's phase 8 deliberation, and then the town's
## Settle. **The player sees the effect two months after writing**, which is the
## whole texture of the game and not a delay to be engineered away.

const KIND: StringName = &"urge_intent"

const EVENT_URGED: StringName = &"intent_urged"

## 🔒 **Somebody went round the PC** (#401): the same landing, from another hand.
## A different event because it is different news — the PC urging his own
## governor is not the Provost pressing one — and the letters tell them apart.
const EVENT_PRESSED: StringName = &"town_pressed"

## An urging from anyone but the PC names its author, its town and its strength
## in the Intent's data (#401). The PC's is found through the governor who
## complied, and its strength is his letter's tone.
const AUTHOR: String = "author"
const TOWN: String = "town"
const STRENGTH: String = "strength"

## The colony the Intent names a town in. Supplied by the turn loop, which is the
## only place that can see both the Order kinds and the colony.
var colony: Colony = null


func handles(intent: Intent) -> bool:
	return intent.kind == KIND


func execute(intent: Intent, state: WorldState, log: EventLog) -> StringName:
	var wanted := StringName(intent.data.get("intent", ""))
	if not GovernorIntent.is_intent(wanted):
		# A letter arguing for something that is not an intent has nowhere to
		# land. It stalls loudly rather than doing nothing quietly, so the next
		# month's post can report that it came to nothing.
		return Intent.STALLED

	var author := StringName(intent.data.get(AUTHOR, String(Urging.PC)))
	var town: Town = null
	if colony != null:
		# The PC's through the man, not through a town id in the letter. A letter
		# is addressed to a person; that he governs Ashmere is the world's
		# knowledge, not the player's instruction. **Anybody else's names the town
		# he pressed** (#401): he went to it, not to a man answering him.
		town = colony.governed_by(intent.source) if author == Urging.PC \
			else colony.by_id(StringName(intent.data.get(TOWN, "")))
	if town == null:
		return Intent.STALLED

	var tone := StringName(intent.data.get(Compliance.URGED_TONE, ""))
	if author == Urging.PC:
		# **And how hard it was said** (#262, `tone.md` §4). Carried from the
		# letter rather than read off the man, because the urging outlives the
		# month it arrived in and it is the letter that was emphatic, not the
		# reader. **The PC's**, replacing his last and nobody else's (#405).
		town.urge(Urging.from_pc(wanted, state.month, tone))
	else:
		# **Another hand's, as hard as his act was** (#401), replacing his own
		# last and nobody else's.
		town.urge(Urging.make(author, wanted, state.month, float(intent.data.get(STRENGTH, 1.0))))

	log.emit(EVENT_URGED if author == Urging.PC else EVENT_PRESSED, intent.source, state.month, {
		"intent": String(intent.id),
		"author": String(author),
		"town": String(town.id),
		"governor": String(town.governor_id),
		"urged": String(wanted),
		"tone": String(tone),
		"held": String(town.intent),
		"already_agreed": town.intent == wanted,
	}, WorldPhase.MOVEMENT)

	intent.progress = intent.months_required
	return Intent.COMPLETED
