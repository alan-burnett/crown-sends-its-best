class_name TurnMachine
extends RefCounted

## The spine of the game loop: date card, desk, send the post, resolution,
## repeat.
##
## SPEC §7's seven steps, with the cutscene and map-playback slots left as no-ops
## for M1. It **runs headless**, with no presentation layer attached, which is
## what lets the determinism tests and the balance harness drive a whole run.
##
## Three invariants live here:
##
## - **🔒 Order of time.** Letters sent this turn are acted on during the *next*
##   simulation step. Nothing the player writes changes the world instantly. The
##   Orders this turn's post produces become Intents, and an Intent committed in
##   one month executes in phase 2 of the next, so the **physical** consequence
##   lands a turn after the acknowledgment.
## - **🔒 Sending the post commits every decision in it and saves the game.**
## - **🔒 Changes of mind are allowed only within a turn.** Until the post is
##   sent, any outgoing letter may be reopened, rewritten, or discarded.

# --- Phases (SPEC §7) ------------------------------------------------------

const DATE_CARD: StringName = &"date_card"
const OPENING_CUTSCENES: StringName = &"opening_cutscenes"
const MAP_PLAYBACK: StringName = &"map_playback"
const DESK: StringName = &"desk"
const SENDING: StringName = &"sending"
const CLOSING_CUTSCENES: StringName = &"closing_cutscenes"
const RESOLUTION: StringName = &"resolution"

const ORDER: Array[StringName] = [
	DATE_CARD, OPENING_CUTSCENES, MAP_PLAYBACK, DESK, SENDING, CLOSING_CUTSCENES, RESOLUTION,
]

## The slots M1 leaves empty. They are in `ORDER` so the sequence is the spec's,
## and skipped cleanly so nothing has to special-case their absence later.
const STUBBED: Array[StringName] = [OPENING_CUTSCENES, MAP_PLAYBACK, CLOSING_CUTSCENES]

const EVENT_TURN_BEGAN: StringName = &"turn_began"
const EVENT_POST_SENT: StringName = &"post_sent"
const EVENT_ORDER_ISSUED: StringName = &"order_issued"

var run: RunState = null
var month_runner: WorldMonth = null
var prestige: PrestigeDriver = null
var expeditions: ExpeditionDriver = null
var crown_foundings: CrownFoundingDriver = null

## Where letter templates come from. Supplied rather than reached for: the
## `Content` autoload only exists when the project boots normally, and this loop
## has to run headless under `--script` for the tests and the balance harness.
var content: ContentDatabase = null

## Where the post's Orders go. #16 resolves them into Intents through compliance;
## until then they are collected so the seam is visible and testable.
var issued_orders: Array[Order] = []

## Set when the post is sent, so a caller can save exactly then and no earlier.
var save_path: String = SaveGame.SAVE_PATH
var saves_on_send: bool = true


## Carries the post to its recipients and resolves their compliance, in phase 7.
var orders: OrderDriver = null

## Settles promises, in phase 5.
var promise_driver: PromiseDriver = null

## Reads the letters the PC did not answer, in phase 7.
var silence: SilenceDriver = null

## Recomputes borders, influence and vision, in phase 3.
var territory: TerritoryDriver = null
var governors: GovernorDriver = null
var crown_standing: CrownStandingDriver = null

## Runs the eight phases of the colony month, in phase 4.
var colony_month: ColonyDriver = null

## Decides who writes to the PC, and about what.
var director: Director = null


