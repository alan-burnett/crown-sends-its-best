class_name CutsceneParams
extends RefCounted

## What a cutscene's caption says, in numbers and names (#299,
## `docs/mechanics/cutscenes.md` §5).
##
## 🔒 **The omniscient engine speaks here.** A cutscene is the one place the
## game reports a moment as a historical record rather than through a man's
## judgement — *Commander LeBeaux led his company of 2,400 against the Duke's
## fort; the fort fell; he lost 300.* So every value is **exact and taken from
## the event that earned the painting** or from the run as it stood, never a
## perception and never a guess.
##
## A trigger declares, per param, where it comes from; this supplies it, already
## written out — a name rather than an id, a number with its thousands. The
## caption substitutes and does nothing else, which is the letters' split
## between the engine that decides the values and the one that decides the words.
##
## ## Sources
##
## | `from` | reads | args |
## | :--- | :--- | :--- |
## | `event` | a field of the triggering event's payload (`a.b` for nested) | `field`, `as` |
## | `subject` | whom the event is about | `as` |
## | `date` | when it happened — *year 3, month 7* | |
## | `colony` | the colony as it now stands | `measure`: `people` or `towns` |
##
## `as` says what the value is and so how it is written: `number`, `people`,
## `gold`, `percent`, `town`, `tribe`, `contact`, `company`, `commander`,
## `building`, `improvement`, `place`, `side`, `text`. A `side` is an
## allegiance, and says *a duke* where the code says *rival* (`CLAUDE.md`). A `place` is a tile — `[x, y]` or
## a `Vector2i` — or a town's id, read as the ground the town stands on.

## What a value that could not be found reads as. **Visible on purpose**: a
## placeholder caption with a hole in it is a hole somebody should see.
const UNKNOWN: String = "[unknown]"

## An allegiance as a caption names it. The player hears *duke*, never *rival*.
const SIDES: Dictionary = {
	"colonial": "the colony",
	"native": "the natives",
	"rebel": "the rebels",
	"rival": "a duke",
}

const SOURCES: PackedStringArray = ["colony", "date", "event", "subject"]
const KINDS: PackedStringArray = [
	"building", "commander", "company", "contact", "gold", "improvement", "number",
	"people", "percent", "place", "side", "text", "town", "tribe",
]


## Every param a trigger declares, written out for this event and this run.
static func supply(spec: Dictionary, event: SimEvent, run: RunState) -> Dictionary:
	var out: Dictionary = {}
	var names: Array = spec.keys()
	names.sort()
	for name in names:
		var source: Variant = spec[name]
		out[String(name)] = one(source if typeof(source) == TYPE_DICTIONARY else {}, event, run)
	return out


static func one(source: Dictionary, event: SimEvent, run: RunState) -> String:
	match String(source.get("from", "")):
		"event":
			if event == null:
				return UNKNOWN
			return written(_field(event.payload, String(source.get("field", ""))),
				String(source.get("as", "text")), run)
		"subject":
			if event == null:
				return UNKNOWN
			return written(String(event.subject), String(source.get("as", "text")), run)
		"date":
			if event == null:
				return UNKNOWN
			return "year %d, month %d" % [
				event.month / WorldState.MONTHS_PER_YEAR + 1,
				posmod(event.month, WorldState.MONTHS_PER_YEAR) + 1,
			]
		"colony":
			return _colony(String(source.get("measure", "")), run)
	return UNKNOWN


## A value as the caption prints it.
static func written(value: Variant, kind: String, run: RunState) -> String:
	if value == null or (typeof(value) == TYPE_STRING and String(value).is_empty()):
		return UNKNOWN
	match kind:
		"number", "gold":
			return Figures.with_thousands(int(roundf(float(value))))
		"people":
			# The one scale letters and the summary use too (`Config`).
			return Figures.people(float(value))
		"percent":
			return "%d%%" % int(roundf(float(value) * 100.0))
		"town":
			var town: Town = null if run == null or run.colony == null \
				else run.colony.by_id(StringName(String(value)))
			return String(value) if town == null else town.display_name
		"tribe":
			var tribe: Tribe = null if run == null or run.tribes == null \
				else run.tribes.find(StringName(String(value)))
			return String(value) if tribe == null else tribe.display_name
		"contact":
			var contact: Contact = null if run == null else run.contact(StringName(String(value)))
			return String(value) if contact == null else contact.display_name
		"company":
			var commander := _commander_of(StringName(String(value)), run)
			return "the company" if commander.is_empty() else "%s's company" % commander
		"commander":
			var named := _commander_of(StringName(String(value)), run)
			return UNKNOWN if named.is_empty() else named
		"building":
			var building := Building.find(StringName(String(value)))
			return String(value) if building == null else building.display_name
		"improvement":
			var improvement := Improvement.find(StringName(String(value)))
			return String(value) if improvement == null else improvement.display_name
		"place":
			return _place(value, run)
		"side":
			return String(SIDES.get(String(value), value))
	return String(value)


static func _field(payload: Dictionary, path: String) -> Variant:
	var at: Variant = payload
	for part in path.split("."):
		if typeof(at) != TYPE_DICTIONARY or not (at as Dictionary).has(part):
			return null
		at = at[part]
	return at


static func _commander_of(company_id: StringName, run: RunState) -> String:
	if run == null or run.companies == null:
		return ""
	var company := run.companies.find(company_id)
	if company == null:
		return ""
	var commander := run.companies.commander_of(company, run.contacts)
	return "" if commander == null else commander.display_name


## *The plains near Ashmere*: the ground itself, and the nearest town to name it by.
static func _place(value: Variant, run: RunState) -> String:
	var at := Vector2i(-1, -1)
	match typeof(value):
		TYPE_VECTOR2I:
			at = value
		TYPE_ARRAY:
			if (value as Array).size() != 2:
				return UNKNOWN
			at = Vector2i(int(value[0]), int(value[1]))
		TYPE_STRING, TYPE_STRING_NAME:
			var town: Town = null
			if run != null and run.colony != null:
				town = run.colony.by_id(StringName(String(value)))
			if town == null:
				return UNKNOWN
			at = town.at
		_:
			return UNKNOWN
	var ground := "the country"
	if run != null and run.map != null:
		var terrain := Terrain.find(run.map.terrain_at(at.x, at.y))
		if terrain != null:
			ground = "the %s" % terrain.display_name.to_lower()
	var nearest: Town = null
	var best := -1
	if run != null and run.colony != null:
		for entry in run.colony.in_order():
			var town: Town = entry
			var distance := absi(town.at.x - at.x) + absi(town.at.y - at.y)
			if best < 0 or distance < best:
				best = distance
				nearest = town
	if nearest == null:
		return ground
	return "%s at %s" % [ground, nearest.display_name] if best == 0 \
		else "%s near %s" % [ground, nearest.display_name]


static func _colony(measure: String, run: RunState) -> String:
	if run == null or run.colony == null:
		return UNKNOWN
	match measure:
		"towns":
			return Figures.with_thousands(run.colony.in_order().size())
		"people":
			var people := 0
			for town in run.colony.in_order():
				people += (town as Town).population()
			return Figures.people(float(people))
	return UNKNOWN
