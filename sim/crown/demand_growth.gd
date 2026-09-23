class_name DemandGrowth
extends RefCounted

## How hard the Crown leans on the PC, and how that changes over a run
## (SPEC §10.2, §6.2; `docs/mechanics/crown-demands.md` §§1, 2, 6, 7).
##
## ## 🔒 Two eras, and the first one does not move
##
## **Year one carries a steady bar, set above what a young colony can produce.**
## A player can grant everything in year one and still watch Crown Standing fall,
## because he is paying out more than the colony returns. Nothing has grown; the
## bar was simply set above him, and his job in that year is to build an economy
## that clears it. It was three years until the Author's ruling on #339.
##
## Implementing this as a curve from month one — which is the obvious reading of
## "demands grow over time" — produces a very different game. The two eras ask
## different questions: *can you clear a fixed bar*, and then *can you keep
## clearing it while it moves*.
##
## ## 🔒 The bar moves twice a year, from year two (#339, §7)
##
## From year two, one of four dimensions is drawn **twice a year** and grows, in
## two months of the year chosen at random — so a player cannot learn when the
## next turn of the screw lands and bank against it. Giving every dimension a
## curve makes the run impossible almost at once; drawing one makes runs differ.
##
## | Dimension | What grows |
## | :--- | :--- |
## | `frequency` | Demands arrive more often |
## | `size` | Each demand asks for more |
## | `desperation` | Refusing costs more |
## | `reach` | More sources are demanding at all |
##
## ## Bucket randomisation
##
## **Written to be lifted.** True randomness will sometimes pick the same axis
## five years running, which produces a run far easier or far harder than the
## design intends through no decision the player made. Aberrant runs are not
## merely unfair — they poison tuning and scoring, because the best scores start
## coming from lucky seeds rather than from good play.
##
## Eight entries, two of each. Draw one at a time without replacement; once four
## have gone, put them back — which at two draws a year is every two years. The
## bucket therefore never holds more than two of anything, and **five of the
## same axis in a row is impossible** rather than unlikely.
##
## Note what that does and does not guarantee: a run of four is reachable, by
## taking an axis twice at the end of one bucket and twice at the start of the
## next. See `tests/test_demand_growth.gd`.
##
## ## 🔒 More hands out, and whose (§6)
##
## **When `reach` is drawn, which source appears is drawn too**: a Crown officer
## who was not asking before, a duke, or a patron. **Any draw can produce any of
## the three** — the first hand a run meets may be a patron's. There is no ladder:
## the thresholds that once put the Marshal's goods behind two hands, the dukes
## behind three and the patrons behind five were invented in code and never in a
## doc, and put the first patron in year nine at the earliest (#339).
##
## A source with no room left is not drawn — a fourth duke does not exist — so a
## draw always produces somebody while anybody is left to produce.
##
## ## Nothing here loosens
##
## No dimension reverses and no source withdraws (`crown-demands.md` §10). That
## is the method rather than an oversight: relief is the business of other
## systems, and each earns its place partly by how it loosens this.

const FREQUENCY: StringName = &"frequency"
const SIZE: StringName = &"size"
const DESPERATION: StringName = &"desperation"
const REACH: StringName = &"reach"

const DIMENSIONS: PackedStringArray = ["desperation", "frequency", "reach", "size"]

const EVENT_GROWTH: StringName = &"crown_demand_grew"

## The first year the bar moves. Year one is a level (§§1–2).
const FIRST_GROWTH_YEAR: int = 2

## 🔒 **How many times a year it moves** (#339, §7), on months drawn at random.
const DRAWS_PER_YEAR: int = 2

## The three sources *more hands out* can produce (§6). **In no order**: the
## list is sorted so the draw does not depend on how it was written.
const SOURCE_CROWN: StringName = &"crown"
const SOURCE_DUKE: StringName = &"duke"
const SOURCE_PATRON: StringName = &"patron"
const SOURCES: PackedStringArray = ["crown", "duke", "patron"]

