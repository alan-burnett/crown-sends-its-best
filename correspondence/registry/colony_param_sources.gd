class_name ColonyParamSources
extends RefCounted

## Where a governor's letter gets the facts about his town (#54).
##
## **`{param:}` slots are exact and truthful** (SPEC §9.7). The bias lives in
## `{perception:}` and nowhere else, so everything here is the plain number or
## the plain name. A governor may be gloomy about how much grain there is; he
## does not misreport which building he is putting up.
##
## Named static functions, not lambdas — a lambda in a static registry crashes
## Godot 4.7 on shutdown (CLAUDE.md).

static func register_all() -> void:
	ContentRegistry.register_param_source(
		"warning_turns", {}, ColonyParamSources.warning_turns
	)
	ContentRegistry.register_param_source("sender_id", {}, ColonyParamSources.sender_id)
	ContentRegistry.register_param_source("town_name", {}, ColonyParamSources.town_name)
	ContentRegistry.register_param_source(
		"objective_name", {"fallback": "string"}, ColonyParamSources.objective_name
	)
	ContentRegistry.register_param_source(
		"finished_name", {"fallback": "string"}, ColonyParamSources.finished_name
	)
	ContentRegistry.register_param_source("intent_name", {}, ColonyParamSources.intent_name)
	ContentRegistry.register_param_source(
		"intent_pursuing", {}, ColonyParamSources.intent_pursuing
	)
	ContentRegistry.register_param_source(
		"town_lacks", {"fallback": "string"}, ColonyParamSources.town_lacks
	)
	ContentRegistry.register_param_source(
		"town_stock", {"resource": "string"}, ColonyParamSources.town_stock
	)
	ContentRegistry.register_param_source(
		"town_lacking_stock", {}, ColonyParamSources.town_lacking_stock
	)
	ContentRegistry.register_param_source("town_trade", {}, ColonyParamSources.town_trade)
	ContentRegistry.register_param_source(
		"town_population", {}, ColonyParamSources.town_population
	)
	ContentRegistry.register_param_source("years_served", {}, ColonyParamSources.years_served)
	ContentRegistry.register_param_source(
		"crown_demand", {"field": "string"}, ColonyParamSources.crown_demand
	)
	ContentRegistry.register_param_source(
		"town_surplus", {"fallback": "string"}, ColonyParamSources.town_surplus
	)
	ContentRegistry.register_param_source(
		"town_surplus_amount", {}, ColonyParamSources.town_surplus_amount
	)
	ContentRegistry.register_param_source(
		"town_months_out", {}, ColonyParamSources.town_months_out
	)
	ContentRegistry.register_param_source(
		"recalled", {"reach": "string", "field": "string"}, ColonyParamSources.recalled
	)


## How many letters the Treasury will still honour.
##
## **The deadline, in something the player can count** (#68). A window he cannot
## see is a trap rather than an opportunity, and this is how the Chancellor says
## it without anybody seeing a standing figure.
static func warning_turns(_args: Dictionary, _context: LetterContext) -> Variant:
	return CrownRefusal.WARNING_TURNS


## How many years the PC has held the post.
##
## Exact and truthful, so it belongs in a `{param:}` rather than a
## `{perception:}` — the Chancellor may be unpleasant about the length of a
## man's tenure but he is not wrong about the number.
static func years_served(_args: Dictionary, context: LetterContext) -> Variant:
	return 0 if context.state == null else context.state.year_index() - 1


## What the Crown asked for, exactly as it asked for it (#69).
##
## **Exact and truthful**, so it is a `{param:}`. The Steward's opinion of the
## figure is his own and belongs in a `{perception:}`; the figure itself is the
## thing the promise will be settled against, and a letter that rounded it would
## be settling the player against a number he was never shown.
static func crown_demand(args: Dictionary, context: LetterContext) -> Variant:
	var book := context.demand_book
	if book == null:
		return 0
	match String(args.get("field", "")):
		"amount":
			return int(roundf(book.amount)) if book.kind == DemandBook.KIND_RESOURCE \
				else book.amount
		"months":
			return book.term_months
		"resource":
			return String(book.resource)
		"turns_left":
			return book.turns_left(context.month)
	return 0


