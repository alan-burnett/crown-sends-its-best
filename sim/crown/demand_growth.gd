class_name DemandGrowth
extends RefCounted

## How hard the Crown leans on the PC, and how that changes over a run
## (SPEC §10.2, §6.2; `docs/mechanics/crown-demands.md` §§1, 2, 6, 7).
##
## ## 🔒 Two eras, and the first one does not move
##
## **Years one to three carry a steady bar, set above what a young colony can
## produce.** A player can grant everything in year one and still watch Crown
## Standing fall, because he is paying out more than the colony returns. Nothing
## has grown; the bar was simply set above him, and his job in those years is to
## build an economy that clears it.
##
## Implementing this as a curve from month one — which is the obvious reading of
## "demands grow over time" — produces a very different game. The two eras ask
## different questions: *can you clear a fixed bar*, and then *can you keep
## clearing it while it moves*.
##
## ## The bar moves along one axis a year
##
## From year four, one of four dimensions is drawn each year and grows. Giving
## every dimension a curve makes the run impossible almost at once; drawing one
## makes runs differ.
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
## Eight entries, two of each. Draw one a year without replacement; once four
## have gone, put them back. The bucket therefore never holds more than two of
## anything, and **five of the same axis in a row is impossible** rather than
## unlikely.
##
## Note what that does and does not guarantee: a run of four is reachable, by
## taking an axis twice at the end of one bucket and twice at the start of the
## next. See `tests/test_demand_growth.gd`.
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

## The first year the bar moves. Years one to three are a level (§§1–2).
const FIRST_GROWTH_YEAR: int = 4

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

## The last year a draw was made, so a year cannot grow twice however many times
## the driver is called.
var last_drawn_year: int = 0


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


## What was drawn in a given year, or empty.
func drawn_in(year: int) -> StringName:
	var index := year - FIRST_GROWTH_YEAR
	if index < 0 or index >= history.size():
		return &""
	return StringName(history[index])


## Move the bar, if this year is one that moves it.
##
## Returns what grew, or empty. **Idempotent within a year**: the driver runs
## every month and only the first call in a growth year draws.
func advance(year: int, streams: RngStreams, log: EventLog, month: int) -> StringName:
	if year < FIRST_GROWTH_YEAR or year <= last_drawn_year:
		return &""
	last_drawn_year = year

	var drawn := _draw(streams.stream(STREAM))
	levels[String(drawn)] = level_of(drawn) + 1
	history.append(String(drawn))

	if log != null:
		log.emit(EVENT_GROWTH, &"crown", month, {
			"year": year,
			"dimension": String(drawn),
			"level": level_of(drawn),
			"levels": levels.duplicate(),
		}, WorldPhase.CROWNS_MONTH)
	return drawn


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
		"last_drawn_year": last_drawn_year,
	}


static func from_dict(data: Dictionary) -> DemandGrowth:
	var restored := DemandGrowth.new()
	restored.levels = {}
	var stored: Dictionary = data.get("levels", {})
	for dimension in DIMENSIONS:
		restored.levels[dimension] = int(stored.get(dimension, 0))
	restored.bucket = PackedStringArray(data.get("bucket", []))
	restored.history = PackedStringArray(data.get("history", []))
	restored.last_drawn_year = int(data.get("last_drawn_year", 0))
	return restored