## How many go before the bucket is topped back up. Half of it, which is what
## keeps two of any one axis the most it can ever hold.
const DRAWS_PER_REFILL: int = 4

## The RNG stream the draw comes from. Named, per `CLAUDE.md`, so the sequence
## of a run's growth does not depend on how many dice anything else has thrown.
const STREAM: StringName = &"crown"


## How many times each dimension has grown. The bar itself is derived from this
## by `DemandSchedule`, so the levels are the whole of the growth state.
var levels: Dictionary = {}

## What is left to draw. Serialised, or a reload changes the run's future, which
## SPEC §16.1's seeded generation forbids.
var bucket: PackedStringArray = PackedStringArray()

## What has been drawn, in order. Kept because the Chancellor and the Steward
## have to be able to name what changed, and because the harness reads it.
var history: PackedStringArray = PackedStringArray()

## The month each entry of `history` was drawn in.
var drawn_months: PackedInt32Array = PackedInt32Array()

## 🔒 **Which hand each `reach` draw put out**, in order (#339).
##
## The whole of what the dukes, the patrons and the Marshal's goods read to know
## whether they are asking. Serialised, because it is the run's future as much
## as the bucket is.
var sources: PackedStringArray = PackedStringArray()

## The year `growth_months` was drawn for.
var schedule_year: int = 0

## The months of `schedule_year` (0 to 11) the bar moves in, earliest first.
## Drawn once, the first time the year is seen, and serialised — a reload must
## not move the next turn of the screw.
var growth_months: PackedInt32Array = PackedInt32Array()

## How many of this year's draws have been made, so a month cannot grow twice
## however many times the driver is called.
var drawn_this_year: int = 0

## The month the bar last moved.
##
## **The Chancellor's announcement is a one-month event**, and the levels alone
## cannot say so: they read the same all year. Without this the announcement
## would either repeat for twelve months or lean on a cooldown, and a cooldown
## that happened to be shorter than a year would put the same letter on the desk
## twice.
var grew_in_month: int = -1


func _init() -> void:
	for dimension in DIMENSIONS:
		levels[dimension] = 0
	_fill()


## How many growth events this dimension has seen.
func level_of(dimension: StringName) -> int:
	return int(levels.get(String(dimension), 0))


## Whether the bar has started moving at all.
func has_begun() -> bool:
	return not history.is_empty()


## What was drawn in a given year, in order, or nothing.
func drawn_in(year: int) -> PackedStringArray:
	var out := PackedStringArray()
	for at in history.size():
		if drawn_months[at] / WorldState.MONTHS_PER_YEAR + 1 == year:
			out.append(history[at])
	return out


## How many hands of this kind the Squeeze has put out (#339).
func sources_of(source: StringName) -> int:
	return sources.count(String(source))


## Move the bar, if this month is one that moves it.
##
## Returns what grew, or empty. **Idempotent within a month**: the driver runs
## every month, and a month grows only if it is one of the year's drawn months
## and has not grown already. A caller that skips ahead catches up rather than
## losing a draw.
func advance(year: int, streams: RngStreams, log: EventLog, month: int) -> StringName:
	if year < FIRST_GROWTH_YEAR:
		return &""
	var rng := streams.stream(STREAM)
	if schedule_year != year:
		schedule_year = year
		growth_months = _schedule(rng)
		drawn_this_year = 0

	var in_year := posmod(month, WorldState.MONTHS_PER_YEAR)
	var drawn: StringName = &""
	while drawn_this_year < growth_months.size() and growth_months[drawn_this_year] <= in_year:
		drawn_this_year += 1
		drawn = _grow(year, month, rng, log)
	return drawn


