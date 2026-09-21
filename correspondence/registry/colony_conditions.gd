class_name ColonyConditions
extends RefCounted

## When a governor has something to write home about (#54).
##
## M1's conditions ask about the world's scalars, which is all the stub had. A
## governor writes about **a place**: what it is short of, what he has set the
## men to, whether the church is finished. These are those questions.
##
## Every one of them returns false when there is no town, so a Crown officer's
## trigger cannot accidentally borrow one and fire on a colony-wide reading of a
## town-shaped question.
##
## **Named static functions, not lambdas.** A lambda held in a static registry
## crashes Godot 4.7 on shutdown (CLAUDE.md), and named functions show up in a
## stack trace.
##
## Every one only ever **reads**. A condition that changed anything would be
## logic in what is supposed to be a declarative layer.

static func register_all() -> void:
	ContentRegistry.register_condition(
		"town_short_of", {"resource": "string"}, ColonyConditions.town_short_of
	)
	ContentRegistry.register_condition(
		"town_is_building", {}, ColonyConditions.town_is_building
	)
	ContentRegistry.register_condition(
		"town_holds_a_posture", {}, ColonyConditions.town_holds_a_posture
	)
	ContentRegistry.register_condition(
		"town_objective_is_new", {}, ColonyConditions.town_objective_is_new
	)
	ContentRegistry.register_condition(
		"town_finished_something", {}, ColonyConditions.town_finished_something
	)
	ContentRegistry.register_condition(
		"town_intent_is", {"intent": "string"}, ColonyConditions.town_intent_is
	)
	ContentRegistry.register_condition(
		"town_disagrees_with_the_crown", {}, ColonyConditions.town_disagrees_with_the_crown
	)
	ContentRegistry.register_condition(
		"town_measure_below", {"measure": "string", "value": "number"},
		ColonyConditions.town_measure_below,
	)
	ContentRegistry.register_condition(
		"town_measure_above", {"measure": "string", "value": "number"},
		ColonyConditions.town_measure_above,
	)

	# **What the Crown is doing, never how it feels about it.** A letter may ask
	# whether the window is open or the faucet shut; it may not ask for the
	# standing figure (SPEC §10.3, #68).
	ContentRegistry.register_condition(
		"crown_opened_the_window", {}, ColonyConditions.crown_opened_the_window
	)
	ContentRegistry.register_condition(
		"crown_closed_the_faucet", {}, ColonyConditions.crown_closed_the_faucet
	)
	ContentRegistry.register_condition(
		"crown_reopened_the_faucet", {}, ColonyConditions.crown_reopened_the_faucet
	)
	ContentRegistry.register_condition(
		"i_was_let_down", {"within": "integer"}, ColonyConditions.i_was_let_down
	)
	ContentRegistry.register_condition(
		"crown_first_leaned_harder", {}, ColonyConditions.crown_first_leaned_harder
	)
	ContentRegistry.register_condition(
		"crown_leaned_on", {"axis": "string"}, ColonyConditions.crown_leaned_on
	)
	ContentRegistry.register_condition(
		"crown_asked_for", {"kind": "string"}, ColonyConditions.crown_asked_for
	)
	ContentRegistry.register_condition(
		"town_came_back", {"within": "integer"}, ColonyConditions.town_came_back
	)
	ContentRegistry.register_condition(
		"remembers_a_kindness", {}, ColonyConditions.remembers_a_kindness
	)
	ContentRegistry.register_condition(
		"town_is_preparing_to_leave", {}, ColonyConditions.town_is_preparing_to_leave
	)
	ContentRegistry.register_condition(
		"town_has_an_idle_building", {}, ColonyConditions.town_has_an_idle_building
	)
	ContentRegistry.register_condition(
		"will_not_carry_it_further", {}, ColonyConditions.will_not_carry_it_further
	)
	ContentRegistry.register_condition(
		"his_draft_was_returned", {"within": "integer"}, ColonyConditions.his_draft_was_returned
	)
	ContentRegistry.register_condition(
		"a_town_began_a_protest", {"within": "integer"},
		ColonyConditions.a_town_began_a_protest,
	)
	ContentRegistry.register_condition(
		"the_court_is_cooling", {}, ColonyConditions.the_court_is_cooling
	)


## Whether the court thinks worse of the PC this month than last (#76).
##
## 🔒 **The direction, never the figure** (`prestige.md` §7). A letter may notice
## that the wind has changed; it may not read the number, and there is no
## condition here that would let it compare the number to anything.
static func the_court_is_cooling(_args: Dictionary, context: LetterContext) -> bool:
	return context != null and context.prestige != null \
		and context.prestige.direction() == "falling"


## Whether any town has refused the Crown a resource lately (#75, SPEC §8.1).
##
## **Asked of the colony, not of a town.** The Steward is an ocean away and has
## no town of his own; what reaches him is the news that a market has shut.
static func a_town_began_a_protest(args: Dictionary, context: LetterContext) -> bool:
	return not _latest_protest(context, maxi(1, int(args.get("within", 2)))).is_empty()


