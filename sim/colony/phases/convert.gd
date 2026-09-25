class_name ConvertPhase
extends ColonyPhase

## **Convert.** The hands Work held back for town work do it
## (`docs/mechanics/town-economy.md` §11, #185).
##
## ## Why it is not part of Work
##
## Work ranks tiles and recipes in one list and sends hands to the winners — a
## worker is in the fields or in the town, never both. But the men in the town do
## nothing until here, four phases later, and three things follow that used to be
## enforced by scoring instead:
##
## **A town cannot brew the grain its people need**, because Consume has already
## eaten it. That was a term in the recipe scorer subtracting the input's
## valuation; now it is arithmetic that cannot be got wrong.
##
## **This month's ore can be this month's iron, and go into this month's frame.**
## Convert sits after Exchange, so a town may buy ore and smelt it rather than
## buying iron at the higher duty a processed good carries. That arbitrage is
## intended.
##
## **Processed goods are a month behind.** Beer brewed here is drunk next month
## and cloth woven here is worn next month, so buying rum comforts a town *now*
## where brewing comforts it later — a real reason to trade rather than make.
##
## The cost is that Work's survival swap can no longer answer a **clothing**
## shortage in the month it happens. No tile yields cloth, so a cold town's
## remedies are relief, purchase, or next month's loom. That is accepted rather
## than worked around: cloth takes time to make.
##
## ## 🔒 Every recipe draws the stockpile as Convert began
##
## Outputs go to the real stockpile and are **invisible to other recipes this
## month**. Without it a town with hands at the forge and the toolworks turns ore
## into tools in one month, `buildings.md`'s deep chain collapses to a single
## step, and the answer depends on which recipe the loop reached first — a result
## depending on iteration order, which is forbidden outright.
##
## The snapshot makes order irrelevant by construction, exactly as the Colony
## Month makes every town finish a phase before any town begins the next.

const EVENT_CONVERTED: StringName = &"town_converted"

## **The town has the makings and no way to make them** (#150, Seam A).
##
## A town sitting on iron it cannot forge into muskets is the whole cost of the
## gunsmith gate, and if the sim only *declined* to convert, nothing downstream
## would know it had happened — the map would show idle hands and the letters
## would have nothing to say about why.
##
## It covers a town that lost the building as well as one that never had it.
## There is no way to lose a building yet; when there is, this fires the month
## after without anything here changing.
const EVENT_CANNOT_CONVERT: StringName = &"town_cannot_convert"


func run(town: Town, _before: ColonySnapshot, context: ColonyContext) -> void:
	var assigned: Array = context.conversions.get(String(town.id), [])
	if assigned.is_empty():
		return

	# **The stores as this phase began**, spent down as recipes claim from them,
	# so two recipes cannot both smelt the same ore and nothing made here can be
	# processed here.
	var available: Dictionary = {}
	for resource in ResourceCatalogue.ids():
		available[resource] = town.held(StringName(resource))

	var made: Dictionary = {}
	var hands := 0
	for entry in assigned:
		var recipe: Conversion = entry
		if _run_recipe(town, recipe, available, made, PolicyEffects.more_of(context.state, recipe.output)):
			hands += 1

	_report_what_it_cannot_make(town, context)

	if made.is_empty():
		return

	context.log.emit(EVENT_CONVERTED, town.id, context.state.month, {
		"town": String(town.id),
		"made": made,
		"hands": hands,
	}, WorldPhase.COLONY_MONTH)


## Say what the town could be making and cannot (#150).
##
## Only for a gated recipe, and only when the town actually holds the input. A
## town with no iron is not being denied anything.
func _report_what_it_cannot_make(town: Town, context: ColonyContext) -> void:
	for entry in Conversion.all():
		var recipe: Conversion = entry
		if not ResourceCatalogue.requires_building(recipe.output):
			continue
		if recipe.available_to(town):
			continue
		if town.held(recipe.input) <= 0.0:
			continue
		context.log.emit(EVENT_CANNOT_CONVERT, town.id, context.state.month, {
			"town": String(town.id),
			"output": String(recipe.output),
			"input": String(recipe.input),
			"held": town.held(recipe.input),
			# **What would fix it**, from the data, so a governor's letter can
			# name the building rather than the prose guessing at it.
			"needs": Building.would_allow(recipe.id()),
		}, WorldPhase.COLONY_MONTH)


## Put one held-back worker to his recipe.
##
## Returns whether he was actually employed. A recipe the town has no input for
## costs no labour — which keeps "every conversion costs a worked tile" true
## without letting an *impossible* conversion cost one, and is why a town that
## sent men to the forge and found no ore is not thereby short a harvest.
func _run_recipe(
	town: Town,
	recipe: Conversion,
	available: Dictionary,
	into: Dictionary,
	more: float = 0.0,
) -> bool:
	var takes := recipe.consumes_for(town)
	if takes <= 0.0:
		return false

	var key := String(recipe.input)
	var on_hand := float(available.get(key, 0.0))
	if on_hand <= 0.0:
		return false

	# A part-supplied worker does part of the work rather than none of it.
	var share := clampf(on_hand / takes, 0.0, 1.0)
	var used := takes * share
	# 🔒 **More of a patron's kind** (#442, `patrons.md` §4): a processed kind's
	# conversions make more, from the same input.
	var output := recipe.made_by(town) * share * (1.0 + more)
	if output <= 0.0:
		return false

	available[key] = on_hand - used
	town.take(recipe.input, used)
	town.store(recipe.output, output)
	into[String(recipe.output)] = float(into.get(String(recipe.output), 0.0)) + output
	return true
