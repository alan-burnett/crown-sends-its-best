class_name TribeAsks
extends RefCounted

## A tribe asks a governor for help with its troubles abroad (#471,
## `natives.md` §7 *They ask for help with troubles abroad*, §3, §11; SPEC §12.5).
##
## ## 🔒 Their wars are beyond the map, and never named
##
## Tribes are neutral with the dukes and with each other (#402), so the troubles a
## tribe asks help with are somewhere the colony will never see. **Now and then**
## one asks the governor whose town borders it for guns, tools or horses: at most
## once a year, and only while its standing toward the colony is civil or better.
##
## ## 🔒 It is answered as any letter of theirs is
##
## The ask is a letter to the governor (`TribeGrievance.HELP_ABROAD`), and he
## answers it through the kernel as he answers a grievance (§11) — but **he
## gives or he refuses**, and nothing else: there is no field to yield and no
## threat to make over a request. A loyal governor asks the PC first, whose reply
## urges him through compliance. **Given, the goods leave his town and the tribe's
## standing rises; refused, it stays where it was** (§3).
##
## Every number here is a placeholder.

const EVENT_ASKED: StringName = &"tribe_asked_for_help"

## What a tribe at war somewhere else wants of the colony.
const WHAT: Array[String] = ["guns", "tools", "horses"]

## At most one ask a year per tribe.
const ONCE_IN: int = 12

## The ask is sized to the village that makes it: a unit for this many people.
const PEOPLE_PER_UNIT: float = 1_000.0

## The natives' own stream, so whether a tribe asks does not move with anything
## else in the sim.
const STREAM: String = "natives"

## The chance, each month, that a tribe which may ask does. A placeholder, and a
## knob so a test can make it certain.
const DEFAULT_CHANCE: float = 0.1
static var _chance: float = DEFAULT_CHANCE


static func set_chance(chance: float) -> void:
	_chance = clampf(chance, 0.0, 1.0)


static func reset() -> void:
	_chance = DEFAULT_CHANCE


## Every tribe that may ask this month, and does (Seam A: the ask is a letter in
## the tribe's book and an event).
static func ask(run: RunState, context: ColonyContext) -> void:
	if run == null or run.tribes == null or run.colony == null or run.colony.is_empty():
		return
	if context == null or context.streams == null:
		return
	var rng := context.streams.stream(STREAM)
	var month := context.state.month
	for entry in run.tribes.in_order():
		var tribe: Tribe = entry
		if not may_ask(tribe, context.log, month):
			continue
		if rng.randf() >= _chance:
			continue
		var village := _largest_village(tribe, run.tribes)
		if village == null:
			continue
		var town := TribeGrievanceDriver.nearest_town(run.colony, village.at)
		if town == null:
			continue
		var resource := WHAT[rng.randi_range(0, WHAT.size() - 1)]
		var amount := maxf(1.0, roundf(float(village.people) / PEOPLE_PER_UNIT))
		var letter := run.tribes.grievances.write(
			tribe.id, town, TribeGrievance.HELP_ABROAD, village.at, &"", context.log, month)
		letter.asked = {"resource": resource, "amount": amount}
		context.log.emit(EVENT_ASKED, tribe.id, month, {
			"tribe": String(tribe.id),
			"town": String(town.id),
			"governor": String(town.governor_id),
			"resource": resource,
			"amount": amount,
		}, WorldPhase.RECKONING)


## 🔒 **Civil or better, met, and not in the last year.**
static func may_ask(tribe: Tribe, log: EventLog, month: int) -> bool:
	if tribe == null or tribe.met_month < 0 or tribe.trust() < Tribe.NEUTRAL:
		return false
	if log == null:
		return true
	for event in log.of_type(EVENT_ASKED):
		if String(event.payload.get("tribe", "")) == String(tribe.id) and month - event.month < ONCE_IN:
			return false
	return true


static func _largest_village(tribe: Tribe, natives: Tribes) -> Village:
	var largest: Village = null
	for entry in natives.villages_of(tribe.id):
		var village: Village = entry
		if largest == null or village.people > largest.people:
			largest = village
	return largest
