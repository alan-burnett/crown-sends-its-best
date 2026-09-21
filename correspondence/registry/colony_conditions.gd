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
	# The Diplomat (#81). His regard governs **what he tells**, so every one of
	# these is a gate on his own reporting rather than on the colony.
	ContentRegistry.register_condition(
		"he_still_writes", {"about": "string"}, ColonyConditions.he_still_writes
	)
	ContentRegistry.register_condition(
		"he_wants_moving", {}, ColonyConditions.he_wants_moving
	)
	ContentRegistry.register_condition(
		"he_wants_paying", {}, ColonyConditions.he_wants_paying
	)
	ContentRegistry.register_condition(
		"he_has_something_to_report", {}, ColonyConditions.he_has_something_to_report
	)
	# The standing ladder (#82). 🔒 **The band, never the figure** — these letters
	# are the entire interface to a number SPEC §10.3 forbids showing, so a
	# condition that could compare the figure to anything would be the first step
	# to printing it.
	ContentRegistry.register_condition(
		"the_colony_has_lived", {"months": "integer"},
		ColonyConditions.the_colony_has_lived,
	)
	ContentRegistry.register_condition(
		"he_holds_a_policy", {}, ColonyConditions.he_holds_a_policy
	)
	ContentRegistry.register_condition(
		"he_is_carrying_the_cost", {}, ColonyConditions.he_is_carrying_the_cost
	)
	ContentRegistry.register_condition(
		"crown_standing_is", {"band": "string"}, ColonyConditions.crown_standing_is
	)
	ContentRegistry.register_condition(
		"crown_standing_changed", {"direction": "string"},
		ColonyConditions.crown_standing_changed,
	)
	ContentRegistry.register_condition(
		"a_town_declared", {"within": "integer"}, ColonyConditions.a_town_declared
	)
	ContentRegistry.register_condition(
		"my_town_declared", {"within": "integer"}, ColonyConditions.my_town_declared
	)
	ContentRegistry.register_condition(
		"a_neighbour_declared", {"within": "integer"},
		ColonyConditions.a_neighbour_declared,
	)


## Whether the colony has actually lived some months yet (#173).
##
## **Not a month number.** A town founded in year four has its own first month,
## and a letter about how the place is getting on must not fire before there is a
## place. Counted off the log, which is where every other "has this happened"
## question is answered.
static func the_colony_has_lived(args: Dictionary, context: LetterContext) -> bool:
	if context == null or context.log == null:
		return false
	return context.log.of_type(SettlePhase.EVENT_LIVED).size() >= maxi(1, int(args.get("months", 1)))


## Whether the Provost is paying for a policy out of his own pocket (#174, §7).
##
## 🔒 **He advises; he does not act.** This is the only letter he sends about a
## policy after it is in force, and what it asks for is that the Crown take up a
## charge he is already carrying — never a larger one.
static func he_is_carrying_the_cost(_args: Dictionary, context: LetterContext) -> bool:
	if context == null or context.policies == null:
		return false
	return not Provost.advises(context.policies).is_empty()


## Whether this sender already has a standing policy of his own (#173).
##
## The Provost's second letter waits on his first being answered: a man does not
## write about the smaller matters before he knows whether the larger ones were
## granted.
static func he_holds_a_policy(_args: Dictionary, context: LetterContext) -> bool:
	if context == null or context.policies == null or context.sender == null:
		return false
	return not context.policies.held_by(context.sender.id).is_empty()


## Which of the four bands the Crown is in (#82, `crown-standing.md`).
##
## 🔒 **The band, never the figure.** Standing is invisible (SPEC §10.3), so
## these letters are the whole of the player's view of it — and they must be
## unmistakable in tone, because there is nothing else to read.
##
## Taken off the log rather than off a field, so the answer is the month's
## judgement rather than whatever a later reader recomputes.
static func crown_standing_is(args: Dictionary, context: LetterContext) -> bool:
	var moved := _standing_moved(context)
	return not moved.is_empty() and String(moved.get("band", "")) == String(args.get("band", ""))


## Whether the Crown's opinion moved a band this month, and which way (#82).
##
## 🔒 **The ladder runs both ways.** A player climbing back out of Alarm must
## hear about it: a Crown that went quiet on the way up would teach him that
## recovering is not a thing that happens.
static func crown_standing_changed(args: Dictionary, context: LetterContext) -> bool:
	var moved := _standing_moved(context)
	if moved.is_empty() or not bool(moved.get("changed_band", false)):
		return false
	var order := CrownStanding.BANDS
	var now := order.find(StringName(moved.get("band", "")))
	var was := order.find(StringName(moved.get("was", "")))
	if now < 0 or was < 0:
		return false
	# BANDS runs worst to best, so a higher index is a better opinion.
	return now > was if String(args.get("direction", "up")) == "up" else now < was


