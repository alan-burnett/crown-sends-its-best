class_name TribeGrievanceDriver
extends RefCounted

## Tribes notice what the colony does and write to the governor first; he answers
## (#435, `docs/mechanics/natives.md` §11).
##
## | Phase | What happens |
## | :--- | :--- |
## | **7 Reckoning** | the tribe takes the answers that reached it, then notices this month's acts and writes |
## | **8 Intent** | each governor answers what was written to him in an earlier month, through the kernel, and commits the answer as an Intent |
## | 2 Movement, the month after | `TribeAnswerExecutor` lands the answer: a yielded tile, a gift, men called home |
##
## So a tribe writes in month N, the governor answers in N+1, and the tribe takes
## the answer in N+2 — ⚠ assumed §11's timing. **No answer within two months is a
## refusal.**
##
## ## 🔒 Tribes react to what the colony does, not to what a governor intends
##
## Four acts, each on ground in a tribe's land or within `Intrusion`'s margin of
## it, read from the event log and the month's work (Seam A). ⚠ assumed: the same
## act on the same tile is noticed once, until it stops and starts again.
##
## ## 🔒 Whether he asks the PC first depends on his loyalty (#436, §11)
##
## | His loyalty | He |
## | :--- | :--- |
## | at or above neutral (50) | writes to the PC asking how to answer, and waits a month for the reply |
## | below neutral | decides, and tells the PC afterwards |
## | at or below the loyalty floor | decides, and says nothing |
##
## ⚠ assumed there: the thresholds are the `loyalty` consideration's —
## `Relationship.NEUTRAL_LOYALTY` and `IntentConsiderations.SEDITION_AT`.

const EVENT_TOOK: StringName = &"tribe_took_the_answer"
const EVENT_ANSWERED: StringName = &"governor_answered_a_tribe"
## 🔒 **A loyal governor asks the PC first** (#436, §11), and holds his answer a
## month for the reply.
const EVENT_ASKED: StringName = &"governor_asked_about_a_tribe"

## The Intent kind a governor's answer becomes.
const ANSWER_KIND: StringName = &"answer_a_tribe"

## How long a tribe waits before it takes silence as a refusal (§11).
const WAITS: int = 2

# --- What the answer does to their standing. Tuning (§11 *What is still open*) ------

## 🔒 **Yield or gift wins back some of what the act cost; refusal costs more; a
## threat to the stronger costs more than a refusal** (§11). Per answer, before
## the act's weight below.
const ANSWER_MOVES: Dictionary = {
	"yield": 1.0,
	"gift": 1.3,
	"refuse": -1.3,
	"threaten": -2.0,
}

## How much each act is worth answering for, so a field is not a founding. A
## warning asks nothing, so its silence costs nothing further.
const ACT_WEIGHT: Dictionary = {
	"town_founded": 3.0,
	"improvement_built": 1.0,
	"company_on_its_ground": 1.0,
	"land_worked": 0.5,
	"we_will_drive_you_off": 0.0,
}
## ⚠ assumed §11: **a tribe whose villages near the town field less than half the
## town's force backs down**, and it costs nothing further.
const BACKS_DOWN_BELOW: float = 0.5

var run: RunState = null


func _init(p_run: RunState = null) -> void:
	run = p_run


