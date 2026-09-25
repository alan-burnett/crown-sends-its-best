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
	# --- The last chance (#268, `endings.md` §2, §3) ------------------------
	ContentRegistry.register_condition(
		"an_independence_condition_just_flipped", {},
		ColonyConditions.an_independence_condition_just_flipped,
	)
	ContentRegistry.register_condition(
		"the_colony_has_fallen_further", {},
		ColonyConditions.the_colony_has_fallen_further,
	)

	ContentRegistry.register_condition(
		"town_short_of", {"resource": "string"}, ColonyConditions.town_short_of
	)
	ContentRegistry.register_condition(
		"town_is_building", {}, ColonyConditions.town_is_building
	)
	ContentRegistry.register_condition(
		"town_holds_no_building", {}, ColonyConditions.town_holds_no_building
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
	# The Marshal's troops (#420): he is about to call them home, and whether
	# there is a rebellion for them to put down.
	ContentRegistry.register_condition(
		"his_troops_are_going_home", {}, ColonyConditions.his_troops_are_going_home
	)
	ContentRegistry.register_condition(
		"a_town_is_in_rebellion", {}, ColonyConditions.a_town_is_in_rebellion
	)
	ContentRegistry.register_condition(
		"he_sends_the_troops", {}, ColonyConditions.he_sends_the_troops
	)
	# A patron whose Barony has a market to turn the colony's way (#396).
	ContentRegistry.register_condition(
		"his_barony_has_a_market", {}, ColonyConditions.his_barony_has_a_market
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
	# Whether the Treasury has paid anything on the PC's word this year (#364).
	ContentRegistry.register_condition(
		"treasury_honoured_this_year", {"at_least": "number"},
		ColonyConditions.treasury_honoured_this_year,
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
	# 🔒 **The sour half, gated the same way** (#391, `contacts.md` §7). A
	# letter that names a memory fires only when there is one to name.
	ContentRegistry.register_condition(
		"remembers_a_slight", {}, ColonyConditions.remembers_a_slight
	)
	# **Something happened that a letter may report** (#398). Any event in
	# `ReportableEvents`, concerning the sender, his town or the colony.
	ContentRegistry.register_condition(
		"it_happened",
		{"event": "string", "within": "integer", "concerning": "string"},
		ReportableEvents.it_happened,
	)
	ContentRegistry.register_condition(
		"remembers_a_broken_word", {}, ColonyConditions.remembers_a_broken_word
	)
	ContentRegistry.register_condition(
		"remembers_in_character", {}, ColonyConditions.remembers_in_character
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
	ContentRegistry.register_condition(
		"the_court_is_warming", {}, ColonyConditions.the_court_is_warming
	)
	ContentRegistry.register_condition(
		"a_patron_has_spoken_ill", {"within": "integer"},
		ColonyConditions.a_patron_has_spoken_ill,
	)
	# The patron writes (#388, `patrons.md` §7, §8, §10). He had no letters at
	# all, so nothing the PC did could reach him and `patron_credit` was a term
	# in the prestige formula that could not move.
	ContentRegistry.register_condition(
		"he_has_just_arrived", {"within": "integer"},
		ColonyConditions.he_has_just_arrived,
	)
	ContentRegistry.register_condition(
		"he_would_propose", {"shape": "string"}, ColonyConditions.he_would_propose
	)
	ContentRegistry.register_condition(
		"he_is_taking_his_leave", {}, ColonyConditions.he_is_taking_his_leave
	)
	# The clergy's two asks (#278). A festival needs a trade worth celebrating
	# and a duty still being charged on it; a holy day needs only the duty.
	ContentRegistry.register_condition(
		"a_duty_could_be_waived", {}, ColonyConditions.a_duty_could_be_waived
	)
	# Where the PC may send the Diplomat (#393). Asked of the governor being
	# written to, because choosing him is how the PC chooses the town.
	ContentRegistry.register_condition(
		"the_diplomat_could_come_here", {},
		ColonyConditions.the_diplomat_could_come_here,
	)
	ContentRegistry.register_condition(
		"a_trade_could_be_celebrated", {},
		ColonyConditions.a_trade_could_be_celebrated,
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
		"he_has_just_been_elected", {"within": "integer"},
		ColonyConditions.he_has_just_been_elected,
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
	ContentRegistry.register_condition(
		"i_have_neighbours", {}, ColonyConditions.i_have_neighbours
	)
	ContentRegistry.register_condition(
		"their_land_is_in_my_way", {"value": "number"},
		ColonyConditions.their_land_is_in_my_way,
	)
	ContentRegistry.register_condition(
		"i_struck_a_bargain", {"within": "integer"},
		ColonyConditions.i_struck_a_bargain,
	)
	ContentRegistry.register_condition(
		"a_rival_has_a_hand_out", {}, ColonyConditions.a_rival_has_a_hand_out
	)
	ContentRegistry.register_condition(
		"they_are_on_my_fields", {}, ColonyConditions.they_are_on_my_fields
	)
	# 🔒 **Consulted, informed, bypassed** (#258). One event, three entirely
	# different months, decided by what the man thinks of the PC.
	ContentRegistry.register_condition(
		"my_regard_is", {"band": "string"}, ColonyConditions.my_regard_is
	)
	ContentRegistry.register_condition(
		"i_changed_my_intent", {"within": "integer"},
		ColonyConditions.i_changed_my_intent,
	)
	ContentRegistry.register_condition(
		"he_did_otherwise", {"within": "integer"},
		ColonyConditions.he_did_otherwise,
	)
	# 🔒 **What the scholar needs before he suggests arranging travel** (#280).
	# More than one of a kind, because a town holding the colony's only weaver
	# has nothing to spare and no reason to write.
	ContentRegistry.register_condition(
		"i_have_experts_to_spare", {},
		ColonyConditions.i_have_experts_to_spare,
	)
	ContentRegistry.register_condition(
		"a_patron_can_deflect_him", {},
		ColonyConditions.a_patron_can_deflect_him,
	)
	ContentRegistry.register_condition(
		"he_is_free_to_demand", {},
		ColonyConditions.he_is_free_to_demand,
	)


## Whether this sender is a governor-elect who has only just set out (#178).
##
## 🔒 **He writes the month the expedition launches** (§4, SPEC §11.4), not the
## month it arrives — which is what gives the PC something to answer while there
## is still a journey in which to answer it, and makes the tone of the letter his
## only warning that the rot has spread.
static func he_has_just_been_elected(args: Dictionary, context: LetterContext) -> bool:
	if context == null or context.log == null or context.sender == null:
		return false
	var within := maxi(1, int(args.get("within", 1)))
	for event in context.log.of_type(Expedition.EVENT_LAUNCHED):
		if String(event.payload.get("governor", "")) != String(context.sender.id):
			continue
		if context.month - event.month < within:
			return true
	return false


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


## Whether the court thinks better of the PC this month than last (#187).
##
## 🔒 **The other direction, and it had been missing.** Only *cooling*
## existed, so a run whose reputation was climbing read exactly like one that had
## not moved — and `prestige.md` §7 has the player perceiving prestige **only**
## through letters. A quantity he can hear falling and never hear rising teaches
## him that his name is a thing which only gets worse.
##
## 🔒 **The direction, never the figure**, like its opposite. There is no
## condition here that would let a letter compare the number to anything.
static func the_court_is_warming(_args: Dictionary, context: LetterContext) -> bool:
	return context != null and context.prestige != null \
		and context.prestige.direction() == "rising"


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
	return nameable(context.sender.relationship.most_generous())


## 🔒 **Whether he remembers being refused, by name** (#391, `contacts.md` §7).
##
## Asked of **the same memory `recalled {reach: slight}` reads** — his most recent
## slight — so the gate and the slot cannot disagree. And only when that slight
## is a refusal: a man whose last grievance is a broken promise writes the angrier
## letter, and *"you refused me"* would be the wrong accusation even if every
## figure in it were true.
static func remembers_a_slight(_args: Dictionary, context: LetterContext) -> bool:
	if context.sender == null or context.sender.relationship == null:
		return false
	var memory := context.sender.relationship.most_recent_slight()
	return nameable(memory) and memory.kind == Relationship.REFUSED


## 🔒 **Whether he remembers the PC's word failing, by name** (#391).
static func remembers_a_broken_word(_args: Dictionary, context: LetterContext) -> bool:
	if context.sender == null or context.sender.relationship == null:
		return false
	return nameable(context.sender.relationship.last_broken_word())


## Whether the memory **his temper** reaches for can be named (#391).
##
## For `recalled {reach: in_character}`, so a sour man with a slight and no
## kindness is not held back by a kindness gate, and a warm one is not by a
## slight gate.
static func remembers_in_character(_args: Dictionary, context: LetterContext) -> bool:
	if context.sender == null or context.sender.relationship == null:
		return false
	return nameable(context.sender.relationship.recalled(
		ColonyParamSources.sourness_of(context.sender)))


## Whether a letter could say what this was: how much, and of what.
##
## A memory with neither is still true, and still a deed — being ignored is a
## slight — but a letter that named it would print *"0 of "* (SPEC §9.1).
static func nameable(memory: Recollection) -> bool:
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


## Whether this man has said he will call his troops home (#420,
## `the-marshal.md` §6): a troops policy of his in its warning months.
##
## 🔒 **He writes first, then the soldiers sail** — this is the letter that puts
## the leaving on the desk while there is still time to answer it.
static func his_troops_are_going_home(_args: Dictionary, context: LetterContext) -> bool:
	if context.sender == null or context.policies == null:
		return false
	for policy in context.policies.held_by(context.sender.id):
		if policy.effect == PolicyEffects.CROWN_TROOPS and policy.is_warning():
			return true
	return false


## Whether this is the man who sends the Crown's troops (#420): the Marshal, and
## nobody else holds the troops policy (`the-marshal.md` §2).
static func he_sends_the_troops(_args: Dictionary, context: LetterContext) -> bool:
	return context.sender != null and context.sender.id == CrownTroops.MARSHAL


## Whether this patron's Barony has a market he could turn the colony's way
## (#396, `policy.md` §8): his specialty is resources or livestock, it names a
## kind, and he is not already carrying a market policy for the PC.
static func his_barony_has_a_market(_args: Dictionary, context: LetterContext) -> bool:
	var him := context.sender
	if him == null or not Patron.is_patron(him) or him.specialty_kind.is_empty():
		return false
	if not ["resources", "livestock"].has(him.specialty):
		return false
	if context.policies != null:
		for policy in context.policies.held_by(him.id):
			if policy.effect == PolicyEffects.FAVOUR_OUR_MARKET:
				return false
	return true


## Whether any town of the colony is in open rebellion (#420): the only time
## there is a rebellion for the Crown's troops to put down (`the-marshal.md` §2).
static func a_town_is_in_rebellion(_args: Dictionary, context: LetterContext) -> bool:
	if context.colony == null:
		return false
	for town in context.colony.in_order():
		if town.rebelling:
			return true
	return false


## Whether a well-connected patron's displeasure has just reached the court
## (#282, `patrons.md` §6).
##
## 🔒 **Reads the event, never the officers' loyalty.** The movement and the
## letter are then one act — there is no month in which the court has cooled and
## nobody says why, and no month in which somebody repeats gossip that did not
## travel.
static func a_patron_has_spoken_ill(args: Dictionary, context: LetterContext) -> bool:
	if context.log == null:
		return false
	var within := maxi(1, int(args.get("within", 2)))
	for event in context.log.of_type(PatronGossip.EVENT_SPREAD):
		if context.month - event.month < within:
			return true
	return false


## Whether **this** patron has only just landed (#388, `patrons.md` §7).
##
## 🔒 **Asked of the sender, not of the colony.** Every other patron in the
## post is a different man with a different arrival, and a condition that read
## *any* arrival would have all of them introducing themselves at once on the
## month the third one came.
static func he_has_just_arrived(args: Dictionary, context: LetterContext) -> bool:
	if context == null or context.log == null or context.sender == null:
		return false
	var within := maxi(1, int(args.get("within", 2)))
	for event in context.log.of_type(Patron.EVENT_ARRIVED):
		if event.subject != context.sender.id:
			continue
		if context.month - event.month < within:
			return true
	return false


## Whether this patron would presently put an offer of this shape in the post
## (#388, `patrons.md` §4).
##
## 🔒 **Gated by loyalty through `PatronOffer.shapes_at`**, which is where
## that rule lives — gifts belong to high regard and bare requests to low. A
## letter that made its own judgement about when a man is generous would be a
## second answer to a question the offer model already answers, and the two would
## disagree the first time either moved.
##
## A bare request is unconditional there, so this gates nothing for the letter
## that exists today and gates everything for the four #368 will bring. That is
## the point of asking the model rather than the letter.
static func he_would_propose(args: Dictionary, context: LetterContext) -> bool:
	if context == null or context.sender == null:
		return false
	if not Patron.is_patron(context.sender):
		return false
	return PatronOffer.shapes_at(context.sender.loyalty()).has(
		String(args.get("shape", PatronOffer.REQUEST)))


## Whether this patron has given his notice and is inside the six months
## (#388, `patrons.md` §8).
##
## 🔒 **The window the whole patron game closes through.** His final loyalty
## banks permanently on departure, so those six months are the last chance to
## move it — and the PC is supposed to **know it to the month**. `patron_leaving`
## was emitted and read by nothing, so he was never told it had started.
static func he_is_taking_his_leave(_args: Dictionary, context: LetterContext) -> bool:
	if context == null or context.sender == null:
		return false
	return PatronTerm.is_leaving(context.sender, context.month)


## Whether there is a duty here worth asking to have set aside (#278).
##
## 🔒 **Two things, and both matter.** A priest does not ask for relief from
## a duty that is already relieved, so a waiver already running silences him —
## and a duty of nothing is nothing to forgive.
##
## With a `resource` named this asks about that trade; without one it asks about
## the colony's base rate, which is the holy day's question.
##
## It does **not** ask about trade protests. A protested resource keeps its duty
## through a waiver (§3, the Author's third ruling), so a priest asking about one
## is asking for something that will not happen — but the answer to that is the
## Author's *a colony in protest does not get a holiday from the thing it is
## protesting*, which reads better as a granted waiver that does not reach it
## than as a letter that never came.
static func a_duty_could_be_waived(_args: Dictionary, context: LetterContext) -> bool:
	if context == null or context.state == null:
		return false
	if TaxWaiver.running(context.state, TaxWaiver.ALL):
		return false
	return TaxRates.base_rate(context.state) > 0.0


## Whether the Diplomat could be sent to **this governor's** town (#393,
## `the-diplomat.md` §7).
##
## 🔒 **The PC chooses the town by choosing its governor.** The composer
## offers recipients and nothing else, and a town picker would be a second way to
## choose where a letter goes. So *send the Resident to Ashmere* is a letter to
## Ashmere's governor, and the Order in it is addressed to the Diplomat — who
## decides, as he decides everything.
##
## Not while he is dead, at sea, or already living there.
static func the_diplomat_could_come_here(_args: Dictionary, context: LetterContext) -> bool:
	if context == null or context.sender == null or context.colony == null:
		return false
	var town := context.colony.governed_by(context.sender.id)
	if town == null:
		return false
	var him := diplomat_in(context.contacts)
	if him == null or him.is_dead:
		return false
	if Diplomat.is_travelling(him, context.month):
		return false
	return him.town != town.display_name


## The Diplomat, or null. There is one, and he is never replaced (SPEC §8.1).
static func diplomat_in(contacts: Dictionary) -> Contact:
	var ids: Array = contacts.keys()
	ids.sort()
	for id in ids:
		var contact: Contact = contacts[id]
		if contact != null and contact.role == Contact.ROLE_DIPLOMAT:
			return contact
	return null


## Whether there is a trade this month worth holding a festival for (#278).
##
## 🔒 **It asks about the very resource the letter will name**, by the same
## call the letter's param uses — so a priest cannot write asking relief on a
## trade that is already relieved, and cannot write at all in a month when
## nothing sold. A condition that guessed differently from the param would put a
## letter on the desk about a thing that was not true.
static func a_trade_could_be_celebrated(_args: Dictionary, context: LetterContext) -> bool:
	if context == null or context.state == null:
		return false
	var id := String(ColonyParamSources.best_selling_resource({}, context))
	if id.is_empty():
		return false
	if TaxWaiver.running(context.state, StringName(id)):
		return false
	return TaxRates.rate_for(context.state, StringName(id)) > 0.0


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
	var monthly := context.town.mouths() * ColonyNeeds.per_head(resource)
	if monthly <= 0.0:
		return false
	return context.town.held(resource) < monthly


## Whether there is a project underway — something with a finish.
static func town_is_building(_args: Dictionary, context: LetterContext) -> bool:
	return context.town != null and Objective.completes(context.town.objective)


## Whether nothing on the menu was worth building, so the town works its land.
static func town_holds_no_building(_args: Dictionary, context: LetterContext) -> bool:
	return context.town != null and context.town.objective == AgendaMenu.NO_BUILDING


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
	var asked: Urging = null if town == null else town.urging_by(Urging.PC)
	if asked == null:
		return false
	return asked.target != town.intent


## Whether the Chancellor's warning is owed this month.
##
## **Fires on the month the window opens**, which is the letter SPEC §10.3 locks:
## the player always gets it before the Crown first refuses. The countdown is at
## its full length only on that month, so this cannot fire twice for one window.
## 🔒 **Whether the Treasury has paid at least this much on the PC's word this
## year** (#364).
##
## Asked of the same figure the letter prints, so the condition and the slot can
## never disagree about whether anything was paid.
static func treasury_honoured_this_year(args: Dictionary, context: LetterContext) -> bool:
	var at_least := float(args.get("at_least", 1.0))
	return float(ColonyParamSources.treasury_honoured_this_year({}, context)) >= at_least


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


## 🔒 Whether this man has anybody next door to write about (#208).
##
## **The lock in `natives.md` §1, as a gate rather than as prose.** A governor
## who has never seen a tribe has nothing to say about one, so every letter that
## mentions the neighbours sits behind this — and a letter file cannot forget to,
## because the measure it would judge is not in his dictionary either.
##
## The Diplomat passes wherever anybody in the colony has a neighbour, which is
## §8.1's *more widely*.
static func i_have_neighbours(_args: Dictionary, context: LetterContext) -> bool:
	if not context.measures.has(ColonyMeasures.NATIVE_REGARD):
		return false
	# **And his town has lived a month there** (#81's lesson, #208's turn to
	# learn it). A governor writing home about the neighbours in the month he
	# stepped off the boat has not met them; he has seen smoke. Folded in here
	# rather than repeated in every trigger, because a trigger that forgot it
	# would put the natives on the desk before the colony has a first harvest.
	return DiplomatReport.has_lived(context.town, context) \
		or ColonyMeasures.colony_touches_anybody_who_has_lived(context)


## Whether enough of this man's ground is in somebody else's hands to mention.
##
## What he can see with his eyes, as distinct from what they think of him.
static func their_land_is_in_my_way(args: Dictionary, context: LetterContext) -> bool:
	if not context.measures.has(ColonyMeasures.NATIVE_PRESSURE):
		return false
	return context.measure(ColonyMeasures.NATIVE_PRESSURE, 0.0) \
		>= float(args.get("value", 0.1))


## 🔒 Whether this governor has lately made an agreement with a village (#206).
##
## **The PC learns of it afterwards** (`natives.md` §5, SPEC §11.3). The town
## runs itself; a governor may arm the people beside him on his own judgement,
## and this is the letter in which the PC finds out. There is no condition here
## that could fire *before* the bargain is struck, because there is no moment at
## which the PC could have stopped it.
static func i_struck_a_bargain(args: Dictionary, context: LetterContext) -> bool:
	return not _bargain(args, context).is_empty()


## The most recent agreement this man's town opened, within the window.
static func _bargain(args: Dictionary, context: LetterContext) -> Dictionary:
	if context == null or context.log == null or context.town == null:
		return {}
	var within := maxi(1, int(args.get("within", 2)))
	var latest: Dictionary = {}
	var when := -1
	for event in context.log.of_type(TradeAgreement.EVENT_OPENED):
		if event.subject != context.town.id:
			continue
		if context.month - event.month > within:
			continue
		if event.month >= when:
			when = event.month
			latest = event.payload
	return latest


## One field of that agreement, for the letter to name.
static func bargain_field(context: LetterContext, field: String) -> String:
	return String(_bargain({"within": 3}, context).get(field, ""))


## Whether the bargain he struck put guns or horses in their hands.
static func bargain_arms_them(context: LetterContext) -> bool:
	return bool(_bargain({"within": 3}, context).get("arms_them", false))


## 🔒 Whether a rival is among the hands out yet (#210, `crown-demands.md` §6).
##
## **Dimension 4 and nothing else.** A duke demanding tribute is the fourth
## dimension selecting him from the catalogue that already names him, so there is
## no second clock: he arrives when the bucket says more sources are demanding,
## staggered because one source is drawn per year and unable to bunch because §7
## caps that dimension at twice in four years.
##
## A `crown_first_leaned_harder` gate used to stand here, which fired on the
## first growth of *any* dimension — so a run whose first draw was `size` had a
## foreign power writing for tribute as its reward for the Steward asking for
## slightly more gold.
static func a_rival_has_a_hand_out(_args: Dictionary, context: LetterContext) -> bool:
	return DemandSchedule.rivals_are_asking(context.demands)


## 🔒 Whether somebody's men are standing on this governor's fields (#188).
##
## **The victim writes** (`contacts.md` §6, `rival-pressure.md` §5). There is no
## blockade bulletin and no announcement from the duke: the man whose fields they
## are asks the PC to deal with these people, and the ask is also how the player
## learns that tile denial exists and that money is the only answer to it.
static func they_are_on_my_fields(_args: Dictionary, context: LetterContext) -> bool:
	return not _denied_tiles(context).is_empty()


## The tiles of this man's town that somebody is sitting on.
static func _denied_tiles(context: LetterContext) -> Array:
	var out: Array = []
	if context == null or context.log == null or context.town == null:
		return out
	for event in context.log.of_type(DeniedTiles.EVENT_PARKED):
		if String(event.payload.get("town", "")) != String(context.town.id):
			continue
		out.append(event.payload)
	return out


## How many of them, for the letter to name.
static func denied_count(context: LetterContext) -> int:
	var seen: Dictionary = {}
	for payload in _denied_tiles(context):
		var at: Array = payload.get("at", [])
		if at.size() >= 2:
			seen["%d,%d" % [int(at[0]), int(at[1])]] = true
	return seen.size()


## 🔒 What his regard lets the PC hear (#258, `the-director.md` §2).
##
## **A band, never the figure.** SPEC §8.5 keeps loyalty off the player's
## screens; what reaches him is which of three letters arrived, or none at all.
static func my_regard_is(args: Dictionary, context: LetterContext) -> bool:
	if context == null or context.sender == null:
		return false
	if context.sender.relationship == null:
		return false
	return context.sender.relationship.band() == StringName(args.get("band", ""))


## Whether this governor has lately settled on a new purpose for his town.
##
## **The most consequential thing he does** (`governor-objectives.md` §2), and
## the thing the PC most wants to hear about — which is why whether he hears it
## at all is a question about the man rather than about the event.
static func i_changed_my_intent(args: Dictionary, context: LetterContext) -> bool:
	if context == null or context.log == null or context.town == null:
		return false
	var within := maxi(1, int(args.get("within", 1)))
	for event in context.log.of_type(GovernorDriver.EVENT_INTENT_SET):
		if String(event.payload.get("town", "")) != String(context.town.id):
			continue
		if context.month - event.month < within:
			return true
	return false


## 🔒 The gap between what the PC wrote and what the town did (#258).
##
## **How the PC learns what people are not telling him.** A governor who says
## nothing has not hidden it from everybody: the Diplomat reads the same log, and
## can name the man's reason truthfully because `choose()` emitted its trace
## (SPEC §9.1).
##
## It is a different job from reporting the world, and it is what prices his
## death — he is never replaced (§8.1), so a PC who loses him goes blind to
## disloyalty and every governor who has quietly stopped writing becomes one he
## knows nothing about.
static func he_did_otherwise(args: Dictionary, context: LetterContext) -> bool:
	return not diverged(args, context).is_empty()


## The most recent divergence, or empty.
##
## **Read off the towns**, because the town already carries what the PC urged and
## when. Reconstructing it from the log would be a second account of the same
## fact, and the two would disagree the first time an urging expired.
static func diverged(args: Dictionary, context: LetterContext) -> Dictionary:
	if context == null or context.colony == null:
		return {}
	var within := maxi(1, int(args.get("within", 6)))

	var latest: Dictionary = {}
	var when := -1
	for town in context.colony.in_order():
		# The PC's urging: this is what *he* asked, and whom the letter answers.
		var asked: Urging = town.urging_by(Urging.PC)
		if asked == null:
			continue
		if context.month - asked.month > within:
			continue
		if town.intent == asked.target:
			continue
		if town.intent_since < asked.month:
			# He has not answered yet; a man who has not moved has not refused.
			continue
		if town.intent_since >= when:
			when = town.intent_since
			latest = {
				"governor": String(town.governor_id),
				"town": String(town.id),
				"asked": String(asked.target),
				"did": String(town.intent),
			}
	return latest


# --- The last chance (#268, `docs/mechanics/endings.md` §2, §3) -------------
#
# 🔒 **Both read the log and nothing else.** `LastChance` writes down the four
# conditions and the population every month, moved or not, and these ask it what
# changed. There is no stage object to consult, because there is no stage.


## 🔒 **One of Independence's four became true this month** (§3: *he writes as
## each condition flips*).
##
## Newly true, never merely true — a letter that fired every month a condition
## held would be nagging, from the one contact whose comic value is that he turns
## up rarely and at the worst possible moment.
static func an_independence_condition_just_flipped(
	_args: Dictionary, context: LetterContext
) -> bool:
	if context == null or context.log == null:
		return false
	return not LastChance.newly_true(context.log, context.month).is_empty()


## 🔒 **The colony fell to a rung of dwindling it has not been on before** (§2).
##
## Overrun has no conjunction to watch approach, only a number falling — so the
## formal warning §13.1 requires hangs off the number. It fires again as it
## worsens, and never twice for the same rung, so a town that loses a man and
## takes in another does not set him writing about the same figure.
static func the_colony_has_fallen_further(
	_args: Dictionary, context: LetterContext
) -> bool:
	if context == null or context.log == null:
		return false
	return LastChance.newly_dire(context.log, context.month)


## Whether this man's town holds more than one expert of some kind (#280).
##
## 🔒 **More than one, never the last man.** The scholar offers to arrange travel
## when there is somebody to spare, and a town that holds the colony's only
## weaver is not somewhere he can take one from — so the letter cannot fire on a
## colony where accepting it would do nothing.
##
## Paired with `loyalty_above` in the trigger, which is the *and* in §3's rule:
## a man at rock bottom does not offer to help.
static func i_have_experts_to_spare(_args: Dictionary, context: LetterContext) -> bool:
	if context == null or context.town == null:
		return false
	return not ExpertTransfer.spare_kinds(context.town).is_empty()


## Whether a patron has arranged for this duke to have a bad year (#284,
## `patrons.md` §5).
##
## 🔒 **What gates the third door.** *Go and collect it from Lord Magilicutty's
## house* cannot be an always-present answer to a tribute demand, because without
## that patron there is nobody to send him to — and #275's whole point is that
## offering a choice the player cannot take is worse than not offering it.
static func a_patron_can_deflect_him(_args: Dictionary, context: LetterContext) -> bool:
	if context == null or context.sender == null or context.state == null:
		return false
	return SabotageDriver.is_sabotaged(
		context.state, context.sender.id, context.state.month)


## Whether this duke is free to ask again (#284).
##
## 🔒 **The demand he skips.** Taking the third door is worth two demands — the
## one deflected and the one skipped — and this is the second. He resumes
## afterwards as though nothing had happened, because as far as he knows nothing
## did.
##
## **Phrased positively because there is no negation in the registry**, and a
## trigger reads a list of things that must be true. Naming it *free to demand*
## rather than *not holding off* also keeps the trigger file readable, which is
## the half a person checks.
static func he_is_free_to_demand(_args: Dictionary, context: LetterContext) -> bool:
	if context == null or context.sender == null or context.state == null:
		return true
	return not DeflectionExecutor.is_holding_off(
		context.state, context.sender.id, context.state.month)
