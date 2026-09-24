class_name MonthPlayback
extends RefCounted

## Which few of a month's events the map plays back, and for how long (#296,
## `docs/mechanics/beats.md` §6).
##
## A busy month emits hundreds of events across nearly a hundred kinds. Drawing
## them all is unwatchable, so playback has the director's problem and takes the
## director's shape: **filters first, then scoring, then a budget.**
##
## ## 🔒 Filters are locked rules, applied before scoring
##
## - **Nothing without a place.** Crown standing moving is not a map event; it
##   belongs to the ledger and the letters. Only the events in `EVENTS` are map
##   events at all, and one of those that cannot be put on a tile is dropped.
## - **Nothing outside the known map** (SPEC §11.2). An event on ground the colony
##   has never explored is not a beat however large it is. Asked of
##   `MapKnowledge`, which is the only map `presentation/` may read.
##
## ## Scoring: magnitude, then novelty
##
## **Routine repetition is damped exactly as the director damps a topic.** A town
## that grew every month for a year stops being worth a beat: each month in the
## last `DAMPER_MONTHS` that the same thing happened to the same subject takes a
## share off its score, and below `WORTH_A_BEAT` it is not played at all.
## Counted off the event log, so nothing is stored and a reload plays the same.
##
## ## 🔒 The budget is time, not count
##
## Beats differ in length, so a month is trimmed by what it costs in **seconds**
## toward `TARGET_SECONDS`, and a thin month is paced out toward it rather than
## flashing past: ten short beats and four long ones take about as long.
##
## ## 🔒 A beat that did not play is not an event that did not happen
##
## A culled beat still reached the ledger, the letters and the state. **Playback
## is the least authoritative view of the month**, and the one place it is safe to
## drop things — which is why nothing here may be read by anything but the map.
##
## ## Headless, like `ReplyWizard`
##
## This returns a list of beats; `MapScreen` plays it. A month's beat list can be
## asserted without a viewport, and it is a pure function of the log and the map
## the colony knows — same seed and decisions, same beats.

## About how long a month's playback runs, in seconds. Tuning (`beats.md` §9).
const TARGET_SECONDS: float = 20.0

## The longest one beat is ever held, however thin the month. Tuning.
const BEAT_CEILING: float = 4.0

## How far back routine repetition is remembered, in months. Tuning.
const DAMPER_MONTHS: int = 12

## What each earlier month of the same thing leaves of a beat's score. Tuning.
const DAMPING: float = 0.75

## Below this a beat is not worth the player's attention at all. Tuning.
const WORTH_A_BEAT: float = 0.05

## The asset ids a beat kind resolves to. **Never paths** (SPEC §16.3).
const SOUND_PREFIX: String = "sound.beat."
const SPRITE_PREFIX: String = "sprite.beat."

## The method on the stage that settles a map beat. One for every kind: the
## outcome of a map beat is a mark on a tile the month-end map already shows.
const SETTLES: String = "mark_beat"