## Who the letter came from, so a reply can be addressed back without the file
## hard-coding a contact id.
##
## **This is what makes a governor letter set reusable.** M4 brings a second
## governor and a second town; without it, every letter file would name Ashmere
## and the set would have to be copied per town, which is a content-scaling
## problem the folder-per-language rule was designed to avoid (SPEC §9.7).
static func sender_id(_args: Dictionary, context: LetterContext) -> Variant:
	return String(context.sender.id) if context.sender != null else ""


static func town_name(_args: Dictionary, context: LetterContext) -> Variant:
	return context.town.display_name if context.town != null else "the colony"


## What the town is working on, by name. Never its id, and never a tile.
static func objective_name(args: Dictionary, context: LetterContext) -> Variant:
	if context.town == null:
		return args.get("fallback", "the work")
	var name := Objective.display_name(context.town.objective)
	return name if not name.is_empty() else args.get("fallback", "the work")


## What the town last finished, by name.
static func finished_name(args: Dictionary, context: LetterContext) -> Variant:
	if context.town == null:
		return args.get("fallback", "the work")
	var name := Objective.display_name(context.town.last_completed)
	return name if not name.is_empty() else args.get("fallback", "the work")


## What the governor is *for*, as a noun phrase.
static func intent_name(_args: Dictionary, context: LetterContext) -> Variant:
	if context.town == null:
		return "the colony"
	return Objective.intent_name(context.town.intent)


## What he says he is doing, as a clause.
static func intent_pursuing(_args: Dictionary, context: LetterContext) -> Variant:
	if context.town == null:
		return "doing what I can"
	return Objective.intent_pursuing(context.town.intent)


## The need the town is furthest from covering, named.
##
## **The worst one**, on the same worst-first rule Relief serves need by, so the
## letter and the simulation agree about which shortage matters.
static func town_lacks(args: Dictionary, context: LetterContext) -> Variant:
	var town := context.town
	if town == null:
		return args.get("fallback", "supplies")

	var worst := ""
	var deepest := INF
	for resource in ColonyNeeds.needed_resources():
		var monthly := maxf(1.0, float(town.population())) * ColonyNeeds.per_head(StringName(resource))
		if monthly <= 0.0:
			continue
		var months := town.held(StringName(resource)) / monthly
		if months < deepest:
			deepest = months
			worst = resource
	return worst if not worst.is_empty() else args.get("fallback", "supplies")


## How much of something is in the store, as a whole number. A letter that
## declares an integer must never render "48.0" at the player.
static func town_stock(args: Dictionary, context: LetterContext) -> Variant:
	if context.town == null:
		return 0
	return int(roundf(context.town.held(StringName(args.get("resource", "")))))


## How much of the thing it is short of the town actually has.
##
## Paired with `town_lacks`, so the letter names one resource and counts the
## same one. Naming the shortage and then counting the grain is the sort of
## mismatch a player notices and a validator cannot.
static func town_lacking_stock(_args: Dictionary, context: LetterContext) -> Variant:
	if context.town == null:
		return 0
	var worst := String(town_lacks({"fallback": ""}, context))
	return 0 if worst.is_empty() else int(roundf(context.town.held(StringName(worst))))


