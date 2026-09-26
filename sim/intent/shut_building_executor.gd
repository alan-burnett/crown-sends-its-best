class_name ShutBuildingExecutor
extends IntentExecutor

## A building a town may not pay for, for a while (#438).
##
## 🔒 **Dark exactly as an unpaid building is** (`buildings.md` §3): it stands,
## it keeps nothing it had, and `Upkeep` will not pay for it until the months
## are out. After that it lights again as soon as the town can pay, like any
## other dark building, with no repair and no rebuilding.
##
## Its first user is the gunsmith whose machines broke and were not mended
## (`GunsmithMachines`), which is why it lands through an Intent: the Crown's
## answer is a letter, and a letter never writes the world (Seam B, C).

const KIND: StringName = &"shut_a_building"

const EVENT_SHUT: StringName = &"building_shut"

var run: RunState = null


func handles(intent: Intent) -> bool:
	return intent.kind == KIND


func execute(intent: Intent, state: WorldState, log: EventLog) -> StringName:
	var town: Town = null if run == null or run.colony == null \
		else run.colony.by_id(StringName(intent.data.get("town", "")))
	var building := StringName(intent.data.get("building", ""))
	var months := int(intent.data.get("months", 0))
	if town == null or not town.has_building(building) or months <= 0:
		return Intent.ABANDONED
	var until := state.month + months
	town.shut(building, until)
	log.emit(EVENT_SHUT, town.id, state.month, {
		"town": String(town.id),
		"building": String(building),
		"name": Building.find(building).display_name,
		"until": until,
		"because": String(intent.data.get("because", "")),
	}, WorldPhase.MOVEMENT)
	intent.progress = intent.months_required
	return Intent.COMPLETED