## One turn of the screw.
func _grow(year: int, month: int, rng: RandomNumberGenerator, log: EventLog) -> StringName:
	var drawn := _draw(rng)
	levels[String(drawn)] = level_of(drawn) + 1
	history.append(String(drawn))
	drawn_months.append(month)
	grew_in_month = month

	# 🔒 **And whose hand it is** (#339). Drawn in the same breath, from the same
	# stream, so a seed's run of dukes and patrons is as fixed as its axes.
	var source: StringName = &""
	if drawn == REACH:
		source = _draw_source(rng)
		if not source.is_empty():
			sources.append(String(source))

	if log != null:
		log.emit(EVENT_GROWTH, &"crown", month, {
			"year": year,
			"dimension": String(drawn),
			"level": level_of(drawn),
			"levels": levels.duplicate(),
			"source": String(source),
		}, WorldPhase.CROWNS_MONTH)
	return drawn


## The two months of the year the bar moves in, drawn without replacement.
func _schedule(rng: RandomNumberGenerator) -> PackedInt32Array:
	var months := PackedInt32Array()
	for month in WorldState.MONTHS_PER_YEAR:
		months.append(month)
	var chosen := PackedInt32Array()
	for _draw_index in mini(DRAWS_PER_YEAR, months.size()):
		var at := rng.randi_range(0, months.size() - 1)
		chosen.append(months[at])
		months.remove_at(at)
	chosen.sort()
	return chosen


## 🔒 **Any of the three, whichever still has room** (§6).
##
## Evenly among the sources that can still put a hand out. Room is
## `DemandSchedule.room_for` — three dukes, as many patrons as the run allows, and
## one Crown officer, the Marshal asking for goods as well as gold, which is the
## one such ask built.
func _draw_source(rng: RandomNumberGenerator) -> StringName:
	var open := PackedStringArray()
	for source in SOURCES:
		if sources_of(StringName(source)) < DemandSchedule.room_for(StringName(source)):
			open.append(source)
	if open.is_empty():
		return &""
	return StringName(open[rng.randi_range(0, open.size() - 1)])


## Take one from the bucket, topping it back up once half of it has gone.
func _draw(rng: RandomNumberGenerator) -> StringName:
	if bucket.size() <= DIMENSIONS.size() * 2 - DRAWS_PER_REFILL:
		_fill()
	var at := rng.randi_range(0, bucket.size() - 1)
	var drawn := StringName(bucket[at])
	bucket.remove_at(at)
	return drawn


## Put two of each back, up to eight.
##
## Tops the bucket back up rather than replacing it, so an axis already spent
## this cycle does not become available again early.
func _fill() -> void:
	var counts: Dictionary = {}
	for dimension in bucket:
		counts[dimension] = int(counts.get(dimension, 0)) + 1
	for dimension in DIMENSIONS:
		for _copy in 2 - int(counts.get(dimension, 0)):
			bucket.append(dimension)
	bucket.sort()


func to_dict() -> Dictionary:
	return {
		"levels": levels.duplicate(),
		"bucket": Array(bucket),
		"history": Array(history),
		"drawn_months": Array(drawn_months),
		"sources": Array(sources),
		"schedule_year": schedule_year,
		"growth_months": Array(growth_months),
		"drawn_this_year": drawn_this_year,
		"grew_in_month": grew_in_month,
	}


static func from_dict(data: Dictionary) -> DemandGrowth:
	var restored := DemandGrowth.new()
	restored.levels = {}
	var stored: Dictionary = data.get("levels", {})
	for dimension in DIMENSIONS:
		restored.levels[dimension] = int(stored.get(dimension, 0))
	restored.bucket = PackedStringArray(data.get("bucket", []))
	restored.history = PackedStringArray(data.get("history", []))
	restored.drawn_months = PackedInt32Array(data.get("drawn_months", []))
	restored.sources = PackedStringArray(data.get("sources", []))
	restored.schedule_year = int(data.get("schedule_year", 0))
	restored.growth_months = PackedInt32Array(data.get("growth_months", []))
	restored.drawn_this_year = int(data.get("drawn_this_year", 0))
	restored.grew_in_month = int(data.get("grew_in_month", -1))
	return restored
