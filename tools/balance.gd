extends SceneTree

## The headless balance harness (#56, SPEC §6.2).
##
##     godot --headless --script res://tools/balance.gd -- [seeds] [years] [policy] [out_dir]
##     godot --headless --script res://tools/balance.gd -- 100 5 steady user://balance
##
## ## Why this exists
##
## SPEC §6.2 sets targets: a sensible player almost always survives year one, it
## becomes impossible to please everyone by the end of year two, and a competent
## run lasts four to eight years. **There is no way to know whether the colony
## hits those numbers by playing it a few times.** From M3 on, every balance
## decision — crown standing constants, demand growth, rebel sentiment — needs
## this to exist first.
##
## ## What it writes
##
## Two CSVs, both openable in a spreadsheet and chartable with no further
## processing:
##
## - `<policy>-years.csv` — one row per seed per year: how the colony was living,
##   what it held, what it was doing, and what the Crown made of it.
## - `<policy>-considerations.csv` — **which considerations actually drive
##   behaviour**, aggregated across every decision in every seed. A consideration
##   that never moves a decision is either mis-weighted or pointless, and there
##   is no way to tell which from a single run.
##
## ## A bad seed is a data point
##
## A seed that goes wrong reports which seed and which turn, and the batch
## carries on. A harness that stops at the first bad seed is a harness nobody
## runs.
##
## **What it can and cannot catch.** GDScript has no exception handling, so a
## hard engine-level error still takes the process down — nothing in a script can
## trap that. What this does catch is every failure that leaves the run in a
## state worth reporting: a colony wiped out, a value gone to NaN or infinity, a
## run that ended early. Those are the ones a balance batch actually produces,
## and each is checked every turn so the turn number in the report is the turn it
## went wrong rather than the turn it was noticed.

const DEFAULT_SEEDS: int = 100
const DEFAULT_YEARS: int = 5
const DEFAULT_POLICY: String = "steady"
const MONTHS_PER_YEAR: int = 12

## Where the run seeds come from. Fixed, so two batches are comparable.
const SEED_BASE: int = 20_260_918


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	var seeds: int = int(arguments[0]) if arguments.size() > 0 else DEFAULT_SEEDS
	var years: int = int(arguments[1]) if arguments.size() > 1 else DEFAULT_YEARS
	var policy_id: String = String(arguments[2]) if arguments.size() > 2 else DEFAULT_POLICY
	var out_dir: String = String(arguments[3]) if arguments.size() > 3 else "user://balance"

	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	M1Registrations.register_all()

	var content := ContentDatabase.new()
	if not content.load_all("en"):
		print(content.error_report())
		content.free()
		quit(1)
		return
	M1Registrations.load_resources(content)

	var policies := _policies(content)
	if not policies.has(policy_id):
		print("no such policy '%s'. Known: %s" % [policy_id, ", ".join(policies.keys())])
		content.free()
		quit(1)
		return
	var policy: Dictionary = policies[policy_id]

	DirAccess.make_dir_recursive_absolute(out_dir)
	var rows: Array = []
	var influence: Dictionary = {}
	var failures: Array = []
	var started := Time.get_ticks_msec()

	for index in seeds:
		var seed_value := SEED_BASE + index
		var result := _play(seed_value, years, policy, content, influence)
		# **Reported, not fatal.** The batch is worth more than the seed, and
		# whatever years it did complete are still worth having.
		rows.append_array(result["rows"])
		if result.has("error"):
			failures.append("seed %d, turn %d: %s" % [
				seed_value, int(result.get("turn", -1)) + 1, String(result["error"]),
			])

	var years_path := "%s/%s-years.csv" % [out_dir, policy_id]
	var traces_path := "%s/%s-considerations.csv" % [out_dir, policy_id]
	_write(years_path, _years_csv(rows))
	_write(traces_path, _considerations_csv(influence))

	print("%d seeds x %d years as '%s' in %.1fs" % [
		seeds, years, policy_id, float(Time.get_ticks_msec() - started) / 1000.0,
	])
	print("  %s  (%d rows)" % [years_path, rows.size()])
	print("  %s  (%d considerations)" % [traces_path, influence.size()])
	if not failures.is_empty():
		print("  %d seed(s) failed:" % failures.size())
		for line in failures:
			print("    %s" % line)

	content.free()
	quit(0)


# --- One seed ---------------------------------------------------------------