## Event type -> the beat it makes: its `kind`, how much it matters before
## repetition (`magnitude`, nought to one) and how long it wants (`seconds`).
## **Adding a map event is adding a row.** Tuning, every figure.
const EVENTS: Dictionary = {
	"town_founded": {"kind": "founded", "magnitude": 0.9, "seconds": 1.6},
	"crown_founding_arrived": {"kind": "founded", "magnitude": 0.9, "seconds": 1.6},
	"town_lost": {"kind": "lost", "magnitude": 1.0, "seconds": 1.8},
	"town_stormed": {"kind": "stormed", "magnitude": 1.0, "seconds": 1.6},
	"town_declared_rebellion": {"kind": "rebellion", "magnitude": 1.0, "seconds": 1.6},
	"town_returned_to_the_crown": {"kind": "returned", "magnitude": 0.9, "seconds": 1.4},
	"battle_fought": {"kind": "battle", "magnitude": 1.0, "seconds": 1.6},
	"expedition_destroyed": {"kind": "lost_party", "magnitude": 1.0, "seconds": 1.4},
	"famine_deaths": {"kind": "starved", "magnitude": 0.8, "seconds": 1.2},
	"expedition_attacked": {"kind": "ambushed", "magnitude": 0.8, "seconds": 1.2},
	"rival_landed": {"kind": "landed", "magnitude": 0.8, "seconds": 1.4},
	"war_party_raised": {"kind": "war_party", "magnitude": 0.7, "seconds": 1.2},
	"rival_parked_on_our_ground": {"kind": "parked", "magnitude": 0.7, "seconds": 1.0},
	"company_destroyed": {"kind": "destroyed", "magnitude": 0.9, "seconds": 1.2},
	"trade_protest_declared": {"kind": "protest", "magnitude": 0.6, "seconds": 1.0},
	"company_raised": {"kind": "raised", "magnitude": 0.6, "seconds": 1.0},
	"company_raised_by_town": {"kind": "raised", "magnitude": 0.6, "seconds": 1.0},
	"expedition_turned_back": {"kind": "turned_back", "magnitude": 0.6, "seconds": 1.0},
	"expedition_launched": {"kind": "set_out", "magnitude": 0.5, "seconds": 1.0},
	"expedition_came_home": {"kind": "came_home", "magnitude": 0.4, "seconds": 0.8},
	"building_completed": {"kind": "built", "magnitude": 0.5, "seconds": 1.0},
	"improvement_built": {"kind": "improved", "magnitude": 0.4, "seconds": 0.8},
	"tribe_lost_land_to_a_town": {"kind": "took_land", "magnitude": 0.5, "seconds": 0.8},
	"village_influence_spread": {"kind": "village_spread", "magnitude": 0.4, "seconds": 0.8},
	"natives_gave": {"kind": "gift", "magnitude": 0.4, "seconds": 0.8},
	"natives_joined": {"kind": "gift", "magnitude": 0.4, "seconds": 0.8},
	"native_trade_opened": {"kind": "trade", "magnitude": 0.35, "seconds": 0.8},
	"native_trade_closed": {"kind": "trade", "magnitude": 0.4, "seconds": 0.8},
	"building_went_dark": {"kind": "went_dark", "magnitude": 0.35, "seconds": 0.8},
	"settlers_arrived": {"kind": "arrived", "magnitude": 0.35, "seconds": 0.8},
	"expert_appeared": {"kind": "expert", "magnitude": 0.3, "seconds": 0.8},
	"company_moved": {"kind": "marched", "magnitude": 0.3, "seconds": 0.7},
	"expedition_moved": {"kind": "travelled", "magnitude": 0.25, "seconds": 0.7},
	"town_grew": {"kind": "grew", "magnitude": 0.25, "seconds": 0.7},
	"village_grew": {"kind": "village_grew", "magnitude": 0.2, "seconds": 0.6},
}


## Put every map beat kind in `BeatKinds`. Idempotent. **Data only** — the
## settling method is a name the stage implements, never a callable.
static func register_kinds() -> void:
	for type in EVENTS:
		var row: Dictionary = EVENTS[type]
		var kind := String(row["kind"])
		BeatKinds.register(StringName(kind), SETTLES, float(row["seconds"]),
			SOUND_PREFIX + kind, SPRITE_PREFIX + kind)


## The beats for one month, in the order they happened.
##
## `events` is the month to play — everything the resolution emitted. `history`
## is the whole log, for the damper and for where a subject was last seen.
## `towns` and `villages` map an id to its tile; the map knows them by where they
## stand, and an event names them by id.
static func select(
	events: Array,
	history: EventLog,
	knowledge: MapKnowledge,
	towns: Dictionary,
	villages: Dictionary = {},
) -> Array[Beat]:
	# Every map kind must know its own length before the budget can be kept.
	register_kinds()
	var candidates := _candidates(events, history, knowledge, towns, villages)

	# **The budget, by score.** Best first, ties to what happened first, so the
	# same month always keeps the same beats.
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["score"]), float(b["score"])):
			return float(a["score"]) > float(b["score"])
		return int(a["seq"]) < int(b["seq"]))
	var kept: Array = []
	var spent := 0.0
	for candidate in candidates:
		var beat: Beat = candidate["beat"]
		if spent + beat.seconds() > TARGET_SECONDS:
			continue
		kept.append(candidate)
		spent += beat.seconds()

	# **Then back into the order they happened**, which is the order the month
	# is told in.
	kept.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["seq"]) < int(b["seq"]))
	var beats: Array[Beat] = []
	for candidate in kept:
		beats.append(candidate["beat"])
	_pace(beats, spent)
	return beats