func _init(p_run: RunState) -> void:
	run = p_run

	orders = OrderDriver.new(run.intents, run.promises)
	orders.contacts = run.contacts
	promise_driver = PromiseDriver.new(run.promises)
	promise_driver.contacts = run.contacts

	var executor := StubIntentExecutor.new()
	executor.table = order_effects()

	# The one Order that reaches a town rather than a world value. It needs the
	# colony, so it cannot live in the table above.
	var urging := UrgeIntentExecutor.new()
	# Goods leave a town over months, so a letter can still reach them (#69).
	var shipments := ShipmentExecutor.new()
	shipments.colony = run.colony
	# The Crown's one punishment before it has troops (#73, #74).
	# **The fourth asker's currency** (#69). Paying a rival costs prestige rather
	# than standing, so it goes nowhere near the Crown's books.
	# **Only while he is walking** (#177). A preference that arrived after he had
	# settled is overtaken by events, and the reply says so.
	var preferences := PreferenceExecutor.new()
	preferences.parties = run.parties

	# **The Crown's own foundings** (#180). No map unit at any point: they are
	# proposed here and appear in phase 1 months later.
	var foundings := FoundingExecutor.new()
	foundings.foundings = run.foundings

	crown_foundings = CrownFoundingDriver.new()
	crown_foundings.colony = run.colony
	crown_foundings.map = run.map
	crown_foundings.contacts = run.contacts
	crown_foundings.foundings = run.foundings

	var tribute := TributeExecutor.new()
	var embargoes := EmbargoExecutor.new()
	embargoes.colony = run.colony
	urging.colony = run.colony

	month_runner = WorldMonth.new(run.intents, run.streams)
	# Order matters only where the mechanics doc says it does; each driver
	# answers for its own phase.
	silence = SilenceDriver.new()
	silence.run = run

	territory = TerritoryDriver.new(run.map, run.colony, run.knowledge)
	territory.natives = run.tribes

	# Phase 4. The colony month replaces the stub's colony half; the phases
	# themselves arrive one ticket at a time (#44 to #50).
	colony_month = ColonyDriver.new(run.colony, run.map, run.run_seed)
	colony_month.territory_driver = territory
	colony_month.intents = run.intents
	colony_month.grievances = run.grievances
	colony_month.contacts = run.contacts
	colony_month.month.set_handler(ColonyMonth.WORK, WorkPhase.new())
	colony_month.month.set_handler(ColonyMonth.RECKON, ReckonPhase.new())
	colony_month.month.set_handler(ColonyMonth.RELIEF, ReliefPhase.new())
	colony_month.month.set_handler(ColonyMonth.EXCHANGE, ExchangePhase.new())
	colony_month.month.set_handler(ColonyMonth.CONSUME, ConsumePhase.new())
	colony_month.month.set_handler(ColonyMonth.CONVERT, ConvertPhase.new())
	colony_month.month.set_handler(ColonyMonth.BUILD, BuildPhase.new())
	colony_month.month.set_handler(ColonyMonth.SELL, SellPhase.new())
	colony_month.month.set_handler(ColonyMonth.SETTLE, SettlePhase.new())

	# Phase 8. Each governor commits to what his town is for, which next month's
	# Settle turns into a project (#53).
	governors = GovernorDriver.new(run.colony, run.map)
	governors.territory_driver = territory
	# A governor weighs how much of his own ground is somebody else's, and cannot
	# intend to drive off people he has never met (#204).
	governors.natives = run.tribes
	for id in run.contact_ids():
		var contact := run.contact(StringName(id))
		if contact != null and contact.role == Governor.ROLE:
			governors.actors[String(id)] = contact

	# Phase 6. Standing reacts to the month's duty and the month's promises, and
	# those land in phases 4 and 5 — so it judges after both (#67).
	crown_standing = CrownStandingDriver.new(run.standing, run.refusal)
	crown_standing.promises = promise_driver
	orders.colony = run.colony
	orders.policies = run.policies
	crown_standing.growth = run.demands
	crown_standing.policies = run.policies
	crown_standing.contacts = run.contacts

	# Phase 5. The standing bill, before standing is judged in phase 6: a PC who
	# has taken on more than the colony returns watches his standing fall for it
	# month after month, which is what a standing commitment ought to feel like.
	var policies := PolicyDriver.new(run.policies)
	policies.contacts = run.contacts
	# The Crown pays until the process says otherwise, which it decides monthly.
	promise_driver.can_crown_pay = run.refusal.pays()

	# Phase 5. The Crown's own business: its wars, and from year four the bar it
	# holds the colony to (#69).
	var crown_affairs := CrownAffairs.new()
	crown_affairs.growth = run.demands
	crown_affairs.demands = run.demand_book

	# Order within the list does not decide anything — each driver answers for its
	# own phase, and the phases are the mechanics doc's.
	# Phase 7. What the month did to the colony's patience, after promises have
	# settled and orders have resolved (#71).
	var grievances := GrievanceDriver.new(run.colony, run.grievances)

	# Phase 1. Settlers land before the colony works its month, so the people who
	# arrived are counted in it — and they are drawn by the quality of life last
	# month's Settle wrote (#170).
	var immigration := ImmigrationDriver.new(run.colony)

	# Phase 7, before compliance. Every contact judges the Crown by how the
	# things he cares about are going, so a governor answers this month's letter
	# in the mood this month has already put him in (#126).
	var drift := DriftDriver.new(run)

	# **After `crown_standing` and before Reckoning** (#76, `prestige.md` §6).
	# Both settle in phase 6; the order inside a phase is the order here, and
	# prestige reads the accounts standing has just judged.
	# Phase 2. Expeditions cross country before territory is recomputed, so a
	# party that came home is part of its town before that town works (#176).
	expeditions = ExpeditionDriver.new()
	expeditions.colony = run.colony
	expeditions.map = run.map
	expeditions.parties = run.parties
	expeditions.natives = run.tribes
	colony_month.parties = run.parties

	crown_affairs.colony = run.colony
	crown_affairs.contacts = run.contacts

	prestige = PrestigeDriver.new(run.prestige)

	# Phase 4, beside the Colony Month. The villages work their land and feed
	# their people on the same ground the towns do (#205). Nothing reads across,
	# so the order between the two decides nothing.
	var villages := VillageDriver.new(run.tribes, run.map)

	# Phase 7. What the month did to the neighbours, asked after the Colony Month
	# so the fields a town worked are fields it has actually worked (#204).
	var standings := StandingDriver.new()
	standings.colony = run.colony
	standings.natives = run.tribes
	standings.map = run.map
	standings.territory_driver = territory

	# Phase 7, after the standing movers. What a people will offer depends on
	# what the month has just done to their regard for the colony (#206).
	var native_trade := NativeTradeDriver.new()
	native_trade.colony = run.colony
	native_trade.natives = run.tribes
	native_trade.book = run.native_trade
	native_trade.map = run.map
	colony_month.native_trade = run.native_trade
	colony_month.natives = run.tribes

	month_runner.drivers = [
		immigration, crown_foundings, expeditions, crown_affairs, territory,
		colony_month, villages, promise_driver, standings, native_trade,
		policies, crown_standing, prestige, drift, orders, silence, governors,
		grievances,
	]
	# The specific executor is asked first; the table-driven one answers for
	# everything else.
	month_runner.executors = [
		urging, shipments, embargoes, tribute, preferences, foundings, executor,
	]