## The most recent declaration inside the window, or empty.
##
## Latest rather than first: a Steward writing about a protest should write about
## the one that just happened.
static func _latest_protest(context: LetterContext, within: int) -> Dictionary:
	if context == null or context.log == null:
		return {}
	var best: Dictionary = {}
	var at := -1
	for event in context.log.of_type(TradeProtest.EVENT_DECLARED):
		if context.month - event.month >= within or event.month < at:
			continue
		at = event.month
		best = event.payload
	return best


## Whether this is the month the bar first moved (#69, `crown-demands.md` §3).
##
## **The announcement, and only the announcement.** The player has to be told the
## rules changed, or a moving bar reads as the game cheating — so this is true
## for exactly one month of one run, the month of the first draw. It reads the
## month rather than the levels because the levels say the same thing all year.
static func crown_first_leaned_harder(_args: Dictionary, context: LetterContext) -> bool:
	var growth := context.demands
	return (
		growth != null
		and growth.history.size() == 1
		and growth.grew_in_month == context.month
	)


## Whether the bar last moved along a named axis.
##
## Paired with the condition above so the Chancellor names what changed. He is
## announcing a direction for the colony's governance, not a mood, and a letter
## that could only say "things are harder now" would be the same letter four
## times.
static func crown_leaned_on(args: Dictionary, context: LetterContext) -> bool:
	var growth := context.demands
	if growth == null or growth.history.is_empty():
		return false
	return String(growth.history[growth.history.size() - 1]) == String(args.get("axis", ""))


## Whether the Crown asked for something of this kind this month (#69).
##
## **The sim decides when**, in phase 5, and this only carries it to the desk. A
## condition cannot record that it fired, so a demand scheduled from the letter
## side would either repeat every month or lean on a cooldown that could not grow
## with the `frequency` axis.
static func crown_asked_for(args: Dictionary, context: LetterContext) -> bool:
	var book := context.demand_book
	return (
		book != null
		and book.is_pending(context.month)
		and String(book.kind) == String(args.get("kind", ""))
	)


## Whether this governor's town has just returned to the Crown (#74).
##
## **Read off the event rather than off the flag**, because a town that is not
## rebelling has either come home or never left, and the governor's letter is
## only owed in the first case. The window exists because the post takes a month
## and the letter must not be lost if the desk was busy.
static func town_came_back(args: Dictionary, context: LetterContext) -> bool:
	if context.town == null or context.log == null:
		return false
	var within := maxi(1, int(args.get("within", 1)))
	for event in context.log.of_type(Rebellion.EVENT_RETURNED):
		if event.subject == context.town.id and context.month - event.month < within:
			return true
	return false


## Whether this contact has a kindness he could name (#127).
##
## **The letter cannot fire without one**, because it opens by describing it.
## A letter that referred to a generosity that never happened would break SPEC
## §9.1's requirement that letters get the past right, and the cheapest way to
## be sure is to only send it when there is something true to say.
static func remembers_a_kindness(_args: Dictionary, context: LetterContext) -> bool:
	if context.sender == null or context.sender.relationship == null:
		return false
	var memory := context.sender.relationship.most_generous()
	return memory != null and memory.magnitude > 0.0 and not memory.subject.is_empty()


## Whether this governor has decided to make his town ready to stand alone
## (#128).
##
## **What makes it fair.** A rebellion the player never saw coming is a
## trapdoor; SPEC §12.3 wants a spiral he can watch and intervene in. So the man
## preparing for it writes about the walls and the powder and the grain, and
## says nothing about why — the player has everything he needs to work it out,
## and nobody tells him.
## Whether something the town built stands idle for want of coin (#151).
##
## 🔒 **Town gold is invisible to the player** (SPEC §11.3), so a governor
## writing is the entire interface of upkeep. Without this the mechanic is a
## number the PC cannot see moving things he cannot account for, which is a trap
## rather than a decision.
static func town_has_an_idle_building(_args: Dictionary, context: LetterContext) -> bool:
	return context.town != null and not context.town.dark_buildings.is_empty()


static func town_is_preparing_to_leave(_args: Dictionary, context: LetterContext) -> bool:
	return context.town != null and GovernorIntent.is_sedition(context.town.intent)


## Whether this contact has said he will not carry an unfunded policy further
## (#80, §4).
##
## 🔒 **The warning always comes before the ending.** A cost the player cannot
## see coming is a trap rather than a decision, and this is what puts the letter
## on the desk while there is still time to answer it.
static func will_not_carry_it_further(_args: Dictionary, context: LetterContext) -> bool:
	if context.sender == null or context.policies == null:
		return false
	for policy in context.policies.held_by(context.sender.id):
		if policy.is_warning():
			return true
	return false