## The month's judgement, or empty if the Crown has not thought about him yet.
static func _standing_moved(context: LetterContext) -> Dictionary:
	if context == null or context.log == null:
		return {}
	var latest: Dictionary = {}
	var at := -1
	for event in context.log.of_type(CrownStanding.EVENT_MOVED):
		if event.month > at and event.month <= context.month:
			at = event.month
			latest = event.payload
	return latest


## Whether any town has declared against the Crown lately (#82).
static func a_town_declared(args: Dictionary, context: LetterContext) -> bool:
	return not _declared_within(args, context).is_empty()


## Whether **this letter's own town** has declared lately (#82).
##
## The governor's last letter. Asked of his town and not of the colony, because a
## man writing "we have declared" about somewhere else would be the wrong letter
## entirely — and with only `a_town_declared` to go on, every governor in the
## colony would have written it at once.
static func my_town_declared(args: Dictionary, context: LetterContext) -> bool:
	if context == null or context.town == null:
		return false
	for event in _declared_within(args, context):
		if event.subject == context.town.id:
			return true
	return false


## Whether a town **other than this letter's** has declared lately (#82).
##
## The spread letter: a governor writing about the place next door, which is how
## a rebellion becomes news rather than a private matter between one town and the
## Crown.
static func a_neighbour_declared(args: Dictionary, context: LetterContext) -> bool:
	if context == null or context.town == null:
		return false
	for event in _declared_within(args, context):
		if event.subject != context.town.id:
			return true
	return false


static func _declared_within(args: Dictionary, context: LetterContext) -> Array:
	var out: Array = []
	if context == null or context.log == null:
		return out
	var within := maxi(1, int(args.get("within", 2)))
	for event in context.log.of_type(Rebellion.EVENT_DECLARED):
		if context.month - event.month < within:
			out.append(event)
	return out


## Whether the Diplomat is writing at all, and at what depth (#81, §5).
##
## 🔒 **Low loyalty spoils the intelligence, not the compliance.** Every other
## contact answers a letter worse when he is slighted; this one tells you less.
## `about` is `colony` for the broad reports and `home` for the sharp ones, and
## **home goes first** — a cooling man stops telling you his own business before
## he stops telling you the colony's.
##
## Silence while he is at sea is not the same thing and is handled here too: a
## man on a ship writes nothing whatever his regard.
static func he_still_writes(args: Dictionary, context: LetterContext) -> bool:
	var him := _the_diplomat(context)
	if him == null or him.is_dead or Diplomat.is_travelling(him, context.month):
		return false
	var tier := Diplomat.reporting_at(him.loyalty())
	if String(args.get("about", "colony")) == "home":
		# **He reports the town he has lived in**, not the one he has just been
		# handed: before its first Settle there is nothing he could have seen.
		return tier == Diplomat.EVERYTHING \
			and DiplomatReport.has_lived(_his_town(context, him), context)
	return tier != Diplomat.SILENT


## Whether his town has become somewhere he would rather not be (§3).
##
## 🔒 **Asked whatever his regard.** At no loyalty at all he writes two letters
## and this is one of them — and granting it is a way back, which is what stops a
## neglected Diplomat being a permanently blind PC.
static func he_wants_moving(_args: Dictionary, context: LetterContext) -> bool:
	var him := _the_diplomat(context)
	if him == null or him.is_dead or Diplomat.is_travelling(him, context.month):
		return false
	return Diplomat.wants_to_move(_his_town(context, him))


## Whether he is asking for money for himself (§4).
##
## He is never lying about the town. He simply also wants a better dinner in it.
static func he_wants_paying(_args: Dictionary, context: LetterContext) -> bool:
	var him := _the_diplomat(context)
	if him == null or him.is_dead or Diplomat.is_travelling(him, context.month):
		return false
	return Diplomat.wants_paying(_his_town(context, him))


## Whether anything in the colony is worth a letter (#81, §2).
##
## **Asked of the colony**, because he is aware of every town, and answered by
## whichever of his four troubles is nearest a crisis anywhere. One question and
## one letter: a Diplomat filing four reports a month would crowd the Crown out
## of the post.
static func he_has_something_to_report(_args: Dictionary, context: LetterContext) -> bool:
	return not DiplomatReport.most_pressing(context).is_empty()


static func _the_diplomat(context: LetterContext) -> Contact:
	if context == null:
		return null
	if context.sender != null and context.sender.role == Contact.ROLE_DIPLOMAT:
		return context.sender
	return null


static func _his_town(context: LetterContext, him: Contact) -> Town:
	if context == null or context.colony == null:
		return null
	return Diplomat.home_of(him, context.colony)


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