## What each kind of Order does to the world.
##
## **The turn loop owns this because it is the only place that can see both
## sides**: the Order kinds belong to the correspondence layer, the world values
## belong to the sim, and neither may name the other.
##
## Until this existed every Order the player wrote stalled for want of an
## executor — the seam was built and nothing was plugged into it, so nothing the
## player decided ever reached the world.
##
## The numbers are placeholders against the stub world and go with it in M2. What
## is not a placeholder is that **every Order kind appears here**: an Order with
## no effect says so with an empty target and completes, rather than stalling.
## A stall means "nothing could carry this out", which is a much louder claim and
## should be rare.
static func order_effects() -> Dictionary:
	return {
		# Sending gold and resources costs the colony, in proportion to what the
		# letter promised — which is what makes the amount a real choice.
		String(M1Registrations.ORDER_PROMISE_GOLD):
			{"target": WorldValues.REVENUE, "amount_factor": -1.0},
		String(M1Registrations.ORDER_PROMISE_RESOURCE):
			{"target": WorldValues.SUPPLY, "amount_factor": -0.05},
		# **Accepting a revenue target moves nothing.** It is a statement about
		# what the colony will return, not an instruction to the colony — and the
		# whole point is that the colony either reaches it or does not, on its own
		# terms. The promise it creates is where it bites.
		String(M1Registrations.ORDER_PROMISE_REVENUE): {"target": ""},
		# Undertaking goods moves nothing either. What moves is the shipment the
		# PC then has to persuade a governor to make.
		String(M1Registrations.ORDER_PROMISE_SHIPMENT): {"target": ""},
		# Troops arrive and are fed and armed out of the colony's stores.
		String(M1Registrations.ORDER_REQUEST_TROOPS):
			{"target": WorldValues.SUPPLY, "per_month": 6.0},
		# These land on the Relationship rather than on the world. The stub has no
		# tax model, and inventing one here would be M3's work done badly.
		# A tax change names the world value it moves, because which rate it is
		# depends on the resource the letter asked about.
		String(M1Registrations.ORDER_SET_TAX_RATE):
			{"target_from_data": "key", "set_from_data": "rate"},
		String(M1Registrations.ORDER_SET_POLICY): {"target": ""},
		String(M1Registrations.ORDER_GRANT_FAVOR): {"target": ""},
		String(M1Registrations.ORDER_ADJUST_LOYALTY): {"target": ""},
		String(M1Registrations.ORDER_REFUSE): {"target": ""},
		# Declining moves no world value. What it costs is Crown standing, and the
		# standing driver reads it off the log in phase 6.
		String(M1Registrations.ORDER_DECLINE_DEMAND): {"target": ""},
		# Goods move through `ShipmentExecutor`, over months, rather than through a
		# world value. Listed so that every Order kind is accounted for here.
		String(M1Registrations.ORDER_SHIP_RESOURCE): {"target": ""},
		# An embargo reaches a town rather than a world value, through
		# `EmbargoExecutor`.
		String(M1Registrations.ORDER_EMBARGO): {"target": ""},
		# **Tribute touches the Crown's books not at all**, which is exactly what
		# makes it dangerous: nothing in standing notices, and the court does.
		String(M1Registrations.ORDER_PAY_TRIBUTE): {"target": ""},
		# A preference moves no world value. What it moves is a governor already
		# walking, which is `PreferenceExecutor`'s business (#177).
		String(M1Registrations.ORDER_PREFER_SITE): {"target": ""},
		# The cost of a Crown founding lands through the letter's other effect, a
		# `promise_gold` on the ordinary promise path — not here (#180).
		String(M1Registrations.ORDER_FUND_FOUNDING): {"target": ""},
		String(M1Registrations.ORDER_DISSUADE_FOUNDING): {"target": ""},
		# A policy is enacted when the enactor agrees to it, in phase 7, and
		# billed from phase 5 thereafter. It moves no world value on its own.
		String(M1Registrations.ORDER_ENACT_POLICY): {"target": ""},
		# Funding one and ending one both reach the policy book, in phase 7.
		String(M1Registrations.ORDER_FUND_POLICY): {"target": ""},
		String(M1Registrations.ORDER_END_POLICY): {"target": ""},
		# Urging an intent reaches the town rather than a world value, so
		# `UrgeIntentExecutor` handles it. Listed here so that every Order kind is
		# still accounted for in one place.
		String(M1Registrations.ORDER_URGE_INTENT): {"target": ""},
	}