## What this town has most of, over what it needs to keep.
##
## **The default the Crown would ask for**, so a composed shipment letter opens
## on something the town could plausibly send rather than on whatever is first in
## the catalogue. Comforts are excluded: the Marshal's wars do not run on rum,
## and asking a town for its beer reads as a joke rather than a requisition.
##
## Ordered by name on a tie, so the same town always suggests the same thing.
static func town_surplus(args: Dictionary, context: LetterContext) -> Variant:
	var fallback := String(args.get("fallback", "iron"))
	if context.town == null:
		return fallback
	var mouths := maxf(1.0, float(context.town.population()))

	var best := ""
	var most := 0.0
	for id in ResourceCatalogue.ids():
		var resource := StringName(id)
		if ResourceCatalogue.is_luxury(resource) or ResourceCatalogue.is_livestock(resource):
			continue
		var keep := mouths * ColonyNeeds.per_head(resource) 			* (1.0 + ColonyNeeds.reserve_months(resource))
		var spare := context.town.held(resource) - keep
		if spare > most + 0.001 or (absf(spare - most) <= 0.001 and best != "" and String(id) < best):
			most = spare
			best = String(id)
	return fallback if best.is_empty() or most <= 0.0 else best


## How much of that surplus there is, rounded to something a letter can say.
##
## Half of it rather than all: the Crown asking a town for every last bar of its
## spare iron is a demand no governor would treat as anything but confiscation,
## and the default a composed letter opens on should be one the PC might
## plausibly send unedited.
static func town_surplus_amount(_args: Dictionary, context: LetterContext) -> Variant:
	if context.town == null:
		return 0
	var resource := StringName(town_surplus({"fallback": "iron"}, context))
	var mouths := maxf(1.0, float(context.town.population()))
	var keep := mouths * ColonyNeeds.per_head(resource) 		* (1.0 + ColonyNeeds.reserve_months(resource))
	return maxi(1, int(roundf(maxf(0.0, context.town.held(resource) - keep) * 0.5)))


## How long the town was outside the Crown, in months (#74).
##
## Read off the return event rather than off the town, which has already
## forgotten: `rebelling_since` is cleared the moment it comes home, because a
## town that is back is not a town that is out.
static func town_months_out(_args: Dictionary, context: LetterContext) -> Variant:
	if context.town == null or context.log == null:
		return 0
	for event in context.log.of_type(Rebellion.EVENT_RETURNED):
		if event.subject == context.town.id:
			return int(event.payload.get("months_out", 0))
	return 0


## Something the sender actually remembers the PC doing (#127).
##
## > *Your Grace was good enough to send two hundred measures of iron in the
## > spring, when we had none.*
##
## **Always true**, because it names a real event on the record, which is what
## SPEC §9.1 requires of a letter. The bias is in `reach` — which memory this
## contact goes to — and that is framing, which §9.1 allows: a warm man leads
## with the last kindness, a sour one with the last slight, and neither is lying.
##
## `field` is `amount`, `resource` or `months_ago`. A letter asks for the pieces
## it needs and builds its own sentence, because **a stored sentence is a
## sentence no translation could reach**.
static func recalled(args: Dictionary, context: LetterContext) -> Variant:
	var field := String(args.get("field", "amount"))
	if context.sender == null or context.sender.relationship == null:
		return 0 if field != "resource" else ""

	var memory: Recollection = null
	match String(args.get("reach", "kindness")):
		"kindness":
			memory = context.sender.relationship.most_generous()
		"slight":
			memory = context.sender.relationship.most_recent_slight()
		"broken_word":
			memory = context.sender.relationship.last_broken_word()
		"in_character":
			memory = context.sender.relationship.recalled(_sourness(context.sender))

	if memory == null:
		return 0 if field != "resource" else ""
	match field:
		"amount":
			return int(roundf(memory.magnitude))
		"resource":
			return memory.subject
		"months_ago":
			return maxi(0, context.month - memory.month)
	return 0


## How sourly this contact remembers things.
##
## **Free characterisation from a weight he already has.** A man who leans hard
## on being let down reaches for the slight; a man who does not reaches for the
## kindness. Same log, same queries, different men.
static func _sourness(contact: Contact) -> float:
	return clampf(1.0 - contact.loyalty() / Relationship.MAX_LOYALTY, 0.0, 1.0)


static func town_trade(_args: Dictionary, context: LetterContext) -> Variant:
	return 0 if context.town == null else int(roundf(context.town.traded_value))


static func town_population(_args: Dictionary, context: LetterContext) -> Variant:
	return 0 if context.town == null else context.town.population()
