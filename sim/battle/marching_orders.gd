class_name MarchingOrders
extends RefCounted

## Where a commander takes his company, and the Intent that tells everybody else
## (#222, `docs/mechanics/commanders.md` §4).
##
## ## 🔒 No faction brain, and no general staff
##
## This is the **ordinary kernel** with a set of candidate places and a set of
## considerations, four of which read the `IntentBook`. There is no faction-level
## actor anywhere, nothing assigns roles, and no commander is scripted.
##
## §12.6 locks that the PC never commands and the Marshal is an ocean away, so in
## fiction there is nobody to model. **Coordination emerges** — exactly as
## governors optimise independently while nobody plans the colony.
##
## ## 🔒 The one-month lag, and why it is the whole design
##
## A commander commits his objective in **phase 8**, and the company marches on
## it in **phase 2 of the next month** (`world-month.md`, `CLAUDE.md`). What he
## reads when he deliberates are Intents **other commanders committed in an
## earlier month**, never one committed this month — enforced in
## `CoordinationConsiderations.plans_laid_before_now` and nowhere else.
##
## Without that filter, commanders deliberating later in the same phase would
## read the fresh decisions of those before them, and the order of the company
## list would silently become a chain of command. That is the general staff,
## arrived at by accident.
##
## ## What it is not
##
## **Not a second decision about what to do this month.** `CommanderOrders`
## already asks that, every step, on a board the last step changed. This asks
## where the company is *for*, which survives the month and is the only part of a
## commander's thinking anybody else can see.

## The Intent a commander commits. One kind, because one is all §4 needs: what
## every consideration wants to know is *where is he going*.
const MARCH_ON: StringName = &"march_on"

## How long a marching Intent is given before it stalls.
##
## Tuning. Long enough that a company crossing the map is not abandoning its
## purpose every few months, short enough that a commander who never arrives
## eventually reconsiders rather than walking into the sea for ever.
const MONTHS_ALLOWED: int = 12

const EVENT_OBJECTIVE: StringName = &"commander_objective"


## Every place this commander could take his company, in a fixed order.
##
## **Towns first, then enemy companies, then standing still**, each in the order
## the colony and the company list already hold them — so two runs of one seed
## offer the same options in the same sequence and the kernel's id tie-break
## means the same thing twice.
##
## 🔒 **Standing still is always on offer.** A commander with nowhere worth going
## must be able to say so; a list that forced him to pick a destination would
## make every company in the game march somewhere every month, which is the
## convergence failure §4 warns about arriving through the option list rather
## than through the weights.
static func candidates_for(company: Company, context: ColonyContext) -> Array:
	var out: Array = []
	if company == null or context == null:
		return out

	if context.colony != null:
		for town in context.colony.in_order():
			if town.at == Vector2i(-1, -1):
				continue
			out.append(_place(company, town.at, town, null))

	if context.companies != null:
		for entry in context.companies.in_resolution_order():
			var other: Company = entry
			if other.id == company.id or other.is_empty():
				continue
			if other.at == Company.NOWHERE:
				continue
			out.append(_place(company, other.at, null, other))

	out.append(_place(company, company.at, null, null))
	return out


static func _place(
	company: Company, at: Vector2i, town: Town, other: Company
) -> Candidate:
	return Candidate.new(StringName("go_to:%d,%d" % [at.x, at.y]), {
		"company": company,
		"at": at,
		"town": town,
		"other": other,
	})


static func at_of(candidate: Candidate) -> Vector2i:
	return candidate.get_value("at", Company.NOWHERE) as Vector2i


static func company_of(candidate: Candidate) -> Company:
	return candidate.get_value("company", null) as Company


static func town_of(candidate: Candidate) -> Town:
	return candidate.get_value("town", null) as Town


static func other_of(candidate: Candidate) -> Company:
	return candidate.get_value("other", null) as Company


## What he settles on, and the Intent that says so.
##
## Returns the tile he is making for, or `Company.NOWHERE` when he is staying
## put. **Headless companies never come here** — §4 of `battles.md` gives them a
## posture and nobody to reconsider it.
static func settle(
	company: Company, context: ColonyContext, book: IntentBook, contacts: Dictionary
) -> Vector2i:
	if company == null or company.is_empty() or company.is_headless():
		return Company.NOWHERE
	var commander: Contact = contacts.get(String(company.commander), null)
	if commander == null or book == null:
		return Company.NOWHERE

	var deliberation := DeliberationContext.new(
		DecisionKind.COMMANDER_OBJECTIVE, context.state, context.log)
	deliberation.phase = WorldPhase.INTENT
	deliberation.data = {"map": context.map, "book": book, "context": context}

	var decision := Deliberation.choose(
		commander, candidates_for(company, context), deliberation)
	if not decision.has_choice():
		return Company.NOWHERE

	var chosen := at_of(decision.chosen)
	if chosen == Company.NOWHERE or chosen == company.at:
		# **He stays.** Whatever he was marching on is let go, because a purpose
		# nobody is acting on is not a purpose — and leaving it live would have
		# every other commander still routing around a march that is not
		# happening.
		_let_go(company, book, context)
		company.destination = Company.NOWHERE
		return Company.NOWHERE

	company.destination = chosen
	_commit(company, chosen, decision, book, context)
	return chosen


static func _commit(
	company: Company,
	chosen: Vector2i,
	decision: Decision,
	book: IntentBook,
	context: ColonyContext,
) -> void:
	# 🔒 **Contending Intents overtake each other** (`IntentBook.commit`), and
	# source plus target is what makes two of them contend — so a commander who
	# changes his mind supersedes his own last objective without this file
	# needing to know that it had one.
	var intent := Intent.new(
		&"", MARCH_ON, company.commander,
		StringName("%d,%d" % [chosen.x, chosen.y]),
		MONTHS_ALLOWED,
		{
			"company": String(company.id),
			"allegiance": String(company.allegiance),
			"at": [chosen.x, chosen.y],
			"from": [company.at.x, company.at.y],
		})
	book.commit(intent, context.log, context.state.month)

	context.log.emit(EVENT_OBJECTIVE, company.commander, context.state.month, {
		"company": String(company.id),
		"commander": String(company.commander),
		"allegiance": String(company.allegiance),
		"at": [chosen.x, chosen.y],
		# Seam A: the trace is already emitted by the kernel, and this says what
		# came of it, so map playback and a letter read the same pair.
		"chose": String(decision.chosen_id()),
	}, WorldPhase.INTENT)


static func _let_go(
	company: Company, book: IntentBook, context: ColonyContext
) -> void:
	for intent in book.live_for_source(company.commander):
		if intent.kind == MARCH_ON:
			book.resolve(intent, Intent.ABANDONED, context.log, context.state.month)