## How long a list of beats plays, in seconds.
static func seconds_of(beats: Array) -> float:
	var total := 0.0
	for beat in beats:
		total += (beat as Beat).seconds()
	return total


# --- Filters and scoring -------------------------------------------------------

static func _candidates(
	events: Array,
	history: EventLog,
	knowledge: MapKnowledge,
	towns: Dictionary,
	villages: Dictionary,
) -> Array:
	if events.is_empty():
		return []
	var first_seq := int((events[0] as SimEvent).seq)
	var month := int((events[events.size() - 1] as SimEvent).month)
	var last_seen := _last_seen_before(history, first_seq)

	# **One beat per thing per subject a month.** A company that marched three
	# tiles is one march, drawn where it ended; the rest is the same beat again.
	var by_key: Dictionary = {}
	for entry in events:
		var event: SimEvent = entry
		_note_a_place(event, last_seen)
		var type := String(event.type)
		if not EVENTS.has(type):
			continue
		var at := _place_of(event, towns, villages, last_seen)
		# 🔒 **Nothing without a place, and nothing the colony has not seen.**
		if at == Beat.NOWHERE or knowledge == null \
				or knowledge.state_of(at) == MapKnowledge.UNEXPLORED:
			continue
		var key := "%s/%s" % [type, event.subject]
		var row: Dictionary = EVENTS[type]
		var score := float(row["magnitude"]) * pow(DAMPING,
			float(_months_it_happened(history, type, event.subject, month, first_seq)))
		if score < WORTH_A_BEAT:
			continue
		by_key[key] = {
			"seq": event.seq,
			"score": score,
			"beat": Beat.new(StringName(row["kind"]), event.subject,
				{"at": [at.x, at.y]}, float(row["magnitude"]), at),
		}

	var keys: Array = by_key.keys()
	keys.sort()
	var out: Array = []
	for key in keys:
		out.append(by_key[key])
	return out


## How many distinct earlier months, within `DAMPER_MONTHS`, the same thing
## happened to the same subject.
static func _months_it_happened(history: EventLog, type: String, subject: StringName, month: int, before_seq: int) -> int:
	if history == null:
		return 0
	var months: Dictionary = {}
	for entry in history.of_type(StringName(type)):
		var event: SimEvent = entry
		if event.seq >= before_seq or event.subject != subject:
			continue
		if event.month < month and month - event.month <= DAMPER_MONTHS:
			months[event.month] = true
	return months.size()


## Where an event happened, or `Beat.NOWHERE`.
##
## Its own tile if it says one; else the town it names, or that is its subject;
## else the village; else where the same subject was last seen — an expedition
## set upon says who, and its last march says where.
static func _place_of(event: SimEvent, towns: Dictionary, villages: Dictionary, last_seen: Dictionary) -> Vector2i:
	var at := _tile(event.payload.get("at", null))
	if at != Beat.NOWHERE:
		return at
	for id in [String(event.payload.get("town", "")), String(event.subject)]:
		if towns.has(id):
			return towns[id]
	var village := String(event.payload.get("village", ""))
	if villages.has(village):
		return villages[village]
	return last_seen.get(String(event.subject), Beat.NOWHERE)


static func _last_seen_before(history: EventLog, before_seq: int) -> Dictionary:
	var seen: Dictionary = {}
	if history == null:
		return seen
	for entry in history.all():
		var event: SimEvent = entry
		if event.seq >= before_seq:
			break
		_note_a_place(event, seen)
	return seen


static func _note_a_place(event: SimEvent, seen: Dictionary) -> void:
	var at := _tile(event.payload.get("at", null))
	if at != Beat.NOWHERE:
		seen[String(event.subject)] = at


static func _tile(value: Variant) -> Vector2i:
	if typeof(value) == TYPE_VECTOR2I:
		return value
	if typeof(value) == TYPE_ARRAY and (value as Array).size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Beat.NOWHERE


## 🔒 **A thin month is paced out toward the target**, never past a beat's
## ceiling, so a quiet month and a violent one take about as long to watch.
## Never shortened: the budget already trimmed a busy month to fit.
static func _pace(beats: Array[Beat], spent: float) -> void:
	if beats.is_empty() or spent <= 0.0 or spent >= TARGET_SECONDS:
		return
	var stretch := TARGET_SECONDS / spent
	for beat in beats:
		beat.hold = minf(beat.seconds() * stretch, maxf(beat.seconds(), BEAT_CEILING))