# --- Driving the turn ------------------------------------------------------

## Begin a turn: the date card, the stubbed cutscene and playback slots, and then
## the desk. Stops there, because **only the desk has decisions**.
## Supply the letter content, and with it the director that reads it.
func use_content(p_content: ContentDatabase) -> void:
	content = p_content
	silence.content = p_content
	director = Director.new(p_content)


func begin_turn() -> void:
	run.phase = DATE_CARD
	run.log.emit(EVENT_TURN_BEGAN, &"run", run.world.month, {
		"turn": run.turn,
		"month": run.world.month,
		"year": run.world.year_index(),
		"month_of_year": run.world.month_of_year(),
	})
	for phase in ORDER:
		if phase == DESK:
			break
		run.phase = phase
	run.phase = DESK

	# The month's letters arrive, acknowledging what became of last month's post.
	if director != null:
		run.inbox = director.compose_inbox(run, orders.results)


func at_desk() -> bool:
	return run.phase == DESK


## Whether this run is finished, by any route.
func is_over() -> bool:
	return run.ending != null and run.ending.is_over()


## Leave the desk for good (#77, SPEC §13.2).
##
## 🔒 **Scored from the state at that moment.** Prestige reflects the Crown's
## current view and can fall, so retiring from a losing position can beat hanging
## on while gold and goodwill drain away — and the score is the one the PC is
## standing on rather than one waiting at the finish line.
##
## 🔒 **Ironman: the save is closed out** (SPEC §16.2). A retired run cannot be
## resumed, and this is where that becomes true.
##
## Confirmation is the caller's job, exactly as it is for `send_post` — this is
## the irreversible half. **Available from any desk phase**, including with
## letters unanswered and a post half-written: a man who has decided to go does
## not owe the Crown his correspondence first.
func retire() -> bool:
	if is_over():
		return false
	run.ending = RunEnding.end(RunEnding.RETIRED, run.log, run.world.month)
	run.phase = RESOLUTION
	if saves_on_send:
		SaveGame.delete_save(save_path)
	return true


## Whether the post may be sent.
##
## Blocked while any incoming letter is still unread, **with a reason**, because
## a send button that simply does nothing is worse than one that explains itself.
func can_send() -> Dictionary:
	if is_over():
		return {"ok": false, "reason": "The run is over."}
	if run.phase != DESK:
		return {"ok": false, "reason": "The post can only be sent from the desk."}
	var unread := run.unread()
	if not unread.is_empty():
		return {
			"ok": false,
			"reason": "%d letter%s still unanswered." % [unread.size(), "" if unread.size() == 1 else "s"],
		}
	return {"ok": true, "reason": ""}