func on_phase(phase: StringName, state: WorldState, log: EventLog, streams: RngStreams) -> void:
	if run == null or run.tribes == null or run.colony == null:
		return
	var context := ColonyContext.new(state, log, streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	match phase:
		WorldPhase.RECKONING:
			_take_the_answers(context)
			_notice(context)
		WorldPhase.INTENT:
			_answer(context)


# --- 7: the tribe takes the answers --------------------------------------------------

func _take_the_answers(context: ColonyContext) -> void:
	var month := context.state.month
	for grievance in run.tribes.grievances.list:
		if grievance.taken_month >= 0:
			continue
		if not grievance.is_answered() or grievance.answered_month < 0:
			if month - grievance.month < WAITS:
				continue
			# 🔒 **Silence is a refusal** (§11).
			grievance.answer = TribeGrievance.REFUSE
			grievance.answered_month = month
		var tribe := run.tribes.find(grievance.tribe)
		if tribe == null:
			grievance.taken_month = month
			continue
		var moved := _standing_for(grievance)
		if not is_zero_approx(moved):
			tribe.move(Tribe.COLONY, moved, "the governor's answer to our letter", context, false)
		grievance.taken_month = month
		context.log.emit(EVENT_TOOK, tribe.id, month, {
			"grievance": String(grievance.id),
			"tribe": String(tribe.id),
			"town": String(grievance.town),
			"answer": String(grievance.answer),
			"backed_down": grievance.answer == TribeGrievance.THREATEN and is_zero_approx(moved),
		}, WorldPhase.RECKONING)


## What this answer does to the tribe's standing toward the colony.
func _standing_for(grievance: TribeGrievance) -> float:
	var weight := float(ACT_WEIGHT.get(String(grievance.act), 1.0))
	if grievance.answer == TribeGrievance.THREATEN:
		var town := run.colony.by_id(grievance.town)
		if town != null and _men_near(grievance.tribe, town) < BACKS_DOWN_BELOW * float(TownCompany.of(town).size):
			# **The weaker backs down**, and it costs nothing further.
			return 0.0
	return weight * float(ANSWER_MOVES.get(String(grievance.answer), ANSWER_MOVES["refuse"]))


## How many men this tribe's villages near the town could send.
func _men_near(tribe: StringName, town: Town) -> float:
	var men := 0.0
	for entry in run.tribes.villages_of(tribe):
		var village: Village = entry
		var away := maxi(absi(village.at.x - town.at.x), absi(village.at.y - town.at.y))
		if away <= OrderRule.THREAT_WITHIN:
			men += float(Muster.going_from(village))
	return men


# --- 7: what the tribe notices ---------------------------------------------------------

func _notice(context: ColonyContext) -> void:
	var book := run.tribes.grievances
	var now: Dictionary = {}
	var order: Array = []
	var month := context.state.month

	# **Land worked**: the first month a town works the tile.
	for town in run.colony.in_order():
		var keys: Array = town.harvested_at.keys()
		keys.sort()
		for key in keys:
			var parts := String(key).split(",")
			if parts.size() < 2:
				continue
			var at := Vector2i(int(parts[0]), int(parts[1]))
			_seen(now, order, TribeGrievance.LAND_WORKED, at, town, &"")

	# **An improvement built** and **a town founded**: the month it happened.
	for event in context.log.for_month(month):
		match event.type:
			&"improvement_built":
				var at := _vector(event.payload.get("at", Vector2i(-1, -1)))
				var town := _town_of_ground(at, context)
				if town != null:
					_seen(now, order, TribeGrievance.IMPROVEMENT_BUILT, at, town, &"", true)
			&"town_founded", &"crown_founding_arrived":
				var at := _vector(event.payload.get("at", []))
				# The town that founded it, or the new town itself when the Crown did.
				var by := run.colony.by_id(StringName(event.payload.get("from", "")))
				if by == null:
					by = _town_at(at)
				if by != null:
					_seen(now, order, TribeGrievance.TOWN_FOUNDED, at, by, &"", true)

	# **A company on its ground**: the first month a colonial or Crown company
	# stands there — an exploring party included.
	if run.companies != null:
		for entry in run.companies.in_resolution_order():
			var company: Company = entry
			if company.is_empty() or company.at == Company.NOWHERE:
				continue
			if company.allegiance != Company.COLONIAL and company.allegiance != Company.CROWN:
				continue
			if _town_at(company.at) != null:
				# **Men at home are not on anybody's ground**: the town itself was
				# noticed the month it was founded.
				continue
			var town := run.colony.by_id(company.support)
			if town == null:
				# ⚠ assumed §11: a Crown company's governor is the nearest town's.
				town = _nearest_town(company.at)
			if town != null:
				_seen(now, order, TribeGrievance.COMPANY_ON_ITS_GROUND, company.at, town, company.id)

	for key in order:
		var entry: Dictionary = now[key]
		if bool(entry["once"]) or not book.ongoing.has(key):
			book.write(entry["tribe"], entry["town"], entry["act"], entry["at"], entry["company"],
				context.log, month)
	book.ongoing = {}
	for key in order:
		if not bool(now[key]["once"]):
			book.ongoing[key] = true


## Record an act if it is on some tribe's ground.
func _seen(
	now: Dictionary, order: Array, act: StringName, at: Vector2i, town: Town, company: StringName,
	once: bool = false,
) -> void:
	var whose: Dictionary = Intrusion.at(at, run.tribes)
	if float(whose["depth"]) <= 0.0 or String(whose["tribe"]).is_empty():
		return
	var key := "%s|%s|%s|%d,%d|%s" % [act, String(whose["tribe"]), String(town.id), at.x, at.y, String(company)]
	if act == TribeGrievance.COMPANY_ON_ITS_GROUND:
		# Noticed per company, wherever on their ground it stands.
		key = "%s|%s|%s" % [act, String(whose["tribe"]), String(company)]
	if now.has(key):
		return
	now[key] = {
		"tribe": StringName(whose["tribe"]), "town": town, "act": act, "at": at,
		"company": company, "once": once,
	}
	order.append(key)


# --- 8: each governor answers -------------------------------------------------------------

func _answer(context: ColonyContext) -> void:
	for grievance in run.tribes.grievances.awaiting_answer(context.state.month):
		if grievance.act == TribeGrievance.WE_WILL_DRIVE_YOU_OFF:
			# Not a request: there is nothing to answer, and silence is taken
			# as what it is.
			continue
		var town := run.colony.by_id(grievance.town)
		var governor: Contact = run.contact(grievance.governor) if not String(grievance.governor).is_empty() else null
		if town == null or governor == null or governor.is_dead:
			continue
		var loyalty := governor.loyalty()
		var asks := loyalty >= Relationship.NEUTRAL_LOYALTY
		if asks:
			if grievance.asked_month < 0:
				# **He asks, and holds his answer a month** for the reply.
				grievance.asked_month = context.state.month
				context.log.emit(EVENT_ASKED, governor.id, context.state.month, {
					"grievance": String(grievance.id),
					"tribe": String(grievance.tribe),
					"town": String(town.id),
					"governor": String(governor.id),
					"act": String(grievance.act),
				}, WorldPhase.INTENT)
				continue
			if context.state.month <= grievance.asked_month:
				continue
		var village := _nearest_village(grievance.tribe, grievance.at)
		var gift := GrievanceConsiderations.gift_for(grievance, town, village, run.map)

		var deliberation := DeliberationContext.new(DecisionKind.TRIBE_GRIEVANCE, context.state, context.log)
		deliberation.phase = WorldPhase.INTENT
		deliberation.rng = context.streams.contact_stream(String(governor.id)) if context.streams != null else null
		deliberation.data = {"town": town, "grievance": grievance, "gift": gift, "map": run.map}
		var candidates: Array = []
		for answer in TribeGrievance.ANSWERS:
			candidates.append(Candidate.new(answer))
		var decision := Deliberation.choose(governor, candidates, deliberation)
		if not decision.has_choice():
			continue

		# 🔒 **Will, not a write** (Seam C): the answer is his, and what it does
		# lands the month after, through an Intent.
		grievance.answer = decision.chosen_id()
		var intent := Intent.new(&"", ANSWER_KIND, governor.id, grievance.id, 1, {
			"grievance": String(grievance.id),
			"answer": String(grievance.answer),
			"gift": gift,
		})
		intent.origin = Intent.ORIGIN_WILL
		run.intents.commit(intent, context.log, context.state.month)
		context.log.emit(EVENT_ANSWERED, governor.id, context.state.month, {
			"grievance": String(grievance.id),
			"tribe": String(grievance.tribe),
			"town": String(town.id),
			"governor": String(governor.id),
			"act": String(grievance.act),
			"answer": String(grievance.answer),
			"asked": asks,
			# 🔒 **Below neutral he tells the PC afterwards; at the floor he says
			# nothing** (§11).
			"tells": not asks and loyalty > IntentConsiderations.SEDITION_AT,
			"urged": String(grievance.urged),
		}, WorldPhase.INTENT)


# --- Where things are ------------------------------------------------------------------------

## The town whose ground a tile is: the one whose territory holds it, or the
## nearest.
func _town_of_ground(at: Vector2i, context: ColonyContext) -> Town:
	var territory := run.territory_now()
	if territory != null:
		for town in run.colony.in_order():
			if territory.tiles_of(town.id).has(at):
				return town
	return _nearest_town(at)


func _town_at(at: Vector2i) -> Town:
	for town in run.colony.in_order():
		if town.at == at:
			return town
	return null


func _nearest_town(at: Vector2i) -> Town:
	return nearest_town(run.colony, at)


## The colony town nearest a tile, ties to the first in id order.
static func nearest_town(colony: Colony, at: Vector2i) -> Town:
	var nearest: Town = null
	var closest := 0
	if colony == null:
		return null
	for town in colony.in_order():
		var away := maxi(absi(town.at.x - at.x), absi(town.at.y - at.y))
		if nearest == null or away < closest:
			nearest = town
			closest = away
	return nearest


## The tribe's village nearest a tile: where a gift goes.
func _nearest_village(tribe: StringName, at: Vector2i) -> Village:
	var nearest: Village = null
	var closest := 0
	for entry in run.tribes.villages_of(tribe):
		var village: Village = entry
		var away := maxi(absi(village.at.x - at.x), absi(village.at.y - at.y))
		if nearest == null or away < closest:
			nearest = village
			closest = away
	return nearest


static func _vector(value: Variant) -> Vector2i:
	if typeof(value) == TYPE_VECTOR2I:
		return value
	if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)