## Play a whole run under a policy. Returns `{rows}` or `{error, turn}`.
func _play(
	seed_value: int,
	years: int,
	policy: Dictionary,
	content: ContentDatabase,
	influence: Dictionary,
) -> Dictionary:
	var run := RunState.new_run(seed_value)
	ContactRoster.load_into(run, content)
	var machine := TurnMachine.new(run)
	machine.use_content(content)
	machine.saves_on_send = false

	var rows: Array = []
	var turns := years * MONTHS_PER_YEAR
	var seen_traces := 0
	var letters := 0

	for turn in turns:
		machine.begin_turn()
		letters += run.inbox.size()
		_answer(run, content, policy)
		machine.send_post()

		seen_traces = _gather(run, influence, seen_traces)

		var wrong := _what_went_wrong(run)
		if not wrong.is_empty():
			# The rows so far are still worth having: a seed that failed in year
			# four told us about years one to three.
			return {"error": wrong, "turn": turn, "rows": rows}

		if run.world.month % MONTHS_PER_YEAR == 0:
			rows.append(_row(seed_value, run, letters))
			letters = 0

	return {"rows": rows}


## Whether this run is still worth measuring, and what is wrong if not.
##
## **Checked every turn**, so the turn reported is the turn it went wrong rather
## than the turn somebody noticed.
func _what_went_wrong(run: RunState) -> String:
	if run.colony == null or run.colony.is_empty():
		return "the colony has no towns left"
	for town in run.colony.in_order():
		if town.population() <= 0:
			return "%s has nobody left in it" % town.id
		if not is_finite(town.quality_of_life):
			return "%s has a quality of life of %f" % [town.id, town.quality_of_life]
	for key in run.world.value_keys():
		var value: Variant = run.world.get_value(key, 0.0)
		if typeof(value) == TYPE_FLOAT and not is_finite(float(value)):
			return "'%s' has gone to %f" % [key, float(value)]
	return ""


## Answer the post the way this policy would.
func _answer(run: RunState, content: ContentDatabase, policy: Dictionary) -> void:
	var answers := String(policy.get("answers", "all"))
	var prefer: Array = policy.get("prefer", [])
	var tone := StringName(policy.get("tone", "dutiful"))

	for inbound in run.inbox.duplicate():
		var letter := Letter.from_record(content.record("letters", inbound.letter_id))
		if letter == null or not letter.has_reply():
			inbound.status = InboundLetter.SET_ASIDE
			continue
		if answers == "none" or (answers == "required" and letter.skippable):
			inbound.status = InboundLetter.SET_ASIDE
			continue

		var outgoing := OutgoingLetter.new(inbound.letter_id, inbound.sender)
		outgoing.in_reply_to = inbound.id
		outgoing.params = inbound.params.duplicate(true)
		var wizard := ReplyWizard.new(letter, outgoing)

		if wizard.has_tone_step():
			var options := wizard.tone_options()
			if not options.is_empty():
				wizard.choose_tone(_preferred_tone(options, tone))

		for step in letter.steps():
			var choices: Array = step.get(LetterSchema.KEY_OPTIONS, [])
			if not choices.is_empty():
				wizard.choose(String(step.get("id", "")), _preferred(choices, prefer))

		inbound.status = InboundLetter.ANSWERED
		run.post.add(outgoing)


## The first offered option this policy prefers, or the first on the letter.
##
## **A policy that matches nothing still plays.** Otherwise adding a letter would
## silently stop a reference player, and the batch would quietly measure
## something else.
func _preferred(choices: Array, prefer: Array) -> String:
	for wanted in prefer:
		for option in choices:
			if String(option.get("id", "")) == String(wanted):
				return String(option["id"])
	return String(choices[0].get("id", ""))


func _preferred_tone(options: Array, wanted: StringName) -> StringName:
	for option in options:
		if StringName(option.get("tone", "")) == wanted:
			return wanted
	return StringName(options[0]["tone"])


# --- A year's row -----------------------------------------------------------