## Send the post: commit every Order in it, save, and resolve the month.
##
## Confirmation is the caller's job (#23) — this is the irreversible half, and it
## refuses to run while anything is unhandled.
func send_post() -> bool:
	var permission := can_send()
	if not permission["ok"]:
		push_error("The post cannot be sent: %s" % permission["reason"])
		return false

	run.phase = SENDING

	# Whatever the player set aside travels with the post as silence, and is read
	# next month in the same phase a reply would have been.
	for inbound in run.inbox:
		if inbound.status == InboundLetter.SET_ASIDE:
			silence.pending.append(inbound)

	issued_orders = _build_orders()
	# **The Crown stops waiting once he has answered.** A demand for goods stands
	# across several posts so the PC can write to a governor first (#69), and this
	# is what closes it — either answer will do, since declining plainly is an
	# answer and the Marshal would rather have it than silence.
	for order in issued_orders:
		if order.kind == M1Registrations.ORDER_PROMISE_SHIPMENT 				or order.kind == M1Registrations.ORDER_DECLINE_DEMAND:
			run.demand_book.answer()
	# The post goes aboard. It is read next month, in phase 7.
	for order in issued_orders:
		orders.carry(order)
	run.post.seal()

	run.log.emit(EVENT_POST_SENT, &"pc", run.world.month, {
		"turn": run.turn,
		"letters": run.post.size(),
		"orders": issued_orders.size(),
	}, WorldPhase.DISPATCH)

	for phase in [CLOSING_CUTSCENES, RESOLUTION]:
		run.phase = phase
		if phase == RESOLUTION:
			_resolve()

	# **The save happens as part of sending**, not on a timer and not on quit.
	#
	# After the resolution rather than before it, so that killing the process the
	# instant the post goes loses nothing: the saved state is the start of the
	# next turn, with the month already run. Saving first would leave a resume
	# holding a sealed post and a month that had not happened yet.
	if saves_on_send:
		SaveGame.save(run, save_path)

	return true


## The simulation runs. This is the **next** step relative to the post just sent,
## which is what "nothing the player writes changes the world instantly" means.
func _resolve() -> void:
	run.last_diff = month_runner.run(run.world, run.log)
	run.turn += 1
	run.inbox.clear()
	run.post = Post.new()
	run.phase = DATE_CARD


## Turn the post's choices into Orders.
##
## **An Order is never a write.** Building them here, at send time rather than as
## the player clicks, is what makes rewriting an outgoing letter free: nothing
## downstream has happened yet.
func _build_orders() -> Array[Order]:
	var orders: Array[Order] = []
	for outgoing in run.post.all():
		var letter := _letter(outgoing.letter_id)
		if letter == null:
			continue
		var context := _context_for(outgoing, letter)
		for step in letter.steps():
			var step_id := String(step.get("id", ""))
			if not outgoing.has_chosen(step_id):
				continue
			var option := _option(step, outgoing.chosen_for(step_id))
			if option.is_empty():
				continue
			for effect_id in option.get(LetterSchema.KEY_EFFECT, {}):
				var order := ContentRegistry.run_effect(
					String(effect_id), option[LetterSchema.KEY_EFFECT][effect_id], context
				)
				if order == null:
					continue
				order.id = StringName("%s.%s" % [outgoing.id, step_id])
				# 🔒 **Harsh orders come from the PC only** (#71). This loop runs
				# over his outgoing post and nothing else, so an NPC's Intent can
				# never arrive carrying it however the content is authored.
				order.harsh = bool(option.get(LetterSchema.KEY_HARSH, false))
				orders.append(order)
				run.log.emit(EVENT_ORDER_ISSUED, order.addressed_to, run.world.month,
					order.to_dict(), WorldPhase.DISPATCH)
	return orders


func _context_for(outgoing: OutgoingLetter, _letter: Letter) -> LetterContext:
	var context := LetterContext.new(run.world, run.contact(outgoing.addressed_to), outgoing.tone)
	context.diff = run.last_diff
	context.params = outgoing.params
	return context


func _letter(letter_id: String) -> Letter:
	if content == null:
		push_error("TurnMachine has no content source.")
		return null
	if not content.has_record("letters", letter_id):
		push_error("No letter '%s'." % letter_id)
		return null
	return Letter.from_record(content.record("letters", letter_id))


## The chosen option, or an empty dictionary. Typed rather than `Variant` so the
## call site stays statically typed — an inferred Variant is a parse error here.
func _option(step: Dictionary, option_id: String) -> Dictionary:
	for option in step.get(LetterSchema.KEY_OPTIONS, []):
		if String(option.get("id", "")) == option_id:
			return option
	return {}