## Whether this contact has just learned the PC's cheque bounced (#80, §5).
##
## **Either way he writes.** Whether he covers it or names the month it ends, the
## PC finds out — a policy apparatus that unwound silently would be the one thing
## in the game that happened to him without a letter.
static func his_draft_was_returned(args: Dictionary, context: LetterContext) -> bool:
	if context.sender == null or context.log == null:
		return false
	var within := maxi(1, int(args.get("within", 2)))
	for event in context.log.of_type(PolicyBook.EVENT_RENEGOTIATING):
		if event.subject == context.sender.id and context.month - event.month < within:
			return true
	return false


## Whether the town could not cover a need out of its own stores this month.
##
## Reads Reckon's own shortfall rather than a fresh comparison, so the letter
## and the simulation cannot disagree about what "short" means (SPEC §9.1).
static func town_short_of(args: Dictionary, context: LetterContext) -> bool:
	if context.town == null:
		return false
	var resource := StringName(args.get("resource", ""))
	var monthly := maxf(1.0, float(context.town.population())) * ColonyNeeds.per_head(resource)
	if monthly <= 0.0:
		return false
	return context.town.held(resource) < monthly


## Whether there is a project underway — something with a finish.
static func town_is_building(_args: Dictionary, context: LetterContext) -> bool:
	return context.town != null and Objective.completes(context.town.objective)


## Whether the town is under a standing order instead.
static func town_holds_a_posture(_args: Dictionary, context: LetterContext) -> bool:
	return context.town != null and Objective.is_posture(context.town.objective)


## Whether the objective was settled on this month and nothing has been done
## about it yet.
##
## **This is the announcement window.** The governor says what he means to do in
## phase 9; the work starts in next month's Build. A letter fired on this
## condition is the player's chance to object before a plank is cut, which is
## what makes the loop feel responsive rather than reportorial.
static func town_objective_is_new(_args: Dictionary, context: LetterContext) -> bool:
	var town := context.town
	if town == null or String(town.objective).is_empty():
		return false
	return town.objective_since == context.month and town.objective_progress == 0


## Whether something was finished this month.
##
## Read from what the town remembers rather than from the objective, which Build
## has already cleared by the time anybody writes about it.
static func town_finished_something(_args: Dictionary, context: LetterContext) -> bool:
	var town := context.town
	if town == null or String(town.last_completed).is_empty():
		return false
	return town.last_completed_month == context.month


static func town_intent_is(args: Dictionary, context: LetterContext) -> bool:
	if context.town == null:
		return false
	return String(context.town.intent) == String(args.get("intent", ""))


## Whether the governor is going his own way after being written to.
##
## **He was asked and he has not come round**, which is a letter he owes the PC
## and the one place compliance becomes visible as character rather than as an
## outcome code.
static func town_disagrees_with_the_crown(_args: Dictionary, context: LetterContext) -> bool:
	var town := context.town
	if town == null or String(town.urged_intent).is_empty():
		return false
	return town.urged_intent != town.intent


## Whether the Chancellor's warning is owed this month.
##
## **Fires on the month the window opens**, which is the letter SPEC §10.3 locks:
## the player always gets it before the Crown first refuses. The countdown is at
## its full length only on that month, so this cannot fire twice for one window.
static func crown_opened_the_window(_args: Dictionary, context: LetterContext) -> bool:
	var refusal := context.refusal
	return (
		refusal != null
		and refusal.state == CrownRefusal.WARNED
		and refusal.countdown == CrownRefusal.WARNING_TURNS
	)


## Whether the faucet shut this month.
static func crown_closed_the_faucet(_args: Dictionary, context: LetterContext) -> bool:
	var refusal := context.refusal
	return refusal != null and refusal.state == CrownRefusal.REFUSING


## Whether the Crown has started paying again after a cutoff.
##
## Only after a real default — a near miss inside the window was never a
## stoppage, so there is nothing to announce.
static func crown_reopened_the_faucet(_args: Dictionary, context: LetterContext) -> bool:
	var refusal := context.refusal
	return refusal != null and refusal.state == CrownRefusal.SOLVENT and refusal.cutoffs > 0


## Whether the PC's word to this contact was recently not kept.
##
## **The letter the cascade needs.** A loyalty drop nobody mentions is a number
## moving in the dark; this is how the injured party comes to write about it, and
## how the player watches a run come apart rather than merely reading that it
## has (SPEC §9.5, #70).
static func i_was_let_down(args: Dictionary, context: LetterContext) -> bool:
	if context.sender == null or context.sender.relationship == null:
		return false
	var when := context.sender.relationship.last_promise_broken_month
	if when < 0:
		return false
	return context.month - when <= maxi(1, int(args.get("within", 2)))


static func town_measure_below(args: Dictionary, context: LetterContext) -> bool:
	if context.town == null:
		return false
	return context.measure(String(args.get("measure", "")), 1.0) < float(args.get("value", 0.0))


static func town_measure_above(args: Dictionary, context: LetterContext) -> bool:
	if context.town == null:
		return false
	return context.measure(String(args.get("measure", "")), 0.0) > float(args.get("value", 0.0))