func _row(seed_value: int, run: RunState, letters: int) -> Dictionary:
	var towns := run.colony.in_order()
	var people := 0
	var quality := 0.0
	var food := 0.0
	var hungry := 0
	var objectives: PackedStringArray = PackedStringArray()
	var intents: PackedStringArray = PackedStringArray()

	for town in towns:
		people += town.population()
		quality += town.quality_of_life * float(town.population())
		food += town.held(&"food")
		hungry += town.months_hungry
		if not String(town.objective).is_empty():
			objectives.append(String(town.objective))
		intents.append(String(town.intent))

	var ledger := Ledger.of(run.log)
	return {
		"seed": seed_value,
		"year": run.world.year_index(),
		"towns": towns.size(),
		"population": people,
		"quality_of_life": 0.0 if people == 0 else quality / float(people),
		"food_held": food,
		"months_hungry": hungry,
		"food_security": float(run.world.get_value(WorldValues.FOOD, 0.0)),
		"supply": float(run.world.get_value(WorldValues.SUPPLY, 0.0)),
		"revenue": float(run.world.get_value(WorldValues.REVENUE, 0.0)),
		"tax_base": TaxRates.base_rate(run.world),
		"tax_burden": TaxRates.burden(run.world),
		# Crown standing is M3 (#67). Until it exists, the Ledger's cumulative
		# position is the honest proxy and is what standing will be built from.
		"net_position": ledger.net_position(),
		"letters": letters,
		"promises_outstanding": run.promises.outstanding().size(),
		"intents": "|".join(intents),
		"objectives": "|".join(objectives),
	}


const COLUMNS: PackedStringArray = [
	"seed", "year", "towns", "population", "quality_of_life", "food_held",
	"months_hungry", "food_security", "supply", "revenue", "tax_base",
	"tax_burden", "net_position", "letters", "promises_outstanding",
	"intents", "objectives",
]


func _years_csv(rows: Array) -> String:
	var lines: PackedStringArray = PackedStringArray([",".join(COLUMNS)])
	for row in rows:
		var cells: PackedStringArray = PackedStringArray()
		for column in COLUMNS:
			cells.append(_cell(row.get(column, "")))
		lines.append(",".join(cells))
	return "\n".join(lines) + "\n"


## A cell a spreadsheet will read without argument.
##
## Floats are fixed to four places rather than left to `str()`, which prints
## enough digits to make a column of them unreadable.
func _cell(value: Variant) -> String:
	match typeof(value):
		TYPE_FLOAT:
			return "%.4f" % float(value)
		TYPE_STRING, TYPE_STRING_NAME:
			var text := String(value)
			return "\"%s\"" % text.replace("\"", "\"\"") if text.contains(",") else text
	return str(value)


# --- Which considerations actually matter -----------------------------------

## Fold every new trace into the running totals.
##
## `since` is the sequence already counted, so a turn's traces are read once
## however many times this is called.
func _gather(run: RunState, influence: Dictionary, since: int) -> int:
	for event in run.log.since(since):
		if event.type != Deliberation.TRACE_EVENT:
			continue
		var kind := String(event.payload.get("kind", ""))
		var chosen := String(event.payload.get("chosen", ""))
		for entry in event.payload.get("candidates", []):
			var was_chosen := String(entry.get("id", "")) == chosen
			for scored in entry.get("considerations", []):
				var key := "%s/%s" % [kind, String(scored.get("id", ""))]
				if not influence.has(key):
					influence[key] = {
						"decision": kind,
						"consideration": String(scored.get("id", "")),
						"times": 0, "total": 0.0, "peak": 0.0, "for_chosen": 0.0,
					}
				var record: Dictionary = influence[key]
				var weighted := absf(float(scored.get("weighted", 0.0)))
				record["times"] = int(record["times"]) + 1
				record["total"] = float(record["total"]) + weighted
				record["peak"] = maxf(float(record["peak"]), weighted)
				if was_chosen:
					record["for_chosen"] = float(record["for_chosen"]) + float(scored.get("weighted", 0.0))
	return run.log.next_seq()


## Per-consideration influence, not just outcomes.
##
## `mean_weight` is what it is worth on an average candidate; `peak` is the most
## it has ever been worth. **A consideration whose peak is near zero has never
## mattered to anything** — which is a finding about the design, and the sort of
## thing that is invisible from playing.
func _considerations_csv(influence: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray([
		"decision,consideration,scored,mean_weight,peak_weight,net_on_chosen",
	])
	var keys: Array = influence.keys()
	keys.sort()
	for key in keys:
		var record: Dictionary = influence[key]
		var times := maxi(1, int(record["times"]))
		lines.append("%s,%s,%d,%.4f,%.4f,%.4f" % [
			record["decision"], record["consideration"], int(record["times"]),
			float(record["total"]) / float(times),
			float(record["peak"]), float(record["for_chosen"]),
		])
	return "\n".join(lines) + "\n"


# --- Odds and ends ----------------------------------------------------------

func _policies(content: ContentDatabase) -> Dictionary:
	var out: Dictionary = {}
	for id in content.ids("balance"):
		out[String(id)] = content.record("balance", String(id))
	return out


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("could not write %s" % path)
		return
	file.store_string(text)
	file.close()
